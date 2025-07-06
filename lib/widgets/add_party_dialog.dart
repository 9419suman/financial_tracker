import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/account_service.dart';
import '../providers/message_provider.dart';
import '../models/message_model.dart';

class AddPartyDialog extends StatefulWidget {
  final String accountName;
  final String accountType; // 'payer' or 'beneficiary'
  final MessageWithAmount message;
  final Function(MessageWithAmount) onMessageUpdated;

  const AddPartyDialog({
    Key? key,
    required this.accountName,
    required this.accountType,
    required this.message,
    required this.onMessageUpdated,
  }) : super(key: key);

  @override
  State<AddPartyDialog> createState() => _AddPartyDialogState();
}

class _AddPartyDialogState extends State<AddPartyDialog> {
  final AccountService _accountService = AccountService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  
  List<String> _myAccounts = [];
  List<KnownParty> _knownParties = [];
  String _selectedAction = 'known_party'; // 'known_party' or 'my_account'
  String _selectedExisting = '';
  bool _isAddingNew = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.accountName;
    _loadData();
  }

  void _loadData() {
    _myAccounts = _accountService.getMyAccounts();
    _knownParties = _accountService.getKnownParties();
    
    // Check if the account already exists in either list
    final isMyAccount = _accountService.isMyAccount(widget.accountName);
    final isKnownParty = _accountService.isKnownParty(widget.accountName);
    
    if (isMyAccount || isKnownParty) {
      // If already exists, show selection mode
      _isAddingNew = false;
      if (isMyAccount) {
        _selectedAction = 'my_account';
        _selectedExisting = _myAccounts.firstWhere(
          (account) => account.toLowerCase() == widget.accountName.toLowerCase(),
          orElse: () => widget.accountName,
        );
      } else {
        _selectedAction = 'known_party';
        final party = _knownParties.firstWhere(
          (party) => party.name.toLowerCase() == widget.accountName.toLowerCase(),
          orElse: () => KnownParty(name: widget.accountName, label: ''),
        );
        _selectedExisting = party.name;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add ${widget.accountType == 'payer' ? 'Payer' : 'Beneficiary'}',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account name display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.accountType == 'payer' 
                          ? Icons.account_balance_wallet 
                          : Icons.account_balance,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.accountType == 'payer' ? 'Payer Account' : 'Beneficiary Account',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.accountName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action selection with toggle buttons
              Row(
                children: [
                  Icon(
                    Icons.category,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add to:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Column(
                children: [
                  _buildToggleOption(
                    icon: Icons.group,
                    title: 'Known Parties',
                    subtitle: 'People and merchants you transact with',
                    isSelected: _selectedAction == 'known_party',
                    onTap: () {
                      setState(() {
                        _selectedAction = 'known_party';
                        _selectedExisting = '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildToggleOption(
                    icon: Icons.account_balance_wallet,
                    title: 'My Accounts',
                    subtitle: 'Your own bank accounts and wallets',
                    isSelected: _selectedAction == 'my_account',
                    onTap: () {
                      setState(() {
                        _selectedAction = 'my_account';
                        _selectedExisting = '';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Divider and second section
              if (_selectedAction == 'known_party' && _knownParties.isNotEmpty ||
                  _selectedAction == 'my_account' && _myAccounts.isNotEmpty) ...[
                _buildSectionDivider(),
                const SizedBox(height: 24),
                
                // Second toggle section header
                Row(
                  children: [
                    Icon(
                      Icons.settings,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Choose Action:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Column(
                  children: [
                    _buildToggleOption(
                      icon: Icons.list,
                      title: 'Select Existing',
                      subtitle: 'Choose from saved ${_selectedAction == 'known_party' ? 'parties' : 'accounts'}',
                      isSelected: !_isAddingNew,
                      onTap: () {
                        setState(() {
                          _isAddingNew = false;
                          _selectedExisting = '';
                        });
                      },
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    _buildToggleOption(
                      icon: Icons.add,
                      title: 'Add New',
                      subtitle: 'Create a new entry',
                      isSelected: _isAddingNew,
                      onTap: () {
                        setState(() {
                          _isAddingNew = true;
                          _selectedExisting = '';
                        });
                      },
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 24),
              ],

              // Content based on selection
              if (!_isAddingNew) ...[
                _buildExistingSelection(),
              ] else ...[
                _buildNewEntryFields(),
              ],

              const SizedBox(height: 20),
              
              // Information panel
              _buildInfoPanel(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey.shade300,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withOpacity(0.2)
                    : effectiveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : effectiveColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isSelected 
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingSelection() {
    if (_selectedAction == 'known_party') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Known Party',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Choose a known party',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            value: _selectedExisting.isEmpty ? null : _selectedExisting,
            items: _knownParties.map((party) {
              return DropdownMenuItem<String>(
                value: party.name,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        party.label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        party.name,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedExisting = value ?? '';
              });
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select My Account',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Choose from my accounts',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            value: _selectedExisting.isEmpty ? null : _selectedExisting,
            items: _myAccounts.map((account) {
              return DropdownMenuItem<String>(
                value: account,
                child: Text(
                  account,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedExisting = value ?? '';
              });
            },
          ),
        ],
      );
    }
  }

  Widget _buildNewEntryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        
        if (_selectedAction == 'known_party') ...[
          const SizedBox(height: 20),
          Text(
            'Category Label',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              hintText: 'e.g., grocery, family, utilities',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAction == 'known_party' ? 'Known Parties' : 'My Accounts',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAction == 'known_party'
                      ? 'Adding to Known Parties will automatically set the transaction category based on the party\'s label.'
                      : 'Adding to My Accounts will help identify your own accounts in future transactions.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;
      String? newCategory;

      if (_isAddingNew) {
        // Add new entry
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          _showError('Please enter a name');
          return;
        }

        if (_selectedAction == 'known_party') {
          final label = _labelController.text.trim();
          if (label.isEmpty) {
            _showError('Please enter a category label');
            return;
          }
          success = await _accountService.addKnownParty(name, label);
          if (success) {
            newCategory = label.toUpperCase();
          }
        } else {
          success = await _accountService.addMyAccount(name);
        }
      } else {
        // Use existing selection
        if (_selectedExisting.isEmpty) {
          _showError('Please select an option');
          return;
        }

        if (_selectedAction == 'known_party') {
          // Get the category for the selected known party
          newCategory = _accountService.getCategoryForKnownParty(_selectedExisting);
        }
        success = true; // No need to add anything, just use existing
      }

      if (success) {
        // Update the message if we have a new category
        if (newCategory != null && newCategory.isNotEmpty) {
          final updatedMessage = widget.message.copyWith(
            category: newCategory,
          );
          
          // Update the message in the provider
          final provider = Provider.of<MessageProvider>(context, listen: false);
          await provider.updateMessage(updatedMessage);
          
          // Notify parent about the update
          widget.onMessageUpdated(updatedMessage);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAddingNew
                    ? 'Successfully added to ${_selectedAction == 'known_party' ? 'Known Parties' : 'My Accounts'}'
                    : 'Successfully updated transaction category',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _showError('Failed to save. Entry may already exist.');
      }
    } catch (e) {
      print('❌ Error saving: $e');
      _showError('Error saving: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
} 