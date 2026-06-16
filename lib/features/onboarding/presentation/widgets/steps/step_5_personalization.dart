import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/services/secure_db_service.dart';

class OnboardingPersonalizationWidget extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const OnboardingPersonalizationWidget({super.key, required this.onNext});

  @override
  ConsumerState<OnboardingPersonalizationWidget> createState() =>
      _OnboardingPersonalizationWidgetState();
}

class _OnboardingPersonalizationWidgetState
    extends ConsumerState<OnboardingPersonalizationWidget> {
  final Set<String> _goals = {};
  final Set<String> _features = {};
  String _userType = 'student';

  final List<String> _goalOptions = [
    'Learn',
    'Teach',
    'Build',
    'Collaborate',
    'Explore',
  ];
  final List<String> _featureOptions = [
    'Watermarks',
    'Private Groups',
    'Secure Viewer',
    'Activity Logs',
    'Curiosity',
  ];

  Future<void> _continueToNext() async {
    HapticFeedback.mediumImpact();
    await SecureDbService.instance.setUserType(_userType);
    widget.onNext();
  }

  Widget _buildUserTypeOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required Color fg,
  }) {
    final selected = _userType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _userType = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? fg : Colors.transparent,
            border: Border.all(
              color: selected ? fg : fg.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? (fg == Colors.black ? Colors.white : Colors.black)
                    : fg,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? (fg == Colors.black ? Colors.white : Colors.black)
                      : fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? (fg == Colors.black ? Colors.white70 : Colors.black54)
                      : fg.withValues(alpha: 0.5),
                  fontSize: 9,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              border: Border.all(
                color: isSelected ? fg : fg.withValues(alpha: 0.15),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? fg : Colors.transparent,
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (fg == Colors.black ? Colors.white : Colors.black)
                    : fg.withValues(alpha: 0.8),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const SizedBox(height: 12),
          Text(
            'CHOOSE YOUR ROLE',
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
            'This personalizes your workspace. Group admin access is still controlled separately.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: fg.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              _buildUserTypeOption(
                value: 'student',
                title: 'STUDENT',
                description: 'Learn, collect notes, and collaborate.',
                icon: Icons.school_outlined,
                fg: fg,
              ),
              const SizedBox(width: 10),
              _buildUserTypeOption(
                value: 'educator',
                title: 'EDUCATOR',
                description: 'Teach, organize, and guide groups.',
                icon: Icons.co_present_outlined,
                fg: fg,
              ),
              const SizedBox(width: 10),
              _buildUserTypeOption(
                value: 'both',
                title: 'BOTH',
                description: 'Switch between learning and teaching.',
                icon: Icons.sync_alt,
                fg: fg,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'WHAT BRINGS YOU HERE?',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: fg.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          _buildChips(_goalOptions, _goals, fg),
          const SizedBox(height: 32),

          Text(
            'WHICH FEATURE CAUGHT YOUR EYE?',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: fg.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          _buildChips(_featureOptions, _features, fg),
          const SizedBox(height: 32),

          GestureDetector(
            onTap: _continueToNext,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'CONTINUE TO COMMUNITY',
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
