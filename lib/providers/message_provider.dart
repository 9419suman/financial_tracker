import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/sms_service.dart';

enum MessageFilter {
  all,
  withAmount,
  bankTransactions, // New filter for bank transactions
}

class MessageProvider extends ChangeNotifier {
  final SmsService _smsService = SmsService();
  
  List<MessageWithAmount> _messages = [];
  List<MessageWithAmount> _filteredMessages = [];
  bool _isLoading = false;
  String _searchQuery = '';
  MessageFilter _currentFilter = MessageFilter.all;
  DateTime _selectedDate = DateTime(2025, 6, 1); // Default date: June 1, 2025
  
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
      print("📅 MESSAGE_PROVIDER: Loading messages with date filter: ${_selectedDate.toString()}");
      
      // Get all messages first
      final rawMessages = await _smsService.getAllMessages();
      print("📅 MESSAGE_PROVIDER: Retrieved ${rawMessages.length} raw messages");
      
      // Filter messages by date first to reduce processing
      final dateFilteredMessages = rawMessages.where((message) {
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
        
        print("📅 MESSAGE_PROVIDER: Comparing message date ${messageDate.toString()} with filter date ${filterDate.toString()}");
        
        // Show messages from the selected date onward
        return messageDate.isAtSameMomentAs(filterDate) || messageDate.isAfter(filterDate);
      }).toList();
      
      print("📅 MESSAGE_PROVIDER: After date filter: ${dateFilteredMessages.length} messages remaining");
      
      // Process messages with Gemini API
      _messages = await _smsService.processMessagesWithGemini(dateFilteredMessages);
      print("📅 MESSAGE_PROVIDER: Processed ${_messages.length} messages with Gemini");
      
      _applyFilters();
    } catch (e) {
      print('📅 MESSAGE_PROVIDER: ❌ Error loading messages: $e');
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
    // Reload messages when date changes to get fresh Gemini processing
    loadMessages();
  }
    // Apply filters based on search query and current filter
  void _applyFilters() {
    print("🔍 MESSAGE_PROVIDER: Applying filters - Search: '${_searchQuery}', Filter: ${_currentFilter.toString()}");
    
    // Start with all messages
    _filteredMessages = List.from(_messages);
    print("🔍 MESSAGE_PROVIDER: Starting with ${_filteredMessages.length} messages");
      
    // Apply search filter if there's a query
    if (_searchQuery.isNotEmpty) {
      _filteredMessages = _filteredMessages.where((message) {
        final bool bodyContains = message.message.body?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        final String sender = message.message.sender ?? '';
        final bool senderContains = sender.toLowerCase().contains(_searchQuery.toLowerCase());
        return bodyContains || senderContains;
      }).toList();
      print("🔍 MESSAGE_PROVIDER: After search filter: ${_filteredMessages.length} messages");
    }
    
    // Apply filters
    if (_currentFilter == MessageFilter.withAmount) {
      _filteredMessages = _smsService.getMessagesWithAmounts(_filteredMessages);
      print("🔍 MESSAGE_PROVIDER: After amount filter: ${_filteredMessages.length} messages");
    } else if (_currentFilter == MessageFilter.bankTransactions) {
      _filteredMessages = _smsService.getBankTransactions(_filteredMessages);
      print("🔍 MESSAGE_PROVIDER: After bank transactions filter: ${_filteredMessages.length} messages");
    }
    
    print("🔍 MESSAGE_PROVIDER: Final filtered messages count: ${_filteredMessages.length}");
    notifyListeners();
  }
}
