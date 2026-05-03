import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../models/bank_config.dart';

class BankSettingsScreen extends StatefulWidget {
  const BankSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BankSettingsScreen> createState() => _BankSettingsScreenState();
}

class _BankSettingsScreenState extends State<BankSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Personal fields
  late TextEditingController _nameCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cardLast4Ctrl;

  // One controller per bank that may have a customer ID
  final Map<String, TextEditingController> _bankPwdCtrls = {};

  // Banks that typically use a customer ID as PDF password
  static const _customerIdBanks = ['hdfc', 'rbl', 'idfc', 'sbi', 'icici', 'axis', 'kotak'];

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController();
    _dobCtrl       = TextEditingController();
    _panCtrl       = TextEditingController();
    _phoneCtrl     = TextEditingController();
    _cardLast4Ctrl = TextEditingController();
    for (final id in _customerIdBanks) {
      _bankPwdCtrls[id] = TextEditingController();
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _panCtrl.dispose();
    _phoneCtrl.dispose();
    _cardLast4Ctrl.dispose();
    for (final c in _bankPwdCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfile.load();
    setState(() {
      _nameCtrl.text      = profile.fullName;
      _dobCtrl.text       = '${profile.dd}/${profile.mm}/${profile.yyyy}';
      _panCtrl.text       = profile.pan;
      _phoneCtrl.text     = profile.phone;
      _cardLast4Ctrl.text = profile.cardLast4;
      for (final id in _customerIdBanks) {
        _bankPwdCtrls[id]!.text = profile.bankPasswords[id] ?? '';
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Parse DOB from DD/MM/YYYY
      final dobParts = _dobCtrl.text.trim().split('/');
      final dob = DateTime(
        int.parse(dobParts[2]),
        int.parse(dobParts[1]),
        int.parse(dobParts[0]),
      );

      final passwords = <String, String>{};
      for (final id in _customerIdBanks) {
        final v = _bankPwdCtrls[id]!.text.trim();
        if (v.isNotEmpty) passwords[id] = v;
      }

      final profile = UserProfile(
        fullName:      _nameCtrl.text.trim(),
        dateOfBirth:   dob,
        pan:           _panCtrl.text.trim().toUpperCase(),
        phone:         _phoneCtrl.text.trim(),
        cardLast4:     _cardLast4Ctrl.text.trim(),
        bankPasswords: passwords,
      );

      await profile.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Bank Settings',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader('Personal Details'),
                  const SizedBox(height: 8),
                  _field(_nameCtrl, 'Full Name', 'e.g. Prasun Kumar',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field(_dobCtrl, 'Date of Birth', 'DD/MM/YYYY',
                      keyboardType: TextInputType.datetime,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parts = v.trim().split('/');
                        if (parts.length != 3) return 'Use DD/MM/YYYY format';
                        try {
                          DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                        } catch (_) {
                          return 'Invalid date';
                        }
                        return null;
                      }),
                  const SizedBox(height: 12),
                  _field(_panCtrl, 'PAN', 'e.g. ABCDE1234F',
                      inputFormatters: [],
                      validator: (v) => (v == null || v.trim().length != 10)
                          ? 'PAN must be 10 characters'
                          : null),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Phone Number', 'e.g. 8604650326',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_cardLast4Ctrl, 'Credit Card Last 4 Digits',
                      'e.g. 1290 (used for SBI Cashback password)',
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 24),

                  _sectionHeader('Bank Customer IDs / PDF Passwords'),
                  const SizedBox(height: 4),
                  Text(
                    'Used to unlock password-protected bank statement PDFs.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ..._customerIdBanks.map((id) {
                    final bank = BankConfig.findById(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _field(
                        _bankPwdCtrls[id]!,
                        '${bank?.displayName ?? id.toUpperCase()} Customer ID',
                        'Leave blank if unknown',
                      ),
                    );
                  }),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Save Settings',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Theme.of(context).colorScheme.primary),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<dynamic> inputFormatters = const [],
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      );
}
