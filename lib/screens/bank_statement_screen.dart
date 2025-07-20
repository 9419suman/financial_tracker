import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../services/bank_auth_service.dart';
import '../services/bank_gmail_service.dart';
import '../services/bank_gemini_service.dart';
import '../services/pdf_decryption_service.dart';
import '../services/pdf_decryptor.dart';
import '../services/cache_service.dart';
import '../config/bank_statement_config.dart';
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
  final CacheService _cacheService = CacheService();
  
  List<EmailMessage> _emails = [];
  bool _isLoading = true;
  bool _isSignedIn = false;
  String _error = '';
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _gmailService = BankGmailService(_authService);
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    try {
      final isSignedIn = await _authService.isSignedIn();
      setState(() {
        _isSignedIn = isSignedIn;
        _isLoading = false;
      });
      
      if (isSignedIn) {
        _loadEmails();
      }
    } catch (e) {
      setState(() {
        _error = 'Error checking sign-in status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final account = await _authService.signIn();
      if (account != null) {
        setState(() {
          _isSignedIn = true;
        });
        _loadEmails();
      } else {
        setState(() {
          _error = 'Sign-in failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error during sign-in: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {
      _isSignedIn = false;
      _emails = [];
    });
  }

  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final emails = await _gmailService.getBankStatements(maxResults: 20);
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load bank statements: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _processAttachment(EmailMessage email, Attachment attachment) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Downloading attachment...';
    });

    try {
      // Download the attachment
      final pdfData = await _gmailService.downloadAttachment(email.id, attachment.id);
      if (pdfData == null) {
        throw Exception('Failed to download attachment');
      }

      setState(() {
        _processingMessage = 'Processing PDF...';
      });

      // Check if it's an HDFC statement that needs decryption
      var dataToAnalyze = pdfData;
      if (PdfDecryptionService.isHdfcBankStatement(attachment.filename, email.sender)) {
        setState(() {
          _processingMessage = 'Decrypting PDF...';
        });
        
        const password = PdfDecryptionService.defaultPassword;
        final decryptedPdf = await PdfDecryptor.removePasswordFromPdf(pdfData, password);
        
        if (decryptedPdf != null) {
          dataToAnalyze = decryptedPdf;
        } else {
          throw Exception('Failed to decrypt PDF');
        }
      }

      // Process with Gemini (now with caching support and progress callback)
      final result = await _geminiService.processStatement(
        dataToAnalyze,
        BankStatementConfig.geminiPrompt,
        BankStatementConfig.geminiModel,
        emailId: email.id,
        attachmentId: attachment.id,
        filename: attachment.filename,
        onProgress: (message) {
          setState(() {
            _processingMessage = message;
          });
        },
      );

      setState(() {
        _isProcessing = false;
        _processingMessage = '';
      });

      if (result.transactions.isNotEmpty) {
        // Navigate to results screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BankTransactionResultsScreen(
              transactions: result.transactions,
              email: email,
              attachment: attachment,
            ),
          ),
        );
      } else {
        _showErrorDialog('No transactions found in the statement');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingMessage = '';
      });
      _showErrorDialog('Error processing statement: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bank Statements',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSignedIn) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'clear_cache':
                    await _clearBankStatementCache();
                    break;
                  case 'logout':
                    await _signOut();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all),
                      SizedBox(width: 8),
                      Text('Clear Cache'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isSignedIn) {
      return _buildSignInView();
    }

    if (_error.isNotEmpty) {
      return _buildErrorView();
    }

    if (_isProcessing) {
      return _buildProcessingView();
    }

    return _buildEmailList();
  }

  Widget _buildSignInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Bank Statement Parser',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in with Google to access your bank statements from Gmail and automatically parse transactions.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadEmails,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing...',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _processingMessage,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    if (_emails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'No Bank Statements Found',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No HDFC bank statements were found in your Gmail.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emails.length,
        itemBuilder: (context, index) {
          final email = _emails[index];
          return _buildEmailCard(email);
        },
      ),
    );
  }

  Widget _buildEmailCard(EmailMessage email) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.email,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email.subject,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${email.sender}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(email.date)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (email.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Attachments:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...email.attachments.map((attachment) => _buildAttachmentItem(email, attachment)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(EmailMessage email, Attachment attachment) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: Colors.red[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.filename,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${(attachment.size / 1024).toStringAsFixed(1)} KB',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<bool>(
            future: _cacheService.isBankStatementCached(
              emailId: email.id,
              attachmentId: attachment.id,
              filename: attachment.filename,
            ),
            builder: (context, snapshot) {
              final isCached = snapshot.data ?? false;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCached) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Cached',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _processAttachment(email, attachment),
                    icon: Icon(isCached ? Icons.cached : Icons.analytics, size: 16),
                    label: Text(isCached ? 'View' : 'Parse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Clear bank statement cache
  Future<void> _clearBankStatementCache() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing cache...'),
            ],
          ),
        ),
      );

      final result = await _cacheService.clearBankStatementCache();
      
      Navigator.pop(context); // Close loading dialog
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank statement cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear cache'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 