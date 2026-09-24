import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nosus_seal.dart';

/// Where this device's private key lives.
enum DeviceKeyKind { keystore, software, web }

/// This device's P-256 key for Drop and Group drops.
///
/// Android API 31+: the private key is created in Android Keystore and never
/// leaves it; only the ECDH result comes back (see DeviceKeyAgreement.kt).
/// Older Android: a Keystore-wrapped software key. Web: a software key in
/// browser storage, which is weaker and reported as [DeviceKeyKind.web].
abstract class DeviceKeyBackend {
  Future<DeviceKeyKind> kind();
  Future<Uint8List> publicKey();
  Future<Uint8List> agree(Uint8List peerPublic);
  Future<void> reset();
}

class AndroidDeviceKeyBackend implements DeviceKeyBackend {
  static const _channel = MethodChannel('co.nosus.app/device_keys');

  @override
  Future<DeviceKeyKind> kind() async {
    final k = await _channel.invokeMethod<String>('kind');
    return k == 'keystore' ? DeviceKeyKind.keystore : DeviceKeyKind.software;
  }

  @override
  Future<Uint8List> publicKey() async =>
      (await _channel.invokeMethod<Uint8List>('publicKey'))!;

  @override
  Future<Uint8List> agree(Uint8List peerPublic) async =>
      (await _channel.invokeMethod<Uint8List>('agree', {'peer': peerPublic}))!;

  @override
  Future<void> reset() => _channel.invokeMethod<void>('reset');
}

/// Web and tests. The private scalar sits in shared_preferences.
class SoftwareDeviceKeyBackend implements DeviceKeyBackend {
  static const _privKey = 'nosus_device_sw_priv';

  GoKeyPair? _pair;

  Future<GoKeyPair> _load() async {
    if (_pair != null) return _pair!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_privKey);
    if (stored != null) {
      _pair = keyPairFromPrivate(b64urlDecode(stored));
    } else {
      _pair = generateGoKeyPair();
      await prefs.setString(_privKey, b64url(_pair!.privateKey));
    }
    return _pair!;
  }

  @override
  Future<DeviceKeyKind> kind() async => DeviceKeyKind.web;

  @override
  Future<Uint8List> publicKey() async => (await _load()).publicKey;

  @override
  Future<Uint8List> agree(Uint8List peerPublic) async =>
      sharedSecret((await _load()).privateKey, peerPublic);

  @override
  Future<void> reset() async {
    _pair = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privKey);
  }
}

class DeviceKeys {
  DeviceKeys._(this._backend);

  static DeviceKeys instance = DeviceKeys._(
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidDeviceKeyBackend()
        : SoftwareDeviceKeyBackend(),
  );

  @visibleForTesting
  static void overrideForTest(DeviceKeyBackend backend) {
    instance = DeviceKeys._(backend);
  }

  final DeviceKeyBackend _backend;
  static const _deviceIdKey = 'nosus_device_id';
  String? _registeredFor;

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = b64url(randomBytes(16));
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<Uint8List> publicKey() => _backend.publicKey();
  Future<DeviceKeyKind> kind() => _backend.kind();

  /// Opens a sealed box addressed to this device.
  Future<Uint8List> open(Uint8List box, String context) async {
    final z = await _backend.agree(boxEphemeralPublic(box));
    return openBoxWithSecret(
      z: z,
      recipientPublic: await _backend.publicKey(),
      context: context,
      box: box,
    );
  }

  Future<String> openText(Uint8List box, String context) async =>
      utf8.decode(await open(box, context));

  /// Publishes this device's public key for the signed-in account.
  /// Cheap to call repeatedly; it only hits the server once per account per
  /// app run. Returns the device_keys row id.
  Future<String?> ensureRegistered({String? label}) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    if (_registeredFor == uid) return _registeredRowId;
    final kind = await _backend.kind();
    final id = await client.rpc('register_device_key', params: {
      'p_device_id': await deviceId(),
      'p_public_key': b64url(await _backend.publicKey()),
      'p_kind': kind.name,
      'p_label': label ?? _defaultLabel(),
    });
    _registeredFor = uid;
    _registeredRowId = id as String?;
    return _registeredRowId;
  }

  String? _registeredRowId;

  /// Forget this device's key (for "reset device key" in settings).
  Future<void> reset() async {
    _registeredFor = null;
    _registeredRowId = null;
    await _backend.reset();
  }

  String _defaultLabel() {
    if (kIsWeb) return 'Web browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android phone',
      TargetPlatform.iOS => 'iPhone',
      _ => 'Device',
    };
  }
}
