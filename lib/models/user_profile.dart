import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String fullName;
  final DateTime dateOfBirth;
  final String pan;
  final String phone;
  final String cardLast4;
  final Map<String, String> bankPasswords; // bankId -> customer ID / password

  const UserProfile({
    required this.fullName,
    required this.dateOfBirth,
    required this.pan,
    this.phone = '',
    this.cardLast4 = '',
    this.bankPasswords = const {},
  });

  // Computed helpers
  String get firstName => fullName.trim().split(' ').first;
  String get dd => dateOfBirth.day.toString().padLeft(2, '0');
  String get mm => dateOfBirth.month.toString().padLeft(2, '0');
  String get yyyy => dateOfBirth.year.toString();
  String get yy => yyyy.substring(2);

  // Pre-filled default (Prasun's profile)
  static final defaultProfile = UserProfile(
    fullName: 'Prasun Kumar',
    dateOfBirth: DateTime(1997, 6, 21),
    pan: 'GQWPK9281H',
    phone: '8604650326',
    cardLast4: '1290',
    bankPasswords: const {
      'hdfc': '114210210',
      'rbl': '103850977',
      'idfc': '6025167902',
    },
  );

  static const _prefsKey = 'user_profile_v1';

  static Future<UserProfile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return defaultProfile;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'dob': dateOfBirth.toIso8601String(),
        'pan': pan,
        'phone': phone,
        'cardLast4': cardLast4,
        'bankPasswords': bankPasswords,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['fullName'] as String? ?? '',
        dateOfBirth: DateTime.parse(json['dob'] as String),
        pan: json['pan'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        cardLast4: json['cardLast4'] as String? ?? '',
        bankPasswords: Map<String, String>.from(
            (json['bankPasswords'] as Map?) ?? {}),
      );

  UserProfile copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    String? pan,
    String? phone,
    String? cardLast4,
    Map<String, String>? bankPasswords,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        pan: pan ?? this.pan,
        phone: phone ?? this.phone,
        cardLast4: cardLast4 ?? this.cardLast4,
        bankPasswords: bankPasswords ?? this.bankPasswords,
      );
}
