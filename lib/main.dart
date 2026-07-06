import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;


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
import 'features/share/presentation/screens/anonymous_share_viewer_screen.dart';
import 'features/share/presentation/screens/in_app_share_viewer_screen.dart';
import 'features/share/presentation/screens/share_analytics_screen.dart';
import 'features/share/presentation/providers/share_providers.dart';
import 'features/share/domain/entities/share_link.dart';

import 'package:app_links/app_links.dart';
import 'features/config/data/remote_config_service.dart';
import 'features/config/presentation/providers/config_provider.dart';


import 'features/share/presentation/screens/burn_note_viewer_screen.dart';

class BurnNoteToken {
  final String id;
  final String keyHex;
  final String ivHex;
  BurnNoteToken({required this.id, required this.keyHex, required this.ivHex});
}

BurnNoteToken? _extractBurnNoteToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  debugLog('NO SUS: Extracting Burn Note Token from: $fullUrl');
  final regExp = RegExp(
    r'burn/([a-f0-9\-]{36})(?:#|%23|/)([a-f0-9]{64})\.([a-f0-9]{32})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(fullUrl);
  if (match != null) {
    debugLog('NO SUS: Burn Note Token Matched! ID: ${match.group(1)}');
    return BurnNoteToken(
      id: match.group(1)!,
      keyHex: match.group(2)!,
      ivHex: match.group(3)!,
    );
  }
  debugLog('NO SUS: No Burn Note Token match.');
  return null;
}

/// Extracts a SecureSend share token from a `/v/<token>` URL, checking both
/// the fragment (default hash-based web routing, e.g. `#/v/abc123`) and the
/// path, so the link works regardless of URL strategy. Returns null on any
/// other platform/URL shape — this only ever matches an intentional share link.
String? _extractShareToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'v' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }
  return null;
}

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // SecureSend anonymous path: a share-link recipient may have no NO SUS
      // account at all, so this branch skips Supabase/auth entirely and never
      // rejoins the normal app below.
      final shareToken = _extractShareToken(Uri.base);
      if (shareToken != null) {
        runApp(AnonymousShareViewerScreen(token: shareToken));
        return;
      }

      final burnNoteToken = _extractBurnNoteToken(Uri.base);
      if (burnNoteToken != null) {
        runApp(BurnNoteViewerScreen(
          noteId: burnNoteToken.id,
          keyHex: burnNoteToken.keyHex,
          ivHex: burnNoteToken.ivHex,
        ));
        return;
      }

      // 1. Supabase MUST come first
      await SupabaseService.instance.initialize();

      Future<void> handleOAuthCallback(Uri uri) async {
        try {
          debugLog('NO SUS: Recovering session from deep link URI: $uri');
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
          debugLog('NO SUS: Session recovered successfully!');
        } catch (e) {
          debugLog('NO SUS: Error recovering session from deep link: $e');
        }
      }

      // Listen to deep links for manual session recovery from OAuth redirects
      final appLinks = AppLinks();
      appLinks.uriLinkStream.listen((uri) async {
        debugLog('NO SUS: Received Deep Link: $uri');
        if (uri.scheme == 'io.supabase.nosus') {
          await handleOAuthCallback(uri);
        } else if (uri.scheme == 'io.nosus.app' && uri.host == 'v') {
          final token = uri.pathSegments.firstOrNull;
          if (token != null && token.isNotEmpty) {
            _handleInAppShareView(token);
          }
        }
      });

      // Handle initial link if app was closed
      try {
        final initialUri = await appLinks.getInitialLink();
        if (initialUri != null) {
          if (initialUri.scheme == 'io.supabase.nosus') {
            await handleOAuthCallback(initialUri);
          } else if (initialUri.scheme == 'io.nosus.app' && initialUri.host == 'v') {
            final token = initialUri.pathSegments.firstOrNull;
            if (token != null && token.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleInAppShareView(token);
              });
            }
          }
        }
      } catch (e) {
        debugLog('NO SUS: Error reading initial deep link: $e');
      }

      // Initialize security audit logging service
      AuditService.instance.init();
      // 2. Block screenshots (FLAG_SECURE on Android) + funny popup on attempt
      await ScreenshotGuard.instance.initialize();

      // Initialize remote config and feature flags
      final remoteConfig = RemoteConfigService(Supabase.instance.client);
      if (SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable) {
        await remoteConfig.initialize();
      }

      runApp(
        ProviderScope(
          overrides: [
            remoteConfigServiceProvider.overrideWithValue(remoteConfig),
          ],
          child: const MyApp(),
        ),
      );

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
        // Web OAuth (Google/GitHub) redirects land on e.g. "/?code=..." — not
        // exactly "/", so Flutter treats it as a distinct route instead of
        // falling back to `home`. By the time this builds, Supabase has
        // already exchanged the code for a session (handled in main() before
        // runApp), so just show the same real entry point `home` would —
        // AuthGate reacts to the now-signed-in state normally.
        if (settings.name != null && settings.name!.contains('code=')) {
          return PageRouteBuilder(
            pageBuilder: (context, _, _) => const VideoSplashScreen(
              nextScreen: AuthGate(child: WorkspaceHome()),
            ),
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

  void _showNotificationBanner(ShareViewEvent event, String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.blueAccent,
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${event.viewerEmail} opened "$fileName"',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShareAnalyticsScreen(
                  linkId: event.linkId,
                  fileName: fileName,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShareNotificationState>(shareNotificationProvider, (prev, next) {
      final event = next.latestEvent;
      if (event != null && next.fileName != null) {
        _showNotificationBanner(event, next.fileName!);
        ref.read(shareNotificationProvider.notifier).dismiss();
      }
    });

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

void _handleInAppShareView(String token) {
  final context = ScreenshotGuard.instance.navigatorKey.currentContext;
  if (context != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InAppShareViewerScreen(token: token),
      ),
    );
  }
}
