import 'dart:typed_data';

import '../../../config/fhe_config.dart';
import '../data/fhe_transport.dart';
import 'fhe_key_manager.dart';

/// Client-side FHE facade. Routes all cryptographic traffic through
/// [FheTransport] (Supabase Edge Function -> Rust microservice). The app never
/// links against TFHE-rs directly, so which backend runs is invisible here.
class FheEngine {
  /// Requests session key material. In the current build the private ClientKey
  /// is held only in RAM by [FheKeyManager]; Supabase stores metadata only.
  Future<void> generateKeys() async {
    if (!FheConfig.enableKeyGeneration) {
      throw StateError('Key generation is disabled (enableKeyGeneration).');
    }

    final res = await FheTransport.instance.send('generate_keys', {
      'security_level': 128,
      'parameter_set': 'default',
    });

    final keyId = (res['parameters_id'] ?? res['key_id'] ??
            'key-session-${DateTime.now().millisecondsSinceEpoch}')
        .toString();

    // Placeholder client/server key buffers; real ClientKey material will be
    // generated on-device once WASM/FFI TFHE is wired. Kept in RAM only.
    final clientKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
    final serverKey = Uint8List.fromList(List<int>.generate(64, (i) => i + 1));

    FheKeyManager.instance.initializeKeys(
      clientKey: clientKey,
      serverKey: serverKey,
      keyId: keyId,
    );
  }

  /// Rotates the session key material. The server generates a fresh key set
  /// (retiring the previous one in `fhe_key_metadata`), so any ciphertexts
  /// produced under the old keys must be re-encrypted after this returns.
  Future<void> rotateKeys() async {
    if (!FheConfig.enableKeyGeneration) {
      throw StateError('Key rotation is disabled (enableKeyGeneration).');
    }

    final res = await FheTransport.instance.send('rotate_keys', {
      'security_level': 128,
      'parameter_set': 'default',
    });

    final keyId = (res['parameters_id'] ?? res['key_id'] ??
            'key-session-${DateTime.now().millisecondsSinceEpoch}')
        .toString();

    // Placeholder client/server key buffers, rotated in RAM only (real ClientKey
    // material is generated on-device once WASM/FFI TFHE is wired).
    final clientKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
    final serverKey = Uint8List.fromList(List<int>.generate(64, (i) => i + 1));

    FheKeyManager.instance.initializeKeys(
      clientKey: clientKey,
      serverKey: serverKey,
      keyId: keyId,
    );
  }

  /// Revokes the session key material. The server drops its copy and marks the
  /// `fhe_key_metadata` row revoked; local key registers are zeroized.
  Future<void> revokeKeys() async {
    if (!FheConfig.enableKeyGeneration) {
      throw StateError('Key revocation is disabled (enableKeyGeneration).');
    }

    await FheTransport.instance.send('revoke_keys', const {});
    FheKeyManager.instance.clearKeys();
  }

  /// Encrypts an integer. Returns a base64 ciphertext.
  Future<String> encrypt(int value) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE is disabled via feature flags.');
    }
    final keyId = FheKeyManager.instance.keyId ?? 'default-key';
    final res = await FheTransport.instance.send('encrypt', {
      'key_id': keyId,
      'value': value,
    });
    return res['ciphertext'] as String;
  }

  /// Decrypts a base64 ciphertext back to an integer.
  Future<int> decrypt(String ciphertext) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE is disabled via feature flags.');
    }
    final keyId = FheKeyManager.instance.keyId ?? 'default-key';
    final res = await FheTransport.instance.send('decrypt', {
      'key_id': keyId,
      'ciphertext': ciphertext,
    });
    return (res['value'] as num).toInt();
  }
}
