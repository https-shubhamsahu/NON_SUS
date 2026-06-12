import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NoSusTheme {
  // Spacing Scale
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // Corner Radii
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // Colors - Light
  static const Color lBackground = Color(0xFFF5F5F3);
  static const Color lCard = Color(0xFFFFFFFF);
  static const Color lText = Color(0xFF111111);
  static const Color lBorder = Color(0xFF1A1A1A);
  static const Color lTextSecondary = Color(0xFF666666);

  // Colors - Dark
  static const Color dBackground = Color(0xFF0D0D0D);
  static const Color dCard = Color(0xFF151515);
  static const Color dText = Color(0xFFF5F5F5);
  static const Color dBorder = Color(0x33FFFFFF); // #FFFFFF20
  static const Color dTextSecondary = Color(0xFF999999);

  // Light ThemeData
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lBackground,
      colorScheme: const ColorScheme.light(
        surface: lCard,
        onSurface: lText,
        primary: lText,
        onPrimary: lCard,
        outline: lBorder,
        outlineVariant: lBorder,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: lText,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: lText,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: lText,
          letterSpacing: -0.5,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: lText,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: lTextSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: lText,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: lCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: const BorderSide(color: lBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lText),
        centerTitle: false,
      ),
    );
  }

  // Dark ThemeData
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dBackground,
      colorScheme: const ColorScheme.dark(
        surface: dCard,
        onSurface: dText,
        primary: dText,
        onPrimary: dBackground,
        outline: dBorder,
        outlineVariant: dBorder,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: dText,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: dText,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: dText,
          letterSpacing: -0.5,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: dText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: dText,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: dTextSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: dText,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: dCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: const BorderSide(color: dBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: dText),
        centerTitle: false,
      ),
    );
  }

  // Common UI styles and decorators
  static BoxDecoration cardDecoration(BuildContext context, {double radius = r16, Color? color}) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.colorScheme.outline,
        width: 1.2,
      ),
    );
  }

  static BoxDecoration buttonDecoration(BuildContext context, {double radius = r12, Color? color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? dCard : Colors.white),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.colorScheme.outline,
        width: 1.2,
      ),
    );
  }
}
