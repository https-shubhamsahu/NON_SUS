import '../entities/authenticated_user.dart';

abstract interface class AuthRepository {
  AuthenticatedUser? get currentUser;

  Stream<AuthenticatedUser?> watchAuthState();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithGitHub();
  Future<void> signInWithPhone(String phone);
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp);

  Future<void> signOut();
}
