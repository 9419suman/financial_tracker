import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/sms_service.dart';
import '../services/cache_service.dart';

enum MessageFilter {
  all,
  bankTransactions, // Filter for bank transactions
}

class MessageProvider extends ChangeNotifier {
  final SmsService _smsService = SmsService();
  final CacheService _cacheService = CacheService();
  
  List<MessageWithAmount> _messages = [];
  List<MessageWithAmount> _filteredMessages = [];
  bool _isLoading = false;
  String _searchQuery = '';
  MessageFilter _currentFilter = MessageFilter.all;
  
  // Date filtering
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeMode = false;
  
  // Initialize with today's date
  MessageProvider() {
    // Set today as default
    setToday();
  }

  // Getters
  List<MessageWithAmount> get messages => _filteredMessages;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  MessageFilter get currentFilter => _currentFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get isDateRangeMode => _isDateRangeMode;
  
  // For backward compatibility
  DateTime get selectedDate => _startDate ?? DateTime.now();
    // Initialize and load messages
  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      print("📅 MESSAGE_PROVIDER: Loading messages with date filter: Start: ${_startDate}, End: ${_endDate}");
      
      // Get all messages first
      final rawMessages = await _smsService.getAllMessages();
      
      print("📅 MESSAGE_PROVIDER: Retrieved ${rawMessages.length} raw messages");
      
      // Filter messages by date range
      final dateFilteredMessages = rawMessages.where((message) {
        // Skip messages with null date
        if (message.message.date == null) return false;
        
        // Compare only the date part (ignoring time)
        final messageDate = DateTime(
          message.message.date!.year,
          message.message.date!.month,
          message.message.date!.day,
        );
        
        final startFilterDate = _startDate != null ? DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        ) : null;
        
        final endFilterDate = _endDate != null ? DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
        ) : null;
        
        //print("📅 MESSAGE_PROVIDER: Comparing message date $messageDate with filter range $startFilterDate to $endFilterDate");
        
        // If no date filters are set, include all messages
        if (startFilterDate == null) return true;
        
        // For single date filter (not range)
        if (!_isDateRangeMode || endFilterDate == null || startFilterDate.isAtSameMomentAs(endFilterDate)) {
          return messageDate.isAtSameMomentAs(startFilterDate);
        }
        
        // For date range
        return (messageDate.isAtSameMomentAs(startFilterDate) || 
                messageDate.isAfter(startFilterDate)) && 
               (messageDate.isAtSameMomentAs(endFilterDate) || 
                messageDate.isBefore(endFilterDate));
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
  
  // Set single date filter (for backward compatibility)
  void setSelectedDate(DateTime date) {
    _startDate = date;
    _endDate = date;
    _isDateRangeMode = false;
    loadMessages();
  }
  
  // Set date range filter
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _isDateRangeMode = true;
    loadMessages();
  }
  
  // Set to today only
  void setToday() {
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = _startDate;
    _isDateRangeMode = false;
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
    
    // Apply filter for bank transactions only
    if (_currentFilter == MessageFilter.bankTransactions) {
      _filteredMessages = _smsService.getBankTransactions(_filteredMessages);
      print("🔍 MESSAGE_PROVIDER: After bank transactions filter: ${_filteredMessages.length} messages");
    }
    
  print("🔍 MESSAGE_PROVIDER: Final filtered messages count: ${_filteredMessages.length}");
    notifyListeners();
  }
  
  // Clear cache and reload messages
  Future<void> clearCache() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      print("🧹 MESSAGE_PROVIDER: Clearing message cache");
      await _cacheService.clearCache();
      print("🧹 MESSAGE_PROVIDER: Cache cleared, reloading messages");
      
      // Reload messages after clearing cache
      await loadMessages();
    } catch (e) {
      print("🧹 MESSAGE_PROVIDER: ❌ Error clearing cache: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
