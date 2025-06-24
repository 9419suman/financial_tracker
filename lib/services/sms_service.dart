import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message_model.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();
  
  // Request SMS permissions
  Future<bool> requestSmsPermission() async {
    var status = await Permission.sms.status;
    
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    
    return status.isGranted;
  }
  
  // Get all SMS messages
  Future<List<MessageWithAmount>> getAllMessages() async {
    final bool hasPermission = await requestSmsPermission();
    
    if (!hasPermission) {
      return [];
    }
    
    try {
      final messages = await _query.querySms();
      return messages.map((message) => MessageWithAmount.fromSmsMessage(message)).toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }
  
  // Filter messages to only include those with amounts
  List<MessageWithAmount> getMessagesWithAmounts(List<MessageWithAmount> messages) {
    return messages.where((message) => message.amount != null).toList();
  }
}
