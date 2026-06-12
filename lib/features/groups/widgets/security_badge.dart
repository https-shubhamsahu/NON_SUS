import 'package:flutter/material.dart';
import '../domain/models/study_group.dart';

/// Minimal outlined security level badge.
/// VERIFIED = filled chip, ENCRYPTED = outline chip, OPEN = ghost chip.
class SecurityBadge extends StatelessWidget {
  final SecurityLevel level;

  const SecurityBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final (bg, fg, borderOpacity) = switch (level) {
      SecurityLevel.verified => (
        onSurface,
        isDark ? Colors.black : Colors.white,
        1.0,
      ),
      SecurityLevel.encrypted => (
        Colors.transparent,
        onSurface.withValues(alpha: 0.7),
        0.5,
      ),
      SecurityLevel.open => (
        Colors.transparent,
        onSurface.withValues(alpha: 0.35),
        0.25,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: onSurface.withValues(alpha: borderOpacity),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForLevel(level), size: 9, color: fg),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: TextStyle(
              color: fg,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLevel(SecurityLevel level) {
    return switch (level) {
      SecurityLevel.verified => Icons.verified_outlined,
      SecurityLevel.encrypted => Icons.lock_outline,
      SecurityLevel.open => Icons.public_outlined,
    };
  }
}
