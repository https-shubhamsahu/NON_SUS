import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'components/floating_nav.dart';
import 'components/study_chart.dart';
import 'components/spyglass_viewer.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/groups/providers/groups_provider.dart';
import 'features/groups/models/group_file.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'services/secure_db_service.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'services/screenshot_guard.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // SecurityService.enableSecure();
      await SupabaseService.instance.initialize();
      // Block screenshots (FLAG_SECURE on Android) + funny popup on attempt
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default to deep matte black theme

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NO SUS',
      debugShowCheckedModeBanner: false,
      navigatorKey: ScreenshotGuard.instance.navigatorKey,
      theme: NoSusTheme.lightTheme,
      darkTheme: NoSusTheme.darkTheme,
      themeMode: _themeMode,
      home: VideoSplashScreen(
        nextScreen: AuthGate(
          child: WorkspaceHome(
            toggleTheme: _toggleTheme,
            isDark: _themeMode == ThemeMode.dark,
          ),
        ),
      ),
    );
  }
}

class WorkspaceHome extends ConsumerStatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const WorkspaceHome({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  ConsumerState<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends ConsumerState<WorkspaceHome> {
  int _currentTab = 0;
  final TextEditingController _noteController = TextEditingController(
    text:
        "Research notes on AES-GCM authentication tags:\n"
        "- Tag length: 128 bits recommended.\n"
        "- Never reuse the initialization vector (IV) under the same key.\n"
        "- Ensure constant-time tag comparison to prevent timing attacks.",
  );

  bool _isRotatingKeys = false;
  String? _selectedFileId;

  @override
  void initState() {
    super.initState();
    // Initialize focus tracking session (timer starts auto-incrementing focus logs)
    ref.read(focusSessionProvider);
    
    // Load note content
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final content = await SecureDbService.instance.fetchUserNote(user.id);
        if (mounted) {
          ref.read(userNoteProvider.notifier).loadNote(user.id);
          _noteController.text = content;
        }
      }
    });
  }

  // Audit logs are now managed reactively via Riverpod's auditLogsProvider

  void _triggerKeyRotation() async {
    if (_isRotatingKeys) return;
    setState(() {
      _isRotatingKeys = true;
    });

    try {
      await SecureDbService.instance.rotateWorkspaceKeys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            content: Text(
              'Encryption keys successfully rotated.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Key rotation failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRotatingKeys = false;
        });
      }
    }
  }

  void _onNoteChanged(String text) {
    ref.read(userNoteProvider.notifier).updateNote(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

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

                  // Animated Screen Content
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentTabContent(context),
                    ),
                  ),
                ],
              ),
            ),

            // Floating bottom navigation
            FloatingNav(
              currentIndex: _currentTab,
              onTap: (index) {
                setState(() {
                  _currentTab = index;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getAvatarAsset(String colorStart) {
    switch (colorStart) {
      case 'FF0072FF':
        return 'assets/images/avatar_builder.png';
      case 'FFCCCCCC':
        return 'assets/images/avatar_researcher.png';
      case 'FFFF0072':
        return 'assets/images/avatar_creator.png';
      case 'FFF5A623':
        return 'assets/images/avatar_academic.png';
      case 'FF800080':
        return 'assets/images/avatar_chaos.png';
      case 'FFADF474':
        return 'assets/images/avatar_archivist.png';
      default:
        return 'assets/images/avatar_builder.png';
    }
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
              onTap: widget.toggleTheme,
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
                  final startColor = Color(int.parse(profile.avatarColorStart, radix: 16));
                  final endColor = Color(int.parse(profile.avatarColorEnd, radix: 16));
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
                        gradient: LinearGradient(
                          colors: [startColor, endColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: startColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Align(
                          alignment: const Alignment(0, 0.25),
                          child: FractionallySizedBox(
                            widthFactor: 0.85,
                            heightFactor: 0.85,
                            child: Image.asset(
                              _getAvatarAsset(profile.avatarColorStart),
                              fit: BoxFit.contain,
                            ),
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

  Widget _buildCurrentTabContent(BuildContext context) {
    switch (_currentTab) {
      case 0:
        return _buildWorkspaceTab(context);
      case 1:
        return _buildVaultTab(context);
      case 2:
        return _buildStudyDeskTab(context);
      case 3:
        return _buildAuditLogTab(context);
      case 4:
        return const GroupsScreen(key: ValueKey('groups_tab'));
      default:
        return _buildWorkspaceTab(context);
    }
  }

  // --- TAB 1: WORKSPACE ---
  Widget _buildWorkspaceTab(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('workspace_tab'),
      children: [
        // Welcome and Status Banner
        (() {
          final authState = ref.watch(authStateProvider);
          final userEmail = authState.value?.email ?? 'Student Guest';
          final profileAsync = ref.watch(profileProvider);
          final displayName = profileAsync.maybeWhen(
            data: (p) => p.displayName,
            orElse: () => userEmail.contains('@') ? userEmail.split('@').first : 'Student Guest',
          );
          final isLive = SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(NoSusTheme.s24),
            decoration: NoSusTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${displayName.toUpperCase()}', style: theme.textTheme.displayMedium),
                const SizedBox(height: NoSusTheme.s4),
                Text(
                  userEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s12),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLive ? const Color(0xFF10B981) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      isLive ? 'Live Encrypted Workspace' : 'Offline Fallback Mode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        })().animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: NoSusTheme.s16),

        // Split Layout: Chart + Notes
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Study Hours Graph Card
              Expanded(
                flex: 12,
                child: const StudyChart()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
              ),
              const SizedBox(height: NoSusTheme.s16),
              // Floating Note Notepad Card
              Expanded(
                flex: 11,
                child:
                    Container(
                          padding: const EdgeInsets.all(NoSusTheme.s24),
                          decoration: NoSusTheme.cardDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SECURE PAD',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    opacity: ref.watch(userNoteProvider).isSaving ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      'ENCRYPTING...',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: Colors.amber,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: NoSusTheme.s16),
                              Expanded(
                                child: TextField(
                                  controller: _noteController,
                                  maxLines: null,
                                  expands: true,
                                  onChanged: _onNoteChanged,
                                  cursorColor: theme.colorScheme.onSurface,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'Courier',
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.85),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText:
                                        'Start writing private study logs...',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.05, end: 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 2: VAULT ---
  Widget _buildVaultTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    final filesAsync = ref.watch(groupFilesProvider);
    final allFiles = filesAsync.maybeWhen(
      data: (filesMap) => filesMap.values.expand((x) => x).toList(),
      orElse: () => <GroupFile>[],
    );

    return Column(
      key: const ValueKey('vault_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STUDY VAULT',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            GestureDetector(
              onTap: _triggerKeyRotation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoSusTheme.s16,
                  vertical: NoSusTheme.s8,
                ),
                decoration: NoSusTheme.buttonDecoration(context),
                child: Row(
                  children: [
                    _isRotatingKeys
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey,
                            ),
                          )
                        : Icon(
                            Icons.sync_lock,
                            size: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      _isRotatingKeys ? 'ROTATING...' : 'ROTATE KEYS',
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NoSusTheme.s24),

        // List of classified study documents
        Expanded(
          child: allFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        size: 48,
                        color: fg.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO SECURE DOCUMENTS YET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: fg.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Navigate to the Groups tab to upload secure files.',
                        style: TextStyle(fontSize: 13, color: subtle),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: allFiles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: NoSusTheme.s16),
                  itemBuilder: (context, index) {
                    final file = allFiles[index];
                    final isSelected = _selectedFileId == file.id;

                    return Container(
                          padding: const EdgeInsets.all(NoSusTheme.s24),
                          decoration: NoSusTheme.cardDecoration(context),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: NoSusTheme.s8,
                                            vertical: 3,
                                          ),
                                          decoration:
                                              NoSusTheme.buttonDecoration(
                                                context,
                                                radius: 6,
                                                color: theme.colorScheme.outline
                                                    .withValues(alpha: 0.05),
                                              ),
                                          child: Text(
                                            file.type.label,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontSize: 9,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: NoSusTheme.s8),
                                        Text(
                                          file.sizeLabel,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: NoSusTheme.s12),
                                    Text(
                                      '${file.name}${file.type.extension}',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: NoSusTheme.s4),
                                    Text(
                                      'Imported: ${file.uploadedAtLabel}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: NoSusTheme.s24),
                              // Action button to open in Spyglass
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFileId = file.id;
                                    _currentTab = 2; // Jump to spyglass tab
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: NoSusTheme.s16,
                                    vertical: NoSusTheme.s12,
                                  ),
                                  decoration: NoSusTheme.buttonDecoration(
                                    context,
                                    radius: 12,
                                    color: isSelected
                                        ? theme.colorScheme.onSurface
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.remove_red_eye_outlined,
                                        size: 16,
                                        color: isSelected
                                            ? theme.colorScheme.surface
                                            : theme.colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: NoSusTheme.s8),
                                      Text(
                                        'REVEAL',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: isSelected
                                                  ? theme.colorScheme.surface
                                                  : theme.colorScheme.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: (index * 80).ms)
                        .slideY(begin: 0.05, end: 0);
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: STUDY DESK (SPYGLASS VIEWER) ---
  Widget _buildStudyDeskTab(BuildContext context) {
    final theme = Theme.of(context);

    final filesAsync = ref.watch(groupFilesProvider);
    final allFiles = filesAsync.maybeWhen(
      data: (filesMap) => filesMap.values.expand((x) => x).toList(),
      orElse: () => <GroupFile>[],
    );

    if (allFiles.isEmpty) {
      final isDark = theme.brightness == Brightness.dark;
      final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
      return Center(
        key: const ValueKey('studydesk_tab'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_person_outlined,
              size: 48,
              color: fg.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'NO DOCUMENT SECURED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: fg.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload and select a document in the Vault or Groups tab.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? NoSusTheme.dTextSecondary
                    : NoSusTheme.lTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final selectedFile = allFiles.firstWhere(
      (f) => f.id == _selectedFileId,
      orElse: () => allFiles.first,
    );

    return Column(
      key: const ValueKey('studydesk_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPYGLASS VIEWER',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s4),
                  Text(
                    '${selectedFile.name}${selectedFile.type.extension}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NoSusTheme.s16),
            // Outlined dropdown to swap files
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoSusTheme.s12,
                  vertical: NoSusTheme.s8,
                ),
                decoration: NoSusTheme.buttonDecoration(context, radius: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      'Swap Doc',
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              onSelected: (String id) {
                setState(() {
                  _selectedFileId = id;
                });
              },
              itemBuilder: (BuildContext context) {
                return allFiles.map((f) {
                  return PopupMenuItem<String>(
                    value: f.id,
                    child: Text(
                      '${f.name}${f.type.extension}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selectedFile.id == f.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ],
        ),
        const SizedBox(height: NoSusTheme.s24),

        // Secure viewer entry card — tapping opens full-screen SpyglassViewer
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpyglassViewer(
                    fileId: selectedFile.id,
                    email: 'student@nosus.app',
                    phone: '+91 98765 43210',
                    documentTitle:
                        '${selectedFile.name}${selectedFile.type.extension}',
                    documentCategory: selectedFile.type.label,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_open_outlined,
                    size: 36,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TAP TO OPEN SECURE VIEWER',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${selectedFile.name}${selectedFile.type.extension}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: NoSusTheme.buttonDecoration(
                      context,
                      radius: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OPEN SECURE VIEWER',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 350.ms),
        ),
      ],
    );
  }

  // --- TAB 4: AUDIT LOGS ---
  Widget _buildAuditLogTab(BuildContext context) {
    final theme = Theme.of(context);
    final auditLogs = ref.watch(auditLogsProvider);
    return Column(
      key: const ValueKey('audit_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SECURITY LEDGER & AUDIT LOGS',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: NoSusTheme.s24),

        // List of audit records
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: NoSusTheme.cardDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              child: ListView.separated(
                padding: const EdgeInsets.all(NoSusTheme.s24),
                itemCount: auditLogs.length,
                separatorBuilder: (context, index) => Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  height: NoSusTheme.s24,
                ),
                itemBuilder: (context, index) {
                  final log = auditLogs[index];

                  Color statusColor;
                  switch (log['status']) {
                    case 'SUCCESS':
                      statusColor = const Color(0xFF10B981);
                      break;
                    case 'SECURITY':
                      statusColor = Colors.amber;
                      break;
                    default:
                      statusColor = theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      );
                  }

                  return Row(
                    children: [
                      // Status dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: NoSusTheme.s16),
                      // Time
                      Text(
                        log['time'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: NoSusTheme.s24),
                      // Event description
                      Expanded(
                        child: Text(
                          log['event'] ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),
      ],
    );
  }
}
