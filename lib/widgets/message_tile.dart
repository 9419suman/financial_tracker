import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message_model.dart';

class MessageTile extends StatelessWidget {
  final MessageWithAmount message;
  final VoidCallback onTap;
  

  const MessageTile({
    Key? key,
    required this.message,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Slidable(
      // Enable sliding from right to left
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) {},
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
          SlidableAction(
            onPressed: (_) {},
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.archive,
            label: 'Archive',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        message.message.sender ?? 'Unknown Sender',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      message.formattedDate,
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.previewText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.amount != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: message.transactionType.toLowerCase() == 'transfer'
                            ? Colors.orange.shade100
                            : message.transactionType.toLowerCase() == 'credit' 
                                ? Colors.green.shade100 
                                : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        message.formattedAmount ?? '',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: message.transactionType.toLowerCase() == 'transfer'
                              ? Colors.orange.shade800
                              : message.transactionType.toLowerCase() == 'credit' 
                                  ? Colors.green.shade800 
                                  : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
                if (message.isTransaction && message.category != 'NA') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _getCategoryIcon(message.category),
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.category,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      if (message.transactionType != 'NA') 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.transactionType,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
}
