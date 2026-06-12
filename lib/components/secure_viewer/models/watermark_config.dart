import 'package:flutter/foundation.dart';

/// Immutable configuration for the diagonal repeating watermark overlay.
/// All fields participate in equality — changing any field triggers a repaint.
@immutable
class WatermarkConfig {
  final String name;
  final String role;
  final String email;
  final String timestamp;

  /// Opacity of the watermark text. Subtle but always readable.
  /// Range: 0.0 – 1.0. Default 0.07 (7%).
  final double opacity;

  /// Base font size for secondary lines (email, phone, timestamp).
  final double fontSize;

  /// Horizontal spacing between watermark tile columns (in logical pixels).
  final double tileSpacingX;

  /// Vertical spacing between watermark tile rows (in logical pixels).
  final double tileSpacingY;

  /// Rotation angle of the watermark grid in degrees (negative = tilts left).
  final double angleDegrees;

  const WatermarkConfig({
    required this.name,
    required this.role,
    required this.email,
    required this.timestamp,
    this.opacity = 0.07,
    this.fontSize = 10.5,
    this.tileSpacingX = 200.0,
    this.tileSpacingY = 100.0,
    this.angleDegrees = -28.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatermarkConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          role == other.role &&
          email == other.email &&
          timestamp == other.timestamp &&
          opacity == other.opacity &&
          fontSize == other.fontSize &&
          tileSpacingX == other.tileSpacingX &&
          tileSpacingY == other.tileSpacingY &&
          angleDegrees == other.angleDegrees;

  @override
  int get hashCode => Object.hash(
        name,
        role,
        email,
        timestamp,
        opacity,
        fontSize,
        tileSpacingX,
        tileSpacingY,
        angleDegrees,
      );
}
