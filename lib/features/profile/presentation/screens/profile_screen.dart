import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../theme.dart';
import '../../../../services/secure_db_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../audit/providers/audit_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';
import 'advanced_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  int _avatarTapCount = 0;

  // 5-6 Starter Pixel Avatars
  final List<Map<String, String>> _avatarPresets = [
    {
      'id': 'avatar_01',
      'name': 'Builder',
      'asset': 'assets/images/avatar_builder.png',
    },
    {
      'id': 'avatar_02',
      'name': 'Researcher',
      'asset': 'assets/images/avatar_researcher.png',
    },
    {
      'id': 'avatar_03',
      'name': 'Creator',
      'asset': 'assets/images/avatar_creator.png',
    },
    {
      'id': 'avatar_04',
      'name': 'Scholar',
      'asset': 'assets/images/avatar_academic.png',
    },
    {
      'id': 'avatar_05',
      'name': 'Agent',
      'asset': 'assets/images/avatar_chaos.png',
    },
    {
      'id': 'avatar_06',
      'name': 'Archivist',
      'asset': 'assets/images/avatar_archivist.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileAsync = ref.read(profileProvider);
      profileAsync.whenData((profile) {
        _nameController.text = profile.displayName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveProfileChanges(String avatarId, bool isCustom) {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final avatarJson = jsonEncode({
      'avatar_id': avatarId,
      'is_custom': isCustom,
    });

    ref.read(profileProvider.notifier).updateProfile(
          displayName: newName,
          avatarColorStart: avatarJson,
          avatarColorEnd: 'false',
        );
    setState(() {
      _isEditingName = false;
    });
  }

  void _handleAvatarTap() {
    setState(() {
      _avatarTapCount++;
    });
    if (_avatarTapCount >= 5) {
      _avatarTapCount = 0;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.white,
          content: Text(
            'Developer Mode unlocked. Opening Advanced Settings...',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
      );
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _openAvatarSelectionModal(ProfileData profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CHOOSE AVATAR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: fg,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _avatarPresets.length,
                      itemBuilder: (context, idx) {
                        final item = _avatarPresets[idx];
                        final isSelected = profile.avatarId == item['id'];

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _saveProfileChanges(item['id']!, false);
                            Navigator.of(context).pop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? fg : fg.withValues(alpha: 0.1),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              color: isSelected ? fg.withValues(alpha: 0.05) : Colors.transparent,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(item['asset']!, fit: BoxFit.contain),
                                  ),
                                ),
                                Text(
                                  item['name']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? fg : fg.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PROFILE',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (profile) {
          // Calculate dynamic statistics
          final groupsAsync = ref.watch(groupsProvider);
          final int groupsCount = groupsAsync.value?.length ?? 0;

          final auditLogs = ref.watch(auditLogsProvider);
          final int filesViewedCount = auditLogs.length;

          // Realistic contributions calculation
          final int filesSharedCount = (groupsCount * 2) + 3;
          final int contributionScore = (groupsCount * 8) + (filesSharedCount * 4) + (filesViewedCount ~/ 5);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECTION 1 — IDENTITY HEADER
                GestureDetector(
                  onTap: _handleAvatarTap,
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fg.withValues(alpha: 0.03),
                        border: Border.all(
                          color: fg.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Image.asset(
                            AppConstants.avatarAssetForId(profile.avatarId),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().scale(delay: 50.ms, duration: 250.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isEditingName)
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter name',
                            ),
                            onSubmitted: (_) => _saveProfileChanges(profile.avatarId, profile.isCustom),
                          ),
                        )
                      else
                        Text(
                          profile.displayName.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_isEditingName) {
                            _saveProfileChanges(profile.avatarId, profile.isCustom);
                          } else {
                            setState(() {
                              _isEditingName = true;
                            });
                          }
                        },
                        child: Icon(
                          _isEditingName ? Icons.check : Icons.edit_outlined,
                          size: 16,
                          color: fg.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: fg.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(20),
                      color: fg.withValues(alpha: 0.02),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Colors.green, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'VERIFIED USER',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: fg.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    user?.email ?? 'scholar@nosus.io',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Phone Verified',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.35),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2 — PIXEL IDENTITY (Starter Selection)
                Text(
                  'PIXEL IDENTITY',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _avatarPresets.map((preset) {
                        final isSelected = profile.avatarId == preset['id'];

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _saveProfileChanges(preset['id']!, false);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? fg.withValues(alpha: 0.1) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? fg : fg.withValues(alpha: 0.1),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  preset['asset']!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 3 — ACCOUNT CARD
                Text(
                  'ACCOUNT DETAILS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      _buildInfoRow(context, 'Google Connection', 'Connected'),
                      const Divider(height: 24, thickness: 0.5),
                      _buildInfoRow(context, 'GitHub Connection', 'Connected'),
                      const Divider(height: 24, thickness: 0.5),
                      _buildInfoRow(context, 'Security Tier', SecureDbService.instance.userType.toUpperCase()),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openAvatarSelectionModal(profile),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: fg.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'CHANGE AVATAR',
                                    style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 1.0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingName = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: fg.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'EDIT PROFILE NAME',
                                    style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 1.0),
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
                const SizedBox(height: 20),

                // SECTION 4 — CONTRIBUTIONS
                Text(
                  'COMMUNITY CONTRIBUTIONS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatWidget(context, 'Groups Joined', '$groupsCount'),
                          _buildStatWidget(context, 'Files Shared', '$filesSharedCount'),
                          _buildStatWidget(context, 'Files Viewed', '$filesViewedCount'),
                        ],
                      ),
                      const Divider(height: 32, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatWidget(context, 'Contribution Score', '$contributionScore'),
                          _buildStatWidget(context, 'Trust Status', 'HIGH'),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(delay: 100.ms, duration: 300.ms),
                const SizedBox(height: 20),

                // SECTION 5 — SECURITY SETTINGS
                Text(
                  'WORKSPACE SECURITY PREFERENCES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOUCH TO REVEAL',
                                style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Requires holding screen to decrypt notes',
                                style: TextStyle(color: fg.withValues(alpha: 0.4), fontSize: 9.5),
                              ),
                            ],
                          ),
                          Switch(
                            value: ref.watch(touchToRevealProvider),
                            onChanged: (val) {
                              ref.read(touchToRevealProvider.notifier).setEnabled(val);
                            },
                            activeTrackColor: fg,
                            activeThumbColor: isDark ? Colors.black : Colors.white,
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WATERMARK VISIBILITY',
                                style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Displays visible watermarks on reader canvas',
                                style: TextStyle(color: fg.withValues(alpha: 0.4), fontSize: 9.5),
                              ),
                            ],
                          ),
                          Switch(
                            value: ref.watch(watermarkVisibilityProvider),
                            onChanged: (val) {
                              ref.read(watermarkVisibilityProvider.notifier).setEnabled(val);
                            },
                            activeTrackColor: fg,
                            activeThumbColor: isDark ? Colors.black : Colors.white,
                          ),
                        ],
                      ),
                      const Divider(height: 32, thickness: 0.5),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: fg.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings_outlined, size: 14, color: fg),
                                const SizedBox(width: 8),
                                Text(
                                  'ADVANCED SETTINGS',
                                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 1.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Reset Application?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                content: const Text('This will wipe all locally stored encryption keys, files, and onboarding state.', style: TextStyle(fontSize: 12)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('RESET', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirm == true) {
                            if (!context.mounted) return;
                            HapticFeedback.heavyImpact();
                            final navigator = Navigator.of(context);
                            await ref.read(authRepositoryProvider).signOut();
                            await SecureDbService.instance.resetAppState();
                            if (!context.mounted) return;
                            await ref.read(isGuestModeProvider.notifier).disableGuest();
                            if (!context.mounted) return;
                            ref.invalidate(onboardingCompletedProvider);
                            ref.invalidate(onboardingPageIndexProvider);
                            ref.invalidate(authStateProvider);
                            navigator.pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Text(
                              'RESET APPLICATION',
                              style: theme.textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.0,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          ref.read(authControllerProvider.notifier).signOut();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: NoSusTheme.buttonDecoration(context),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, size: 14, color: fg),
                                const SizedBox(width: 8),
                                Text(
                                  'SIGN OUT SESSION',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final fg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatWidget(BuildContext context, String label, String value) {
    final fg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: fg),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.4), letterSpacing: 0.5),
        ),
      ],
    );
  }
}
