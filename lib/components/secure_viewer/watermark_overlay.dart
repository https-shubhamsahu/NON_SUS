import 'package:flutter/material.dart';
import 'models/watermark_config.dart';
import 'painters/watermark_painter.dart';

/// A stateless overlay that renders the [WatermarkPainter] over its parent.
///
/// Isolation guarantees:
/// - [RepaintBoundary]: this layer never repaints when the document scrolls
///   or when the blur animation runs.
/// - [IgnorePointer]: events (touch, scroll) pass through transparently.
/// - [SizedBox.expand]: ensures CustomPaint fills the full available space.
///
/// The [isDark] flag is resolved from [Theme.of(context)] so the watermark
/// automatically adapts to light/dark mode changes.
class WatermarkOverlay extends StatelessWidget {
  final WatermarkConfig config;

  const WatermarkOverlay({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: WatermarkPainter(config: config, isDark: isDark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
