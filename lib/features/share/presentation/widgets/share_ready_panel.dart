import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../theme.dart';

/// Sender-side success: huge 2-digit pin + share actions for the pairing link.
class ShareReadyPanel extends StatelessWidget {
  final String title;
  final String body;
  final String link;
  final String? pin;
  final String? pairingLink;
  final VoidCallback onReset;
  final String resetLabel;

  const ShareReadyPanel({
    super.key,
    required this.title,
    required this.body,
    required this.link,
    required this.onReset,
    this.pin,
    this.pairingLink,
    this.resetLabel = 'Create another',
  });

  String get _shareTarget => pairingLink ?? link;

  Future<void> _copy(BuildContext context, String value, String toast) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toast), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    return Column(
      children: [
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
        ),
        if (pin != null) ...[
          const SizedBox(height: 28),
          Text(
            'THEIR CODE',
            style: theme.textTheme.labelLarge?.copyWith(
              color: subtle,
              letterSpacing: 1.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pin!,
            style: theme.textTheme.displayLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send the link, then tell them this code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: subtle, fontSize: 12),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: _shareTarget,
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text('Share link'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _copy(
              context,
              _shareTarget,
              pin == null ? 'Link copied.' : 'Link copied. Tell them the code is $pin.',
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy link'),
          ),
        ),
        if (pairingLink != null && pairingLink != link) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _copy(context, link, 'Encrypted link copied.'),
            child: Text(
              'Copy the encrypted link instead',
              style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: onReset,
          child: Text(resetLabel, style: TextStyle(color: subtle, fontSize: 12)),
        ),
      ],
    );
  }
}
