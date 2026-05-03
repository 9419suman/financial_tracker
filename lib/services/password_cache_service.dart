import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfPasswordCache {
  final String? password;
  final String confidence;
  final bool instructionFound;
  final List<String> candidates; // populated when instructionFound == false
  final String? statementType;
  final String? bankName;
  final String? cardName;
  final String? statementMonth;
  final String? totalAmountDue;
  final String? minimumAmountDue;
  final String? paymentDueDate;
  final String cachedAt;

  const PdfPasswordCache({
    this.password,
    this.confidence = 'unknown',
    this.instructionFound = true,
    this.candidates = const [],
    this.statementType,
    this.bankName,
    this.cardName,
    this.statementMonth,
    this.totalAmountDue,
    this.minimumAmountDue,
    this.paymentDueDate,
    required this.cachedAt,
  });

  factory PdfPasswordCache.fromJson(Map<String, dynamic> json) => PdfPasswordCache(
        password: json['password'] as String?,
        confidence: json['password_confidence'] as String? ?? 'unknown',
        instructionFound: json['password_instruction_found'] as bool? ?? true,
        candidates: List<String>.from(json['password_candidates'] as List? ?? []),
        statementType: json['statement_type'] as String?,
        bankName: json['bank_name'] as String?,
        cardName: json['card_name'] as String?,
        statementMonth: json['statement_month'] as String?,
        totalAmountDue: json['total_amount_due']?.toString(),
        minimumAmountDue: json['minimum_amount_due']?.toString(),
        paymentDueDate: json['payment_due_date'] as String?,
        cachedAt: json['cached_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'password': password,
        'password_confidence': confidence,
        'password_instruction_found': instructionFound,
        'password_candidates': candidates,
        'statement_type': statementType,
        'bank_name': bankName,
        'card_name': cardName,
        'statement_month': statementMonth,
        'total_amount_due': totalAmountDue,
        'minimum_amount_due': minimumAmountDue,
        'payment_due_date': paymentDueDate,
        'cached_at': cachedAt,
      };

  // Ordered list of passwords to actually try when decrypting:
  // known password first, then candidates, then empty string as last resort.
  List<String> get passwordsToTry {
    final list = <String>[];
    if (password != null && password!.isNotEmpty) list.add(password!);
    list.addAll(candidates);
    list.add(''); // try unencrypted last
    return list;
  }
}

// Singleton cache — same key structure as password_cache.json in Python scripts.
class PasswordCacheService {
  static const _filename = 'password_cache.json';
  static final PasswordCacheService instance = PasswordCacheService._();
  PasswordCacheService._();

  Map<String, dynamic> _cache = {};
  bool _loaded = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        _cache = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _persist() async {
    final f = await _file();
    await f.writeAsString(jsonEncode(_cache));
  }

  Future<PdfPasswordCache?> get(String filename) async {
    await _ensureLoaded();
    final entry = _cache[filename];
    if (entry == null) return null;
    return PdfPasswordCache.fromJson(Map<String, dynamic>.from(entry as Map));
  }

  Future<void> set(String filename, PdfPasswordCache entry) async {
    await _ensureLoaded();
    _cache[filename] = entry.toJson();
    await _persist();
  }

  Future<void> clear() async {
    _cache = {};
    _loaded = true;
    await _persist();
  }

  Future<int> get count async {
    await _ensureLoaded();
    return _cache.length;
  }
}
