import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme_presets.dart';

class AppTypography {
  const AppTypography._();

  static String _family = 'Inter';

  static TextStyle get _base => GoogleFonts.inter();

  static TextStyle get h1 => _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static TextStyle get h2 => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static TextStyle get h3 =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get body =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400);
  static TextStyle get caption =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  static TextStyle get label =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500);
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle _ui({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double height = 1.4,
    required bool useGoogleFonts,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
    if (!useGoogleFonts) return style;
    try {
      return GoogleFonts.getFont(_family, textStyle: style);
    } catch (_) {
      return GoogleFonts.inter(textStyle: style);
    }
  }

  static TextTheme _baseTheme() {
    try {
      return GoogleFonts.getTextTheme(_family);
    } catch (_) {
      return GoogleFonts.interTextTheme();
    }
  }

  static TextTheme textThemeFor(
    ThemePreset palette, {
    bool useGoogleFonts = true,
  }) {
    final ios = palette.isIosChrome;
    _family = palette.id == 'oled' ? 'Instrument Sans' : 'Inter';
    // google_fonts' base theme carries near-black colours: every style not
    // overridden below (dialog titles, dropdown values...) was unreadable on
    // dark presets. Give them all the palette's text colour first.
    final baseTextTheme = (useGoogleFonts ? _baseTheme() : const TextTheme())
        .apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        );
    return baseTextTheme.copyWith(
      displayLarge: _ui(
        fontSize: ios ? 28 : 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: palette.textPrimary,
        height: 1.2,
        useGoogleFonts: useGoogleFonts,
      ),
      // AlertDialog titles: without this the google_fonts base kept its
      // near-black default, unreadable on every dark preset.
      headlineSmall: _ui(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        height: 1.3,
        useGoogleFonts: useGoogleFonts,
      ),
      titleSmall: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: ios ? 0.2 : 0.4,
        color: palette.textSecondary,
        height: 1.4,
        useGoogleFonts: useGoogleFonts,
      ),
      bodyMedium: _ui(
        fontSize: ios ? 15 : 14,
        fontWeight: FontWeight.w400,
        color: palette.textPrimary,
        height: 1.5,
        useGoogleFonts: useGoogleFonts,
      ),
      bodySmall: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        height: 1.4,
        useGoogleFonts: useGoogleFonts,
      ),
      labelMedium: _ui(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
        height: 1.0,
        useGoogleFonts: useGoogleFonts,
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
