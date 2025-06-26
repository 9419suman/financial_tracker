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
    // Initialize Gemini API with key from .env file
    String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _geminiApi = GeminiApi(apiKey: apiKey);
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
            toAccount: cachedDict['to_account'] ?? 'NA',
            category: cachedDict['category'] ?? 'NA',
            description: cachedDict['description'] ?? 'NA',
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
      
      // Create array of message bodies for messages that need processing
      List<String> messageBodies = messagesToProcess.map((msg) => 
          msg.message.body != null ? msg.message.body! : "").toList();
      
      print("📱 SMS_SERVICE: Message bodies prepared for Gemini");
      
      // Create prompt for Gemini API
      String prompt = '''
You are expert in identifying and parsing bank (credit/debit/upi etc.) transaction. You are given the list of messages:
Message List : ${jsonEncode(messageBodies)}
Categorize each transaction and extract structured data as a list of transactions with: transaction_flag (True for bank transaction/ False for otherwise), date, amount, type (credit or debit), to_account, category, and description.
Note: Other fields for non financial (bank) transactions should be kept 'NA'
Ensure that the order of structured output matches the order of array input for ease of parsing
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
        
        // Match transactions with messages
        for (int i = 0; i < messagesToProcess.length; i++) {
          if (i < transactionData.length) {
            print("📱 SMS_SERVICE: Processing message ${i+1}/${messagesToProcess.length}");
            print("📱 SMS_SERVICE: Transaction data for message ${i+1}: ${transactionData[i]}");
            
            newlyProcessedMessages.add(
              MessageWithAmount.fromGeminiResponse(messagesToProcess[i].message, transactionData[i])
            );
          } else {
            // If we have more messages than transactions, use original message
            print("📱 SMS_SERVICE: ⚠️ No transaction data for message ${i+1}, using original");
            newlyProcessedMessages.add(messagesToProcess[i]);
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
