import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'theme.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/theme_provider.dart';
import 'components/floating_nav.dart';
import 'screens/splash_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/workspace/presentation/pages/workspace_tab.dart';
import 'features/vault/presentation/pages/vault_tab.dart';
import 'features/vault/presentation/pages/study_desk_tab.dart';
import 'features/audit/presentation/pages/audit_tab.dart';

import 'services/supabase_service.dart';
import 'services/screenshot_guard.dart';
import 'services/audit_service.dart';
import 'services/share_intent_service.dart';
import 'features/workspace/presentation/widgets/save_to_no_sus_dialog.dart';
import 'features/focus/providers/focus_provider.dart';
import 'core/utils/debug_logger.dart';

import 'package:app_links/app_links.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // 1. Supabase MUST come first
      await SupabaseService.instance.initialize();
      
      // Listen to deep links for manual session recovery from OAuth redirects
      final appLinks = AppLinks();
      appLinks.uriLinkStream.listen((uri) async {
        debugLog('NO SUS: Received Deep Link: $uri');
        if (uri.scheme == 'io.supabase.nosus' && uri.host == 'login-callback') {
          try {
            debugLog('NO SUS: Recovering session from deep link URI...');
            await Supabase.instance.client.auth.getSessionFromUrl(uri);
            debugLog('NO SUS: Session recovered successfully!');
          } catch (e) {
            debugLog('NO SUS: Error recovering session from deep link: $e');
          }
        }
      });

      // Initialize security audit logging service
      AuditService.instance.init();
      // 2. Block screenshots (FLAG_SECURE on Android) + funny popup on attempt
      await ScreenshotGuard.instance.initialize();
      
      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      // Catch all unhandled async errors (e.g. Supabase realtime WebSocket failures)
      // These are logged but do NOT crash the app — the mock fallback data remains active.
      debugLog('NO SUS: Caught unhandled async error: $error');
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize share intent listener early
    ref.watch(shareIntentProvider);
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

class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void changeTab(int index) {
    state = index;
  }
}

final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(() {
  return ActiveTabNotifier();
});

class _WorkspaceHomeState extends ConsumerState<WorkspaceHome> {
  int _currentTab = 0;
  String? _deskFileId;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentTab = ref.read(activeTabProvider);
    _pageController = PageController(initialPage: _currentTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shared = ref.read(shareIntentProvider);
      if (shared != null) {
        _showSaveToNoSusModal(shared);
      }
    });
  }

  bool _isShareModalOpen = false;

  void _showSaveToNoSusModal(SharedContent content) {
    if (_isShareModalOpen) return;
    _isShareModalOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SaveToNoSusDialog(content: content),
    ).then((_) {
      _isShareModalOpen = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    ref.read(activeTabProvider.notifier).changeTab(index);
  }

  void _navigateToDesk(String fileId) {
    setState(() {
      _deskFileId = fileId;
    });
    ref.read(activeTabProvider.notifier).changeTab(2); // Jump to Study Desk
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
                        color: const Color(0xFF1A1A1A),
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
    ref.listen<SharedContent?>(shareIntentProvider, (previous, next) {
      if (next != null) {
        _showSaveToNoSusModal(next);
      }
    });

    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next != previous) {
        _pageController.jumpToPage(next);
      }
    });

    _currentTab = ref.watch(activeTabProvider);

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
