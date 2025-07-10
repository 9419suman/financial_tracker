import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../config/bank_statement_config.dart';

class BankAuthService {
  static const _scopes = [
    GmailApi.gmailReadonlyScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    serverClientId: BankStatementConfig.googleServerClientId,
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Get current signed-in account
  Future<GoogleSignInAccount?> get currentUser async {
    return _googleSignIn.currentUser;
  }

  // Sign in with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        // Save user info to secure storage for persistence
        await _secureStorage.write(key: 'bank_email', value: account.email);
        await _secureStorage.write(key: 'bank_displayName', value: account.displayName);
        await _secureStorage.write(key: 'bank_photoUrl', value: account.photoUrl);
      }
      return account;
    } catch (error) {
      debugPrint('Error signing in: $error');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _secureStorage.delete(key: 'bank_email');
    await _secureStorage.delete(key: 'bank_displayName');
    await _secureStorage.delete(key: 'bank_photoUrl');
  }

  // Get authenticated HTTP client for Gmail API
  Future<http.Client> getAuthenticatedClient() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) {
      throw Exception('User not signed in');
    }

    final authHeaders = await account.authHeaders;
    final client = BankAuthClient(
      http.Client(),
      AccessCredentials(
        AccessToken(
          'Bearer',
          authHeaders['Authorization']!.substring(7),
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null, // No refresh token needed with GoogleSignIn
        _scopes,
      ),
    );

    return client;
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
}

class BankAuthClient extends http.BaseClient {
  final http.Client _inner;
  final AccessCredentials _credentials;

  BankAuthClient(this._inner, this._credentials);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer ${_credentials.accessToken.data}';
    return _inner.send(request);
  }
} 