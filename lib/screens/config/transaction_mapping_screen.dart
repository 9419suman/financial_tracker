import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../services/account_service.dart';
import '../../utils/constants.dart';

class TransactionMappingScreen extends StatefulWidget {
  const TransactionMappingScreen({Key? key}) : super(key: key);

  @override
  _TransactionMappingScreenState createState() => _TransactionMappingScreenState();
}

class _TransactionMappingScreenState extends State<TransactionMappingScreen> {
  final _formKey = GlobalKey<FormState>();
  final AccountService _accountService = AccountService();
  
  // For My Accounts
  final List<TextEditingController> _accountControllers = [];
  
  // For Known Parties
  final List<KnownParty> _knownParties = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  void _loadCurrentValues() {
    print('🔄 TRANSACTION_MAPPING: Loading current values...');
    
    // Load My Accounts using AccountService
    final myAccounts = _accountService.getMyAccounts();
    print('🔄 TRANSACTION_MAPPING: Loaded ${myAccounts.length} accounts');
    
    for (var account in myAccounts) {
      _accountControllers.add(TextEditingController(text: account));
    }
    
    // If there are no accounts saved yet, start with one empty field
    if (_accountControllers.isEmpty) {
      _accountControllers.add(TextEditingController());
    }
    
    // Load Known Parties using AccountService
    final knownParties = _accountService.getKnownParties();
    print('🔄 TRANSACTION_MAPPING: Loaded ${knownParties.length} known parties');
    
    _knownParties.addAll(knownParties);
    
    // If there are no known parties saved yet, start with one empty field
    if (_knownParties.isEmpty) {
      _knownParties.add(KnownParty(name: '', label: ''));
    }
    
    print('🔄 TRANSACTION_MAPPING: Loaded ${_accountControllers.length} accounts and ${_knownParties.length} known parties');
  }
  
  void _addAccount() {
    setState(() {
      _accountControllers.add(TextEditingController());
    });
  }
  
  void _removeAccount(int index) {
    setState(() {
      _accountControllers[index].dispose();
      _accountControllers.removeAt(index);
    });
  }
  
  void _addKnownParty() {
    setState(() {
      _knownParties.add(KnownParty(name: '', label: ''));
    });
  }
  
  void _removeKnownParty(int index) {
    setState(() {
      _knownParties.removeAt(index);
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        print('💾 TRANSACTION_MAPPING: Starting save process...');
        print('💾 TRANSACTION_MAPPING: Current env vars before save: ${dotenv.env.keys.toList()}');
        
        // Create or update the environment map
        final Map<String, String> envMap = Map<String, String>.from(dotenv.env);
        print('💾 TRANSACTION_MAPPING: envMap created with ${envMap.length} variables');

        // Update My Accounts
        final accounts = _accountControllers
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .join(',');
        
        print('💾 TRANSACTION_MAPPING: MY_ACCOUNTS to save: "$accounts"');
        envMap['MY_ACCOUNTS'] = accounts;
        
        // Update Known Parties
        final validKnownParties = _knownParties
            .where((party) => party.name.isNotEmpty)
            .toList();
            
        final knownPartiesJson = json.encode(
          validKnownParties.map((party) => {
            'name': party.name,
            'label': party.label.toUpperCase(),
          }).toList()
        );
        
        print('💾 TRANSACTION_MAPPING: KNOWN_PARTIES to save: "$knownPartiesJson"');
        envMap['KNOWN_PARTIES'] = knownPartiesJson;

        print('💾 TRANSACTION_MAPPING: Final envMap has ${envMap.length} variables: ${envMap.keys.toList()}');

        // Write to file
        await _writeEnvFile(envMap);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction mapping settings saved successfully')),
        );

        Navigator.pop(context);
      } catch (e) {
        print('❌ TRANSACTION_MAPPING: Error saving settings: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  Future<void> _writeEnvFile(Map<String, String> envMap) async {
    print('📝 TRANSACTION_MAPPING: Writing env file with ${envMap.length} variables');
    
    final sb = StringBuffer();
    
    // Write each key-value pair
    envMap.forEach((key, value) {
      sb.writeln('$key=$value');
    });
    
    final content = sb.toString();
    print('📝 TRANSACTION_MAPPING: File content to write:\n$content');
    
    try {
      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      print('📝 TRANSACTION_MAPPING: Documents directory: ${directory.path}');
      
      // Make sure the directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/financial_tracker_config.env');
      print('📝 TRANSACTION_MAPPING: Writing to file: ${file.path}');
      
      // Write the file with explicit flags
      await file.writeAsString(content, flush: true);
      
      // Verify the file was written
      final verifyContent = await file.readAsString();
      print('📝 TRANSACTION_MAPPING: File verification - length: ${verifyContent.length}');
      
      // Update the env vars in memory
      print('📝 TRANSACTION_MAPPING: Updating in-memory env vars');
      dotenv.env.clear(); // Clear existing env vars
      envMap.forEach((key, value) {
        dotenv.env[key] = value; // Set values directly in memory
      });
      
      print('📝 TRANSACTION_MAPPING: Final in-memory env vars: ${dotenv.env.keys.toList()}');
    } catch (e) {
      print('❌ TRANSACTION_MAPPING: Error writing file: $e');
      // Still update in-memory values even if file write fails
      dotenv.env.clear();
      envMap.forEach((key, value) {
        dotenv.env[key] = value;
      });
      
      // Rethrow the error to be caught by the caller
      rethrow;
    }
  }

  @override
  void dispose() {
    for (var controller in _accountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Mapping'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // My Accounts Section
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your bank accounts, UPI IDs, credit cards, etc.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._buildAccountFields(),
                      
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addAccount,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Known Parties Section
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Known Parties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add people or merchants you transact with frequently',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._buildKnownPartyFields(),
                      
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addKnownParty,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Known Party'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Save Button
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Mapping Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildAccountFields() {
    return List.generate(
      _accountControllers.length,
      (index) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _accountControllers[index],
                decoration: InputDecoration(
                  labelText: 'Account ${index + 1}',
                  hintText: 'Enter account identifier',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  // Account can be empty (will be ignored), so no validation needed
                  return null;
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeAccount(index),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildKnownPartyFields() {
    return List.generate(
      _knownParties.length,
      (index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _knownParties[index].name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _knownParties[index].name = value;
                        });
                      },
                      validator: (value) {
                        // Name can be empty (party will be ignored), so no validation needed
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeKnownParty(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _knownParties[index].label.isEmpty ? null : _knownParties[index].label.toUpperCase(),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Select category',
                  border: OutlineInputBorder(),
                ),
                items: AppConstants.transactionCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _knownParties[index].label = value ?? '';
                  });
                },
                validator: (value) {
                  // Category can be empty (party will be ignored), so no validation needed
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


