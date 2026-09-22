import 'package:flutter/material.dart';

import '../../theme.dart';
import 'go_session.dart';

/// Three codes plus "None of these". The real one is not marked here.
class MatchChoices extends StatelessWidget {
  final List<int> choices;
  final ValueChanged<int> onPick;
  final VoidCallback onNone;

  const MatchChoices({
    super.key,
    required this.choices,
    required this.onPick,
    required this.onNone,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final code in choices) ...[
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => onPick(code),
              child: Text(
                twoDigits(code),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 48,
          child: TextButton(onPressed: onNone, child: const Text('None of these')),
        ),
      ],
    );
  }
}

/// A self-chat line. Alignment stays the same for phone and computer;
/// [detail] says which side, in words, not color.
class SavedLine extends StatelessWidget {
  final String text;
  final String? detail;
  final String? status;

  const SavedLine({
    super.key,
    required this.text,
    this.detail,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fg.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(text, style: TextStyle(color: fg, fontSize: 16, height: 1.4)),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(detail!, style: TextStyle(color: subtle, fontSize: 12)),
              ],
              if (status != null) ...[
                const SizedBox(height: 4),
                Text(status!, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
