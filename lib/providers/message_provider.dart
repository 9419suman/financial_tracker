import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/sms_service.dart';

enum MessageFilter {
  all,
  withAmount,
}

class MessageProvider extends ChangeNotifier {
  final SmsService _smsService = SmsService();
  
  List<MessageWithAmount> _messages = [];
  List<MessageWithAmount> _filteredMessages = [];
  bool _isLoading = false;
  String _searchQuery = '';
  MessageFilter _currentFilter = MessageFilter.all;
  DateTime _selectedDate = DateTime(2025, 1, 1); // Default date: January 1, 2025
  
  // Getters
  List<MessageWithAmount> get messages => _filteredMessages;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  MessageFilter get currentFilter => _currentFilter;
  DateTime get selectedDate => _selectedDate;
  
  // Initialize and load messages
  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _messages = await _smsService.getAllMessages();
      _applyFilters();
    } catch (e) {
      print('Error loading messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }
  
  // Set filter
  void setFilter(MessageFilter filter) {
    _currentFilter = filter;
    _applyFilters();
  }
  
  // Set date filter
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _applyFilters();
  }
  
  // Apply filters based on search query and current filter
  void _applyFilters() {
    // Start with all messages
    _filteredMessages = List.from(_messages);
    
    // Apply date filter
    _filteredMessages = _filteredMessages.where((message) {
      // Skip messages with null date
      if (message.message.date == null) return false;
      
      // Compare only the date part (ignoring time)
      final messageDate = DateTime(
        message.message.date!.year,
        message.message.date!.month,
        message.message.date!.day,
      );
      
      final filterDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      
      // Show messages from the selected date onward
      return messageDate.isAtSameMomentAs(filterDate) || messageDate.isAfter(filterDate);
    }).toList();
      
    // Apply search filter if there's a query
    if (_searchQuery.isNotEmpty) {
      _filteredMessages = _filteredMessages.where((message) {
        final bool bodyContains = message.message.body?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        final String sender = message.message.sender ?? '';
        final bool senderContains = sender.toLowerCase().contains(_searchQuery.toLowerCase());
        return bodyContains || senderContains;
      }).toList();
    }
    
    // Apply amount filter if needed
    if (_currentFilter == MessageFilter.withAmount) {
      _filteredMessages = _smsService.getMessagesWithAmounts(_filteredMessages);
    }
    
    notifyListeners();
  }
}
