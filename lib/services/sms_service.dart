import 'dart:convert';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message_model.dart';
import '../gemini_api_fin.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();
  late final GeminiApi _geminiApi;
  
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
  }
    // Process messages with Gemini API
  Future<List<MessageWithAmount>> processMessagesWithGemini(List<MessageWithAmount> messages) async {
    if (messages.isEmpty) {
      print("📱 SMS_SERVICE: No messages to process with Gemini");
      return [];
    }
    
    try {
      print("📱 SMS_SERVICE: Starting Gemini processing for ${messages.length} messages");
      
      // Create array of message bodies
      List<String> messageBodies = messages.map((msg) => 
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
        return messages; // Return original messages if API fails
      }
      
      print("📱 SMS_SERVICE: ✅ Gemini API call successful");
      print("📱 SMS_SERVICE: Raw response: ${response.text.substring(0, response.text.length > 100 ? 100 : response.text.length)}...");
      
      try {
        // Parse response JSON
        print("📱 SMS_SERVICE: Attempting to parse JSON response");
        final List<dynamic> transactionData = jsonDecode(response.text);
        print("📱 SMS_SERVICE: ✅ Successfully parsed JSON with ${transactionData.length} items");
        
        // Create new list with processed messages
        List<MessageWithAmount> processedMessages = [];
        
        // Match transactions with messages
        for (int i = 0; i < messages.length; i++) {
          if (i < transactionData.length) {
            print("📱 SMS_SERVICE: Processing message ${i+1}/${messages.length}");
            print("📱 SMS_SERVICE: Transaction data for message ${i+1}: ${transactionData[i]}");
            
            processedMessages.add(
              MessageWithAmount.fromGeminiResponse(messages[i].message, transactionData[i])
            );
          } else {
            // If we have more messages than transactions, use original message
            print("📱 SMS_SERVICE: ⚠️ No transaction data for message ${i+1}, using original");
            processedMessages.add(messages[i]);
          }
        }
        
        print("📱 SMS_SERVICE: ✅ Finished processing ${processedMessages.length} messages with Gemini");
        return processedMessages;
      } catch (e) {
        print("📱 SMS_SERVICE: ❌ Error parsing Gemini API response: $e");
        print("📱 SMS_SERVICE: Raw response: ${response.text}");
        return messages; // Return original messages if parsing fails
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
