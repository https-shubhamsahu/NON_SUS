import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/cryptography_service.dart';

void main() {
  group('CryptographyService', () {
    test('generates valid base64 symmetric key of correct length', () {
      final key = CryptographyService.generateSymmetricKey();
      expect(key, isNotEmpty);
      final decoded = base64.decode(key);
      expect(decoded.length, 32); // 256 bits
    });

    test('generates valid base64 IV of correct length', () {
      final iv = CryptographyService.generateIV();
      expect(iv, isNotEmpty);
      final decoded = base64.decode(iv);
      expect(decoded.length, 12); // 96 bits
    });

    test('encrypts and decrypts bytes successfully', () async {
      final key = CryptographyService.generateSymmetricKey();
      final iv = CryptographyService.generateIV();
      final plainText = 'Top Secret Protocol';
      final plainBytes = Uint8List.fromList(utf8.encode(plainText));

      final encrypted = await CryptographyService.encryptBytes(plainBytes, key, iv);
      expect(encrypted, isNot(equals(plainBytes)));

      final decrypted = await CryptographyService.decryptBytes(encrypted, key, iv);
      expect(decrypted, equals(plainBytes));
      expect(utf8.decode(decrypted), plainText);
    });

    test('decrypting with wrong key fails', () async {
      final key = CryptographyService.generateSymmetricKey();
      final wrongKey = CryptographyService.generateSymmetricKey();
      final iv = CryptographyService.generateIV();
      final plainBytes = Uint8List.fromList(utf8.encode('Data'));

      final encrypted = await CryptographyService.encryptBytes(plainBytes, key, iv);
      
      expect(
        () async => await CryptographyService.decryptBytes(encrypted, wrongKey, iv),
        throwsException,
      );
    });
  });
}
