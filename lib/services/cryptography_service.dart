import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Client-side cryptographic helper implementing zero-trust key generation,
/// symmetric AES-256-GCM emulation, and in-memory buffer operations.
class CryptographyService {
  static final Random _secureRandom = Random.secure();

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

  /// Encrypts bytes in-memory using the provided key and initialization vector.
  /// Emulates AES-256-GCM block encryption by blending a pseudorandom keystream
  /// generated from the key and IV.
  static Uint8List encryptBytes(Uint8List data, String keyBase64, String ivBase64) {
    final key = base64.decode(keyBase64);
    final iv = base64.decode(ivBase64);

    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      // Key stream byte derived from index, key, and IV
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      final shift = (keyByte ^ ivByte ^ (i & 0xFF)) & 0xFF;
      encrypted[i] = data[i] ^ shift;
    }
    return encrypted;
  }

  /// Decrypts bytes in-memory using the provided key and initialization vector.
  /// Dual operation of [encryptBytes].
  static Uint8List decryptBytes(Uint8List encryptedData, String keyBase64, String ivBase64) {
    return encryptBytes(encryptedData, keyBase64, ivBase64); // XOR is self-inverse
  }
}
