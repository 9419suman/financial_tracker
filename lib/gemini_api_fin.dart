import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiApiResponse {
  final bool success;
  final String text;
  final String? error;
  final Map<String, dynamic>? rawResponse; // Added for debugging

  GeminiApiResponse({
    required this.success,
    required this.text,
    this.error,
    this.rawResponse,
  });

  @override
  String toString() {
    if (success) {
      return text;
    } else {
      return 'Error: $error';
    }
  }
}

class GeminiApi {
  final String apiKey;
  final String baseUrl;
  final String model;

  GeminiApi({
    required this.apiKey,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.model = 'gemini-2.5-flash',
  });
    Future<GeminiApiResponse> generateContent(String prompt) async {
    try {
      // Debug print statements with visible markers
      print('\n\n🚀🚀🚀 GEMINI API DEBUG: STARTING REQUEST 🚀🚀🚀');
      print('📝 PROMPT: "$prompt"');
      print('🔑 API KEY LENGTH: ${apiKey.length}');
      print('🔑 API KEY FIRST 4 CHARS: ${apiKey.substring(0, 4)}...');
      print('🔑 API KEY LAST 4 CHARS: ...${apiKey.substring(apiKey.length - 4)}');
      print('🤖 MODEL: $model');
      print('🌐 URL: $baseUrl/models/$model:generateContent');
      
      // Display timestamp for tracking request time
      print('⏱️ REQUEST TIME: ${DateTime.now().toString()}');
      
      final url = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');
      
      final headers = {
        'Content-Type': 'application/json',
      };
      
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": prompt
              }
            ]
          }
        ],
        "generationConfig": {
          "thinkingConfig": {
            "thinkingBudget": 0
          },
          'response_mime_type': 'application/json',
          'response_schema': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'message_id': {'type': 'STRING'},
                'transaction_flag': {'type': 'BOOLEAN'},
                'amount': {'type': 'STRING'},
                'type': {'type': 'STRING'},
                'account': {'type': 'STRING'},
                'category': {'type': 'STRING'},
                'reason': {'type': 'STRING'}
              },
              'required': ['message_id', 'transaction_flag', 'amount', 'type', 'account', 'category', 'reason']
            }
          },
        }
      };
      
      // Print request body for debugging
      print('📦 REQUEST BODY: ${jsonEncode(requestBody)}');
      
      final body = jsonEncode(requestBody);

      print('📤 SENDING REQUEST...');
      final response = await http.post(url, headers: headers, body: body);
        // Print response details with clearly visible markers
      print('\n🔍🔍🔍 GEMINI API DEBUG: RESPONSE RECEIVED 🔍🔍🔍');
      print('🟢 STATUS CODE: ${response.statusCode}');
      print('🟢 RESPONSE HEADERS: ${response.headers}');
      print('🟢 RESPONSE BODY:');
      print(response.body);
      print('================================================\n');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        try {
          // Extract the text content from the response
          final text = responseBody['candidates'][0]['content']['parts'][0]['text'];
          print('✅ SUCCESSFULLY EXTRACTED TEXT FROM RESPONSE');
          return GeminiApiResponse(
            success: true,
            text: text,
            rawResponse: responseBody,
          );
        } catch (e) {
          print('❌ ERROR PARSING RESPONSE: $e');
          print('❌ RESPONSE STRUCTURE:');
          print(responseBody);
          return GeminiApiResponse(
            success: false,
            text: '',
            error: 'Failed to parse response: $e',
            rawResponse: responseBody,
          );
        }
      } else {
        print('❌ ERROR STATUS CODE: ${response.statusCode}');
        print('❌ ERROR RESPONSE:');
        print(response.body);
          // Try to parse the error message in a more readable format
        String errorMessage = 'Status ${response.statusCode}';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['error'] != null) {
            errorMessage += ': ${errorJson['error']['message'] ?? 'Unknown error'}';
            print('✗ PARSED ERROR MESSAGE: ${errorJson['error']['message']}');
          }
        } catch (e) {
          errorMessage += ': ${response.body}';
        }
        
        return GeminiApiResponse(
          success: false,
          text: '',
          error: errorMessage,
          rawResponse: response.statusCode == 200 ? jsonDecode(response.body) : null,
        );
      }
    } catch (e) {
      print('✗ EXCEPTION DURING API CALL: $e');
      return GeminiApiResponse(
        success: false,
        text: '',
        error: 'Exception: $e',
      );
    } finally {
      print('===== GEMINI API DEBUG: REQUEST COMPLETED =====\n\n');
    }
  }
}
