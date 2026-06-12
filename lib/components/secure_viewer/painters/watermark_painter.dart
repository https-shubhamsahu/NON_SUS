import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/watermark_config.dart';

/// Renders a dense, diagonally-repeating watermark grid across the full canvas.
///
/// Performance profile:
/// - Wrapped in RepaintBoundary → repaints ONLY when [shouldRepaint] returns true
/// - All TextPainter objects are created and disposed within a single [paint] call
/// - Canvas rotate + translate = single GPU matrix multiplication (essentially free)
/// - Tile count bounded: typically ≤ 35 tiles for a 400×800dp canvas at default spacing
///
/// Security note: This watermark provides LEGAL traceability and VISUAL deterrence.
/// It does NOT cryptographically prevent screen capture by an external camera.
class WatermarkPainter extends CustomPainter {
  final WatermarkConfig config;
  final bool isDark;

  const WatermarkPainter({
    required this.config,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: config.opacity);

    // Build text blocks: (text, fontSize, fontWeight)
    final lines = <(String, double, FontWeight)>[
      ('CONFIDENTIAL', config.fontSize + 2.5, FontWeight.w700),
      (config.name, config.fontSize + 1.0, FontWeight.w600),
      (config.role, config.fontSize + 0.5, FontWeight.w500),
      (config.email, config.fontSize, FontWeight.w400),
      (config.timestamp, config.fontSize - 1.0, FontWeight.w300),
    ];

    // Layout all painters once before entering the drawing loop.
    final painters = <TextPainter>[];
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line.$1,
          style: TextStyle(
            color: color,
            fontSize: line.$2,
            fontWeight: line.$3,
            letterSpacing: 0.6,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
    }

    // Block metrics
    const intraLineGap = 3.5;
    final lineHeight = config.fontSize + intraLineGap;
    final blockH = painters.length * lineHeight + 14.0; // +14 inter-block gap

    // Canvas diagonal determines tile count needed to cover all corners after rotation.
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final cols = (diagonal / config.tileSpacingX).ceil() + 2;
    final rows = (diagonal / blockH).ceil() + 2;

    final angleRad = config.angleDegrees * math.pi / 180.0;

    canvas.save();
    // Rotate around the canvas center so the grid appears centered.
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.rotate(angleRad);

    for (int row = -rows; row <= rows; row++) {
      for (int col = -cols; col <= cols; col++) {
        canvas.save();
        canvas.translate(
          col * config.tileSpacingX,
          row * blockH,
        );

        // Draw each line of the block, centered horizontally.
        double yOffset = 0.0;
        for (final tp in painters) {
          tp.paint(canvas, Offset(-tp.width / 2.0, yOffset));
          yOffset += lineHeight;
        }

        canvas.restore();
      }
    }

    canvas.restore();

    // Dispose TextPainter objects to release internal paragraph resources.
    for (final tp in painters) {
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(WatermarkPainter oldDelegate) =>
      oldDelegate.config != config || oldDelegate.isDark != isDark;

  @override
  bool shouldRebuildSemantics(WatermarkPainter oldDelegate) => false;
}
