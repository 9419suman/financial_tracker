import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../models/email_message.dart';
import '../models/bank_config.dart';
import 'bank_auth_service.dart';

class BankGmailService {
  final BankAuthService _authService;

  BankGmailService(this._authService);

  // Fetch bank statements for selected banks within a date range
  Future<List<EmailMessage>> getBankStatements({
    List<String> bankIds = const ['hdfc'],
    DateTime? after,
    DateTime? before,
    int maxResults = 50,
  }) async {
    final now = DateTime.now();
    final rangeAfter = after ?? now.subtract(const Duration(days: 180));
    final rangeBefore = before ?? now;

    final selectedBanks = bankIds.isEmpty
        ? BankConfig.all
        : bankIds
            .map((id) => BankConfig.findById(id))
            .whereType<BankConfig>()
            .toList();

    // Fetch per-bank in parallel and merge results
    final futures = selectedBanks.map((bank) => _fetchForBank(
          bank: bank,
          after: rangeAfter,
          before: rangeBefore,
          maxResults: maxResults,
        ));

    final results = await Future.wait(futures);
    final all = results.expand((e) => e).toList();

    // Deduplicate by email id and sort newest first
    final seen = <String>{};
    final unique = all.where((e) => seen.add(e.id)).toList();
    unique.sort((a, b) => b.date.compareTo(a.date));
    return unique;
  }

  Future<List<EmailMessage>> _fetchForBank({
    required BankConfig bank,
    required DateTime after,
    required DateTime before,
    required int maxResults,
  }) async {
    final query = bank.buildGmailQuery(after: after, before: before);
    print('📧 GMAIL: Querying ${bank.displayName}: $query');
    return getEmailsByQuery(query: query, maxResults: maxResults);
  }

  // Fetch emails with a specific query
  Future<List<EmailMessage>> getEmailsByQuery({String query = '', int maxResults = 20}) async {
    try {
      print('Attempting to get authenticated client...');
      final client = await _authService.getAuthenticatedClient();
      print('Successfully obtained authenticated client');
      
      print('Initializing Gmail API...');
      final gmailApi = gmail.GmailApi(client);
      print('Gmail API initialized');
      
      // Get message list with query
      print('Fetching message list with query: $query and limit: $maxResults');
      final response = await gmailApi.users.messages.list(
        'me',
        maxResults: maxResults,
        q: query.isNotEmpty ? query : null,
      );
      print('Message list fetched. Count: ${response.messages?.length ?? 0}');
      
      final messages = response.messages ?? [];
      final emails = <EmailMessage>[];
      
      // Process in parallel for better performance
      final futures = <Future<EmailMessage?>>[];
      for (var message in messages) {
        if (message.id != null) {
          futures.add(_fetchMessageDetails(gmailApi, message.id!));
        }
      }
      
      // Wait for all messages to be fetched
      final results = await Future.wait(futures);
      for (var email in results) {
        if (email != null) {
          emails.add(email);
        }
      }
      
      print('All messages fetched. Count: ${emails.length}');
      
      // Sort by date (newest first)
      emails.sort((a, b) => b.date.compareTo(a.date));
      
      return emails;
    } catch (e) {
      print('Error fetching emails: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  Future<Uint8List?> getAttachment(String messageId, String attachmentId) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      final gmailApi = gmail.GmailApi(client);
      final response = await gmailApi.users.messages.attachments.get(
        'me',
        messageId,
        attachmentId,
      );
      if (response.data != null) {
        return base64Url.decode(response.data!);
      }
    } catch (e) {
      print('Error fetching attachment: $e');
    }
    return null;
  }
  
  // Helper method to fetch message details
  Future<EmailMessage?> _fetchMessageDetails(gmail.GmailApi gmailApi, String messageId) async {
    try {
      print('Fetching message ID: $messageId');
      final detail = await gmailApi.users.messages.get('me', messageId);
      
      // Extract headers directly from the payload
      final headers = detail.payload?.headers ?? [];
      
      // Find subject and sender
      String subject = 'No Subject';
      String sender = 'Unknown';
      
      for (var header in headers) {
        if (header.name == 'Subject') {
          subject = header.value ?? 'No Subject';
        } else if (header.name == 'From') {
          sender = header.value ?? 'Unknown';
        }
      }
      
      // Extract attachments
      final attachments = <Attachment>[];
      bool hasPdfAttachment = false;
      
      // Process parts recursively to find attachments
      if (detail.payload != null) {
        _extractAttachments(detail.payload!, attachments, messageId);
        
        // Check if any attachment is a PDF
        hasPdfAttachment = attachments.any((attachment) => attachment.isPdf);
      }
      
      // Extract body text
      final body = _extractBody(detail.payload!);

      // Create email with extracted data
      return EmailMessage(
        id: detail.id ?? '',
        sender: sender,
        subject: subject,
        snippet: detail.snippet ?? 'No preview available',
        body: body,
        date: DateTime.fromMillisecondsSinceEpoch(
          int.parse(detail.internalDate ?? '0')),
        attachments: attachments,
        hasPdfAttachment: hasPdfAttachment,
      );
    } catch (messageError) {
      print('Error fetching message $messageId: $messageError');
      return null;
    }
  }
  
  // Recursively extract attachments from message parts
  void _extractAttachments(gmail.MessagePart part, List<Attachment> attachments, String messageId) {
    // Check if this part has attachments
    if (part.body?.attachmentId != null && 
        part.filename != null && 
        part.filename!.isNotEmpty) {
      
      final mimeType = part.mimeType ?? 'application/octet-stream';
      final filename = part.filename!;
      final isPdf = mimeType == 'application/pdf' || 
                    (filename.toLowerCase().endsWith('.pdf') && 
                     (mimeType == 'application/octet-stream' || mimeType.isEmpty));
      
      print('Found attachment: $filename (mimeType: $mimeType, isPdf: $isPdf, size: ${part.body?.size ?? 0} bytes)');
      
      attachments.add(Attachment(
        id: part.body!.attachmentId!,
        filename: filename,
        mimeType: mimeType,
        size: part.body?.size ?? 0,
      ));
    }
    
    // Check child parts recursively
    if (part.parts != null) {
      for (var childPart in part.parts!) {
        _extractAttachments(childPart, attachments, messageId);
      }
    }
  }
  
  // Download attachment as bytes
  Future<Uint8List?> downloadAttachment(String messageId, String attachmentId) async {
    try {
      print('BankGmailService: Downloading attachment: $attachmentId from message: $messageId');
      final client = await _authService.getAuthenticatedClient();
      print('BankGmailService: Got authenticated client');
      
      final gmailApi = gmail.GmailApi(client);
      print('BankGmailService: Initialized Gmail API');
      
      print('BankGmailService: Requesting attachment data from Gmail API');
      final attachment = await gmailApi.users.messages.attachments.get(
        'me', 
        messageId, 
        attachmentId
      );
      
      if (attachment.data != null) {
        print('BankGmailService: Got attachment data, length: ${attachment.data!.length}');
        try {
          // Convert from base64Url to Uint8List
          final bytes = base64Url.decode(attachment.data!);
          print('BankGmailService: Successfully decoded attachment, size: ${bytes.length} bytes');
          
          // Validate if this is a valid PDF by checking for the PDF header
          if (bytes.length < 5 || 
              bytes[0] != 0x25 || // %
              bytes[1] != 0x50 || // P
              bytes[2] != 0x44 || // D
              bytes[3] != 0x46 || // F
              bytes[4] != 0x2D) { // -
            print('BankGmailService: WARNING - Downloaded content does not have a valid PDF header');
            
            // Print the first few bytes for debugging
            if (bytes.isNotEmpty) {
              final headerHex = bytes.take(10).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ');
              print('BankGmailService: First 10 bytes: $headerHex');
            }
          } else {
            print('BankGmailService: PDF header validation passed');
          }
          
          return bytes;
        } catch (decodeError) {
          print('BankGmailService: Error decoding attachment data: $decodeError');
          return null;
        }
      } else {
        print('BankGmailService: Attachment data is null');
        return null;
      }
    } catch (e) {
      print('BankGmailService: Error downloading attachment: $e');
      print('BankGmailService: Stack trace: ${StackTrace.current}');
      return null;
    }
  }
  
  // Fetch the last 100 emails (original method for backward compatibility)
  Future<List<EmailMessage>> getLastEmails({int maxResults = 20}) async {
    return getEmailsByQuery(maxResults: maxResults);
  }

  // Recursively extract plain text from message parts (mirrors Python get_email_body)
  String _extractBody(gmail.MessagePart part) {
    final buffer = StringBuffer();
    final mime = part.mimeType ?? '';
    final data = part.body?.data;

    if (data != null && data.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64Url.decode(data), allowMalformed: true);
        if (mime == 'text/plain') {
          buffer.write(decoded);
        } else if (mime == 'text/html') {
          // Strip HTML tags
          buffer.write(decoded.replaceAll(RegExp(r'<[^>]+>'), ' '));
        }
      } catch (_) {}
    }

    for (final child in part.parts ?? []) {
      buffer.write(_extractBody(child));
    }

    // Collapse excessive whitespace
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
} 