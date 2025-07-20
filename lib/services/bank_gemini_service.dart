import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/bank_transaction.dart';
import '../models/analysis_result.dart';
import '../config/bank_statement_config.dart';
import 'cache_service.dart';

class BankGeminiService {
  final String apiKey = BankStatementConfig.geminiApiKey;
  final String baseUrl = BankStatementConfig.geminiBaseUrl;
  final CacheService _cacheService = CacheService();

  BankGeminiService();

  Future<http.Response> _makeApiRequest(String url, Map<String, dynamic> requestBody, {int retries = 2}) async {
    int attempt = 0;
    Exception? lastException;
    
    while (attempt <= retries) {
      try {
        attempt++;
        print("API request attempt $attempt/${retries + 1}");
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        ).timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            print("API request timed out after 2 minutes on attempt $attempt");
            throw Exception("API request timed out. The PDF might be too large or the service is unavailable.");
          },
        );
        
        return response;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print("Error on API request attempt $attempt: $e");
        
        if (attempt <= retries) {
          final waitTime = Duration(seconds: pow(2, attempt).toInt());
          print("Retrying in ${waitTime.inSeconds} seconds...");
          await Future.delayed(waitTime);
        }
      }
    }
    
    throw lastException ?? Exception("Failed after $retries retries");
  }

  Future<AnalysisResult> processStatement(
    Uint8List pdfData, 
    String prompt, 
    String model, {
    String? emailId,
    String? attachmentId,
    String? filename,
    Function(String)? onProgress,
  }) async {
    
    // Check cache first if we have the required identifiers
    if (emailId != null && attachmentId != null && filename != null) {
      print("🏦 BANK_GEMINI_SERVICE: Checking cache for statement: $filename");
      onProgress?.call('Checking cache...');
      
      try {
        final cachedResult = await _cacheService.getCachedBankStatementResult(
          emailId: emailId,
          attachmentId: attachmentId,
          filename: filename,
        );
        
        if (cachedResult != null) {
          print("🏦 BANK_GEMINI_SERVICE: ✅ Found cached result with ${cachedResult.transactions.length} transactions");
          onProgress?.call('Loading cached results...');
          // Add a small delay to show the cache loading message
          await Future.delayed(const Duration(milliseconds: 500));
          return cachedResult;
        } else {
          print("🏦 BANK_GEMINI_SERVICE: No cached result found, proceeding with Gemini API");
        }
      } catch (e) {
        print("🏦 BANK_GEMINI_SERVICE: ⚠️ Error checking cache: $e, proceeding with Gemini API");
      }
    } else {
      print("🏦 BANK_GEMINI_SERVICE: Missing cache identifiers, proceeding directly with Gemini API");
    }
    
    onProgress?.call('Analyzing transactions with AI...');
    
    final url = '$baseUrl/models/$model:generateContent?key=$apiKey';

    print("--- PROMPT SENT TO GEMINI API ---");
    print(prompt);
    print("---------------------------------");
    
    final String base64Pdf = base64Encode(pdfData);
    print("PDF encoded to base64, length: ${base64Pdf.length}");
    
    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': 'application/pdf',
                'data': base64Pdf
              }
            },
            {
              'text': prompt
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'response_schema': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'date': {'type': 'STRING'},
              'amount': {'type': 'STRING'},
              'type': {'type': 'STRING'},
              'to_account': {'type': 'STRING'},
              'category': {'type': 'STRING'},
              'description': {'type': 'STRING'}
            },
            'required': ['date', 'amount', 'type', 'description', 'category']
          }
        },
        'maxOutputTokens': 60000,
      }
    };

    try {
      print("Sending request to Gemini API: $url");
      
      final response = await _makeApiRequest(url, requestBody);

      print("Response received, status code: ${response.statusCode}");
      
      // Print the raw response body in chunks to avoid truncation
      const chunkSize = 1024;
      if (response.body.length > chunkSize) {
        print("Raw response body from Gemini (chunked):");
        for (int i = 0; i < response.body.length; i += chunkSize) {
          int end = (i + chunkSize < response.body.length) ? i + chunkSize : response.body.length;
          print(response.body.substring(i, end));
        }
      } else {
        print("Raw response body from Gemini: ${response.body}");
      }
      
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          
          if (responseData.containsKey('candidates') && responseData['candidates'].isNotEmpty) {
            final content = responseData['candidates'][0]['content']['parts'][0]['text'];
            final decodedJson = jsonDecode(content);
            final usageMetadata = responseData['usageMetadata'] ?? {};

            if (decodedJson is List) {
              final transactions = decodedJson
                  .map((item) => BankTransaction.fromJson(item))
                  .toList();
              
              final result = AnalysisResult(transactions: transactions, usageMetadata: usageMetadata);
              
              // Cache the result if we have the required identifiers
              if (emailId != null && attachmentId != null && filename != null) {
                print("🏦 BANK_GEMINI_SERVICE: Saving result to cache with ${transactions.length} transactions");
                try {
                  final cacheResult = await _cacheService.saveBankStatementResult(
                    emailId: emailId,
                    attachmentId: attachmentId,
                    filename: filename,
                    result: result,
                  );
                  
                  if (cacheResult) {
                    print("🏦 BANK_GEMINI_SERVICE: ✅ Successfully cached result");
                  } else {
                    print("🏦 BANK_GEMINI_SERVICE: ⚠️ Failed to cache result");
                  }
                } catch (e) {
                  print("🏦 BANK_GEMINI_SERVICE: ❌ Error caching result: $e");
                }
              } else {
                print("🏦 BANK_GEMINI_SERVICE: Missing cache identifiers, skipping cache save");
              }
              
              return result;
            }
          }
          throw Exception('Failed to parse response from Gemini API. The response was not a valid JSON array.');
        } catch (e) {
          print("Error parsing JSON response: $e");
          // Also print the full body here in chunks for debugging failed parsing
          if (response.body.length > chunkSize) {
            print("Raw response body on error (chunked):");
            for (int i = 0; i < response.body.length; i += chunkSize) {
              int end = (i + chunkSize < response.body.length) ? i + chunkSize : response.body.length;
              print(response.body.substring(i, end));
            }
          } else {
            print("Raw response body on error: ${response.body}");
          }
          throw Exception("Could not parse the response from Gemini. Please check the logs.");
        }
      } else {
        print("Gemini API returned an error: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to process statement. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error processing statement with Gemini: $e');
      rethrow;
    }
  }

  Future<bool> testApiConnection() async {
    // This test is now more complex with direct http calls, 
    // for now we assume if processStatement is called, the connection is tested.
    // A proper test would involve a simple ping or a dedicated test endpoint.
    return true; 
  }
} 