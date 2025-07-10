import 'package:flutter_dotenv/flutter_dotenv.dart';

class BankStatementConfig {
  // Gemini API Configuration - using the same API key as SMS parsing
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String geminiModel = 'gemini-1.5-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  // Google Sign-In Configuration
  static String get googleServerClientId => dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';
  
  // Bank Statement Prompt
  static const String geminiPrompt = '''Categorize each transaction and extract structured data as a list of transactions with: date, amount, type (credit or debit), to_account, category, and description. Rules:
    1. I have these accounts. For these accounts the category would be "Internal Transfer".
        b. Baba RBL: account number - 309020687546
        c. My IDFC: account number - 10112867949, upi looks like 8604650326@something
        d. My HDFC: account number - 50100233891260, upi looks like 8604650326@ybl
    2. Categorise this as "Nupur Di Transfer":
        a. Nupur di phone number - 9582796471
    3. Use your intelligence to categorise. Example:
        a. UPI-IRCTC Web UPI-paytm-651536@ptybl-YESB0PTMUPI-284162166918-Oid100005764197150 Value Dt 01/05/2025 Ref 284162166918 - Travel (because IRCTC is train ticket company)
    4. CRED is used for "Credit Card Payment"
    5. If amount is less than 500, and transaction category is difficult to categorise, then categorise it as "Other":
        - UPI-KESHAV-9643511146@ybl-KKBK0004608-524841658646-Payment from Phone Value Dt 17/05 2025 Ref 524841658646 - Looks like some payment to a person. so make it "Other" if amount is less than 500
    6. If amount is greater than 500, and transaction category is difficult to categorise, then make it "Attention Needed"
    7. Categorise this as "Salary":
        - Something like Play Games24x7 Pvt Ltd Salary for May25 Value Dt 31/05/2025 Ref 505293289923
    8.Some UPI transaction of categorisation:
        - desription: UPI-NEETI GUPTA AND NEEL-9935889050@axl-UCBA0000310-144344019760-Shivani 3 tickets Value Dt 31/05/2025 Ref 144344019760
            - example: from the above description Shivani 3 tickets is the main description - which means this transaction was for flight tickets
        - desription: UPI-Westside A Unit of T-paytmd18384070493@pty-YESBOMCHUPI-770355822312-Shirt Value Dt 31/05/2025 Ref 770355822312
            - example: from the above description Shirt is the main description - which means this transaction was for garments

    9. Category will have things like: 
        - Travel
        - Groceries
        - Shopping
        - Salary
        - Credit Card Payment
        - Internal Transfer
        - Attention Needed
        - Other
        - Nupur Di Transfer and others based on your intelligence
    ''';
} 