import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../theme.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../audit/providers/audit_provider.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../groups/models/group_file.dart';
import 'advanced_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/supabase_service.dart';
import '../../../config/presentation/providers/config_provider.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../data/avatar_processor.dart';
import '../widgets/profile_avatar.dart';
import 'package:file_picker/file_picker.dart' as fp;


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  int _avatarTapCount = 0;

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

    ref
        .read(profileProvider.notifier)
        .updateProfile(
          displayName: newName,
          avatarColorStart: avatarJson,
          avatarColorEnd: 'false',
        );
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()));
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _pickAndStylePhoto() async {
    final fp.FilePickerResult? result;
    try {
      result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        withData: true,
      );
    } catch (_) {
      return;
    }
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;

    AvatarStyle selected = AvatarStyle.pixel;
    final previews = <AvatarStyle, Uint8List?>{};
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
            final fgc = isDark ? Colors.white : Colors.black;

            // Lazily process one preview per style, cached for the sheet's
            // lifetime — switching styles is instant after the first render.
            if (!previews.containsKey(selected)) {
              previews[selected] = null;
              processAvatar(bytes, selected).then((out) {
                if (sheetContext.mounted) {
                  setSheetState(() => previews[selected] = out);
                }
              });
            }
            final preview = previews[selected];

            Future<void> save() async {
              setSheetState(() => isSaving = true);
              try {
                await ref
                    .read(profileProvider.notifier)
                    .uploadCustomAvatar(bytes, selected);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile photo updated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() => isSaving = false);
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save photo: ${e.toString().replaceAll('StateError: ', '').replaceAll('Exception: ', '')}',
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            Widget styleChip(AvatarStyle style, String label) {
              final isSel = selected == style;
              return Expanded(
                child: GestureDetector(
                  onTap: isSaving
                      ? null
                      : () => setSheetState(() => selected = style),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSel ? fgc : Colors.transparent,
                      border: Border.all(
                        color: fgc.withValues(alpha: isSel ? 1.0 : 0.2),
                        width: 0.75,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isSel
                              ? (isDark ? Colors.black : Colors.white)
                              : fgc.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CHOOSE YOUR STYLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: fgc,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: fgc.withValues(alpha: 0.15)),
                      ),
                      child: ClipOval(
                        child: preview == null
                            ? Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: fgc,
                                  ),
                                ),
                              )
                            : Image.memory(
                                preview,
                                key: ValueKey(selected),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      styleChip(AvatarStyle.pixel, 'PIXEL B/W'),
                      styleChip(AvatarStyle.noir, 'NOIR'),
                      styleChip(AvatarStyle.original, 'ORIGINAL'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected == AvatarStyle.pixel
                        ? 'Dithered 1-bit pixel art — the NO SUS look.'
                        : selected == AvatarStyle.noir
                            ? 'Black & white photograph.'
                            : 'Your photo, full color.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: fgc.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving || preview == null ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fgc,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Text(
                            'USE THIS PHOTO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: 11,
                            ),
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
            final fg = Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black;
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
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickAndStylePhoto();
                    },
                    icon: Icon(Icons.add_a_photo_outlined, size: 16, color: fg),
                    label: Text(
                      'UPLOAD YOUR PHOTO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: fg,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: fg.withValues(alpha: 0.25), width: 0.75),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OR PICK A CHARACTER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: fg.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                color: isSelected
                                    ? fg
                                    : fg.withValues(alpha: 0.15),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              color: isSelected
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFF1A1A1A),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      item['asset']!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Text(
                                  item['name']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
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

  void _openEditProfileModal(ProfileData profile) {
    final nameEditController = TextEditingController(text: profile.displayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'EDIT PROFILE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: fg,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameEditController,
                style: TextStyle(color: fg),
                decoration: InputDecoration(
                  labelText: 'DISPLAY NAME',
                  labelStyle: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final newName = nameEditController.text.trim();
                  if (newName.isNotEmpty) {
                    _nameController.text = newName;
                    _saveProfileChanges(profile.avatarId, profile.isCustom);
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: fg,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openHelpFeedbackModal() {
    final feedbackController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'HELP & FEEDBACK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: fg,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FREQUENTLY ASKED QUESTIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFaqItem(
                    context,
                    'How are my notes protected?',
                    'All notes are uploaded to Supabase Storage and protected with strict Row Level Security (RLS) policies.',
                  ),
                  _buildFaqItem(
                    context,
                    'What does touch-to-reveal do?',
                    'It hides sensitive note content behind a blur layer. Hold your finger down on the screen to view the plain text.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SUBMIT FEEDBACK OR REPORT A BUG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    style: TextStyle(color: fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type your suggestions or bug details...',
                      hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: fg.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: fg),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final text = feedbackController.text.trim();
                      if (text.isEmpty) return;
                      HapticFeedback.lightImpact();
                      try {
                        String? version;
                        try {
                          version =
                              (await PackageInfo.fromPlatform()).version;
                        } catch (_) {}
                        await Supabase.instance.client.from('feedback').insert({
                          'user_id':
                              Supabase.instance.client.auth.currentUser?.id,
                          'message': text,
                          'app_version': version,
                        });
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Feedback submitted! Thank you for helping us improve NO SUS.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not send feedback. Check your connection and try again.',
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fg,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'SUBMIT FEEDBACK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 11,
                      ),
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

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tilePadding: EdgeInsets.zero,
      collapsedIconColor: fg.withValues(alpha: 0.5),
      iconColor: fg,
      children: [
        Text(
          answer,
          style: TextStyle(
            color: fg.withValues(alpha: 0.7),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _openAboutModal() async {
    // Real version from the build, never a hardcoded string that drifts.
    String versionLabel = 'Version unavailable';
    try {
      final info = await PackageInfo.fromPlatform();
      versionLabel = 'Version: ${info.version} (Build ${info.buildNumber})';
    } catch (_) {}
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: Text(
            'ABOUT NO SUS',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                versionLabel,
                style: TextStyle(color: fg, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Framework: Flutter & Riverpod',
                style: TextStyle(color: fg, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Database Backend: Supabase Postgres & Storage',
                style: TextStyle(color: fg, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2026 NO SUS Enclave App. All rights reserved. Designed for ultra-secure peer-to-peer workspace sharing.',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openTermsModal() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: Text(
            'TERMS OF SERVICE',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Text(
                'Welcome to NO SUS.\n\n'
                '1. Acceptable Use\n'
                'You agree to use this secure enclave application solely for academic, private study collaborations. Any dissemination of unauthorized content or security audits bypasses is strictly forbidden.\n\n'
                '2. RLS & Access Protocols\n'
                'All operations are logged to a public audit ledger to ensure integrity. You are fully responsible for all documents uploaded under your credentials.\n\n'
                '3. Limitation of Liability\n'
                'NO SUS is provided "as is". We are not responsible for any transient network failures, client disconnects, or device-level screen recordings.',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'DISMISS',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPrivacyPolicyModal() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: Text(
            'PRIVACY POLICY',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Text(
                'Last updated: June 2026\n\n'
                '1. Data Collection\n'
                'We store your email, display name, and avatar index inside secure Supabase database tables. Documents are streamed directly into volatile device memory and never cached permanently on disk.\n\n'
                '2. Audit Logs\n'
                'To detect potential leaks, we record events such as file openings and screenshots. These records containing user email and timestamps are immutable and visible to all group members.\n\n'
                '3. Data Deletion\n'
                'You may delete your account at any time. Account deletion wipes your profile record and all corresponding memberships permanently.',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'DISMISS',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount(String userEmail) {
    final emailInputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161616) : Colors.white,
              title: const Text(
                'DELETE ACCOUNT?',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is permanent. All your groups, memberships, and logs will be permanently deleted.',
                    style: TextStyle(color: fg, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please type your email to confirm ($userEmail):',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailInputController,
                    style: TextStyle(color: fg, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: fg.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      emailInputController.text.trim() == userEmail.trim()
                      ? () async {
                          Navigator.pop(context); // Close dialog
                          HapticFeedback.heavyImpact();
                          try {
                            // Call Edge Function to self-delete
                            if (SupabaseService.instance.isReachable) {
                              await Supabase.instance.client.functions.invoke(
                                'account-manager',
                              );
                            }

                            // Sign out
                            await ref.read(authRepositoryProvider).signOut();
                            ref.invalidate(onboardingCompletedProvider);
                            ref.invalidate(onboardingPageIndexProvider);
                            ref.invalidate(authStateProvider);

                            if (context.mounted) {
                              Navigator.pop(context); // Pop profile screen
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete account: $e'),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: Text(
                    'DELETE PERMANENTLY',
                    style: TextStyle(
                      color:
                          emailInputController.text.trim() == userEmail.trim()
                          ? Colors.redAccent
                          : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openChangePasswordDialog() {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSaving = false;
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              final pw = newCtrl.text;
              if (pw.length < 6) {
                setDialogState(
                    () => errorText = 'Must be at least 6 characters.');
                return;
              }
              if (pw != confirmCtrl.text) {
                setDialogState(() => errorText = 'Passwords do not match.');
                return;
              }
              setDialogState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await ref.read(authRepositoryProvider).updatePassword(pw);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  isSaving = false;
                  errorText = e
                      .toString()
                      .replaceAll('AuthApiException: ', '')
                      .replaceAll('AuthException: ', '')
                      .replaceAll('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
              title: Text(
                'CHANGE PASSWORD',
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newCtrl,
                    obscureText: obscure,
                    autofocus: true,
                    style: TextStyle(color: fg, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'New password',
                      labelStyle: TextStyle(
                          color: fg.withValues(alpha: 0.5), fontSize: 11),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: fg.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    style: TextStyle(color: fg, fontSize: 13),
                    onSubmitted: (_) => save(),
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      labelStyle: TextStyle(
                          color: fg.withValues(alpha: 0.5), fontSize: 11),
                      errorText: errorText,
                      errorMaxLines: 3,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('UPDATE', style: TextStyle(fontSize: 11)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MascotView(character: MascotCharacter.nox, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LOG OUT SESSION?',
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to end your current session?',
            style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                HapticFeedback.mediumImpact();
                ref.read(noxMascotProvider.notifier).play(MascotMood.returnToLogo);
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.pop(context); // Pop profile screen
                }
              },
              child: const Text(
                'LOG OUT',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;
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
          'PROFILE & SETTINGS',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: fg)),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (profile) {
          // Calculate dynamic statistics
          final groupsAsync = ref.watch(groupsProvider);
          final int groupsCount = groupsAsync.value?.length ?? 0;

          final auditLogs =
              ref.watch(auditLogsProvider).value ?? const <Map<String, String>>[];
          final int filesViewedCount = auditLogs
              .where(
                (log) => log['event']?.contains('Opened secure file') == true,
              )
              .length;

          // Realistic contributions calculation based on actual uploads
          final filesAsync = ref.watch(groupFilesProvider);
          final allFiles =
              filesAsync.value?.values.expand((x) => x).toList() ??
              <GroupFile>[];
          final int filesSharedCount = allFiles
              .where((f) => f.ownerId == user?.id || f.uploadedBy == user?.id)
              .length;

          final int contributionScore =
              (groupsCount * 10) + (filesSharedCount * 5) + filesViewedCount;

          final hasViolations = auditLogs.any(
            (log) =>
                log['event']?.contains('screenshot') == true ||
                log['event']?.contains('recording') == true ||
                log['event']?.contains('unauthorized') == true,
          );
          final String trustStatus = hasViolations ? 'WARNING' : 'SECURE';

          // Real usage: sum of the user's own uploaded file sizes (kept live
          // by the same realtime stream that feeds the vault). 100 MB is the
          // product's free-tier allowance, not a hard server quota.
          final int storageBytes = allFiles
              .where((f) => f.ownerId == user?.id || f.uploadedBy == user?.id)
              .fold(0, (sum, f) => sum + f.sizeBytes);
          final double storageMB = storageBytes / (1024 * 1024);
          final double storagePercent = (storageMB / 100.0).clamp(0.0, 1.0);

          return SingleChildScrollView(
            physics: NoSusTheme.getScrollPhysics(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── IDENTITY CARD (Notion/Discord Style) ──────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openAvatarSelectionModal(profile),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A1A1A),
                                border: Border.all(
                                  color: fg.withValues(alpha: 0.1),
                                  width: 1.0,
                                ),
                              ),
                              child: ClipOval(
                                child: ProfileAvatar(profile: profile, size: 80),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: fg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 10,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.displayName.toUpperCase(),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _openEditProfileModal(profile),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: fg.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _handleAvatarTap,
                              child: Text(
                                user?.email ?? 'scholar@nosus.io',
                                style: TextStyle(color: subtle, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              // Real verification state, not decoration.
                              final isVerified = SupabaseService
                                          .instance.isReachable &&
                                      Supabase.instance.client.auth.currentUser
                                              ?.emailConfirmedAt !=
                                          null;
                              final badgeColor =
                                  isVerified ? Colors.green : Colors.amber;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: badgeColor.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVerified
                                          ? Icons.verified_user_outlined
                                          : Icons.mark_email_unread_outlined,
                                      color: badgeColor,
                                      size: 8,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVerified
                                          ? 'EMAIL VERIFIED'
                                          : 'EMAIL UNVERIFIED',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms),
                const SizedBox(height: 20),

                // ─── ACCOUNT & SECURITY ────────────────────────────────────────
                Text(
                  'ACCOUNT & SECURITY',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.alternate_email,
                            size: 18, color: fg),
                        title: const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          user?.email ?? '—',
                          style: TextStyle(color: subtle, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: fg.withValues(alpha: 0.08),
                      ),
                      ListTile(
                        leading: Icon(Icons.lock_outline, size: 18, color: fg),
                        title: const Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Set a new password for this account',
                          style: TextStyle(color: subtle, fontSize: 10),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openChangePasswordDialog();
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 30.ms, duration: 250.ms),
                const SizedBox(height: 20),

                // ─── STORAGE USAGE CARD (Proton Style) ─────────────────────────
                Text(
                  'STORAGE RESOURCE',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enclave Disk Space',
                            style: TextStyle(
                              fontSize: 11,
                              color: fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${storageMB.toStringAsFixed(1)} MB / 100 MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: storagePercent,
                          backgroundColor: fg.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Free Account Tier',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: fg.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(storagePercent * 100).toStringAsFixed(1)}% Used',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 50.ms, duration: 250.ms),
                const SizedBox(height: 20),

                // ─── SETTINGS CATEGORY: PRIVACY & PREFERENCES ─────────────────
                Text(
                  'PRIVACY & PREFERENCES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      // Touch to Reveal Switch
                      ListTile(
                        title: const Text(
                          'Touch to Reveal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Hold screen to view notes content',
                          style: TextStyle(color: subtle, fontSize: 10),
                        ),
                        trailing: Switch(
                          value: ref.watch(touchToRevealProvider),
                          onChanged: (val) {
                            ref
                                .read(touchToRevealProvider.notifier)
                                .setEnabled(val);
                          },
                          activeTrackColor: fg,
                          activeThumbColor: isDark
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: fg.withValues(alpha: 0.08),
                      ),
                      // Watermark Visibility Switch
                      ListTile(
                        title: const Text(
                          'Watermark Overlay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Display user email on reader canvas',
                          style: TextStyle(color: subtle, fontSize: 10),
                        ),
                        trailing: Switch(
                          value: ref.watch(watermarkVisibilityProvider),
                          onChanged: (val) {
                            ref
                                .read(watermarkVisibilityProvider.notifier)
                                .setEnabled(val);
                          },
                          activeTrackColor: fg,
                          activeThumbColor: isDark
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 250.ms),
                const SizedBox(height: 20),


                ref.watch(userRoleProvider).maybeWhen(
                      data: (role) {
                        if (role == 'admin' || role == 'super_admin') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADMINISTRATION',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: fg.withValues(alpha: 0.4),
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: NoSusTheme.cardDecoration(context),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 18,
                                    color: fg,
                                  ),
                                  title: const Text(
                                    'Super Admin Console',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Manage feature flags, user roles, and config',
                                    style: TextStyle(color: subtle, fontSize: 10),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: subtle,
                                  ),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AdminDashboardScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                // ─── SETTINGS CATEGORY: HELP & LEGAL ──────────────────────────

                Text(
                  'HELP & LEGAL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.help_outline, size: 18, color: fg),
                        title: const Text(
                          'Help & Feedback',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: _openHelpFeedbackModal,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: fg.withValues(alpha: 0.08),
                      ),
                      ListTile(
                        leading: Icon(Icons.info_outline, size: 18, color: fg),
                        title: const Text(
                          'About NO SUS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: _openAboutModal,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: fg.withValues(alpha: 0.08),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.gavel_outlined,
                          size: 18,
                          color: fg,
                        ),
                        title: const Text(
                          'Terms of Service',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: _openTermsModal,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: fg.withValues(alpha: 0.08),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          size: 18,
                          color: fg,
                        ),
                        title: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: _openPrivacyPolicyModal,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
                const SizedBox(height: 20),

                // ─── CATEGORY: STATS ───────────────────────────────────────────
                Text(
                  'ENCLAVE METRICS',
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
                          _buildStatWidget(context, 'Groups', '$groupsCount'),
                          _buildStatWidget(
                            context,
                            'Uploaded',
                            '$filesSharedCount',
                          ),
                          _buildStatWidget(
                            context,
                            'Viewed',
                            '$filesViewedCount',
                          ),
                        ],
                      ),
                      const Divider(height: 32, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatWidget(
                            context,
                            'Contributions',
                            '$contributionScore',
                          ),
                          _buildStatWidget(
                            context,
                            'Trust Tier',
                            trustStatus,
                            valueColor: trustStatus == 'WARNING'
                                ? Colors.redAccent
                                : Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 250.ms),
                const SizedBox(height: 20),

                // ─── DANGER ZONE ───────────────────────────────────────────────
                Text(
                  'DANGER ZONE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.redAccent.withValues(alpha: 0.6),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      width: 0.75,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sign Out Button
                      OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(
                          Icons.logout,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'LOG OUT SESSION',
                          style: TextStyle(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Delete Account Button
                      ElevatedButton.icon(
                        onPressed: () =>
                            _confirmDeleteAccount(user?.email ?? ''),
                        icon: Icon(
                          Icons.delete_forever,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        label: const Text(
                          'DELETE USER ACCOUNT',
                          style: TextStyle(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 250.ms),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatWidget(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: valueColor ?? fg,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: fg.withValues(alpha: 0.4),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
