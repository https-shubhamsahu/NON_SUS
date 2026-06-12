import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/theme.dart';
import '../providers/auth_providers.dart';
import '../screens/auth_screen.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    if (!onboardingCompleted) {
      return const OnboardingScreen();
    }

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const AuthScreen();
        }
        return child;
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.grey,
          ),
        ),
      ),
      error: (error, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
        final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Container(
                padding: const EdgeInsets.all(NoSusTheme.s32),
                decoration: NoSusTheme.cardDecoration(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.report_gmailerrorred_outlined,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s24),
                    Text(
                      'AUTHENTICATION ERROR',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.redAccent,
                        letterSpacing: 2.0,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s16),
                    Text(
                      error.toString().replaceAll('Exception: ', '').replaceAll('AuthApiException: ', ''),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtle,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s32),
                    GestureDetector(
                      onTap: () {
                        ref.invalidate(authStateProvider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'RETRY',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
