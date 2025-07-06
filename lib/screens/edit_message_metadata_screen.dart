import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../providers/message_provider.dart';
import '../widgets/add_party_dialog.dart';
import '../utils/constants.dart';

class EditMessageMetadataScreen extends StatefulWidget {
  final MessageWithAmount message;

  const EditMessageMetadataScreen({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  State<EditMessageMetadataScreen> createState() => _EditMessageMetadataScreenState();
}

class _EditMessageMetadataScreenState extends State<EditMessageMetadataScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _typeController;
  late final TextEditingController _fromAccountController;
  late final TextEditingController _toAccountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late bool _isTransaction;
  late MessageWithAmount _currentMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize current message
    _currentMessage = widget.message;
    
    // Initialize controllers with current values
    _amountController = TextEditingController(text: widget.message.extractedAmountText);
    _dateController = TextEditingController(text: widget.message.transactionDate);
    _typeController = TextEditingController(text: widget.message.transactionType);
    _fromAccountController = TextEditingController(text: widget.message.from_account);
    _toAccountController = TextEditingController(text: widget.message.to_account);
    _categoryController = TextEditingController(text: widget.message.category);
    _descriptionController = TextEditingController(text: widget.message.description);
    _isTransaction = widget.message.isTransaction;
  }

  @override
  void dispose() {
    // Dispose controllers when not needed
    _amountController.dispose();
    _dateController.dispose();
    _typeController.dispose();
    _fromAccountController.dispose();
    _toAccountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Transaction Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
            tooltip: 'Save changes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Is Transaction Switch
            SwitchListTile(
              title: Text(
                'Is this a transaction?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: _isTransaction,
              onChanged: (value) {
                setState(() {
                  _isTransaction = value;
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            
            // Amount field
            _buildTextField(
              controller: _amountController,
              label: 'Amount',
              hint: 'Enter the transaction amount',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
            ),
            
            // Date field
            _buildTextField(
              controller: _dateController,
              label: 'Transaction Date',
              hint: 'YYYY-MM-DD',
              icon: Icons.calendar_today,
            ),
            
            // Transaction Type dropdown
            _buildDropdownField(
              controller: _typeController,
              label: 'Transaction Type',
              hint: 'Select transaction type',
              icon: Icons.swap_horiz,
              options: ['CREDIT', 'DEBIT', 'TRANSFER'],
            ),
            
            // From Account field with add party option
            _buildAccountField(
              controller: _fromAccountController,
              label: 'Payer\'s A/C',
              hint: 'Enter payer\'s account',
              icon: Icons.account_balance_wallet,
              accountType: 'payer',
            ),
            
            // To Account field with add party option
            _buildAccountField(
              controller: _toAccountController,
              label: 'Beneficiary\'s A/C',
              hint: 'Enter beneficiary\'s account',
              icon: Icons.account_balance,
              accountType: 'beneficiary',
            ),
            
            // Category dropdown
            _buildDropdownField(
              controller: _categoryController,
              label: 'Category',
              hint: 'Select category',
              icon: Icons.category,
              options: AppConstants.transactionCategories,
            ),
            
            // Description field
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Enter description',
              icon: Icons.description,
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Full message display (non-editable)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original Message',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.message.message.body ?? 'No message content',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: GoogleFonts.poppins(
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildAccountField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String accountType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.person_add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => _showAddPartyDialog(accountType),
                  tooltip: 'Add to Known Parties/My Accounts',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: GoogleFonts.poppins(
          fontSize: 16,
        ),
        onChanged: (value) {
          // Trigger rebuild to show/hide the add party button
          setState(() {});
        },
      ),
    );
  }


  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> options,
  }) {
    // Uppercase function
    String toUpperCase(String s) => s.toUpperCase();

    // Uppercase controller text
    final controllerTextUppercase = toUpperCase(controller.text);

    // Make a local list with uppercase options
    final List<String> dropdownOptions =
        options.map((opt) => toUpperCase(opt)).toSet().toList();

    // Add controller text if not already present (case-insensitively)
    if (controller.text.isNotEmpty &&
        !dropdownOptions
            .any((opt) => opt.toLowerCase() == controller.text.toLowerCase())) {
      dropdownOptions.add(controllerTextUppercase);
    }

    // Sort the dropdown options alphabetically
    dropdownOptions.sort();

    // Move "Other" to the end if present
    final otherIndex =
        dropdownOptions.indexWhere((opt) => opt.toLowerCase() == 'other');

    if (otherIndex != -1) {
      final otherOption = dropdownOptions.removeAt(otherIndex);
      dropdownOptions.add(otherOption);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: controllerTextUppercase.isEmpty ? null : controllerTextUppercase,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        dropdownColor: Colors.white,  // add this
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.black,        // add this
        ),
        items: dropdownOptions.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black),  // force visible text
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            controller.text = newValue;
          }
        },
      ),
    );
  }



  void _showAddPartyDialog(String accountType) {
    final accountName = accountType == 'payer' 
        ? _fromAccountController.text.trim()
        : _toAccountController.text.trim();
    
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the ${accountType == 'payer' ? 'payer\'s' : 'beneficiary\'s'} account first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddPartyDialog(
        accountName: accountName,
        accountType: accountType,
        message: _currentMessage,
        onMessageUpdated: (updatedMessage) {
          setState(() {
            _currentMessage = updatedMessage;
            _categoryController.text = updatedMessage.category;
          });
        },
      ),
    );
  }

  void _saveChanges() async {
    // Parse amount to double if possible
    double? parsedAmount;
    String? formattedAmount;
    
    if (_amountController.text.isNotEmpty && _amountController.text != 'NA') {
      try {
        // Clean amount string for parsing
        String amountStr = _amountController.text.replaceAll(',', '').replaceAll('Rs.', '').replaceAll('₹', '').trim();
        parsedAmount = double.parse(amountStr);
        
        // Format amount
        final formatter = NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 2,
        );
        formattedAmount = formatter.format(parsedAmount);
      } catch (e) {
        print('❌ Error parsing amount: $e');
        // Keep the original values if parsing fails
        parsedAmount = widget.message.amount;
        formattedAmount = widget.message.formattedAmount;
      }
    }

    // Create an updated message with the new values
    final updatedMessage = MessageWithAmount(
      message: widget.message.message,
      amount: parsedAmount,
      formattedAmount: formattedAmount,
      extractedAmountText: _amountController.text,
      isTransaction: _isTransaction,
      transactionDate: _dateController.text,
      transactionType: _typeController.text,
      from_account: _fromAccountController.text,
      to_account: _toAccountController.text,
      reason: _descriptionController.text,  // Use reason parameter but keep using description in UI
      category: _categoryController.text,
    );

    // Update the message in provider
    final provider = Provider.of<MessageProvider>(context, listen: false);
    await provider.updateMessage(updatedMessage);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction details updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, updatedMessage);
    }
  }
}
