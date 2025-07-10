import './bank_transaction.dart';

class AnalysisResult {
  final List<BankTransaction> transactions;
  final Map<String, dynamic> usageMetadata;

  AnalysisResult({required this.transactions, required this.usageMetadata});
} 