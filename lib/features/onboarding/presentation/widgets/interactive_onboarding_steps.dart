import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:no_sus/theme.dart';
import 'package:no_sus/services/secure_db_service.dart';
import 'package:no_sus/features/profile/providers/profile_provider.dart';

// ─── SCREEN 1: THE INCIDENT ───

class OnboardingIncidentWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingIncidentWidget({super.key, required this.onNext});

  @override
  State<OnboardingIncidentWidget> createState() => _OnboardingIncidentWidgetState();
}

class PixelFile {
  double x;
  double y;
  double vx;
  double vy;
  double angle;
  double rotSpeed;
  PixelFile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.rotSpeed,
  });
}

class _OnboardingIncidentWidgetState extends State<OnboardingIncidentWidget> {
  final List<PixelFile> _files = [];
  Timer? _timer;
  int _tapCount = 0;
  final double _gravity = 0.6;
  final double _bounce = -0.45;
  final double _friction = 0.98;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = 380.0; // clamp height area

        for (final file in _files) {
          file.vy += _gravity;
          file.x += file.vx;
          file.y += file.vy;
          file.vx *= _friction;
          file.angle += file.rotSpeed;

          // Bottom collision
          if (file.y > screenHeight) {
            file.y = screenHeight;
            file.vy = file.vy * _bounce;
            file.rotSpeed *= 0.5;
            if (file.vy.abs() < 1) file.vy = 0;
          }

          // Side collisions
          if (file.x < 0) {
            file.x = 0;
            file.vx = -file.vx * 0.7;
          } else if (file.x > screenWidth - 40) {
            file.x = screenWidth - 40;
            file.vx = -file.vx * 0.7;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _spawnFiles() {
    HapticFeedback.lightImpact();
    final rand = math.Random();
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _tapCount++;
      // Spawn 3 files with varying velocities
      for (int i = 0; i < 3; i++) {
        _files.add(
          PixelFile(
            x: screenWidth / 2 - 20,
            y: 120,
            vx: rand.nextDouble() * 12 - 6,
            vy: rand.nextDouble() * -10 - 5,
            angle: rand.nextDouble() * math.pi,
            rotSpeed: rand.nextDouble() * 0.2 - 0.1,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'THAT ESCALATED QUICKLY.',
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
          'Most leaks don\'t start with bad intentions. One click turns a small share into an uncontrollable flood.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: fg.withValues(alpha: 0.6),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Interactive Canvas
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Interactive tap target document (idle float)
              Align(
                alignment: const Alignment(0, -0.6),
                child: GestureDetector(
                  onTap: _spawnFiles,
                  child: Container(
                    width: 72,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: fg, width: 1.8),
                      borderRadius: BorderRadius.circular(6),
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    child: Center(
                      child: Icon(Icons.description_outlined, size: 36, color: fg),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .slideY(begin: 0, end: -0.08, duration: 1200.ms, curve: Curves.easeInOutSine),
                ),
              ),

              // Scattered Duplicated Files
              ..._files.map((file) {
                return Positioned(
                  left: file.x,
                  top: file.y,
                  child: Transform.rotate(
                    angle: file.angle,
                    child: Container(
                      width: 36,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.2),
                        borderRadius: BorderRadius.circular(3),
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      child: Icon(Icons.description, size: 18, color: fg.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        
        // Microcopy and Next Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              Text(
                'TAP THE FILE ABOVE TO SHARE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: fg.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: widget.onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      _tapCount >= 3 ? 'CONTINUE HANDSHAKE' : 'SKIP INTRO',
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
        ),
      ],
    );
  }
}

// ─── SCREEN 2: WHAT ARE YOU TRYING TO PROTECT? ───

class OnboardingProtectWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingProtectWidget({super.key, required this.onNext});

  @override
  State<OnboardingProtectWidget> createState() => _OnboardingProtectWidgetState();
}

class _OnboardingProtectWidgetState extends State<OnboardingProtectWidget> {
  final Set<String> _selected = {};
  String _reaction = "We don't judge, we just protect.";

  final List<Map<String, dynamic>> _options = [
    {'title': 'Notes', 'icon': Icons.edit_note, 'reaction': 'Saving the group project single-handedly again, are we?'},
    {'title': 'Solutions', 'icon': Icons.fact_check, 'reaction': 'Question bank answers. You must be the popular kid in class.'},
    {'title': 'Projects', 'icon': Icons.folder_shared, 'reaction': 'Code and designs. Safe from the slide-only teammates.'},
    {'title': 'Research', 'icon': Icons.science, 'reaction': 'Deep insights. Let\'s keep it away from copy-paste vultures.'},
    {'title': 'Resources', 'icon': Icons.auto_stories, 'reaction': 'Assorted study gold. Your circle will thank you.'},
    {'title': 'Secret Ideas', 'icon': Icons.fingerprint, 'reaction': 'Mysterious. We like a good secret.'},
  ];

  void _toggle(String title, String reaction) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(title)) {
        _selected.remove(title);
      } else {
        _selected.add(title);
        _reaction = reaction;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'WHAT IS IN YOUR VAULT?',
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
            'Select the study assets you want to share responsibly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: fg.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Grid Selection
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.35,
              ),
              itemCount: _options.length,
              itemBuilder: (context, idx) {
                final opt = _options[idx];
                final isSelected = _selected.contains(opt['title']);

                return GestureDetector(
                  onTap: () => _toggle(opt['title'], opt['reaction']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutQuad,
                    decoration: BoxDecoration(
                      color: isSelected ? fg : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? fg : fg.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          color: isSelected ? (isDark ? Colors.black : Colors.white) : fg,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opt['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? (isDark ? Colors.black : Colors.white) : fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Reactive witty toast box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: 0.08), width: 0.75),
              borderRadius: BorderRadius.circular(10),
              color: fg.withValues(alpha: 0.02),
            ),
            child: Text(
              _reaction,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: fg.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  _selected.isNotEmpty ? 'PROCEED TO LOCK' : 'SKIP SELECTION',
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
    );
  }
}

// ─── SCREEN 3: THE SOLUTION (DRAG & DROP) ───

class OnboardingSolutionWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingSolutionWidget({super.key, required this.onNext});

  @override
  State<OnboardingSolutionWidget> createState() => _OnboardingSolutionWidgetState();
}

class _OnboardingSolutionWidgetState extends State<OnboardingSolutionWidget> with SingleTickerProviderStateMixin {
  bool _isDropped = false;
  bool _groupChecked = false;
  bool _accountChecked = false;
  bool _trackChecked = false;
  bool _watermarkChecked = false;
  AnimationController? _vaultSlamController;

  @override
  void initState() {
    super.initState();
    _vaultSlamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _vaultSlamController?.dispose();
    super.dispose();
  }

  void _onDrop() async {
    HapticFeedback.heavyImpact();
    setState(() => _isDropped = true);
    _vaultSlamController?.forward();

    // Sequentially check features with delays
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _groupChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _accountChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _trackChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _watermarkChecked = true);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'LOCK IT DOWN.',
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
            'Drag the file into the vault to encrypt and track.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: fg.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Draggable/Target Canvas
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isDropped)
                  Draggable<String>(
                    data: 'file',
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 72,
                        height: 84,
                        decoration: BoxDecoration(
                          border: Border.all(color: fg, width: 1.8),
                          borderRadius: BorderRadius.circular(6),
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        child: Center(
                          child: Icon(Icons.description_outlined, size: 36, color: fg),
                        ),
                      ),
                    ),
                    childWhenDragging: Container(
                      width: 72,
                      height: 84,
                      decoration: BoxDecoration(
                        border: Border.all(color: fg.withValues(alpha: 0.15), width: 1.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Container(
                      width: 72,
                      height: 84,
                      decoration: BoxDecoration(
                        border: Border.all(color: fg, width: 1.8),
                        borderRadius: BorderRadius.circular(6),
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      child: Center(
                        child: Icon(Icons.description_outlined, size: 36, color: fg),
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .slideY(begin: 0, end: -0.05, duration: 1.seconds, curve: Curves.easeInOutSine)
                else
                  const SizedBox(height: 84),
                const SizedBox(height: 48),

                // Vault target
                DragTarget<String>(
                  onWillAcceptWithDetails: (details) => !_isDropped,
                  onAcceptWithDetails: (details) => _onDrop(),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;

                    return AnimatedBuilder(
                      animation: _vaultSlamController!,
                      builder: (context, child) {
                        final slamScale = 1.0 + (0.15 * math.sin(_vaultSlamController!.value * math.pi));
                        return Transform.scale(
                          scale: isHovering ? 1.08 : slamScale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isDropped ? fg : fg.withValues(alpha: 0.5),
                                width: _isDropped ? 2.2 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: isHovering ? fg.withValues(alpha: 0.05) : Colors.transparent,
                            ),
                            child: Icon(
                              _isDropped ? Icons.lock_outline : Icons.lock_open_outlined,
                              size: 48,
                              color: _isDropped ? fg : fg.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Sequenced Checkbox outputs
          if (_isDropped)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                children: [
                  _buildTickLine('Private Groups', _groupChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Viewer Accountability', _accountChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Activity Tracking', _trackChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Dynamic Watermarks', _watermarkChecked, fg),
                ],
              ),
            ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  _watermarkChecked ? 'BUILD IDENTITY' : 'SKIP TO IDENTITY',
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
    );
  }

  Widget _buildTickLine(String text, bool ticked, Color fg) {
    return AnimatedOpacity(
      opacity: ticked ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: ticked ? const Color(0xFF10B981) : fg, size: 16),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg.withValues(alpha: ticked ? 0.95 : 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SCREEN 4: BUILD YOUR IDENTITY ───

class OnboardingIdentityWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingIdentityWidget({super.key, required this.onNext});

  @override
  State<OnboardingIdentityWidget> createState() => _OnboardingIdentityWidgetState();
}

class _OnboardingIdentityWidgetState extends State<OnboardingIdentityWidget> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  int _gradientIdx = 0;

  // Visual gradient options with corresponding pixel avatars
  final List<Map<String, String>> _gradientPresets = [
    {'name': 'THE BUILDER', 'start': 'FF0072FF', 'end': 'FF00F2FE', 'asset': 'assets/images/avatar_builder.png'},
    {'name': 'THE RESEARCHER', 'start': 'FFCCCCCC', 'end': 'FFAAAAAA', 'asset': 'assets/images/avatar_researcher.png'},
    {'name': 'THE CREATOR', 'start': 'FFFF0072', 'end': 'FF00F2FE', 'asset': 'assets/images/avatar_creator.png'},
    {'name': 'THE ACADEMIC WEAPON', 'start': 'FFF5A623', 'end': 'FFF8E71C', 'asset': 'assets/images/avatar_academic.png'},
    {'name': 'THE CHAOS AGENT', 'start': 'FF800080', 'end': 'FF4A90E2', 'asset': 'assets/images/avatar_chaos.png'},
    {'name': 'THE ARCHIVIST', 'start': 'FFADF474', 'end': 'FF018037', 'asset': 'assets/images/avatar_archivist.png'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid => _nameController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty;

  void _submit(WidgetRef ref) async {
    HapticFeedback.lightImpact();

    final name = _nameController.text.trim().isEmpty ? 'Enclave Member' : _nameController.text.trim();

    // Cache the identity in securedb & profileProvider directly
    final currentPreset = _gradientPresets[_gradientIdx];
    await SecureDbService.instance.saveProfile(
      userId: 'temp_user', // Will be linked on auth completion
      email: 'guest@nosus.io',
      displayName: name,
      avatarColorStart: currentPreset['start']!,
      avatarColorEnd: currentPreset['end']!,
    );
    
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    final preset = _gradientPresets[_gradientIdx];
    final startColor = Color(int.parse(preset['start']!, radix: 16));
    final endColor = Color(int.parse(preset['end']!, radix: 16));


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
                'Unlock your custom pixel identity badge.',
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
                    gradient: LinearGradient(
                      colors: [startColor, endColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: startColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
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
                          preset['asset']!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  preset['name']!,
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
                itemCount: _gradientPresets.length,
                itemBuilder: (context, idx) {
                  final item = _gradientPresets[idx];
                  final isSelected = _gradientIdx == idx;
                  final itemStart = Color(int.parse(item['start']!, radix: 16));
                  final itemEnd = Color(int.parse(item['end']!, radix: 16));
                  
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _gradientIdx = idx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? fg : fg.withValues(alpha: 0.1),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [itemStart.withValues(alpha: 0.15), itemEnd.withValues(alpha: 0.15)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : fg.withValues(alpha: 0.02),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                              child: Image.asset(
                                item['asset']!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              item['name']!.replaceAll('THE ', ''),
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isSelected ? fg : fg.withValues(alpha: 0.5),
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
                  labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.0),
                  floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                  helperText: 'Use your real name.',
                  helperStyle: TextStyle(color: fg.withValues(alpha: 0.35), fontSize: 11),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.15))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
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
                  labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.0),
                  floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                  helperText: 'Use your real one too.',
                  helperStyle: TextStyle(color: fg.withValues(alpha: 0.35), fontSize: 11),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.15))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
                ),
              ),
              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => _submit(ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      _isValid ? 'LOCK IDENTITY' : 'CONTINUE WITH DEFAULT IDENTITY',
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

// ─── SCREEN 5: QUICK PERSONALIZATION ───

class OnboardingPersonalizationWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingPersonalizationWidget({super.key, required this.onNext});

  @override
  State<OnboardingPersonalizationWidget> createState() => _OnboardingPersonalizationWidgetState();
}

class _OnboardingPersonalizationWidgetState extends State<OnboardingPersonalizationWidget> {
  final Set<String> _goals = {};
  final Set<String> _features = {};

  final List<String> _goalOptions = ['Learn', 'Teach', 'Build', 'Collaborate', 'Explore'];
  final List<String> _featureOptions = ['Watermarks', 'Private Groups', 'Secure Viewer', 'Activity Logs', 'Curiosity'];

  bool get _isValid => _goals.isNotEmpty && _features.isNotEmpty;

  Widget _buildChips(List<String> options, Set<String> selection, Color fg) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selection.contains(opt);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                selection.remove(opt);
              } else {
                selection.add(opt);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: isSelected ? fg : fg.withValues(alpha: 0.15), width: 1.0),
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? fg : Colors.transparent,
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? (fg == Colors.black ? Colors.white : Colors.black) : fg.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'QUICK PERSONALIZATION',
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
            'Configure your workspace parameters.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: fg.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Text(
            'WHAT BRINGS YOU HERE?',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: fg.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          _buildChips(_goalOptions, _goals, fg),
          const SizedBox(height: 32),

          Text(
            'WHICH FEATURE CAUGHT YOUR EYE?',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: fg.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          _buildChips(_featureOptions, _features, fg),
          const SizedBox(height: 48),

          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  _isValid ? 'FINALIZE CONFIGURATION' : 'SKIP CONFIGURATION',
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
    );
  }
}

// ─── SCREEN 6: AUTHENTICATION + WELCOME ───

class OnboardingAuthWelcomeWidget extends ConsumerStatefulWidget {
  const OnboardingAuthWelcomeWidget({super.key});

  @override
  ConsumerState<OnboardingAuthWelcomeWidget> createState() => _OnboardingAuthWelcomeWidgetState();
}

class _OnboardingAuthWelcomeWidgetState extends ConsumerState<OnboardingAuthWelcomeWidget> {
  bool _isPhoneAuth = false;
  bool _otpSent = false;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showWelcome = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onGoogleSignIn() {
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _onGitHubSignIn() {
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).signInWithGitHub();
  }

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).signInWithPhone(phone).then((_) {
      if (mounted) {
        setState(() => _otpSent = true);
      }
    });
  }

  void _onVerifyOtp() {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).verifyPhoneOtp(phone, otp);
  }

  void _triggerWelcome() {
    setState(() => _showWelcome = true);
  }

  /// After successful authentication, migrate the temp onboarding identity
  /// (name + avatar colors chosen during setup) to the real user's profile.
  Future<void> _linkTempProfileToUser(String userId, String email) async {
    try {
      final cache = SecureDbService.instance.cachedProfile;
      if (cache.isNotEmpty && cache['displayName'] != null) {
        await SecureDbService.instance.saveProfile(
          userId: userId,
          email: email,
          displayName: cache['displayName']!,
          avatarColorStart: cache['avatarColorStart'] ?? 'FF0072FF',
          avatarColorEnd: cache['avatarColorEnd'] ?? 'FF00F2FE',
        );
        // Invalidate profileProvider so it re-reads with the linked data
        ref.invalidate(profileProvider);
      }
    } catch (e) {
      // Non-fatal — profile will load from Supabase on next open
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black87;

    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;

    // Auto-advance/Show welcome when session becomes active
    ref.listen<AsyncValue<AuthenticatedUser?>>(authStateProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null && mounted) {
            // Link onboarding identity (name/avatar) to the authenticated user
            _linkTempProfileToUser(user.id, user.email ?? '');
            _triggerWelcome();
          }
        },
      );
    });

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                error.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', ''),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      );
    });

    if (_showWelcome) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                border: Border.all(color: fg, width: 1.8),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.verified, size: 52, color: fg),
                ],
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 32),
            Text(
              'WELCOME TO NO SUS.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Face hidden. Reputation visible. Your secure sharing enclave is ready.',
              style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.6), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(onboardingCompletedProvider.notifier).complete();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 36),
                decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  'LET\'S GO',
                  style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isPhoneAuth
                ? (_otpSent ? 'VERIFY OTP' : 'PHONE AUTHENTICATION')
                : 'GET VERIFIED',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _isPhoneAuth
                ? (_otpSent
                    ? 'Enter the 6-digit verification code sent to your phone.'
                    : 'Enter your phone number to receive a secure OTP code.')
                : 'Sign in to complete identity lock. Only verified members are admitted.',
            style: TextStyle(fontSize: 13, color: subtle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
              ),
            )
          else if (_isPhoneAuth) ...[
            if (!_otpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                cursorColor: fg,
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'PHONE NUMBER',
                  hintText: '+1234567890',
                  hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                  labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.0),
                  floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.15))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _onSendOtp,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      'SEND OTP',
                      style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _phoneController,
                enabled: false,
                style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'PHONE NUMBER',
                  labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.0),
                  floatingLabelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1.0),
                  disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.15))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                cursorColor: fg,
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'VERIFICATION CODE',
                  labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.0),
                  floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.15))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _onVerifyOtp,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      'VERIFY OTP',
                      style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _otpSent = false),
                child: Text(
                  'CHANGE NUMBER',
                  style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isPhoneAuth = false;
                _otpSent = false;
              }),
              child: Text(
                'BACK TO OTHER METHODS',
                style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ] else ...[
            _buildOAuthButton(Icons.g_mobiledata, 'Continue with Google', _onGoogleSignIn, fg),
            const SizedBox(height: 12),
            _buildOAuthButton(Icons.code, 'Continue with GitHub', _onGitHubSignIn, fg),
            const SizedBox(height: 12),
            _buildOAuthButton(Icons.phone_android, 'Continue with Phone', () => setState(() => _isPhoneAuth = true), fg),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _triggerWelcome();
              },
              child: Text(
                'BYPASS AUTHENTICATION',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOAuthButton(IconData icon, String text, VoidCallback onPressed, Color fg) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: fg.withValues(alpha: 0.15), width: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Text(
              text.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
