import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/config/fhe_config.dart';
import 'package:no_sus/features/fhe/domain/fhe_key_manager.dart';

/// FheKeyManager is flag-gated by design: with every FHE capability flag off
/// (the default build, and the default `flutter test` run), initializeKeys
/// must be a no-op so no key material is ever held. With any flag enabled
/// (e.g. `flutter test --dart-define=FHE_ENABLE_BENCHMARKS=true`), it must
/// cache in RAM and zeroize on clear. These tests assert the contract that
/// matches the compile-time flags of the current run.
void main() {
  group('FheKeyManager Secure Lifecycle Tests', () {
    setUp(() {
      FheKeyManager.instance.clearKeys();
    });

    tearDown(() {
      FheKeyManager.instance.clearKeys();
    });

    test('Key initialization honors the FHE feature-flag gate', () {
      final clientBytes = Uint8List.fromList([1, 2, 3]);
      final serverBytes = Uint8List.fromList([4, 5, 6]);
      const keyId = "test-session-key";

      FheKeyManager.instance.initializeKeys(
        clientKey: clientBytes,
        serverKey: serverBytes,
        keyId: keyId,
      );

      if (FheConfig.anyEnabled) {
        expect(FheKeyManager.instance.hasKeys, isTrue);
        expect(FheKeyManager.instance.clientKey, equals(clientBytes));
        expect(FheKeyManager.instance.serverKey, equals(serverBytes));
        expect(FheKeyManager.instance.keyId, equals(keyId));
      } else {
        // Flags off: the manager must refuse to hold any key material.
        expect(FheKeyManager.instance.hasKeys, isFalse);
        expect(FheKeyManager.instance.clientKey, isNull);
        expect(FheKeyManager.instance.serverKey, isNull);
        expect(FheKeyManager.instance.keyId, isNull);
      }
    });

    test('Secure clear leaves no key material behind', () {
      final clientBytes = Uint8List.fromList([10, 20, 30]);
      final serverBytes = Uint8List.fromList([40, 50, 60]);

      FheKeyManager.instance.initializeKeys(
        clientKey: clientBytes,
        serverKey: serverBytes,
        keyId: "dummy-key",
      );

      // Trigger clear/zeroize
      FheKeyManager.instance.clearKeys();

      expect(FheKeyManager.instance.hasKeys, isFalse);
      expect(FheKeyManager.instance.clientKey, isNull);
      expect(FheKeyManager.instance.serverKey, isNull);
      expect(FheKeyManager.instance.keyId, isNull);

      if (FheConfig.anyEnabled) {
        // Flags on: the adopted buffers must be zeroized in place.
        expect(clientBytes, equals([0, 0, 0]));
        expect(serverBytes, equals([0, 0, 0]));
      } else {
        // Flags off: the manager never adopted the buffers, so the caller's
        // copies are untouched — and nothing was retained to zeroize.
        expect(clientBytes, equals([10, 20, 30]));
        expect(serverBytes, equals([40, 50, 60]));
      }
    });
  });
}
