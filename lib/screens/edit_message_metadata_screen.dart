import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../providers/message_provider.dart';

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
  late final TextEditingController _toAccountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late bool _isTransaction;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current values
    _amountController = TextEditingController(text: widget.message.extractedAmountText);
    _dateController = TextEditingController(text: widget.message.transactionDate);
    _typeController = TextEditingController(text: widget.message.transactionType);
    _toAccountController = TextEditingController(text: widget.message.toAccount);
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
              options: ['CREDIT', 'DEBIT', 'TRANSFER', 'NA'],
            ),
            
            // To Account field
            _buildTextField(
              controller: _toAccountController,
              label: 'To Account',
              hint: 'Enter account or recipient',
              icon: Icons.account_balance,
            ),
            
            // Category dropdown
            _buildDropdownField(
              controller: _categoryController,
              label: 'Category',
              hint: 'Select category',
              icon: Icons.category,
              options: [
                'FOOD', 'SHOPPING', 'TRANSPORTATION', 'ENTERTAINMENT',
                'HEALTH', 'UTILITIES', 'INCOME', 'TRANSFER', 'OTHER', 'NA'
              ],
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


  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> options,
  }) {
    // Capitalize function
    String capitalize(String s) =>
        s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : '';

    // Capitalized controller text
    final controllerTextCapitalized = capitalize(controller.text);

    // Make a local list with capitalized options
    final List<String> dropdownOptions =
        options.map((opt) => capitalize(opt)).toSet().toList();

    // Add controller text if not already present (case-insensitively)
    if (controller.text.isNotEmpty &&
        !dropdownOptions
            .any((opt) => opt.toLowerCase() == controller.text.toLowerCase())) {
      dropdownOptions.add(controllerTextCapitalized);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: controllerTextCapitalized.isEmpty ? null : controllerTextCapitalized,
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
      toAccount: _toAccountController.text,
      category: _categoryController.text,
      description: _descriptionController.text,
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
