import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure, device-local storage for AES-256-GCM file keys and IVs.
///
/// Keys are NEVER stored in the Supabase database. They live exclusively
/// in the device's secure enclave (Android Keystore / iOS Keychain).
///
/// This is the correct E2E encryption model: if the server is compromised,
/// the attacker cannot decrypt any file because the keys are device-local.
class SecureKeyStore {
  const SecureKeyStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String _keyKey(String fileId) => 'nosus_key_$fileId';
  static String _ivKey(String fileId) => 'nosus_iv_$fileId';

  /// Persist the AES key + IV for a specific file.
  static Future<void> saveFileKey(
    String fileId,
    String keyBase64,
    String ivBase64,
  ) async {
    try {
      await Future.wait([
        _storage.write(key: _keyKey(fileId), value: keyBase64),
        _storage.write(key: _ivKey(fileId), value: ivBase64),
      ]);
    } catch (e) {
      debugPrint('SecureKeyStore: saveFileKey error for $fileId — $e');
    }
  }

  /// Retrieve the AES key + IV for a specific file.
  /// Returns null if the keys have never been saved for this device.
  static Future<({String key, String iv})?> getFileKey(String fileId) async {
    try {
      final results = await Future.wait([
        _storage.read(key: _keyKey(fileId)),
        _storage.read(key: _ivKey(fileId)),
      ]);
      final key = results[0];
      final iv = results[1];
      if (key == null || iv == null) return null;
      return (key: key, iv: iv);
    } catch (e) {
      debugPrint('SecureKeyStore: getFileKey error for $fileId — $e');
      return null;
    }
  }

  /// Remove keys for a specific file (e.g. when file is deleted).
  static Future<void> deleteFileKey(String fileId) async {
    try {
      await Future.wait([
        _storage.delete(key: _keyKey(fileId)),
        _storage.delete(key: _ivKey(fileId)),
      ]);
    } catch (e) {
      debugPrint('SecureKeyStore: deleteFileKey error for $fileId — $e');
    }
  }

  /// Delete ALL stored file keys (used during sign-out).
  static Future<void> deleteAll() async {
    try {
      // Only delete nosus_key_* and nosus_iv_* entries — not third-party keys.
      final all = await _storage.readAll();
      final nosusKeys = all.keys.where(
        (k) => k.startsWith('nosus_key_') || k.startsWith('nosus_iv_'),
      );
      await Future.wait(nosusKeys.map((k) => _storage.delete(key: k)));
    } catch (e) {
      debugPrint('SecureKeyStore: deleteAll error — $e');
    }
  }

  /// Check if keys are available locally for a file.
  /// Returns false if the file was uploaded on a different device.
  static Future<bool> hasFileKey(String fileId) async {
    final result = await getFileKey(fileId);
    return result != null;
  }
}
