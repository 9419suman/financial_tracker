import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/bank_transaction.dart';
import '../models/analysis_result.dart';

class CacheService {
  static const String _cacheKey = 'processed_messages_cache';  // Save processed messages to cache
  static const String _bankStatementCacheKey = 'processed_bank_statements_cache';

  // --- EXISTING SMS CACHING METHODS ---
  
  // Save processed messages to cache
  Future<bool> saveProcessedMessages(List<MessageWithAmount> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing messages
      final List<String> existingJsonMessages = prefs.getStringList(_cacheKey) ?? [];
      print('💾 CACHE_SERVICE: Found ${existingJsonMessages.length} existing cached messages');
      
      // Create a map of existing message IDs for quick lookup
      final Map<String, String> existingMessageMap = {};
      for (String jsonString in existingJsonMessages) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          final String id = (data['message_id'] ?? '').toString();
          if (id.isNotEmpty) {
            existingMessageMap[id] = jsonString;
            print('💾 CACHE_SERVICE: Existing message ID in cache: $id');
          }
        } catch (e) {
          // Skip invalid entries
          print('💾 CACHE_SERVICE: ⚠️ Skipping invalid cache entry: $e');
        }
      }
      
      // Convert new messages to JSON and add to existing if not already present
      int newMessagesCount = 0;
      int skippedMessagesCount = 0;
      List<String> updatedMessages = [];
      
      // First add all existing messages to our updated list
      updatedMessages.addAll(existingMessageMap.values);
      print('💾 CACHE_SERVICE: Added ${existingMessageMap.values.length} existing messages to updated list');
      
      for (var message in messages) {
        final String messageId = message.message.id.toString();
        final String messagePreview = message.message.body != null 
            ? (message.message.body!.length > 30 
                ? message.message.body!.substring(0, 30) + "..." 
                : message.message.body!)
            : "[no body]";
        
        print('💾 CACHE_SERVICE: Processing message with ID: $messageId (Preview: $messagePreview)');
        
        // Skip if already in cache
        if (existingMessageMap.containsKey(messageId)) {
          print('💾 CACHE_SERVICE: Skipping already cached message ID: $messageId');
          skippedMessagesCount++;
          continue;
        }
        
        // Create a map with all the data we want to cache
        final Map<String, dynamic> data = {
          'message_id': messageId,
          'message_body': message.message.body,
          'message_sender': message.message.sender,
          'message_date': message.message.date?.millisecondsSinceEpoch,
          'amount': message.amount,
          'formatted_amount': message.formattedAmount,
          'extracted_amount_text': message.extractedAmountText,
          'is_transaction': message.isTransaction,
          'transaction_date': message.transactionDate,
          'transaction_type': message.transactionType,
          'from_account': message.from_account,
          'to_account': message.to_account,
          'account': message.to_account,  // Keep account for backward compatibility
          'category': message.category,
          'reason': message.reason,
          'description': message.reason,  // Keep description for backward compatibility
        };
        
        final String jsonString = jsonEncode(data);
        updatedMessages.add(jsonString);
        print('💾 CACHE_SERVICE: Added new message ID to cache: $messageId (Preview: $messagePreview)');
        newMessagesCount++;
      }
      
      // Save to SharedPreferences
      await prefs.setStringList(_cacheKey, updatedMessages);
      print('💾 CACHE_SERVICE: Added $newMessagesCount new messages to cache, skipped $skippedMessagesCount, total now ${updatedMessages.length}');
      
      // Verify that the messages were saved correctly
      final List<String>? verifyJsonMessages = prefs.getStringList(_cacheKey);
      print('💾 CACHE_SERVICE: Verified cache now has ${verifyJsonMessages?.length ?? 0} messages');
      
      return true;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error saving to cache: $e');
      return false;
    }
  }
  // Get cached messages as plain JSON/dict objects
  Future<List<Map<String, dynamic>>> getCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get cached data
      final List<String>? jsonMessages = prefs.getStringList(_cacheKey);
      if (jsonMessages == null || jsonMessages.isEmpty) {
        print('💾 CACHE_SERVICE: No cached messages found');
        return [];
      }
      
      print('💾 CACHE_SERVICE: Found ${jsonMessages.length} cached message entries');
      
      // Convert JSON strings to Map objects
      final List<Map<String, dynamic>> messages = [];
      
      for (String jsonString in jsonMessages) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          
          // Print the message ID for debugging
          final String messageId = data['message_id']?.toString() ?? '';
          final String messagePreview = data['message_body'] != null 
              ? (data['message_body'].toString().length > 30 
                  ? data['message_body'].toString().substring(0, 30) + "..." 
                  : data['message_body'].toString())
              : "[no body]";
          
          print('💾 CACHE_SERVICE: Retrieved cached message ID: $messageId (Preview: $messagePreview)');
          
          // Add the raw data dictionary to our list
          messages.add(data);
        } catch (e) {
          print('💾 CACHE_SERVICE: ❌ Error parsing cached message: $e');
          // Continue with next message
        }
      }
      
      print('💾 CACHE_SERVICE: Retrieved ${messages.length} message dictionaries from cache');
      return messages;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error retrieving from cache: $e');
      return [];
    }
  }
  // Check if a message exists in cache by its ID
  Future<bool> isMessageCached(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonMessages = prefs.getStringList(_cacheKey);
      
      if (jsonMessages == null || jsonMessages.isEmpty) {
        print('💾 CACHE_SERVICE: No cached messages found when checking ID: $messageId');
        return false;
      }
      
      print('💾 CACHE_SERVICE: Checking if message ID: $messageId exists in ${jsonMessages.length} cached messages');
      
      // Directly check the JSON for the message ID without parsing the entire message
      for (String jsonString in jsonMessages) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          final String cachedId = data['message_id'].toString();
          
          // More detailed debug comparison
          if (cachedId == messageId) {
            final String messagePreview = data['message_body'] != null 
                ? (data['message_body'].toString().length > 30 
                    ? data['message_body'].toString().substring(0, 30) + "..." 
                    : data['message_body'].toString())
                : "[no body]";
            print('💾 CACHE_SERVICE: ✅ Found message ID: $messageId in cache (Preview: $messagePreview)');
            return true;
          }
        } catch (e) {
          // Skip invalid entries
          print('💾 CACHE_SERVICE: ⚠️ Error checking cached message ID: $e');
          continue;
        }
      }
      
      print('💾 CACHE_SERVICE: ❌ Message ID: $messageId not found in cache');
      return false;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error checking message cache: $e');
      return false;
    }
  }
  
  // Clear cache
  Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      print('💾 CACHE_SERVICE: Cache cleared');
      return true;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error clearing cache: $e');
      return false;
    }
  }
  // Update a specific message in the cache
  Future<bool> updateMessage(MessageWithAmount message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing messages
      final List<String> existingJsonMessages = prefs.getStringList(_cacheKey) ?? [];
      print('💾 CACHE_SERVICE: Found ${existingJsonMessages.length} existing cached messages');
      
      final String messageId = message.message.id.toString();
      print('💾 CACHE_SERVICE: Updating message with ID: $messageId');
      
      bool foundAndUpdated = false;
      List<String> updatedMessages = [];
      
      for (int i = 0; i < existingJsonMessages.length; i++) {
        try {
          final Map<String, dynamic> data = jsonDecode(existingJsonMessages[i]);
          final String cachedId = data['message_id'].toString();
          
          if (cachedId == messageId) {
            // This is the message we want to update
            print('💾 CACHE_SERVICE: Found message to update with ID: $messageId');
            
            // Create an updated map with the new values
            final Map<String, dynamic> updatedData = {
              'message_id': messageId,
              'message_body': message.message.body,
              'message_sender': message.message.sender,
              'message_date': message.message.date?.millisecondsSinceEpoch,
              'amount': message.amount,
              'formatted_amount': message.formattedAmount,
              'extracted_amount_text': message.extractedAmountText,
              'is_transaction': message.isTransaction,
              'transaction_date': message.transactionDate,
              'transaction_type': message.transactionType,
              'from_account': message.from_account,
              'to_account': message.to_account,
              'account': message.to_account,  // Keep account for backward compatibility
              'category': message.category,
              'reason': message.reason,
              'description': message.reason,  // Keep description for backward compatibility
            };
            
            final String updatedJsonString = jsonEncode(updatedData);
            updatedMessages.add(updatedJsonString);
            foundAndUpdated = true;
            print('💾 CACHE_SERVICE: Updated message in cache: $messageId');
          } else {
            // Not the message we're looking for, keep it as is
            updatedMessages.add(existingJsonMessages[i]);
          }
        } catch (e) {
          // Skip invalid entries but keep them in the cache
          print('💾 CACHE_SERVICE: ⚠️ Skipping invalid cache entry: $e');
          updatedMessages.add(existingJsonMessages[i]);
        }
      }
      
      if (!foundAndUpdated) {
        print('💾 CACHE_SERVICE: ❌ Message not found in cache, ID: $messageId');
        return false;
      }
      
      // Save updated list back to SharedPreferences
      await prefs.setStringList(_cacheKey, updatedMessages);
      print('💾 CACHE_SERVICE: Successfully saved updated message cache');
      
      return true;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error updating message in cache: $e');
      return false;
    }
  }
  // Get a specific message from cache by ID
  Future<Map<String, dynamic>?> getCachedMessageById(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonMessages = prefs.getStringList(_cacheKey);
      
      if (jsonMessages == null || jsonMessages.isEmpty) {
        print('💾 CACHE_SERVICE: No cached messages found when looking for ID: $messageId');
        return null;
      }
      
      print('💾 CACHE_SERVICE: Searching for message ID: $messageId in ${jsonMessages.length} cached messages');
      
      for (String jsonString in jsonMessages) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          final String cachedId = data['message_id'].toString();
          
          if (cachedId == messageId) {
            print('💾 CACHE_SERVICE: ✅ Found message ID: $messageId in cache');
            return data;
          }
        } catch (e) {
          // Skip invalid entries
          print('💾 CACHE_SERVICE: ⚠️ Error checking cached message: $e');
          continue;
        }
      }
      
      print('💾 CACHE_SERVICE: ❌ Message ID: $messageId not found in cache');
      return null;
    } catch (e) {
      print('💾 CACHE_SERVICE: ❌ Error retrieving specific message from cache: $e');
      return null;
    }
  }

  // --- NEW BANK STATEMENT CACHING METHODS ---
  
  // Generate a unique cache key for a bank statement based on email and attachment info
  String _generateBankStatementCacheKey(String emailId, String attachmentId, String filename) {
    // Create a unique identifier combining email ID, attachment ID, and filename
    final identifier = '${emailId}_${attachmentId}_${filename}';
    print('🏦 CACHE_SERVICE: Generated cache key: $identifier');
    return identifier;
  }
  
  // Save processed bank statement to cache
  Future<bool> saveBankStatementResult({
    required String emailId,
    required String attachmentId,
    required String filename,
    required AnalysisResult result,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateBankStatementCacheKey(emailId, attachmentId, filename);
      
      // Get existing bank statement cache
      final Map<String, String> existingCache = await _getBankStatementCache();
      print('🏦 CACHE_SERVICE: Found ${existingCache.length} existing bank statement cache entries');
      
      // Create cache data structure
      final Map<String, dynamic> cacheData = {
        'cache_key': cacheKey,
        'email_id': emailId,
        'attachment_id': attachmentId,
        'filename': filename,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'transactions': result.transactions.map((t) => t.toJson()).toList(),
        'usage_metadata': result.usageMetadata,
        'transaction_count': result.transactions.length,
      };
      
      final String jsonString = jsonEncode(cacheData);
      
      // Add to existing cache
      existingCache[cacheKey] = jsonString;
      
      // Save back to SharedPreferences as a list of values
      final List<String> cacheList = existingCache.values.toList();
      await prefs.setStringList(_bankStatementCacheKey, cacheList);
      
      print('🏦 CACHE_SERVICE: ✅ Saved bank statement to cache: $cacheKey with ${result.transactions.length} transactions');
      return true;
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error saving bank statement to cache: $e');
      return false;
    }
  }
  
  // Get cached bank statement result
  Future<AnalysisResult?> getCachedBankStatementResult({
    required String emailId,
    required String attachmentId,
    required String filename,
  }) async {
    try {
      final cacheKey = _generateBankStatementCacheKey(emailId, attachmentId, filename);
      final Map<String, String> cache = await _getBankStatementCache();
      
      if (!cache.containsKey(cacheKey)) {
        print('🏦 CACHE_SERVICE: No cached result found for: $cacheKey');
        return null;
      }
      
      final Map<String, dynamic> cacheData = jsonDecode(cache[cacheKey]!);
      
      // Convert transactions back from JSON
      final List<BankTransaction> transactions = (cacheData['transactions'] as List)
          .map((json) => BankTransaction.fromJson(json))
          .toList();
      
      final Map<String, dynamic> usageMetadata = cacheData['usage_metadata'] ?? {};
      
      print('🏦 CACHE_SERVICE: ✅ Retrieved cached bank statement: $cacheKey with ${transactions.length} transactions');
      
      return AnalysisResult(
        transactions: transactions,
        usageMetadata: usageMetadata,
      );
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error retrieving cached bank statement: $e');
      return null;
    }
  }
  
  // Check if a bank statement is cached
  Future<bool> isBankStatementCached({
    required String emailId,
    required String attachmentId,
    required String filename,
  }) async {
    try {
      final cacheKey = _generateBankStatementCacheKey(emailId, attachmentId, filename);
      final Map<String, String> cache = await _getBankStatementCache();
      
      final bool isCached = cache.containsKey(cacheKey);
      print('🏦 CACHE_SERVICE: Bank statement cache check for $cacheKey: $isCached');
      
      return isCached;
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error checking bank statement cache: $e');
      return false;
    }
  }
  
  // Get all cached bank statements as a map
  Future<Map<String, String>> _getBankStatementCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? cacheList = prefs.getStringList(_bankStatementCacheKey);
      
      if (cacheList == null || cacheList.isEmpty) {
        return {};
      }
      
      final Map<String, String> cache = {};
      for (String jsonString in cacheList) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          final String cacheKey = data['cache_key'];
          cache[cacheKey] = jsonString;
        } catch (e) {
          print('🏦 CACHE_SERVICE: ⚠️ Skipping invalid bank statement cache entry: $e');
        }
      }
      
      return cache;
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error getting bank statement cache: $e');
      return {};
    }
  }
  
  // Clear bank statement cache
  Future<bool> clearBankStatementCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bankStatementCacheKey);
      print('🏦 CACHE_SERVICE: Bank statement cache cleared');
      return true;
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error clearing bank statement cache: $e');
      return false;
    }
  }
  
  // Clear all caches (both SMS and bank statements)
  Future<bool> clearAllCaches() async {
    try {
      final smsResult = await clearCache();
      final bankResult = await clearBankStatementCache();
      
      print('🏦 CACHE_SERVICE: All caches cleared - SMS: $smsResult, Bank: $bankResult');
      return smsResult && bankResult;
    } catch (e) {
      print('🏦 CACHE_SERVICE: ❌ Error clearing all caches: $e');
      return false;
    }
  }
}
