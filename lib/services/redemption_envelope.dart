import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'burn_file_crypto.dart' show bytesToHex, hexToBytes;

/// Client-side envelope for pairing-link key material.
///
/// The pairing token and PIN are generated locally.  The backend receives
/// only SHA-256 look-up hashes and this ciphertext, so it cannot recover the
/// Burn key/IV it temporarily stores for a pending redemption.
class RedemptionEnvelope {
  const RedemptionEnvelope._();

  static const _pinHashPrefix = 'no-sus:redemption:pin:v1:';
  static const _wrapKeyPrefix = 'no-sus:redemption:wrap:v1:';

  static String tokenHash(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static String pinHash(String token, String pin) =>
      sha256.convert(utf8.encode('$_pinHashPrefix$token:$pin')).toString();

  static enc.Key _wrappingKey(String token, String pin) => enc.Key(
    Uint8List.fromList(
      sha256.convert(utf8.encode('$_wrapKeyPrefix$token:$pin')).bytes,
    ),
  );

  static ({String ciphertextHex, String ivHex}) seal({
    required String token,
    required String pin,
    required String keyHex,
    required String contentIvHex,
  }) {
    final iv = enc.IV.fromSecureRandom(16);
    final plaintext = jsonEncode({'key_hex': keyHex, 'iv_hex': contentIvHex});
    final encrypted = enc.Encrypter(
      enc.AES(_wrappingKey(token, pin), mode: enc.AESMode.cbc),
    ).encrypt(plaintext, iv: iv);
    return (
      ciphertextHex: bytesToHex(Uint8List.fromList(encrypted.bytes)),
      ivHex: iv.base16,
    );
  }

  static ({String keyHex, String ivHex}) open({
    required String token,
    required String pin,
    required String ciphertextHex,
    required String envelopeIvHex,
  }) {
    final plaintext =
        enc.Encrypter(
          enc.AES(_wrappingKey(token, pin), mode: enc.AESMode.cbc),
        ).decrypt(
          enc.Encrypted(hexToBytes(ciphertextHex)),
          iv: enc.IV.fromBase16(envelopeIvHex),
        );
    final decoded = jsonDecode(plaintext) as Map<String, dynamic>;
    final keyHex = decoded['key_hex'] as String?;
    final ivHex = decoded['iv_hex'] as String?;
    if (keyHex == null || ivHex == null) {
      throw const FormatException('Invalid pairing envelope.');
    }
    return (keyHex: keyHex, ivHex: ivHex);
  }
}
