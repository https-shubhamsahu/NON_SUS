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

  /// Returns the current active buffer (null if purged).
  static Uint8List? get activeBuffer => _activeBuffer;

  /// Loads a plain UTF-8 string as the active buffer.
  /// Used for mock/fallback document content — no encryption key required.
  static void loadPlainText(String text) {
    purge();
    _activeBuffer = Uint8List.fromList(utf8.encode(text));
    debugPrint(
      'SecureEnclave: Loaded plain-text buffer (${_activeBuffer!.length} bytes) into volatile RAM.',
    );
  }

  /// Sets the active buffer directly to an existing in-memory decrypted buffer.
  /// Used after AES-256-GCM decryption by [CryptographyService].
  static void registerDecryptedBuffer(Uint8List bytes) {
    purge();
    _activeBuffer = bytes;
    debugPrint(
      'SecureEnclave: Registered in-memory decrypted buffer (${bytes.length} bytes) in volatile RAM.',
    );
  }

  /// Purge the active memory buffer by explicitly overwriting (zero-filling) the bytes.
  /// Called in [SpyglassViewer.dispose()] to enforce Zero-Trust memory hygiene.
  static void purge() {
    if (_activeBuffer != null) {
      _activeBuffer!.fillRange(0, _activeBuffer!.length, 0);
      _activeBuffer = null;
      debugPrint('SecureEnclave: Active volatile RAM buffer zero-filled and purged.');
    }
  }
}
