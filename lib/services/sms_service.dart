import 'dart:convert';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/message_model.dart';
import '../gemini_api_fin.dart';
import 'cache_service.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();
  late final GeminiApi _geminiApi;
  final CacheService _cacheService = CacheService();
  
  SmsService() {
    // Initialize Gemini API from .env file
    _geminiApi = GeminiApi.fromEnv();
  }
  
  // Extract user accounts from environment variables
  List<String> _extractMyAccounts() {
    final myAccounts = dotenv.env['MY_ACCOUNTS'] ?? '';
    if (myAccounts.isEmpty) {
      return [];
    }
    return myAccounts.split(',').map((account) => account.trim()).where((account) => account.isNotEmpty).toList();
  }
  
  // Extract known parties from environment variables
  List<Map<String, String>> _extractKnownParties() {
    final knownPartiesJson = dotenv.env['KNOWN_PARTIES'] ?? '';
    if (knownPartiesJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> parties = jsonDecode(knownPartiesJson);
      return parties.map((party) => {
        'name': party['name']?.toString() ?? '',
        'label': party['label']?.toString() ?? '',
      }).where((party) => party['name']!.isNotEmpty).toList();
    } catch (e) {
      print('📱 SMS_SERVICE: ❌ Error parsing known parties: $e');
      return [];
    }
  }
  
  // Request SMS permissions
  Future<bool> requestSmsPermission() async {
    var status = await Permission.sms.status;
    
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    
    return status.isGranted;
  }
  
  // Get all SMS messages
  Future<List<MessageWithAmount>> getAllMessages() async {
    final bool hasPermission = await requestSmsPermission();
    
    if (!hasPermission) {
      return [];
    }
    
    try {
      final messages = await _query.querySms();
      return messages.map((message) => MessageWithAmount.fromSmsMessage(message)).toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }  // Process messages with Gemini API
  Future<List<MessageWithAmount>> processMessagesWithGemini(List<MessageWithAmount> messages) async {
    if (messages.isEmpty) {
      print("📱 SMS_SERVICE: No messages to process with Gemini");
      return [];
    }
    
    try {
      print("📱 SMS_SERVICE: Starting processing for ${messages.length} messages");
      
      // First, try to get cached messages as dictionaries
      List<Map<String, dynamic>> cachedMessageDicts = [];
      try {
        cachedMessageDicts = await _cacheService.getCachedMessages();
        print("📱 SMS_SERVICE: Retrieved ${cachedMessageDicts.length} message dictionaries from cache");
      } catch (e) {
        print("📱 SMS_SERVICE: ❌ Error retrieving cached messages: $e");
        // Continue with an empty cache if there's an error
        cachedMessageDicts = [];
      }
        
      // Create a map for faster lookup of cached messages by ID
      final Map<String, Map<String, dynamic>> cachedMessagesMap = {};
      for (var messageDict in cachedMessageDicts) {
        final String msgId = messageDict['message_id']?.toString() ?? '';
        if (msgId.isNotEmpty) {
          cachedMessagesMap[msgId] = messageDict;
          
          // Enhanced debug log to see what's in the cache with more details
          final String msgPreview = messageDict['message_body'] != null 
              ? (messageDict['message_body'].toString().length > 30 
                  ? messageDict['message_body'].toString().substring(0, 30) + "..." 
                  : messageDict['message_body'].toString())
              : "[no body]";
          // print("📱 SMS_SERVICE: Cached message ID: $msgId (Preview: $msgPreview)");
        }
      }
      
      // Create lists for cached and non-cached messages
      List<MessageWithAmount> processedMessages = [];
      List<MessageWithAmount> messagesToProcess = [];
      
      // Separate messages that are already cached from those that need processing
      for (var message in messages) {
        final String msgId = message.message.id.toString();
        final String msgPreview = message.message.body != null 
            ? (message.message.body!.length > 30 
                ? message.message.body!.substring(0, 30) + "..." 
                : message.message.body!)
            : "[no body]";
        
        // Debug to see what we're checking
        print("📱 SMS_SERVICE: Checking if message ID $msgId is in cache (Preview: $msgPreview)");
        
        // Check if this message is in cache by ID
        if (cachedMessagesMap.containsKey(msgId)) {
          // If it's in cache, convert the cached dictionary to MessageWithAmount
          print("📱 SMS_SERVICE: Found message $msgId in cache");
          
          final cachedDict = cachedMessagesMap[msgId]!;
          
          // // Create an SmsMessage from the cached data
          // int messageDate;
          // try {
          //   if (cachedDict['message_date'] != null) {
          //     messageDate = cachedDict['message_date'] is int 
          //         ? cachedDict['message_date'] 
          //         : int.parse(cachedDict['message_date'].toString());
          //   } else {
          //     messageDate = DateTime.now().millisecondsSinceEpoch;
          //   }
          // } catch (e) {
          //   print('📱 SMS_SERVICE: ⚠️ Error parsing message_date. Using current time as fallback.');
          //   messageDate = DateTime.now().millisecondsSinceEpoch;
          // }
          
          // int messageId;
          // try {
          //   messageId = int.parse(cachedDict['message_id'].toString());
          // } catch (e) {
          //   print('📱 SMS_SERVICE: ⚠️ Error parsing message_id. Using original message ID as fallback.');
          //   messageId = message.message.id ?? 0;
          // }
          
          // final smsMessage = SmsMessage.fromJson({
          //   'id': messageId,
          //   'address': cachedDict['message_sender'] ?? '',
          //   'body': cachedDict['message_body'] ?? '',
          //   'date': messageDate,
          //   'dateSent': messageDate,
          // });
          
          // Create MessageWithAmount from cached data
          final cachedMessage = MessageWithAmount(
            message: message.message,
            amount: cachedDict['amount'],
            formattedAmount: cachedDict['formatted_amount'],
            extractedAmountText: cachedDict['extracted_amount_text'] ?? '',
            isTransaction: cachedDict['is_transaction'] ?? false,
            transactionDate: cachedDict['transaction_date'] ?? 'NA',
            transactionType: cachedDict['transaction_type'] ?? 'NA',
            from_account: cachedDict['from_account'] ?? 'NA',
            to_account: cachedDict['to_account'] ?? 'NA',
            category: cachedDict['category'] ?? 'NA',
            reason: cachedDict['reason'] ?? cachedDict['description'] ?? 'NA',  // Try reason first, fall back to description
          );
          
          processedMessages.add(cachedMessage);
        } else {
          // If not in cache, add to list for processing
          print("📱 SMS_SERVICE: Message $msgId not in cache, will process");
          messagesToProcess.add(message);
        }
      }
      
      print("📱 SMS_SERVICE: ${processedMessages.length} messages from cache, ${messagesToProcess.length} messages to process");
      
      // If all messages were in cache, return them
      if (messagesToProcess.isEmpty) {
        print("📱 SMS_SERVICE: All messages found in cache, no Gemini API call needed");
        return processedMessages;
      }
        // Process only the messages that weren't in cache
      print("📱 SMS_SERVICE: Processing ${messagesToProcess.length} messages with Gemini");
      
      // Create array of message bodies with IDs for messages that need processing
      List<Map<String, dynamic>> messageDataList = messagesToProcess.map((msg) => {
        'id': msg.message.id.toString(),
        'body': msg.message.body != null ? msg.message.body! : ""
      }).toList();
      
      print("📱 SMS_SERVICE: Message data prepared for Gemini with IDs");
      
      // Extract user configuration for better categorization
      final myAccounts = _extractMyAccounts();
      final knownParties = _extractKnownParties();
      
      print("📱 SMS_SERVICE: Using ${myAccounts.length} user accounts and ${knownParties.length} known parties for categorization");
      
      // Create enhanced prompt for Gemini API
      String prompt = '''
You are an expert in identifying and parsing personal financial transactions (bank/credit card/UPI/etc.) from SMS messages. You are given a list of messages (with unique IDs) from a user's SMS inbox.

Message List : ${jsonEncode(messageDataList)}

${myAccounts.isNotEmpty ? '''
USER'S ACCOUNTS (these belong to the user):
${myAccounts.map((account) => '- $account').join('\n')}
''' : ''}

${knownParties.isNotEmpty ? '''
KNOWN PARTIES (for consistent categorization):
${knownParties.map((party) => '- ${party['name']} (Label: ${party['label']})').join('\n')}
''' : ''}

Your task is to:
1. Identify messages that reflect actual personal financial transactions (e.g., money credited, debited, or transferred via UPI or banking channels).
2. Exclude messages that do not indicate a completed transaction (like OTPs, reminders, promotional offers, payment due alerts, etc.) — such messages should be flagged appropriately.

For identified transaction messages, extract the following structured metadata:
- message_id (from input)
- transaction_flag (True if it's a financial transaction, else False)
- amount
- type (credit / debit / transfer)
- from_account (payer's account, if available)
- to_account (beneficiary's account, if available)
- category (FOOD/GROCERIES/SHOPPING/TRANSPORTATION/ENTERTAINMENT/HEALTH/UTILITIES/INCOME/P2P TRANSFER/OTHER)
- reason (brief explanation for categorization)

IMPORTANT RULES:
1. If BOTH from_account and to_account are in the user's accounts list, set type as "transfer"
2. For known parties, use the configured label for consistent categorization
3. If from_account is user's account, it's typically a "debit" transaction
4. If to_account is user's account, it's typically a "credit" transaction
5. Match account names flexibly (partial matches are okay for similar names)

For non-transactional messages, keep other fields as "NA".
Return your result as a valid JSON array, where each item maps to a message by its message_id.
''';

      print("📱 SMS_SERVICE: Gemini prompt created, calling API now");
      
      // Call Gemini API
      final response = await _geminiApi.generateContent(prompt);
      
      if (!response.success) {
        print("📱 SMS_SERVICE: ❌ Error from Gemini API: ${response.error}");
        // Return combined list of cached messages and original messages that couldn't be processed
        return [...processedMessages, ...messagesToProcess];
      }
      
      print("📱 SMS_SERVICE: ✅ Gemini API call successful");
      print("📱 SMS_SERVICE: Raw response: ${response.text.substring(0, response.text.length > 100 ? 100 : response.text.length)}...");
      
      try {
        // Parse response JSON
        print("📱 SMS_SERVICE: Attempting to parse JSON response");
        final List<dynamic> transactionData = jsonDecode(response.text);
        print("📱 SMS_SERVICE: ✅ Successfully parsed JSON with ${transactionData.length} items");
        
        // Process new messages with Gemini data
        List<MessageWithAmount> newlyProcessedMessages = [];
        
        // Create a map of transaction data by message ID for easier lookup
        Map<String, dynamic> transactionDataByMessageId = {};
        for (var transaction in transactionData) {
          if (transaction['message_id'] != null) {
            transactionDataByMessageId[transaction['message_id'].toString()] = transaction;
          }
        }
        
        // Match transactions with messages by message ID
        for (var message in messagesToProcess) {
          final String messageId = message.message.id.toString();
          print("📱 SMS_SERVICE: Looking for transaction data for message ID: $messageId");
          
          if (transactionDataByMessageId.containsKey(messageId)) {
            print("📱 SMS_SERVICE: Found transaction data for message ID: $messageId");
            
            newlyProcessedMessages.add(
              MessageWithAmount.fromGeminiResponse(message.message, transactionDataByMessageId[messageId])
            );
          } else {
            // If we don't have transaction data for this message, use original message
            print("📱 SMS_SERVICE: ⚠️ No transaction data for message ID: $messageId, using original");
            newlyProcessedMessages.add(message);
          }
        }
        
        // Save newly processed messages to cache
        print("📱 SMS_SERVICE: Saving ${newlyProcessedMessages.length} newly processed messages to cache");
        final cacheResult = await _cacheService.saveProcessedMessages(newlyProcessedMessages);
        if (cacheResult) {
          print("📱 SMS_SERVICE: ✅ Successfully saved to cache");
        } else {
          print("📱 SMS_SERVICE: ⚠️ Cache save returned false");
        }
        
        // Verify cache was updated
        final updatedCachedDicts = await _cacheService.getCachedMessages();
        print("📱 SMS_SERVICE: ✅ Cache now contains ${updatedCachedDicts.length} messages total (was ${cachedMessageDicts.length} before)");
        
        // Combine cached and newly processed messages
        final allProcessedMessages = [...processedMessages, ...newlyProcessedMessages];
        print("📱 SMS_SERVICE: ✅ Returning ${allProcessedMessages.length} total processed messages");
        
        return allProcessedMessages;
      } catch (e) {
        print("📱 SMS_SERVICE: ❌ Error parsing Gemini API response: $e");
        print("📱 SMS_SERVICE: Raw response: ${response.text}");
        // Return combined list of cached messages and original messages that couldn't be processed
        return [...processedMessages, ...messagesToProcess];
      }
    } catch (e) {
      print("📱 SMS_SERVICE: ❌ Error processing messages with Gemini: $e");
      return messages; // Return original messages if anything fails
    }
  }
    // Filter messages to only include those with amounts
  List<MessageWithAmount> getMessagesWithAmounts(List<MessageWithAmount> messages) {
    final filteredMessages = messages.where((message) => message.amount != null).toList();
    print("💰 SMS_SERVICE: Filtered for amounts: ${messages.length} → ${filteredMessages.length} messages");
    return filteredMessages;
  }
  
  // Filter messages to only include bank transactions
  List<MessageWithAmount> getBankTransactions(List<MessageWithAmount> messages) {
    final filteredMessages = messages.where((message) => message.isTransaction).toList();
    print("🏦 SMS_SERVICE: Filtered for bank transactions: ${messages.length} → ${filteredMessages.length} messages");
    return filteredMessages;
  }
}
