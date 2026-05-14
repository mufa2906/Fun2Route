import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KineticFlowTheme {
  static const Color primary = Color(0xFFFF5C35);
  static const Color secondary = Color(0xFF1A1C1E);
  static const Color tertiary = Color(0xFF27AE60);
  static const Color background = Color(0xFFFFF8F6);
  static const Color surface = Color(0xFFFFF8F6);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF271814);
  static const Color onSurfaceVariant = Color(0xFF5B413A);
  static const Color outline = Color(0xFF8F7069);
  static const Color surfaceContainer = Color(0xFFFFE9E4);
  static const Color surfaceContainerHigh = Color(0xFFFFE2DB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: onPrimary,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.01,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  static TextStyle get statsXl => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: onSurface,
      );
}
