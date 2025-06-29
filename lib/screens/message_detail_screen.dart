import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message_model.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'edit_message_metadata_screen.dart';

class MessageDetailScreen extends StatefulWidget {
  final MessageWithAmount message;

  const MessageDetailScreen({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  late MessageWithAmount _message;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Message Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
            tooltip: 'Edit transaction details',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              context,
              'From',
              _message.message.sender ?? 'Unknown Sender',
              Icons.person,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              'Date & Time',
              _message.formattedDate,
              Icons.access_time,
            ),
            if (_message.isTransaction && _message.transactionDate != 'NA') ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                'Transaction Date',
                _message.transactionDate,
                Icons.calendar_today,
              ),
            ],
            if (_message.amount != null) ...[
              const SizedBox(height: 16),
             _buildInfoCard(
                context,
                'Amount',
                _message.formattedAmount ?? '',
                MdiIcons.currencyInr,   // <- here's the rupee icon
                isAmount: true,
                isCredit: _message.transactionType.toLowerCase() == 'credit',
              ),
            ],
            if (_message.isTransaction && _message.transactionType != 'NA') ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                'Transaction Type',
                _message.transactionType,
                Icons.swap_horiz,
                isCredit: _message.transactionType.toLowerCase() == 'credit',
              ),
            ],
            if (_message.isTransaction && _message.category != 'NA') ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                'Category',
                _message.category,
                _getCategoryIcon(_message.category),
              ),
            ],
            if (_message.isTransaction && _message.account != 'NA') ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                'Account',
                _message.account,
                Icons.account_balance,
              ),
            ],
            if (_message.isTransaction && _message.description != 'NA') ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                'Description',
                _message.description,
                Icons.description,
              ),
            ],
            const SizedBox(height: 16),
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
                      'Full Message',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _message.message.body ?? 'No message content',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
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
  
  Future<void> _navigateToEdit() async {
    final result = await Navigator.push<MessageWithAmount>(
      context,
      MaterialPageRoute(
        builder: (context) => EditMessageMetadataScreen(message: _message),
      ),
    );
    
    // If we got a result back, update the message
    if (result != null) {
      setState(() {
        _message = result;
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();
    
    if (lowerCategory.contains('food') || lowerCategory.contains('restaurant') || lowerCategory.contains('dining')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('shopping') || lowerCategory.contains('purchase')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('travel') || lowerCategory.contains('transport')) {
      return Icons.directions_car;
    } else if (lowerCategory.contains('entertainment')) {
      return Icons.movie;
    } else if (lowerCategory.contains('health') || lowerCategory.contains('medical')) {
      return Icons.medical_services;
    } else if (lowerCategory.contains('utility') || lowerCategory.contains('bill')) {
      return Icons.receipt;
    } else if (lowerCategory.contains('salary') || lowerCategory.contains('income')) {
      return Icons.account_balance_wallet;
    } else if (lowerCategory.contains('transfer')) {
      return Icons.swap_horiz;
    } else {
      return Icons.category;
    }
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isAmount = false,
    bool isCredit = true,
  }) {
    final Color iconBgColor = isAmount || (title == 'Transaction Type')
        ? isCredit 
            ? Colors.green.shade100
            : Colors.red.shade100
        : Theme.of(context).colorScheme.primary.withOpacity(0.1);
    
    final Color iconColor = isAmount || (title == 'Transaction Type')
        ? isCredit
            ? Colors.green.shade800
            : Colors.red.shade800
        : Theme.of(context).colorScheme.primary;
      final Color? textColor = isAmount || (title == 'Transaction Type')
        ? isCredit
            ? Colors.green.shade800
            : Colors.red.shade800
        : null;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
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
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
