import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Client-side cryptographic helper implementing AES-256-GCM encryption.
class CryptographyService {
  static final Random _secureRandom = Random.secure();
  static final _algorithm = AesGcm.with256bits();

  /// Generates a cryptographically secure 256-bit symmetric key (base64 encoded).
  static String generateSymmetricKey() {
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return base64.encode(bytes);
  }

  /// Generates a cryptographically secure 96-bit Initialization Vector (base64 encoded).
  static String generateIV() {
    final bytes = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return base64.encode(bytes);
  }

  /// Encrypts bytes using AES-256-GCM.
  static Future<Uint8List> encryptBytes(Uint8List data, String keyBase64, String ivBase64) async {
    final key = SecretKey(base64.decode(keyBase64));
    final nonce = base64.decode(ivBase64);

    final secretBox = await _algorithm.encrypt(
      data,
      secretKey: key,
      nonce: nonce,
    );
    return Uint8List.fromList(secretBox.concatenation(nonce: false));
  }

  /// Decrypts bytes using AES-256-GCM.
  static Future<Uint8List> decryptBytes(Uint8List encryptedData, String keyBase64, String ivBase64) async {
    final key = SecretKey(base64.decode(keyBase64));
    final nonce = base64.decode(ivBase64);

    final secretBox = SecretBox.fromConcatenation(
      encryptedData,
      nonceLength: 0,
      macLength: _algorithm.macAlgorithm.macLength,
    );

    final decrypted = await _algorithm.decrypt(
      SecretBox(secretBox.cipherText, nonce: nonce, mac: secretBox.mac),
      secretKey: key,
    );
    return Uint8List.fromList(decrypted);
  }
}
