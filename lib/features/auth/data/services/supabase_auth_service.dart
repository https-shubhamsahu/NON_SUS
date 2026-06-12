import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client;

  const SupabaseAuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<User?> watchUser() async* {
    yield currentUser;
    yield* _client.auth.onAuthStateChange
        .map((state) => state.session?.user)
        .distinct((previous, next) => previous?.id == next?.id);
  }

  Future<User> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(response);
  }

  Future<User> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return _requireUser(response);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.nosus://login-callback/',
    );
  }

  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'io.supabase.nosus://login-callback/',
    );
  }

  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(
      phone: phone.trim(),
    );
  }

  Future<User> verifyPhoneOtp(String phone, String otp) async {
    final response = await _client.auth.verifyOTP(
      phone: phone.trim(),
      token: otp.trim(),
      type: OtpType.sms,
    );
    return _requireUser(response);
  }

  Future<void> signOut() => _client.auth.signOut();

  User _requireUser(AuthResponse response) {
    final user = response.user;
    if (user == null) {
      throw StateError('Supabase authentication returned no user.');
    }
    return user;
  }
}
