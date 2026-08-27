import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_presets.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle _ui({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double height = 1.4,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextTheme textThemeFor(ThemePreset palette) {
    final ios = palette.isIosChrome;
    return GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: _ui(
        fontSize: ios ? 28 : 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: palette.textPrimary,
        height: 1.2,
      ),
      titleSmall: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: ios ? 0.2 : 0.4,
        color: palette.textSecondary,
        height: 1.4,
      ),
      bodyMedium: _ui(
        fontSize: ios ? 15 : 14,
        fontWeight: FontWeight.w400,
        color: palette.textPrimary,
        height: 1.5,
      ),
      bodySmall: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        height: 1.4,
      ),
      labelMedium: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
        height: 1.0,
      ),
    );
  }

  static TextStyle monoFor(ThemePreset palette) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: palette.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
