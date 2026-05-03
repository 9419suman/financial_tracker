import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../models/bank_config.dart';
import '../models/user_profile.dart';
import '../services/bank_auth_service.dart';
import '../services/bank_gmail_service.dart';
import '../services/bank_gemini_service.dart';
import '../services/deepseek_service.dart';
import '../services/password_cache_service.dart';
import '../services/pdf_decryptor.dart';
import '../services/cache_service.dart';
import '../config/bank_statement_config.dart';
import 'bank_settings_screen.dart';
import 'bank_transaction_results_screen.dart';

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({Key? key}) : super(key: key);

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

class _BankStatementScreenState extends State<BankStatementScreen> {
  final BankAuthService _authService = BankAuthService();
  late final BankGmailService _gmailService;
  final BankGeminiService _geminiService = BankGeminiService();
  final DeepSeekService _deepSeekService = DeepSeekService();
  final CacheService _cacheService = CacheService();

  UserProfile _profile = UserProfile.defaultProfile;

  bool _isLoading = true;
  bool _isSignedIn = false;
  bool _isProcessing = false;
  String _processingMessage = '';
  String _error = '';

  int _selectedMonths = 6;
  final Set<String> _selectedBankIds = {'hdfc', 'rbl'};

  List<EmailMessage> _emails = [];
  bool _hasFetched = false;

  static const _timeWindows = [1, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    _gmailService = BankGmailService(_authService);
    _loadProfileAndCheckSignIn();
  }

  Future<void> _loadProfileAndCheckSignIn() async {
    _profile = await UserProfile.load();
    try {
      final isSignedIn = await _authService.isSignedIn();
      setState(() {
        _isSignedIn = isSignedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error checking sign-in: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final account = await _authService.signIn();
      setState(() {
        _isSignedIn = account != null;
        _error = account == null ? 'Sign-in failed. Please try again.' : '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error during sign-in: $e'; _isLoading = false; });
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() { _isSignedIn = false; _emails = []; _hasFetched = false; });
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (_) => const BankSettingsScreen()),
    );
    if (updated != null) setState(() => _profile = updated);
  }

  Future<void> _fetchStatements() async {
    if (_selectedBankIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one bank')),
      );
      return;
    }
    setState(() { _isLoading = true; _error = ''; _emails = []; });
    try {
      final now = DateTime.now();
      final after = DateTime(now.year, now.month - _selectedMonths, now.day);
      final emails = await _gmailService.getBankStatements(
        bankIds: _selectedBankIds.toList(),
        after: after,
        before: now,
        maxResults: 50,
      );
      setState(() { _emails = emails; _isLoading = false; _hasFetched = true; });
    } catch (e) {
      setState(() { _error = 'Failed to load statements: $e'; _isLoading = false; });
    }
  }

  Future<void> _processAttachment(EmailMessage email, Attachment attachment) async {
    setState(() { _isProcessing = true; _processingMessage = 'Downloading PDF...'; });

    try {
      final pdfData = await _gmailService.downloadAttachment(email.id, attachment.id);
      if (pdfData == null) throw Exception('Failed to download attachment');

      setState(() => _processingMessage = 'Analyzing email (DeepSeek)...');

      // ── DeepSeek: get password (cached or fresh LLM call) ──────────────────
      final analysis = await _deepSeekService.analyzeEmail(
        subject:  email.subject,
        body:     email.body,
        filename: attachment.filename,
        profile:  _profile,
      );

      // ── Build ordered password list to try ─────────────────────────────────
      final List<String> passwords;
      if (analysis != null) {
        passwords = analysis.passwordsToTry;
      } else {
        // Fallback: no LLM result — generate candidates directly
        passwords = [
          ..._profile.bankPasswords.values,
          '${_profile.dd}${_profile.mm}${_profile.yyyy}',
          '${_profile.dd}${_profile.mm}',
          '',
        ];
      }

      setState(() => _processingMessage = 'Decrypting PDF...');

      var dataToAnalyze = pdfData;
      String? usedPassword;

      for (final pwd in passwords) {
        final decrypted = await PdfDecryptor.removePasswordFromPdf(pdfData, pwd);
        if (decrypted != null) {
          dataToAnalyze = decrypted;
          usedPassword = pwd;
          print('✅ Decrypted with: "${pwd.isEmpty ? '(no password)' : pwd}"');
          break;
        }
      }

      if (usedPassword == null) {
        print('⚠️ All passwords failed — proceeding with original PDF');
      }

      setState(() => _processingMessage = 'Parsing transactions...');

      final result = await _geminiService.processStatement(
        dataToAnalyze,
        BankStatementConfig.geminiPrompt,
        BankStatementConfig.geminiModel,
        emailId:      email.id,
        attachmentId: attachment.id,
        filename:     attachment.filename,
        onProgress:   (msg) => setState(() => _processingMessage = msg),
      );

      setState(() { _isProcessing = false; _processingMessage = ''; });

      if (result.transactions.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BankTransactionResultsScreen(
              transactions: result.transactions,
              email:        email,
              attachment:   attachment,
            ),
          ),
        );
      } else {
        _showError('No transactions found in the statement');
      }
    } catch (e) {
      setState(() { _isProcessing = false; _processingMessage = ''; });
      _showError('Error processing statement: $e');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _clearPasswordCache() async {
    await PasswordCacheService.instance.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password cache cleared'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(), SizedBox(width: 16), Text('Clearing cache...'),
        ]),
      ),
    );
    final result = await _cacheService.clearBankStatementCache();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ? 'Cache cleared' : 'Failed to clear cache'),
      backgroundColor: result ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bank Statements',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSignedIn) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Profile & Settings',
              onPressed: _openSettings,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'clear_cache') await _clearCache();
                if (v == 'clear_pwd_cache') await _clearPasswordCache();
                if (v == 'logout') await _signOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear_pwd_cache',
                    child: Row(children: [Icon(Icons.lock_reset), SizedBox(width: 8), Text('Clear Password Cache')])),
                PopupMenuItem(value: 'clear_cache',
                    child: Row(children: [Icon(Icons.clear_all), SizedBox(width: 8), Text('Clear Statement Cache')])),
                PopupMenuItem(value: 'logout',
                    child: Row(children: [Icon(Icons.logout), SizedBox(width: 8), Text('Sign Out')])),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading)    return const Center(child: CircularProgressIndicator());
    if (_isProcessing) return _buildProcessingView();
    if (!_isSignedIn)  return _buildSignInView();
    return _buildMainView();
  }

  Widget _buildSignInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Bank Statement Parser',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            Text(
              'Sign in with Google to fetch bank statements from Gmail and parse transactions.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(_error, style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        // Profile banner
        Container(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 16),
              const SizedBox(width: 6),
              Text(_profile.fullName,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton(
                onPressed: _openSettings,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('Edit',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
        ),
        _buildFiltersPanel(),
        Expanded(child: _hasFetched ? _buildEmailList() : _buildPromptFetch()),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time Window',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: _timeWindows.map((months) {
              final label = months == 12 ? '1 Year' : '$months Month${months > 1 ? 's' : ''}';
              final selected = _selectedMonths == months;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedMonths = months),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Select Banks',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: BankConfig.all.map((bank) {
              final selected = _selectedBankIds.contains(bank.id);
              return FilterChip(
                label: Text(bank.displayName, style: GoogleFonts.poppins(fontSize: 12)),
                selected: selected,
                onSelected: (val) => setState(() {
                  if (val) _selectedBankIds.add(bank.id);
                  else _selectedBankIds.remove(bank.id);
                }),
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchStatements,
              icon: const Icon(Icons.search),
              label: Text(
                  'Fetch Statements${_selectedBankIds.isNotEmpty ? ' (${_selectedBankIds.length} bank${_selectedBankIds.length > 1 ? 's' : ''})' : ''}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptFetch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Select banks and tap Fetch Statements',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    if (_emails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No bank statements found',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text(
                'No PDF statements found in the last $_selectedMonths month${_selectedMonths > 1 ? 's' : ''}.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchStatements,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emails.length,
        itemBuilder: (_, i) => _buildEmailCard(_emails[i]),
      ),
    );
  }

  Widget _buildEmailCard(EmailMessage email) {
    final bank = BankConfig.detectFromSender(email.sender);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance,
                    color: Theme.of(context).colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                if (bank != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(bank.displayName,
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                const Spacer(),
                Text(DateFormat('dd MMM yyyy').format(email.date),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(email.subject,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 4),
            Text('From: ${email.sender}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
            if (email.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...email.attachments.map((a) => _buildAttachmentRow(email, a)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(EmailMessage email, Attachment attachment) {
    return FutureBuilder<PdfPasswordCache?>(
      future: PasswordCacheService.instance.get(attachment.filename),
      builder: (_, snap) {
        final cached = snap.data;
        final isCached = cached != null;
        final isStatementCachedFuture = _cacheService.isBankStatementCached(
          emailId: email.id, attachmentId: attachment.id, filename: attachment.filename,
        );
        return FutureBuilder<bool>(
          future: isStatementCachedFuture,
          builder: (_, txSnap) {
            final txCached = txSnap.data ?? false;
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red[400], size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attachment.filename,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500, fontSize: 13)),
                        Row(
                          children: [
                            Text('${(attachment.size / 1024).toStringAsFixed(1)} KB',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[600])),
                            if (isCached) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('pwd cached',
                                    style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (txCached)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Cached',
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w500,
                              color: Colors.green[700])),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _processAttachment(email, attachment),
                    icon: Icon(txCached ? Icons.cached : Icons.analytics, size: 14),
                    label: Text(txCached ? 'View' : 'Parse',
                        style: GoogleFonts.poppins(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Processing...',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            Text(_processingMessage,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
