// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/nosus_seal.dart';

// A local-only WebAuthn credential used as a device lock on the web app
// (iPhone Safari → Face ID / Touch ID). Nothing is sent to a server; the
// assertion is not verified anywhere. It only proves that the platform
// authenticator unlocked, which is what local_auth proves on Android.

@JS('navigator.credentials.create')
external JSPromise<JSObject?> _create(JSObject options);

@JS('navigator.credentials.get')
external JSPromise<JSObject?> _get(JSObject options);

@JS('PublicKeyCredential')
external JSObject? get _publicKeyCredential;

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _platformAvailable();

const _credKey = 'nosus_web_lock_cred';

JSObject _obj(Map<String, Object?> m) => m.jsify() as JSObject;

Future<bool> confirmWithDeviceLock(String reason) async {
  try {
    if (_publicKeyCredential == null) return false;
    if (!(await _platformAvailable().toDart).toDart) return false;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_credKey);
    if (stored == null) {
      final id = await _register(reason);
      if (id == null) return false;
      await prefs.setString(_credKey, b64url(id));
      return true; // creation itself required user verification
    }
    if (await _assert(b64urlDecode(stored))) return true;
    // Credential was deleted from the device: register a fresh one once.
    await prefs.remove(_credKey);
    final id = await _register(reason);
    if (id == null) return false;
    await prefs.setString(_credKey, b64url(id));
    return true;
  } catch (_) {
    return false;
  }
}

Future<Uint8List?> _register(String reason) async {
  final publicKey = _obj({
    'rp': {'name': 'NO SUS'},
    'user': {'name': 'NO SUS approvals', 'displayName': reason},
    'pubKeyCredParams': [
      {'type': 'public-key', 'alg': -7},
      {'type': 'public-key', 'alg': -257},
    ],
    'authenticatorSelection': {
      'authenticatorAttachment': 'platform',
      'userVerification': 'required',
      'residentKey': 'discouraged',
    },
    'attestation': 'none',
    'timeout': 60000,
  });
  publicKey.setProperty('challenge'.toJS, randomBytes(32).toJS);
  final user = publicKey.getProperty<JSObject>('user'.toJS);
  user.setProperty('id'.toJS, randomBytes(16).toJS);
  final cred = await _create(_obj({})..setProperty('publicKey'.toJS, publicKey)).toDart;
  if (cred == null) return null;
  return cred.getProperty<JSArrayBuffer>('rawId'.toJS).toDart.asUint8List();
}

Future<bool> _assert(Uint8List credentialId) async {
  final allow = _obj({'type': 'public-key'})..setProperty('id'.toJS, credentialId.toJS);
  final publicKey = _obj({'userVerification': 'required', 'timeout': 60000})
    ..setProperty('challenge'.toJS, randomBytes(32).toJS)
    ..setProperty('allowCredentials'.toJS, [allow].toJS);
  try {
    final result = await _get(_obj({})..setProperty('publicKey'.toJS, publicKey)).toDart;
    return result != null;
  } catch (_) {
    return false;
  }
}
