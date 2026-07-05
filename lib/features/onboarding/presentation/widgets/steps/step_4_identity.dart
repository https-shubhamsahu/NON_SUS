import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/features/profile/providers/profile_provider.dart';
class OnboardingIdentityWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingIdentityWidget({super.key, required this.onNext});

  @override
  State<OnboardingIdentityWidget> createState() =>
      _OnboardingIdentityWidgetState();
}

class _OnboardingIdentityWidgetState extends State<OnboardingIdentityWidget> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  int _avatarIdx = 0;

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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

  void _submit(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim().isEmpty
        ? 'Scholar'
        : _nameController.text.trim();

    // Cache the identity in securedb & profileProvider directly
    final currentAvatar = _avatarPresets[_avatarIdx];
    final avatarJson = jsonEncode({
      'avatar_id': currentAvatar['id'],
      'is_custom': false,
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await SupabaseService.instance.saveProfile(
        userId: user.id,
        email: user.email ?? 'guest@nosus.io',
        displayName: name,
        avatarColorStart: avatarJson,
        avatarColorEnd: 'false',
        onboardingCompleted: false, // Not complete until step 6
      );
    }
    
    ref.invalidate(profileProvider);

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    final preset = _avatarPresets[_avatarIdx];

    return Consumer(
      builder: (context, ref, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'BUILD YOUR IDENTITY',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: fg,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Select your starter pixel avatar identity.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Live Avatar Preview
              Center(
                child: Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: fg.withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        preset['asset']!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  preset['name']!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3x2 Avatar Selection Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: _avatarPresets.length,
                itemBuilder: (context, idx) {
                  final item = _avatarPresets[idx];
                  final isSelected = _avatarIdx == idx;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _avatarIdx = idx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? fg : fg.withValues(alpha: 0.1),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF141414),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Image.asset(
                                item['asset']!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: Text(
                              item['name']!,
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isSelected
                                    ? fg
                                    : fg.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Text inputs
              TextField(
                controller: _nameController,
                cursorColor: fg,
                style: TextStyle(color: fg, fontSize: 14),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'DISPLAY NAME',
                  labelStyle: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: fg,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                  helperText: 'Use your real name.',
                  helperStyle: TextStyle(
                    color: fg.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                cursorColor: fg,
                style: TextStyle(color: fg, fontSize: 14),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'PHONE NUMBER',
                  labelStyle: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: fg,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                  helperText: 'Use your real one too.',
                  helperStyle: TextStyle(
                    color: fg.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: fg),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => _submit(ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _isValid
                          ? 'LOCK IDENTITY'
                          : 'CONTINUE WITH DEFAULT IDENTITY',
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
            ],
          ),
        );
      },
    );
  }
}
