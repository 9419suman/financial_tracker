import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'password_candidate_service.dart';
import 'password_cache_service.dart';

class DeepSeekService {
  static String get _apiKey => dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  static String get _model => dotenv.env['DEEPSEEK_MODEL'] ?? 'deepseek-v4-flash';

  // Analyze an email to determine statement type and PDF password.
  // Returns cached result immediately if filename was seen before.
  Future<PdfPasswordCache?> analyzeEmail({
    required String subject,
    required String body,
    required String filename,
    required UserProfile profile,
  }) async {
    // Cache check — no API call if already processed
    final cached = await PasswordCacheService.instance.get(filename);
    if (cached != null) {
      print('💾 Password cache hit: $filename');
      return cached;
    }

    if (_apiKey.isEmpty) {
      print('⚠️ DEEPSEEK_API_KEY not set — skipping LLM analysis');
      return null;
    }

    print('🤖 DeepSeek: analyzing $filename');

    try {
      final response = await http
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': _buildPrompt(subject, body, profile)}
              ],
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        print('❌ DeepSeek ${response.statusCode}: ${response.body.substring(0, 300)}');
        return null;
      }

      final outer = jsonDecode(response.body) as Map<String, dynamic>;
      final content = jsonDecode(
              outer['choices'][0]['message']['content'] as String)
          as Map<String, dynamic>;

      final instructionFound = content['password_instruction_found'] as bool? ?? true;
      final password = content['password'] as String?;

      final entry = PdfPasswordCache(
        password: password,
        confidence: content['password_confidence'] as String? ?? 'unknown',
        instructionFound: instructionFound,
        // Generate full candidate list when no instruction found
        candidates: (!instructionFound || password == null)
            ? PasswordCandidateService.generate(profile)
            : [],
        statementType: content['statement_type'] as String?,
        bankName: content['bank_name'] as String?,
        cardName: content['card_name'] as String?,
        statementMonth: content['statement_month'] as String?,
        totalAmountDue: content['total_amount_due']?.toString(),
        minimumAmountDue: content['minimum_amount_due']?.toString(),
        paymentDueDate: content['payment_due_date'] as String?,
        cachedAt: DateTime.now().toIso8601String(),
      );

      await PasswordCacheService.instance.set(filename, entry);
      print('✅ DeepSeek result cached for: $filename  pwd=${entry.password ?? "unknown"}');
      return entry;
    } catch (e) {
      print('❌ DeepSeek call failed: $e');
      return null;
    }
  }

  String _buildPrompt(String subject, String body, UserProfile profile) {
    return '''Analyze this bank email and return ONLY valid JSON.

Subject: $subject

Email body:
---
$body
---

User details:
- Full Name: ${profile.fullName}
- Date of Birth: ${profile.dd}/${profile.mm}/${profile.yyyy} (DD/MM/YYYY)
- PAN: ${profile.pan}
- Phone: ${profile.phone}
- Card last 4 digits: ${profile.cardLast4}
- Known Customer IDs: ${jsonEncode(profile.bankPasswords)}

Return ONLY this JSON (null for unknown):
{
  "statement_type": "account_statement | credit_card_statement | loan_statement | investment_statement | other | not_a_statement",
  "bank_name": "e.g. HDFC Bank",
  "card_name": "card product name if credit card, else null",
  "statement_month": "YYYY-MM of the statement period",
  "password_instruction_found": true or false — whether the email explicitly states how the PDF is password-protected,
  "password": "computed password using the instruction and user details — null only if instruction is absent or unresolvable",
  "password_confidence": "high | medium | low | none",
  "total_amount_due": "credit card total due as string, null otherwise",
  "minimum_amount_due": "credit card minimum due as string, null otherwise",
  "payment_due_date": "YYYY-MM-DD, null otherwise"
}''';
  }
}
