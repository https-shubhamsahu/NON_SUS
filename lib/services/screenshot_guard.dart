import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot_callback/screenshot_callback.dart';

/// Manages Android FLAG_SECURE (blocks screenshot content) and
/// detects screenshot / screen-recording attempts to show a funny popup.
///
/// FLAG_SECURE is also set natively in MainActivity.kt via onCreate(),
/// so content is blocked even before Dart initializes.
/// The MethodChannel call here is a belt-and-suspenders reinforcement.
class ScreenshotGuard {
  ScreenshotGuard._();
  static final ScreenshotGuard instance = ScreenshotGuard._();

  static const _channel = MethodChannel('co.nosus.app/security');

  ScreenshotCallback? _callback;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Funny messages — rotated each attempt
  static const List<(String, String)> _roasts = [
    ('📸', 'Nice try, paparazzi.\nThis app doesn\'t do photo ops.'),
    ('🕵️', 'Oh wow, a spy in the building.\nContent classified. Move along.'),
    ('🙈', 'Screenshot detected.\nYour honour has been noted... and judged.'),
    ('😂', 'LOL. Really?\nThe screenshot is just black. Enjoy your nothing.'),
    ('🚨', 'SECURITY BREACH DETECTED.\nJust kidding. But also — stop it.'),
    ('🫠', 'The audacity.\nThe screen said no. The screen means no.'),
    ('🤡', 'Congratulations!\nYou took a screenshot of pure darkness. Frame it.'),
    ('👁️', 'We see you seeing us.\nThat\'s not how this works.'),
    ('💀', 'RIP your screenshot attempt.\nIt will be missed by absolutely no one.'),
    ('🫵', 'Caught. Red-handed.\nAbsolutely unhinged behaviour.'),
  ];

  int _roastIndex = 0;

  /// Call once at app startup.
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Reinforce FLAG_SECURE via MethodChannel (already set in MainActivity.onCreate)
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('enableSecure');
      } catch (_) {
        // MainActivity already set the flag in onCreate — this is just extra insurance
      }
    }

    // Watch for screenshot file creation and show funny popup
    _callback = ScreenshotCallback();
    _callback!.addListener(_onScreenshotAttempt);
  }

  void _onScreenshotAttempt() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final (emoji, msg) = _roasts[_roastIndex % _roasts.length];
    _roastIndex++;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => _ScreenshotRoastDialog(emoji: emoji, message: msg),
    );
  }

  void dispose() {
    _callback?.dispose();
  }
}

// ─── Funny Roast Dialog ───────────────────────────────────────────────────────

class _ScreenshotRoastDialog extends StatefulWidget {
  final String emoji;
  final String message;

  const _ScreenshotRoastDialog({
    required this.emoji,
    required this.message,
  });

  @override
  State<_ScreenshotRoastDialog> createState() => _ScreenshotRoastDialogState();
}

class _ScreenshotRoastDialogState extends State<_ScreenshotRoastDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Auto-dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black38,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'yeah yeah, I know 🙄',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
