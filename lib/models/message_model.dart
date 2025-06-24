import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';

class MessageWithAmount {
  final SmsMessage message;
  final double? amount;
  final String? formattedAmount;
  final String extractedAmountText;

  MessageWithAmount({
    required this.message,
    required this.amount,
    required this.formattedAmount,
    required this.extractedAmountText,
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
