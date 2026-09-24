import 'package:local_auth/local_auth.dart';

Future<bool> confirmWithDeviceLock(String reason) async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    return await auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}
