class BankConfig {
  final String id;
  final String displayName;
  final String keyword; // used in Gmail query: from:keyword
  final List<String> senderDomains; // for bank detection after fetch
  final String color;

  const BankConfig({
    required this.id,
    required this.displayName,
    required this.keyword,
    this.senderDomains = const [],
    required this.color,
  });

  static const List<BankConfig> all = [
    BankConfig(id: 'hdfc',     displayName: 'HDFC Bank',                keyword: 'hdfc',     color: '#003366'),
    BankConfig(id: 'rbl',      displayName: 'RBL Bank',                 keyword: 'rbl',      color: '#276749'),
    BankConfig(id: 'idfc',     displayName: 'IDFC First Bank',          keyword: 'idfc',     color: '#2C5282'),
    BankConfig(id: 'sbi',      displayName: 'SBI',                      keyword: 'sbi',      color: '#1A365D'),
    BankConfig(id: 'icici',    displayName: 'ICICI Bank',               keyword: 'icici',    color: '#B7791F'),
    BankConfig(id: 'axis',     displayName: 'Axis Bank',                keyword: 'axis',     color: '#702459'),
    BankConfig(id: 'kotak',    displayName: 'Kotak Bank',               keyword: 'kotak',    color: '#C05621'),
    BankConfig(id: 'pnb',      displayName: 'PNB',                      keyword: 'pnb',      color: '#2B4C7E'),
    BankConfig(id: 'canara',   displayName: 'Canara Bank',              keyword: 'canara',   color: '#276749'),
    BankConfig(id: 'indusind', displayName: 'IndusInd Bank',            keyword: 'indusind', color: '#553C9A'),
    BankConfig(id: 'federal',  displayName: 'Federal Bank',             keyword: 'federal',  color: '#2C5282'),
    BankConfig(id: 'csb',      displayName: 'CSB Bank',                 keyword: 'csb',      color: '#744210'),
    BankConfig(id: 'aubank',   displayName: 'AU Small Finance Bank',    keyword: 'aubank',   color: '#1A202C'),
    BankConfig(id: 'equitas',  displayName: 'Equitas Small Finance',    keyword: 'equitas',  color: '#234E52'),
    BankConfig(id: 'ujjivan',  displayName: 'Ujjivan Small Finance',    keyword: 'ujjivan',  color: '#322659'),
  ];

  static BankConfig? findById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // Keyword-based query — matches any sender containing the keyword (like Python).
  // Broader than exact sender matching, catches all domain variants.
  String buildGmailQuery({required DateTime after, required DateTime before}) {
    final afterStr =
        '${after.year}/${after.month.toString().padLeft(2, '0')}/${after.day.toString().padLeft(2, '0')}';
    final beforeStr =
        '${before.year}/${before.month.toString().padLeft(2, '0')}/${before.day.toString().padLeft(2, '0')}';
    return 'from:$keyword has:attachment filename:pdf after:$afterStr before:$beforeStr';
  }

  // Detect which bank an email belongs to by scanning the sender string.
  static BankConfig? detectFromSender(String sender) {
    final s = sender.toLowerCase();
    for (final bank in all) {
      if (s.contains(bank.keyword)) return bank;
    }
    return null;
  }
}
