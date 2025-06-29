import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';

class MessageWithAmount {
  final SmsMessage message;
  final double? amount;
  final String? formattedAmount;
  final String extractedAmountText;
  
  // New fields from Gemini API
  final bool isTransaction;
  final String transactionDate;
  final String transactionType;
  final String account;  // Changed from toAccount
  final String category;
  final String reason;  // Primary field for reason/description

  MessageWithAmount({
    required this.message,
    required this.amount,
    required this.formattedAmount,
    required this.extractedAmountText,
    this.isTransaction = false,
    this.transactionDate = 'NA',
    this.transactionType = 'NA',
    this.account = 'NA',  // Changed from toAccount
    String? toAccount,    // Added for backward compatibility
    this.category = 'NA',
    this.reason = 'NA',
    String? description,  // Optional parameter for backward compatibility
  });
  
  // Getter for backward compatibility
  String get description => reason;
  
  // Getter for backward compatibility
  String get toAccount => account;

  // Factory method to create a MessageWithAmount from an SmsMessage
  factory MessageWithAmount.fromSmsMessage(SmsMessage message) {
    return MessageWithAmount(
      message: message,
      amount: null,
      formattedAmount: null,
      extractedAmountText: "",
    );
  }
    // Create a MessageWithAmount from Gemini API response
  factory MessageWithAmount.fromGeminiResponse(SmsMessage message, Map<String, dynamic> geminiData) {
    print("🔄 MODEL: Creating MessageWithAmount from Gemini response: $geminiData");
    
    double? amount;
    String formattedAmount = '';
    
    // Try to parse amount from Gemini response
    if (geminiData['amount'] != null && geminiData['amount'] != 'NA') {
      String amountStr = geminiData['amount'].toString().replaceAll(',', '').replaceAll('Rs.', '').replaceAll('₹', '').trim();
      print("🔄 MODEL: Parsing amount string: '$amountStr'");
      try {
        amount = double.parse(amountStr);
        print("🔄 MODEL: Parsed amount: $amount");
        // Format amount
        final formatter = NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 2,
        );
        formattedAmount = formatter.format(amount);
        print("🔄 MODEL: Formatted amount: $formattedAmount");
      } catch (e) {
        print("🔄 MODEL: ❌ Error parsing amount: $e for value: ${geminiData['amount']}");
      }
    }
    
    return MessageWithAmount(
      message: message,
      amount: amount,
      formattedAmount: formattedAmount.isNotEmpty ? formattedAmount : null,
      extractedAmountText: geminiData['amount'] ?? '',
      isTransaction: geminiData['transaction_flag'] ?? false,
      transactionDate: geminiData['date'] ?? 'NA',
      transactionType: geminiData['type'] ?? 'NA',
      account: geminiData['account'] ?? geminiData['to_account'] ?? 'NA',  // Try account first, fall back to to_account
      category: geminiData['category'] ?? 'NA',
      reason: geminiData['reason'] ?? geminiData['description'] ?? 'NA',  // Try reason first, fall back to description
    );
  }
  
  // Copy with method to allow updating specific fields
  MessageWithAmount copyWith({
    SmsMessage? message,
    double? amount,
    String? formattedAmount,
    String? extractedAmountText,
    bool? isTransaction,
    String? transactionDate,
    String? transactionType,
    String? account,
    String? toAccount,  // Added for backward compatibility
    String? category,
    String? reason,
    String? description,  // Added for backward compatibility
  }) {
    return MessageWithAmount(
      message: message ?? this.message,
      amount: amount ?? this.amount,
      formattedAmount: formattedAmount ?? this.formattedAmount,
      extractedAmountText: extractedAmountText ?? this.extractedAmountText,
      isTransaction: isTransaction ?? this.isTransaction,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      account: account ?? toAccount ?? this.account,  // Use account if provided, then toAccount, then fall back to current account
      category: category ?? this.category,
      reason: reason ?? description ?? this.reason,  // Use reason if provided, then description, then fall back to current reason
    );
  }

  // Helper method to get formatted date
  String get formattedDate {
    if (message.date == null) return '';
    return DateFormat('MMM dd, yyyy - hh:mm a').format(message.date!);
  }

  // Get preview text (first 100 characters)
  String get previewText {
    if (message.body == null || message.body!.isEmpty) return '';
    return message.body!.length > 100
        ? '${message.body!.substring(0, 100)}...'
        : message.body!;
  }
}
