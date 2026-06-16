import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/theme.dart';
import '../providers/auth_providers.dart';
import '../screens/auth_screen.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../services/supabase_service.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    final isGuest = ref.watch(isGuestModeProvider);
    final authState = ref.watch(authStateProvider);

    // ── 1. Guest mode bypass ───────────────────────────────────────────────────
    if (isGuest) {
      if (!onboardingCompleted) {
        return const OnboardingScreen();
      }
      return child;
    }

    // ── 2. Auth state ──────────────────────────────────────────────────────────
    return authState.when(
      data: (user) {
        // If not logged in, force AuthScreen first
        if (user == null) {
          return const AuthScreen();
        }

        // ── 2a. Email confirmation gate ────────────────────────────────────────
        if (SupabaseService.instance.isReachable) {
          final rawUser = Supabase.instance.client.auth.currentUser;
          if (rawUser != null && rawUser.emailConfirmedAt == null) {
            return _EmailConfirmationScreen(email: user.email ?? '');
          }
        }

        // ── 2b. Profile / Onboarding Gate ──────────────────────────────────────
        if (!SupabaseService.instance.isReachable) {
          // Offline mode fallback
          if (onboardingCompleted) return child;
          return const OnboardingScreen();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: SupabaseService.instance.fetchProfile(user.id).then((profile) async {
            if (profile.isEmpty && SupabaseService.instance.isReachable) {
              try {
                // Verify the user actually still exists on the server
                await Supabase.instance.client.auth.getUser();
              } catch (e) {
                // Session invalid (e.g. user was deleted from DB but local token remains)
                await Supabase.instance.client.auth.signOut();
                return <String, dynamic>{};
              }
            }
            return profile;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Colors.grey)),
              );
            }

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SESSION ERROR',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.redAccent,
                            letterSpacing: 2.0,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString().replaceAll('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {
                            ref.invalidate(authStateProvider);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: fg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'RETRY',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final profileData = snapshot.data ?? {};
            final hasCompletedRemoteOnboarding = profileData['onboarding_completed'] == true;

            if (hasCompletedRemoteOnboarding && !onboardingCompleted) {
              // Remote profile onboarding is complete but local state is out of sync.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(onboardingCompletedProvider.notifier).complete();
                ref.invalidate(profileProvider);
              });
            }

            // Always allow entering workspace directly.
            // Onboarding popup will prompt inside WorkspaceHome if not completed.
            return child;
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.grey)),
      ),
      error: (error, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
        final subtle = isDark
            ? NoSusTheme.dTextSecondary
            : NoSusTheme.lTextSecondary;

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Container(
                padding: const EdgeInsets.all(NoSusTheme.s32),
                decoration: NoSusTheme.cardDecoration(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      error
                          .toString()
                          .replaceAll('Exception: ', '')
                          .replaceAll('AuthApiException: ', ''),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtle,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s32),
                    GestureDetector(
                      onTap: () => ref.invalidate(authStateProvider),
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

// ─── Email Confirmation Holding Screen ────────────────────────────────────────

class _EmailConfirmationScreen extends ConsumerWidget {
  final String email;
  const _EmailConfirmationScreen({required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated envelope icon
                Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: fg.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 40,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 2000.ms,
                    ),
                const SizedBox(height: 32),
                Text(
                  'CONFIRM YOUR EMAIL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    letterSpacing: 2.5,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a confirmation link to\n$email\n\nCheck your inbox and click the link to activate your account.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                // Check status button
                GestureDetector(
                  onTap: () => ref.invalidate(authStateProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 32,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "I'VE CONFIRMED — CONTINUE",
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sign out and try another account
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    ref.invalidate(authStateProvider);
                  },
                  child: Text(
                    'USE A DIFFERENT ACCOUNT',
                    style: TextStyle(
                      color: subtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
