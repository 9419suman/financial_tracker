class AppConstants {
  // Transaction categories used throughout the app
  static const Map<String, List<String>> transactionCategories = {
    "EXPENSE": [
      "Housing & Utilities",
      "Food & Dining",
      "Transportation",
      "Health & Insurance",
      "Shopping & Personal Care",
      "Entertainment & Subscriptions",
      "Financial Services & Fees",
      "Transfers & Gifts",
      "Investments & Savings",
      "Miscellaneous"
    ],
    "INCOME": [
      "Salary",
      "Interest & Dividends",
      "Refunds & Cashback",
      "Transfers & Gifts",
      "Other Income"
    ]
  };
  
  // Helper method to get all categories as a flat list
  static List<String> get allCategories {
    List<String> all = [];
    transactionCategories.forEach((key, categories) {
      all.addAll(categories);
    });
    return all;
  }
  
  // Helper method to get categories by transaction type
  static List<String> getCategoriesByType(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'debit':
        return transactionCategories['EXPENSE'] ?? [];
      case 'credit':
        return transactionCategories['INCOME'] ?? [];
      case 'transfer':
        return ['Transfers & Gifts'];
      default:
        return allCategories;
    }
  }
  
  // Helper method to determine transaction type from category
  static String getTransactionTypeFromCategory(String category) {
    if (transactionCategories['EXPENSE']?.contains(category) == true) {
      return category == 'Transfers & Gifts' ? 'transfer' : 'debit';
    } else if (transactionCategories['INCOME']?.contains(category) == true) {
      return category == 'Transfers & Gifts' ? 'transfer' : 'credit';
    }
    return 'debit'; // default
  }
}