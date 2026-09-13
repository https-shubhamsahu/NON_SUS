import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'config/crash_reporting_config.dart';
import 'theme.dart';
import 'features/profile/presentation/widgets/profile_avatar.dart';
import 'core/providers/theme_provider.dart';
import 'components/floating_nav.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/groups/screens/group_invite_landing_screen.dart';
import 'features/workspace/presentation/pages/workspace_tab.dart';
import 'features/vault/presentation/pages/vault_tab.dart';
import 'features/vault/presentation/pages/study_desk_tab.dart';
import 'features/audit/presentation/pages/audit_tab.dart';

import 'services/supabase_service.dart';
import 'services/screenshot_guard.dart';
import 'services/audit_service.dart';
import 'services/device_integrity_service.dart';
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
import 'core/mascot/mascot_state.dart';
import 'core/mascot/mascot_view.dart';


import 'features/share/presentation/screens/burn_note_viewer_screen.dart';
import 'features/share/presentation/screens/burn_file_viewer_screen.dart';
import 'features/share/presentation/screens/redeem_pin_screen.dart';
import 'core/layout/app_breakpoints.dart';
import 'core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BurnNoteToken {
  final String id;
  final String keyHex;
  final String ivHex;
  BurnNoteToken({required this.id, required this.keyHex, required this.ivHex});
}

/// Public (rather than private) so the URL contract has regression tests —
/// see test/unit/deep_link_parsing_test.dart. Burn links are shared into the
/// wild; silently changing what parses is a production outage.
BurnNoteToken? extractBurnNoteToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  debugLog('NO SUS: Extracting Burn Note Token from: $fullUrl');

  // ── Format 1 (new): #/burn/<uuid>?k=<keyHex>&v=<ivHex> ─────────────────
  // Extract the hash fragment, then parse query params from within it.
  // e.g. https://nosus.foo/#/burn/abc-123?k=aaa...&v=bbb...
  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx != -1) {
    final fragment = fullUrl.substring(hashIdx + 1); // /burn/<uuid>?k=...&v=...
    final qIdx = fragment.indexOf('?');
    if (qIdx != -1) {
      final path = fragment.substring(0, qIdx);       // /burn/<uuid>
      final query = fragment.substring(qIdx + 1);     // k=...&v=...
      final params = Uri.splitQueryString(query);
      final burnMatch = RegExp(r'burn/([a-f0-9\-]{36})', caseSensitive: false)
          .firstMatch(path);
      final k = params['k'];
      final v = params['v'];
      if (burnMatch != null && k != null && v != null &&
          k.length == 64 && v.length == 32) {
        debugLog('NO SUS: Burn Note matched (new format) id=${burnMatch.group(1)}');
        return BurnNoteToken(id: burnMatch.group(1)!, keyHex: k, ivHex: v);
      }
    }
  }

  // ── Format 2 (legacy): burn/<uuid>#<keyHex>.<ivHex> ─────────────────────
  final legacyRegExp = RegExp(
    r'burn/([a-f0-9\-]{36})(?:#|%23|/)([a-f0-9]{64})\.([a-f0-9]{32})',
    caseSensitive: false,
  );
  final match = legacyRegExp.firstMatch(fullUrl);
  if (match != null) {
    debugLog('NO SUS: Burn Note matched (legacy format) id=${match.group(1)}');
    return BurnNoteToken(
      id: match.group(1)!,
      keyHex: match.group(2)!,
      ivHex: match.group(3)!,
    );
  }

  debugLog('NO SUS: No Burn Note Token match in: $fullUrl');
  return null;
}

class BurnFileToken {
  final String id;
  final String keyHex;
  final String ivHex;
  BurnFileToken({required this.id, required this.keyHex, required this.ivHex});
}

/// Public for the same reason as [extractBurnNoteToken] — a regression here
/// silently breaks every Burn Files link already shared into the wild. Only
/// one URL format exists (no legacy format to carry, unlike burn notes).
/// e.g. https://nosus.foo/#/burnfile/abc-123?k=aaa...&v=bbb...
BurnFileToken? extractBurnFileToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  debugLog('NO SUS: Extracting Burn File Token from: $fullUrl');

  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx == -1) return null;

  final fragment = fullUrl.substring(hashIdx + 1); // /burnfile/<uuid>?k=...&v=...
  final qIdx = fragment.indexOf('?');
  if (qIdx == -1) return null;

  final path = fragment.substring(0, qIdx); // /burnfile/<uuid>
  final query = fragment.substring(qIdx + 1); // k=...&v=...
  final params = Uri.splitQueryString(query);
  final match = RegExp(r'burnfile/([a-f0-9\-]{36})', caseSensitive: false).firstMatch(path);
  final k = params['k'];
  final v = params['v'];
  if (match != null && k != null && v != null && k.length == 64 && v.length == 32) {
    debugLog('NO SUS: Burn File matched id=${match.group(1)}');
    return BurnFileToken(id: match.group(1)!, keyHex: k, ivHex: v);
  }

  debugLog('NO SUS: No Burn File Token match in: $fullUrl');
  return null;
}

/// Multi-file Burn Files share — a NEW, additive link shape living on its
/// own `burnfiles` (plural) path so it can never collide with or change the
/// parsing of `burnfile/<uuid>` links already shared into the wild. Each
/// file keeps its own independent key/IV (the exact same per-file crypto as
/// [extractBurnFileToken] — no new crypto primitive, just N of them), so the
/// only new thing here is the list-shaped URL, not the encryption scheme.
/// e.g. https://app.nosus.foo/#/burnfiles/id1,id2?k=key1,key2&v=iv1,iv2
List<BurnFileToken>? extractBurnFilesToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();

  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx == -1) return null;

  final fragment = fullUrl.substring(hashIdx + 1); // /burnfiles/<id,id,...>?k=...&v=...
  final qIdx = fragment.indexOf('?');
  if (qIdx == -1) return null;

  final path = fragment.substring(0, qIdx);
  final query = fragment.substring(qIdx + 1);
  final params = Uri.splitQueryString(query);

  final match = RegExp(r'burnfiles/([a-f0-9,\-]+)', caseSensitive: false).firstMatch(path);
  final ids = match?.group(1)?.split(',') ?? const [];
  final keys = params['k']?.split(',') ?? const [];
  final ivs = params['v']?.split(',') ?? const [];

  if (ids.isEmpty || ids.length != keys.length || ids.length != ivs.length) {
    return null;
  }
  final tokens = <BurnFileToken>[];
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final k = keys[i];
    final v = ivs[i];
    if (id.length != 36 || k.length != 64 || v.length != 32) return null;
    tokens.add(BurnFileToken(id: id, keyHex: k, ivHex: v));
  }
  debugLog('NO SUS: Burn Files batch matched, count=${tokens.length}');
  return tokens;
}

/// Extracts a SecureSend share token from a `/v/<token>` URL, checking both
/// the fragment (default hash-based web routing, e.g. `#/v/abc123`) and the
/// path, so the link works regardless of URL strategy. Returns null on any
/// other platform/URL shape — this only ever matches an intentional share link.
String? extractShareToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'v' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }
  return null;
}

/// Extracts a group invite code from a URL/deep link, supporting hash routing
/// (#/join/abc123xyz), path routing (/join/abc123xyz), path segments, and custom scheme formats.
String? extractInviteToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'join' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }
  if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
    return uri.pathSegments[1];
  }
  if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  return null;
}

/// Pairing-link token from `/#/r/<32-hex>`. The pin is entered separately.
String? extractRedeemToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'r' && parts[1].isNotEmpty) {
      final token = parts[1].split('?').first;
      if (RegExp(r'^[a-f0-9]{32}$', caseSensitive: false).hasMatch(token)) {
        return token.toLowerCase();
      }
    }
  }
  return null;
}

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Crash reporting — no-op unless SENTRY_DSN is supplied via
      // --dart-define (see lib/config/crash_reporting_config.dart). Used at
      // the low-level `SentryFlutter.init(configure)` form (no `appRunner`)
      // so it slots into this existing bootstrap sequence instead of
      // requiring runApp() to move inside a callback. sendDefaultPii is
      // explicitly off and tracing defaults to 0% — this product's premise
      // is zero-knowledge/no-tracking, so crash capture stays scoped to
      // errors, not analytics.
      if (CrashReportingConfig.isEnabled) {
        await SentryFlutter.init((options) {
          options.dsn = CrashReportingConfig.sentryDsn;
          options.tracesSampleRate = CrashReportingConfig.tracesSampleRate;
          options.sendDefaultPii = false;
        });
      }
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (CrashReportingConfig.isEnabled) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        }
      };

      // Pre-load SharedPreferences synchronously before routing and app run
      final prefs = await SharedPreferences.getInstance();

      // Initialize Supabase immediately so all early routing screens can access the client
      await SupabaseService.instance.initialize();

      // Session recovery (refresh expired access tokens, sign out only when
      // the refresh token is actually dead) runs inside SupabaseBootstrap.

      // SecureSend anonymous path: a share-link recipient may have no NO SUS
      // account at all, so this branch skips Supabase/auth entirely and never
      // rejoins the normal app below.
      final redeemToken = extractRedeemToken(Uri.base);
      if (redeemToken != null) {
        runApp(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            title: 'NO SUS',
            debugShowCheckedModeBanner: false,
            theme: NoSusTheme.lightTheme,
            darkTheme: NoSusTheme.darkTheme,
            home: RedeemPinScreen(accessToken: redeemToken),
          ),
        ));
        return;
      }

      final shareToken = extractShareToken(Uri.base);
      if (shareToken != null) {
        // ProviderScope here is only so the mascot system (Riverpod) works on
        // this standalone entrypoint — it has no Supabase session and never
        // will; nothing mascot-related depends on one.
        runApp(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: AnonymousShareViewerScreen(token: shareToken),
        ));
        return;
      }

      final burnNoteToken = extractBurnNoteToken(Uri.base);
      if (burnNoteToken != null) {
        runApp(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: BurnNoteViewerScreen(
            noteId: burnNoteToken.id,
            keyHex: burnNoteToken.keyHex,
            ivHex: burnNoteToken.ivHex,
          ),
        ));
        return;
      }

      // Burn Files anonymous path — same "no session, never rejoins the
      // normal app" pattern as burn notes/SecureSend above. The recipient
      // never has a NO SUS account (product decision — see
      // supabase/migrations/20260710050000_burn_files.sql).
      final burnFileToken = extractBurnFileToken(Uri.base);
      if (burnFileToken != null) {
        runApp(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: BurnFileViewerScreen(files: [(
            id: burnFileToken.id,
            keyHex: burnFileToken.keyHex,
            ivHex: burnFileToken.ivHex,
          )]),
        ));
        return;
      }

      // Multi-file share — checked after the single-file path so an old
      // `burnfile/<uuid>` link (no trailing 's') is never re-parsed here;
      // the two regexes are structurally disjoint (see extractBurnFilesToken).
      final burnFilesToken = extractBurnFilesToken(Uri.base);
      if (burnFilesToken != null) {
        runApp(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: BurnFileViewerScreen(
            files: burnFilesToken
                .map((t) => (id: t.id, keyHex: t.keyHex, ivHex: t.ivHex))
                .toList(),
          ),
        ));
        return;
      }

      Future<void> handleOAuthCallback(Uri uri) async {
        try {
          debugLog('NO SUS: Recovering session from deep link URI: $uri');
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
          debugLog('NO SUS: Session recovered successfully!');
        } catch (e) {
          debugLog('NO SUS: Error recovering session from deep link: $e');
        }
      }

      // Listen to deep links for manual session recovery and invite codes
      final appLinks = AppLinks();
      appLinks.uriLinkStream.listen((uri) async {
        debugLog('NO SUS: Received Deep Link: $uri');
        final inviteCode = extractInviteToken(uri);
        if (inviteCode != null) {
          _handleInAppInviteLink(inviteCode);
          return;
        }

        if (uri.scheme == 'io.supabase.nosus') {
          await handleOAuthCallback(uri);
        } else if (uri.scheme == 'foo.nosus.app' && uri.host == 'v') {
          final token = uri.pathSegments.firstOrNull;
          if (token != null && token.isNotEmpty) {
            _handleInAppShareView(token);
          }
        }
      });

      unawaited(() async {
        try {
          final initialUri = await appLinks.getInitialLink();
          if (initialUri == null) return;
          final inviteCode = extractInviteToken(initialUri);
          if (inviteCode != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleInAppInviteLink(inviteCode);
            });
          } else if (initialUri.scheme == 'io.supabase.nosus') {
            await handleOAuthCallback(initialUri);
          } else if (initialUri.scheme == 'foo.nosus.app' && initialUri.host == 'v') {
            final token = initialUri.pathSegments.firstOrNull;
            if (token != null && token.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleInAppShareView(token);
              });
            }
          }
        } catch (e) {
          debugLog('NO SUS: Error reading initial deep link: $e');
        }
      }());

      AuditService.instance.init();
      unawaited(ScreenshotGuard.instance.initialize());
      unawaited(DeviceIntegrityService.instance.runStartupChecks());

      // Initialize remote config and feature flags. Fire-and-forget — flags/
      // configs are mutated in place on the same instance handed to
      // remoteConfigServiceProvider below, and every consumer already falls
      // back to a default value until the fetch lands, so first paint never
      // needs to wait on this network round-trip.
      // In mock fallback mode there is no Supabase client at all — a null
      // client makes the service serve defaults (touching Supabase.instance
      // uninitalized would throw and kill boot before runApp).
      final remoteConfig = RemoteConfigService(
        SupabaseService.instance.isConfigured ? Supabase.instance.client : null,
      );
      if (SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable) {
        unawaited(remoteConfig.ensureInitialized());
      }

      runApp(
        ProviderScope(
          overrides: [
            remoteConfigServiceProvider.overrideWithValue(remoteConfig),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MyApp(),
        ),
      );

    },
    (error, stack) {
      // Catch all unhandled async errors (e.g. Supabase realtime WebSocket failures)
      // These are logged but do NOT crash the app — the mock fallback data remains active.
      debugLog('NO SUS: Caught unhandled async error: $error');
      if (CrashReportingConfig.isEnabled) {
        Sentry.captureException(error, stackTrace: stack);
      }
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

    final inviteToken = extractInviteToken(Uri.base);

    return MaterialApp(
      title: 'NO SUS',
      debugShowCheckedModeBanner: false,
      navigatorKey: ScreenshotGuard.instance.navigatorKey,
      theme: NoSusTheme.lightTheme,
      darkTheme: NoSusTheme.darkTheme,
      themeMode: themeMode,
      home: inviteToken != null
          ? GroupInviteLandingScreen(inviteCode: inviteToken)
          : const AuthGate(child: WorkspaceHome()),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.contains('code=')) {
          return PageRouteBuilder(
            pageBuilder: (context, _, _) => const AuthGate(child: WorkspaceHome()),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shared = ref.read(shareIntentProvider);
      if (shared != null) {
        _showSaveToNoSusModal(shared);
      }

      // Check for pending invite code
      try {
        final prefs = await SharedPreferences.getInstance();
        final pendingCode = prefs.getString('pending_invite_code');
        if (pendingCode != null && mounted) {
          await prefs.remove('pending_invite_code');
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupInviteLandingScreen(inviteCode: pendingCode),
            ),
          );
        }
      } catch (_) {}
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
              AppConstants.appTagline,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
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
                        color: NoSusTheme.lBorder,
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: ProfileAvatar(profile: profile, size: 42),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 6),
        // A dimmer blue in dark mode avoids an oversaturated highlight
        // against the near-black background; white text/icon keeps
        // sufficient contrast against either shade.
        backgroundColor: isDark ? Colors.blue.shade700 : Colors.blueAccent,
        content: Row(
          children: [
            const MascotView(
              character: MascotCharacter.nox,
              size: 20,
              fallback: Icon(Icons.notifications_active, color: Colors.white, size: 20),
            ),
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

    final expanded = AppBreakpoints.isExpanded(context);
    final pages = [
      const WorkspaceTab(),
      VaultTab(onRevealRequested: _navigateToDesk),
      StudyDeskTab(initialFileId: _deskFileId),
      const AuditTab(),
      const GroupsScreen(key: ValueKey('groups_tab')),
    ];

    final content = Padding(
      padding: EdgeInsets.only(
        left: expanded ? NoSusTheme.s32 : NoSusTheme.s24,
        right: expanded ? NoSusTheme.s32 : NoSusTheme.s24,
        top: NoSusTheme.s16,
        bottom: expanded ? NoSusTheme.s24 : 110.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isDark),
          const SizedBox(height: NoSusTheme.s24),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: pages,
            ),
          ),
        ],
      ),
    );

    if (expanded) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentTab,
                onDestinationSelected: _onTabTapped,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: Text('Files'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.visibility_outlined),
                    selectedIcon: Icon(Icons.visibility),
                    label: Text('Viewer'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: Text('Activity'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.group_outlined),
                    selectedIcon: Icon(Icons.group),
                    label: Text('Groups'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.contentMaxExpanded,
                    ),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.contentMaxCompact,
            ),
            child: Stack(
              children: [
                content,
                FloatingNav(
                  currentIndex: _currentTab,
                  onTap: _onTabTapped,
                ),
              ],
            ),
          ),
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

void _handleInAppInviteLink(String inviteCode) {
  final context = ScreenshotGuard.instance.navigatorKey.currentContext;
  if (context != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInviteLandingScreen(inviteCode: inviteCode),
      ),
    );
  }
}
