import 'dart:typed_data';
import '../../../config/fhe_config.dart';
import '../../../core/utils/debug_logger.dart';

/// Manages client-side FHE key material strictly in-memory.
/// Ensures private ClientKeys never touch persistent storage (e.g. SSD disk).
class FheKeyManager {
  Uint8List? _clientKey;
  Uint8List? _serverKey;
  String? _keyId;

  FheKeyManager._privateConstructor();
  static final FheKeyManager instance = FheKeyManager._privateConstructor();

  /// Checks if keys are initialized in RAM
  bool get hasKeys => _clientKey != null;

  /// Retrieves the current ClientKey bytes
  Uint8List? get clientKey {
    if (!FheConfig.anyEnabled) return null;
    return _clientKey;
  }

  /// Retrieves the current ServerKey / Evaluation Key bytes
  Uint8List? get serverKey {
    if (!FheConfig.anyEnabled) return null;
    return _serverKey;
  }

  /// Retrieves the registered key identifier
  String? get keyId => _keyId;

  /// Loads keys into protected memory session
  void initializeKeys({
    required Uint8List clientKey,
    required Uint8List serverKey,
    required String keyId,
  }) {
    if (!FheConfig.anyEnabled) return;
    _clientKey = clientKey;
    _serverKey = serverKey;
    _keyId = keyId;
    debugLog("FHE keys loaded into secure RAM session. KeyID: $keyId");
  }

  /// Securely overwrites (zeroizes) key material in RAM
  void clearKeys() {
    if (_clientKey != null) {
      _clientKey!.fillRange(0, _clientKey!.length, 0);
      _clientKey = null;
    }
    if (_serverKey != null) {
      _serverKey!.fillRange(0, _serverKey!.length, 0);
      _serverKey = null;
    }
    _keyId = null;
    debugLog("FHE memory registers zeroized and cleared.");
  }
}
