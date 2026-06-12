import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Zero-Trust memory enclaves for sensitive document rendering in Volatile RAM.
/// Implements secure crypt-buffers and memory purging (zero-filling).
///
/// NOTE: This is a simulation. Dart is a managed language — zero-filling a
/// Uint8List does not guarantee memory is actually cleared. A proper native
/// implementation would use dart:ffi with mlock()/memset() on pinned memory.
class SecureEnclave {
  /// The active document cache in volatile RAM.
  static Uint8List? _activeBuffer;

  /// Returns the current active buffer.
  static Uint8List? get activeBuffer => _activeBuffer;

  /// Loads an encrypted base64 payload, decrypts it in-memory via XOR block
  /// and holds it exclusively in volatile memory.
  static Future<Uint8List> loadDocument(String encryptedBase64, String key) async {
    purge();
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final cipherBytes = base64Decode(encryptedBase64);
      final keyBytes = utf8.encode(key);

      final plainBytes = Uint8List(cipherBytes.length);
      for (int i = 0; i < cipherBytes.length; i++) {
        plainBytes[i] = cipherBytes[i] ^ keyBytes[i % keyBytes.length];
      }

      _activeBuffer = plainBytes;
      debugPrint("SecureEnclave: Successfully decrypted ${plainBytes.length} bytes into volatile RAM.");
      return _activeBuffer!;
    } catch (e) {
      debugPrint("SecureEnclave: Decryption error: $e");
      rethrow;
    }
  }

  /// Sets the active buffer directly to an existing in-memory decrypted buffer.
  static void registerDecryptedBuffer(Uint8List bytes) {
    purge();
    _activeBuffer = bytes;
    debugPrint("SecureEnclave: Registered in-memory decrypted buffer (${bytes.length} bytes) in volatile RAM.");
  }

  /// Purge the active memory buffer by explicitly overwriting (zero-filling) the bytes.
  static void purge() {
    if (_activeBuffer != null) {
      _activeBuffer!.fillRange(0, _activeBuffer!.length, 0);
      _activeBuffer = null;
      debugPrint("SecureEnclave: Active volatile RAM buffer zero-filled and purged.");
    }
  }

  /// Utility to encrypt a plain string using the same XOR cipher for generating mock feeds.
  static String encryptMockData(String plainText, String key) {
    final plainBytes = utf8.encode(plainText);
    final keyBytes = utf8.encode(key);

    final cipherBytes = Uint8List(plainBytes.length);
    for (int i = 0; i < plainBytes.length; i++) {
      cipherBytes[i] = plainBytes[i] ^ keyBytes[i % keyBytes.length];
    }

    return base64Encode(cipherBytes);
  }
}
