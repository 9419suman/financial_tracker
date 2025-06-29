import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ModelSettingsScreen extends StatefulWidget {
  const ModelSettingsScreen({Key? key}) : super(key: key);

  @override
  _ModelSettingsScreenState createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  void _loadCurrentValues() {
    _apiKeyController.text = dotenv.env['GEMINI_API_KEY'] ?? '';
    _baseUrlController.text = dotenv.env['GEMINI_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1beta';
    _modelController.text = dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Create or update the environment map
        final Map<String, String> envMap = Map<String, String>.from(dotenv.env);

        // Update values
        envMap['GEMINI_API_KEY'] = _apiKeyController.text;
        envMap['GEMINI_BASE_URL'] = _baseUrlController.text;
        envMap['GEMINI_MODEL'] = _modelController.text;

        // Write to file
        await _writeEnvFile(envMap);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API settings saved successfully')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  Future<void> _writeEnvFile(Map<String, String> envMap) async {
    final sb = StringBuffer();
    
    // Write each key-value pair
    envMap.forEach((key, value) {
      sb.writeln('$key=$value');
    });
    
    try {
      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      
      // Make sure the directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/financial_tracker_config.env');
      
      // Write the file with explicit flags
      await file.writeAsString(sb.toString(), flush: true);
      
      // Update the env vars in memory
      dotenv.env.clear(); // Clear existing env vars
      envMap.forEach((key, value) {
        dotenv.env[key] = value; // Set values directly in memory
      });
    } catch (e) {
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
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // API Key
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter your Gemini API key',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Base URL
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'Enter Gemini API base URL',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a base URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Model
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Enter Gemini model name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save API Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
