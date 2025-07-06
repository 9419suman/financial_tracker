import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class KnownParty {
  String name;
  String label;
  
  KnownParty({
    required this.name,
    required this.label,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'label': label.toUpperCase(),
    };
  }
  
  factory KnownParty.fromJson(Map<String, dynamic> json) {
    return KnownParty(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
    );
  }
}

class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  // Get My Accounts from environment
  List<String> getMyAccounts() {
    try {
      final myAccounts = dotenv.env['MY_ACCOUNTS'] ?? '';
      print('🏦 ACCOUNT_SERVICE: MY_ACCOUNTS value: "$myAccounts"');
      
      if (myAccounts.isNotEmpty) {
        final accounts = myAccounts.split(',')
            .map((account) => account.trim())
            .where((account) => account.isNotEmpty)
            .toList();
        print('🏦 ACCOUNT_SERVICE: Parsed accounts: $accounts');
        return accounts;
      }
      return [];
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error loading accounts: $e');
      return [];
    }
  }

  // Get Known Parties from environment
  List<KnownParty> getKnownParties() {
    try {
      final knownPartiesJson = dotenv.env['KNOWN_PARTIES'] ?? '';
      print('🏦 ACCOUNT_SERVICE: KNOWN_PARTIES value: "$knownPartiesJson"');
      
      if (knownPartiesJson.isNotEmpty) {
        final List<dynamic> parties = json.decode(knownPartiesJson);
        final List<KnownParty> knownParties = parties
            .map((party) => KnownParty.fromJson(party))
            .where((party) => party.name.isNotEmpty)
            .toList();
        print('🏦 ACCOUNT_SERVICE: Parsed known parties: ${knownParties.length}');
        return knownParties;
      }
      return [];
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error loading known parties: $e');
      return [];
    }
  }

  // Add a new account to My Accounts
  Future<bool> addMyAccount(String account) async {
    try {
      final currentAccounts = getMyAccounts();
      
      // Check if account already exists (case-insensitive)
      final accountExists = currentAccounts.any(
        (existing) => existing.toLowerCase() == account.toLowerCase()
      );
      
      if (accountExists) {
        print('🏦 ACCOUNT_SERVICE: Account already exists: $account');
        return false;
      }
      
      // Add the new account
      currentAccounts.add(account);
      
      // Save to environment
      await _saveEnvironmentChanges({
        'MY_ACCOUNTS': currentAccounts.join(','),
      });
      
      print('🏦 ACCOUNT_SERVICE: Added new account: $account');
      return true;
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error adding account: $e');
      return false;
    }
  }

  // Add a new known party
  Future<bool> addKnownParty(String name, String label) async {
    try {
      final currentParties = getKnownParties();
      
      // Check if party already exists (case-insensitive)
      final partyExists = currentParties.any(
        (existing) => existing.name.toLowerCase() == name.toLowerCase()
      );
      
      if (partyExists) {
        print('🏦 ACCOUNT_SERVICE: Known party already exists: $name');
        return false;
      }
      
      // Add the new party
      currentParties.add(KnownParty(name: name, label: label));
      
      // Convert to JSON
      final partiesJson = json.encode(
        currentParties.map((party) => party.toJson()).toList()
      );
      
      // Save to environment
      await _saveEnvironmentChanges({
        'KNOWN_PARTIES': partiesJson,
      });
      
      print('🏦 ACCOUNT_SERVICE: Added new known party: $name with label: $label');
      return true;
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error adding known party: $e');
      return false;
    }
  }

  // Get category for a known party by name
  String? getCategoryForKnownParty(String name) {
    try {
      final knownParties = getKnownParties();
      final party = knownParties.firstWhere(
        (party) => party.name.toLowerCase() == name.toLowerCase(),
        orElse: () => KnownParty(name: '', label: ''),
      );
      
      if (party.name.isNotEmpty) {
        print('🏦 ACCOUNT_SERVICE: Found category for $name: ${party.label}');
        return party.label;
      }
      
      return null;
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error getting category for known party: $e');
      return null;
    }
  }

  // Check if an account is in My Accounts
  bool isMyAccount(String account) {
    final myAccounts = getMyAccounts();
    return myAccounts.any(
      (existing) => existing.toLowerCase() == account.toLowerCase()
    );
  }

  // Check if a name is in Known Parties
  bool isKnownParty(String name) {
    final knownParties = getKnownParties();
    return knownParties.any(
      (existing) => existing.name.toLowerCase() == name.toLowerCase()
    );
  }

  // Save environment changes to file
  Future<void> _saveEnvironmentChanges(Map<String, String> changes) async {
    try {
      print('🏦 ACCOUNT_SERVICE: Saving environment changes: $changes');
      
      // Create or update the environment map
      final Map<String, String> envMap = Map<String, String>.from(dotenv.env);
      
      // Apply changes
      changes.forEach((key, value) {
        envMap[key] = value;
      });
      
      // Write to file
      await _writeEnvFile(envMap);
      
      // Update in-memory environment
      changes.forEach((key, value) {
        dotenv.env[key] = value;
      });
      
      print('🏦 ACCOUNT_SERVICE: Environment changes saved successfully');
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error saving environment changes: $e');
      rethrow;
    }
  }

  // Write environment file
  Future<void> _writeEnvFile(Map<String, String> envMap) async {
    try {
      final sb = StringBuffer();
      
      // Write each key-value pair
      envMap.forEach((key, value) {
        sb.writeln('$key=$value');
      });
      
      final content = sb.toString();
      
      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      
      // Make sure the directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/financial_tracker_config.env');
      await file.writeAsString(content, flush: true);
      
      print('🏦 ACCOUNT_SERVICE: Environment file written successfully');
    } catch (e) {
      print('🏦 ACCOUNT_SERVICE: ❌ Error writing environment file: $e');
      rethrow;
    }
  }
} 