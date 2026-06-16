import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingProtectWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingProtectWidget({super.key, required this.onNext});

  @override
  State<OnboardingProtectWidget> createState() =>
      _OnboardingProtectWidgetState();
}

class _OnboardingProtectWidgetState extends State<OnboardingProtectWidget> {
  final Set<String> _selected = {};
  String _reaction = "We don't judge, we just protect.";

  final List<Map<String, dynamic>> _options = [
    {
      'title': 'Notes',
      'icon': Icons.edit_note,
      'reaction': 'Saving the group project single-handedly again, are we?',
    },
    {
      'title': 'Solutions',
      'icon': Icons.fact_check,
      'reaction':
          'Question bank answers. You must be the popular kid in class.',
    },
    {
      'title': 'Projects',
      'icon': Icons.folder_shared,
      'reaction': 'Code and designs. Safe from the slide-only teammates.',
    },
    {
      'title': 'Research',
      'icon': Icons.science,
      'reaction':
          'Deep insights. Let\'s keep it away from copy-paste vultures.',
    },
    {
      'title': 'Resources',
      'icon': Icons.auto_stories,
      'reaction': 'Assorted study gold. Your circle will thank you.',
    },
    {
      'title': 'Secret Ideas',
      'icon': Icons.fingerprint,
      'reaction': 'Mysterious. We like a good secret.',
    },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          GridView.builder(
            shrinkWrap: true,
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
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : fg,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        opt['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : fg,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Reactive witty toast box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: fg.withValues(alpha: 0.08),
                width: 0.75,
              ),
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
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(10),
              ),
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
