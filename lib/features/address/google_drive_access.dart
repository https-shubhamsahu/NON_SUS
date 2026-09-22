import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/go_config.dart';
import 'drive_saved_store.dart';

/// Google stays on the phone. The borrowed computer never sees this token.
class GoogleDriveAccess {
  GoogleDriveAccess._();
  static final GoogleDriveAccess instance = GoogleDriveAccess._();

  static const scope = 'https://www.googleapis.com/auth/drive.file';
  static const _emailKey = 'go_drive_email';

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (!GoConfig.isConfigured) {
      throw const DriveFailure(
        'config',
        'Drive is not configured. Build with GO_WEB_CLIENT_ID.',
      );
    }
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? GoConfig.webClientId : null,
      serverClientId: GoConfig.webClientId,
    );
    _initialized = true;
  }

  Future<String?> savedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Interactive connect. Returns the account email, or null when the
  /// client id was never compiled in.
  Future<String?> connect() async {
    if (!GoConfig.isConfigured) return null;
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const [scope],
      );
      await account.authorizationClient.authorizeScopes(const [scope]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailKey, account.email);
      return account.email;
    } on GoogleSignInException catch (e) {
      throw DriveFailure('auth', e.description ?? 'Google sign-in was cancelled.');
    }
  }

  Future<void> switchAccount() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }

  /// Silent token, then one prompt if [prompt] is set. A 401 from Drive
  /// should call this again with [prompt] true after [clear].
  Future<String> accessToken({bool prompt = false}) async {
    await _ensureInit();
    final client = GoogleSignIn.instance.authorizationClient;
    final silent = await client.authorizationForScopes(const [scope]);
    if (silent != null) return silent.accessToken;
    if (!prompt) {
      throw const DriveFailure('auth', 'Connect Google Drive first.');
    }
    try {
      final fresh = await client.authorizeScopes(const [scope]);
      return fresh.accessToken;
    } on GoogleSignInException catch (e) {
      throw DriveFailure('auth', e.description ?? 'Google access expired.');
    }
  }

  Future<void> clear(String token) async {
    if (!_initialized) return;
    await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
      accessToken: token,
    );
  }
}
