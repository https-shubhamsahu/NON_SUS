import 'platform_lock_io.dart'
    if (dart.library.js_interop) 'platform_lock_web.dart' as impl;

/// Asks the person holding this device to prove it's them: fingerprint,
/// face or device PIN on Android (local_auth); Face ID / Touch ID / Windows
/// Hello on the web app through a local WebAuthn platform authenticator.
///
/// This is a local presence check only — the server does not verify it.
/// Returns false when no lock is set up or the prompt was cancelled.
Future<bool> confirmWithDeviceLock(String reason) => impl.confirmWithDeviceLock(reason);
