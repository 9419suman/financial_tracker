class BankTransaction {
  final String date;
  final String amount;
  final String type;
  final String toAccount;
  final String category;
  final String description;

  BankTransaction({
    required this.date,
    required this.amount,
    required this.type,
    required this.toAccount,
    required this.category,
    required this.description,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    // Clean amount - handle non-numeric chars and convert string to double if needed
    String cleanAmount = json['amount'].toString()
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll('Rs.', '')
        .trim();
    
    // Ensure type is standardized
    String standardizedType = json['type'].toString().toLowerCase();
    if (standardizedType == 'credit' || 
        standardizedType == 'cr' || 
        standardizedType.contains('credit')) {
      standardizedType = 'Credit';
    } else if (standardizedType == 'debit' || 
               standardizedType == 'dr' || 
               standardizedType.contains('debit')) {
      standardizedType = 'Debit';
    }
    
    return BankTransaction(
      date: json['date'] ?? '',
      amount: cleanAmount,
      type: standardizedType,
      toAccount: json['to_account'] ?? 'Unknown',
      category: json['category'] ?? 'Uncategorized',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'amount': amount,
        'type': type,
        'to_account': toAccount,
        'category': category,
        'description': description,
      };

  // Helper method to get the amount as a double
  double get amountValue {
    try {
      return double.parse(amount);
    } catch (e) {
      print('Error parsing amount "$amount" as double: $e');
      return 0.0;
    }
  }

  // Helper method to get the sign of the amount (positive for credit, negative for debit)
  double get signedAmount {
    return type.toLowerCase() == 'credit' ? amountValue : -amountValue;
  }

  // Get a list of all possible categories (for filtering)
  static List<String> getCategories(List<BankTransaction> transactions) {
    final categories = transactions
        .map((t) => t.category)
        .toSet()
        .toList();
    
    categories.sort();
    return categories;
  }
} 