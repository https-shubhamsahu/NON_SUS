import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/features/profile/providers/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/features/groups/presentation/providers/group_dependencies.dart';
import 'package:no_sus/services/supabase_service.dart';
import 'package:no_sus/features/onboarding/presentation/providers/onboarding_providers.dart';

class OnboardingCommunityWidget extends ConsumerStatefulWidget {
  const OnboardingCommunityWidget({super.key});

  @override
  ConsumerState<OnboardingCommunityWidget> createState() =>
      _OnboardingCommunityWidgetState();
}

class _OnboardingCommunityWidgetState extends ConsumerState<OnboardingCommunityWidget> {
  bool _isFinishing = false;

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    HapticFeedback.mediumImpact();

    final user = SupabaseService.instance.isReachable ? Supabase.instance.client.auth.currentUser : null;
    if (user != null && SupabaseService.instance.isReachable) {
      // 1. Sync Profile
      final cache = await SupabaseService.instance.fetchProfile(user.id);
      String name = (cache['display_name'] ?? '').trim();
      if (name.isEmpty) {
        name = user.email != null && user.email!.contains('@')
            ? user.email!.split('@').first
            : 'Enclave Member';
      }

      await SupabaseService.instance.saveProfile(
        userId: user.id,
        email: user.email ?? '',
        displayName: name,
        avatarColorStart: cache['avatar_color_start'] ?? 'FF0072FF',
        avatarColorEnd: cache['avatar_color_end'] ?? 'FF00F2FE',
      );

      // 2. Join Global Community
      final repo = ref.read(studyGroupRepositoryProvider);
      await repo.ensureCommunityExists('Global Community', 'A home for all No Sus users.', true);
      await repo.joinGroupByName('Global Community', user.id);

      // 3. Join TSEC (Optional)
      final isTsec = ref.read(tsecCommunityProvider);
      if (isTsec) {
        await repo.ensureCommunityExists('TSEC, Kandivali', 'TSEC Kandivali Students Community', true);
        await repo.joinGroupByName('TSEC, Kandivali', user.id);
      }

      ref.invalidate(profileProvider);
    }

    ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final isTsec = ref.watch(tsecCommunityProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'JOIN YOUR COMMUNITY',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: fg,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You will automatically be added to the Global Community.\n\nAre you a student at TSEC, Kandivali?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: fg.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // TSEC Toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(tsecCommunityProvider.notifier).set(true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isTsec ? fg : Colors.transparent,
                        border: Border.all(
                          color: isTsec ? fg : fg.withValues(alpha: 0.15),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.school,
                            color: isTsec
                                ? (fg == Colors.black ? Colors.white : Colors.black)
                                : fg,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'YES',
                            style: TextStyle(
                              color: isTsec
                                  ? (fg == Colors.black ? Colors.white : Colors.black)
                                  : fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(tsecCommunityProvider.notifier).set(false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !isTsec ? fg : Colors.transparent,
                        border: Border.all(
                          color: !isTsec ? fg : fg.withValues(alpha: 0.15),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.public,
                            color: !isTsec
                                ? (fg == Colors.black ? Colors.white : Colors.black)
                                : fg,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'NO',
                            style: TextStyle(
                              color: !isTsec
                                  ? (fg == Colors.black ? Colors.white : Colors.black)
                                  : fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            GestureDetector(
              onTap: _isFinishing ? null : _finishOnboarding,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _isFinishing ? 'JOINING...' : 'FINISH ONBOARDING',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
