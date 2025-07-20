import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
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

  // Expansion state for sections
  bool _isAccountsExpanded = false;
  bool _isKnownPartiesExpanded = false;

  // Temporary entry controllers for adding new items
  final TextEditingController _tempAccountController = TextEditingController();
  bool _showTempAccount = false;
  
  // Temporary known party for adding new items
  KnownParty? _tempKnownParty;
  bool _showTempKnownParty = false;

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
      _showTempAccount = true;
      _tempAccountController.clear();
    });
  }

  void _saveTempAccount() {
    if (_tempAccountController.text.trim().isNotEmpty) {
      setState(() {
        _accountControllers.add(TextEditingController(text: _tempAccountController.text.trim()));
        _showTempAccount = false;
        _tempAccountController.clear();
        // Auto-expand if we're adding beyond the default view
        if (_accountControllers.length > 3) {
          _isAccountsExpanded = true;
        }
      });
    }
  }

  void _cancelTempAccount() {
    setState(() {
      _showTempAccount = false;
      _tempAccountController.clear();
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
      _showTempKnownParty = true;
      _tempKnownParty = KnownParty(name: '', label: '');
    });
  }

  void _saveTempKnownParty() {
    if (_tempKnownParty != null && _tempKnownParty!.name.trim().isNotEmpty) {
      setState(() {
        _knownParties.add(KnownParty(name: _tempKnownParty!.name.trim(), label: _tempKnownParty!.label));
        _showTempKnownParty = false;
        _tempKnownParty = null;
        // Auto-expand if we're adding beyond the default view
        if (_knownParties.length > 3) {
          _isKnownPartiesExpanded = true;
        }
      });
    }
  }

  void _cancelTempKnownParty() {
    setState(() {
      _showTempKnownParty = false;
      _tempKnownParty = null;
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
    _tempAccountController.dispose();
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
                      const SizedBox(height: 4),
                      const Text(
                        'Add your bank accounts, UPI IDs, credit cards, etc.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      
                      if (_accountControllers.length > 3 && !_isAccountsExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Showing 3 of ${_accountControllers.length} items',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      ..._buildAccountFieldsWithFade(),
                      
                      // Temporary account entry widget
                      if (_showTempAccount) _buildTempAccountWidget(),
                      
                      // Show All/Show Less button positioned above Add Account
                      if (_accountControllers.length > 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isAccountsExpanded = !_isAccountsExpanded;
                                });
                              },
                              icon: Icon(
                                _isAccountsExpanded ? Icons.expand_less : Icons.expand_more,
                              ),
                              label: Text(
                                _isAccountsExpanded 
                                  ? 'Show Less' 
                                  : 'Show All (${_accountControllers.length})',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 4),
                      const Text(
                        'Add people or merchants you transact with frequently',
                        style: TextStyle(color: Colors.grey),
                      ),
                      
                      if (_knownParties.length > 3 && !_isKnownPartiesExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Showing 3 of ${_knownParties.length} items',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      ..._buildKnownPartyFieldsWithFade(),
                      
                      // Temporary known party entry widget
                      if (_showTempKnownParty) _buildTempKnownPartyWidget(),
                      
                      // Show All/Show Less button positioned above Add Known Party
                      if (_knownParties.length > 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isKnownPartiesExpanded = !_isKnownPartiesExpanded;
                                });
                              },
                              icon: Icon(
                                _isKnownPartiesExpanded ? Icons.expand_less : Icons.expand_more,
                              ),
                              label: Text(
                                _isKnownPartiesExpanded 
                                  ? 'Show Less' 
                                  : 'Show All (${_knownParties.length})',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 8),
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
                isExpanded: true,
                items: AppConstants.allCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category.toUpperCase(),
                    child: Text(
                      category,
                      overflow: TextOverflow.ellipsis,
                    ),
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

  List<Widget> _buildAccountFieldsWithFade() {
    final totalFields = _accountControllers.length;
    final visibleCount = _isAccountsExpanded ? totalFields : math.min(3, totalFields);
    
    return List.generate(visibleCount, (index) {
      // Apply gradual fade effect to the last visible item when not expanded and there are more items
      final shouldFade = !_isAccountsExpanded && totalFields > 3 && index == 2;
      
      Widget field = Padding(
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
      );

      if (shouldFade) {
        return Stack(
          children: [
            field,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      
      return field;
    });
  }

  Widget _buildTempAccountWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _tempAccountController,
                  decoration: const InputDecoration(
                    labelText: 'New Account',
                    hintText: 'Enter account identifier',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelTempAccount,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveTempAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildKnownPartyFieldsWithFade() {
    final totalFields = _knownParties.length;
    final visibleCount = _isKnownPartiesExpanded ? totalFields : math.min(3, totalFields);
    
    return List.generate(visibleCount, (index) {
      // Apply gradual fade effect to the last visible item when not expanded and there are more items
      final shouldFade = !_isKnownPartiesExpanded && totalFields > 3 && index == 2;
      
      Widget field = Card(
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
                isExpanded: true,
                items: AppConstants.allCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category.toUpperCase(),
                    child: Text(
                      category,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _knownParties[index].label = value ?? '';
                  });
                },
                validator: (value) {
                  return null;
                },
              ),
            ],
          ),
        ),
      );

      if (shouldFade) {
        return Stack(
          children: [
            field,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      
      return field;
    });
  }

  Widget _buildTempKnownPartyWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.05),
      ),
      child: Column(
        children: [
          TextFormField(
            initialValue: _tempKnownParty?.name ?? '',
            decoration: const InputDecoration(
              labelText: 'New Known Party Name',
              hintText: 'Enter name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onChanged: (value) {
              if (_tempKnownParty != null) {
                _tempKnownParty!.name = value;
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _tempKnownParty?.label?.isEmpty ?? true ? null : _tempKnownParty!.label.toUpperCase(),
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'Select category',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: AppConstants.allCategories.map((String category) {
              return DropdownMenuItem<String>(
                value: category.toUpperCase(),
                child: Text(
                  category,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (_tempKnownParty != null) {
                setState(() {
                  _tempKnownParty!.label = value ?? '';
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelTempKnownParty,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveTempKnownParty,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


