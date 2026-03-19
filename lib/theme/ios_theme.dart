import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/theme/palette.dart';

class IOSTheme {
  // --- Colors ---
  static const Color systemBlue = Palette.neonBlue;
  static const Color systemGreen = Palette.neonGreen;
  static const Color systemRed = Palette.error;
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemYellow = Palette.warning;
  static const Color systemPurple = Palette.neonPurple;
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFF636366);
  static const Color systemGray3 = Color(0xFF48484A);
  static const Color systemGray4 = Color(0xFF3A3A3C);
  static const Color systemGray5 = Color(0xFF2C2C2E);
  static const Color systemGray6 = Color(0xFF1C1C1E);

  // Backgrounds
  static const Color background = Palette.backgroundDeep;
  static const Color secondaryBackground = Palette.backgroundSoft;

  // Text
  static const Color label = Palette.textPrimary;
  static const Color secondaryLabel = Palette.textSecondary;
  static const Color tertiaryLabel = Palette.textQuaternary;

  // --- Typography ---
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: label,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: label,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: label,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        color: label,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: label,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondaryLabel,
      ),
    );
  }

  // --- Effects ---
  static const double kPad = 20.0;
  static const double kRadiusLarge = 24.0;
  static const double kRadiusMedium = 16.0;
  static const double kRadiusSmall = 10.0;

  static BoxDecoration glassDecoration({
    double radius = kRadiusLarge,
    Color color = Palette.glassWhite,
    Color borderColor = Palette.borderWhite,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
