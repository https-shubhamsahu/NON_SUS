import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/domain/repositories/auth_repository.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/auth/presentation/widgets/auth_gate.dart';
import 'package:no_sus/features/onboarding/presentation/widgets/interactive_onboarding_steps.dart';
import 'package:no_sus/services/secure_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('role selection continues to the single auth screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SecureDbService.instance.resetAppState();
    await SecureDbService.instance.loadPersistedState();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingPersonalizationWidget(
              onNext: () async {
                await SecureDbService.instance.completeOnboarding();
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('EDUCATOR'));
    await tester.ensureVisible(find.text('CONTINUE TO COMMUNITY'));
    await tester.tap(find.text('CONTINUE TO COMMUNITY'));
    await tester.pumpAndSettle();

    expect(SecureDbService.instance.userType, 'educator');
    expect(SecureDbService.instance.isOnboardingCompleted(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _SignedOutRepository(),
          ),
        ],
        child: const MaterialApp(
          home: AuthGate(child: SizedBox(key: Key('workspace'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUTHENTICATE'), findsOneWidget);
    expect(find.byKey(const Key('workspace')), findsNothing);
    expect(find.text('GET VERIFIED'), findsNothing);
  });
}

class _SignedOutRepository implements AuthRepository {
  const _SignedOutRepository();

  @override
  AuthenticatedUser? get currentUser => null;

  @override
  Stream<AuthenticatedUser?> watchAuthState() => Stream.value(null);

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGitHub() {
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithPhone(String phone) {
    throw UnimplementedError();
  }

  @override
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
