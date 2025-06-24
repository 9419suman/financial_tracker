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
  final String toAccount;
  final String category;
  final String description;

  MessageWithAmount({
    required this.message,
    required this.amount,
    required this.formattedAmount,
    required this.extractedAmountText,
    this.isTransaction = false,
    this.transactionDate = 'NA',
    this.transactionType = 'NA',
    this.toAccount = 'NA',
    this.category = 'NA',
    this.description = 'NA',
  });

  // Factory method to create a MessageWithAmount from an SmsMessage
  factory MessageWithAmount.fromSmsMessage(SmsMessage message) {
    // Extract amount using regex for common patterns like Rs. 1,234.56 or $1,234.56
    final RegExp amountRegex = RegExp(
      r'(?:Rs\.?|INR|₹|\$)?\s?(\d{1,3}(,\d{3})*(\.\d{1,2})?)',
      caseSensitive: false,
    );
    
    String? extractedAmountText = "";
    double? amount;
    
    final match = amountRegex.firstMatch(message.body ?? "");
    if (match != null) {
      extractedAmountText = match.group(0) ?? "";
      // Clean up the amount string and convert to double
      String cleanAmount = match.group(1)?.replaceAll(',', '') ?? "";
      try {
        amount = double.parse(cleanAmount);
      } catch (e) {
        amount = null;
      }
    }
    
    // Format the amount with a currency symbol if it exists
    String? formattedAmount;
    if (amount != null) {
      final formatter = NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 2,
      );
      formattedAmount = formatter.format(amount);
    }
    
    return MessageWithAmount(
      message: message,
      amount: amount,
      formattedAmount: formattedAmount,
      extractedAmountText: extractedAmountText,
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
      toAccount: geminiData['to_account'] ?? 'NA',
      category: geminiData['category'] ?? 'NA',
      description: geminiData['description'] ?? 'NA',
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
