import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/secure_enclave.dart';

void main() {
  setUp(() {
    SecureEnclave.purge();
  });

  group('SecureEnclave', () {
    test('loadPlainText sets active buffer', () {
      const testText = 'Hello, Enclave';
      SecureEnclave.loadPlainText(testText);

      expect(SecureEnclave.activeBuffer, isNotNull);
      expect(utf8.decode(SecureEnclave.activeBuffer!), testText);
    });

    test('registerDecryptedBuffer sets active buffer', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      SecureEnclave.registerDecryptedBuffer(bytes);

      expect(SecureEnclave.activeBuffer, isNotNull);
      expect(SecureEnclave.activeBuffer, bytes);
    });

    test('purge clears and zero-fills active buffer', () {
      final bytes = Uint8List.fromList([42, 42, 42]);
      SecureEnclave.registerDecryptedBuffer(bytes);
      
      expect(SecureEnclave.activeBuffer, isNotNull);
      
      SecureEnclave.purge();
      
      expect(SecureEnclave.activeBuffer, isNull);
      
      // Check if original reference was zero-filled
      expect(bytes, [0, 0, 0]);
    });
  });
}
