import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/theme_provider.dart';
import 'components/floating_nav.dart';
import 'screens/splash_screen.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/onboarding/presentation/providers/onboarding_providers.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/workspace/presentation/pages/workspace_tab.dart';
import 'features/vault/presentation/pages/vault_tab.dart';
import 'features/vault/presentation/pages/study_desk_tab.dart';
import 'features/audit/presentation/pages/audit_tab.dart';

import 'services/supabase_service.dart';
import 'services/secure_db_service.dart';
import 'services/screenshot_guard.dart';
import 'features/focus/providers/focus_provider.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // 1. Supabase MUST come first — SecureDbService._init() reads isReachable
      //    to decide whether to connect to real streams or fall back to mock data.
      await SupabaseService.instance.initialize();
      // 2. Now SecureDbService singleton is created with isReachable=true → real streams
      await SecureDbService.instance.loadPersistedState();
      // 3. Block screenshots (FLAG_SECURE on Android) + funny popup on attempt
      await ScreenshotGuard.instance.initialize();
      
      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      // Catch all unhandled async errors (e.g. Supabase realtime WebSocket failures)
      // These are logged but do NOT crash the app — the mock fallback data remains active.
      debugPrint('NO SUS: Caught unhandled async error: $error');
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'NO SUS',
      debugShowCheckedModeBanner: false,
      navigatorKey: ScreenshotGuard.instance.navigatorKey,
      theme: NoSusTheme.lightTheme,
      darkTheme: NoSusTheme.darkTheme,
      themeMode: themeMode,
      home: const VideoSplashScreen(
        nextScreen: AuthGate(
          child: WorkspaceHome(),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.contains('code=')) {
          return PageRouteBuilder(
            pageBuilder: (context, _, _) => const SizedBox.shrink(),
            transitionDuration: Duration.zero,
          );
        }
        return null;
      },
    );
  }
}

class WorkspaceHome extends ConsumerStatefulWidget {
  const WorkspaceHome({super.key});

  @override
  ConsumerState<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends ConsumerState<WorkspaceHome> {
  int _currentTab = 0;
  String? _deskFileId;
  bool _hasPromptedOnboarding = false;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingPromptIfNeeded();
    });
  }

  void _showOnboardingPromptIfNeeded() {
    if (_hasPromptedOnboarding) return;

    final onboardingCompleted = ref.read(onboardingCompletedProvider);
    final isGuest = ref.read(isGuestModeProvider);

    if (!onboardingCompleted && !isGuest) {
      _hasPromptedOnboarding = true;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
          final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: fg.withValues(alpha: 0.1), width: 1.5),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 28,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'INITIALIZE PROFILE',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      fontSize: 12,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Configure your customized profile identity, color scheme, and secure enclave vault settings to get the full security experience.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subtle,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: fg.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'LATER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: fg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'START SETUP',
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().scale(
            duration: 200.ms,
            curve: Curves.easeOutBack,
            begin: const Offset(0.9, 0.9),
          ).fadeIn(duration: 150.ms);
        },
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentTab) return;
    setState(() {
      _currentTab = index;
    });
    _pageController.jumpToPage(index);
  }

  void _navigateToDesk(String fileId) {
    setState(() {
      _deskFileId = fileId;
      _currentTab = 2; // Jump to Study Desk
    });
    _pageController.jumpToPage(2);
  }

  void _toggleTheme() {
    ref.read(themeModeProvider.notifier).toggle();
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NO SUS',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SILENT SECURITY WORKSPACE',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Minimalist Outlined Theme Selector Toggle
            GestureDetector(
              onTap: _toggleTheme,
              child: Container(
                padding: const EdgeInsets.all(NoSusTheme.s12),
                decoration: NoSusTheme.buttonDecoration(context, radius: 14),
                child: Icon(
                  isDark
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: NoSusTheme.s12),
            // Glowing Gradient Profile Avatar Button
            (() {
              final profileAsync = ref.watch(profileProvider);
              return profileAsync.maybeWhen(
                data: (profile) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            AppConstants.avatarAssetForId(profile.avatarId),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                orElse: () => GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: NoSusTheme.buttonDecoration(context, radius: 21),
                    child: Icon(
                      Icons.person_outline,
                      color: theme.colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              );
            })(),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(focusSessionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Area with thin border framing
            Padding(
              padding: const EdgeInsets.only(
                left: NoSusTheme.s24,
                right: NoSusTheme.s24,
                top: NoSusTheme.s16,
                bottom: 110.0, // Space for floating bottom nav
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar (Calm Monochrome UI Style)
                  _buildHeader(context, isDark),
                  const SizedBox(height: NoSusTheme.s24),

                  // Animated Screen Content — using PageView to preserve states properly
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Prevent swipe
                      children: [
                        const WorkspaceTab(),
                        VaultTab(onRevealRequested: _navigateToDesk),
                        StudyDeskTab(initialFileId: _deskFileId),
                        const AuditTab(),
                        const GroupsScreen(key: ValueKey('groups_tab')),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Floating bottom navigation
            FloatingNav(
              currentIndex: _currentTab,
              onTap: _onTabTapped,
            ),
          ],
        ),
      ),
    );
  }
}
