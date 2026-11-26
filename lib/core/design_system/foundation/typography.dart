import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_spec.dart';
import '../../theme/theme_presets.dart';

class AppTypography {
  const AppTypography._();

  // Set from the active design when its theme is built (one design is on
  // screen at a time), so the static styles below follow it.
  static String _family = 'Inter';
  static String _displayFamily = 'Inter';
  static String _monoFamily = 'JetBrains Mono';

  static TextStyle _font(String family, [TextStyle? style]) {
    try {
      return GoogleFonts.getFont(family, textStyle: style);
    } catch (_) {
      return GoogleFonts.inter(textStyle: style);
    }
  }

  static TextStyle get _base => _font(_family);
  static TextStyle get _display => _font(_displayFamily);

  static TextStyle get h1 => _display.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static TextStyle get h2 => _display.copyWith(
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
  static TextStyle get mono => _font(
    _monoFamily,
    const TextStyle(
      fontSize: 12,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  /// Big numbers and page titles in the design's display face.
  static TextStyle display(double size, {FontWeight weight = FontWeight.w700}) =>
      _display.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: 1.0,
        letterSpacing: -0.03 * size,
      );

  static TextStyle _ui({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double height = 1.4,
    required bool useGoogleFonts,
    String? family,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
    if (!useGoogleFonts) return style;
    return _font(family ?? _family, style);
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
    final spec = DesignSpec.forId(palette.id);
    _family = spec.uiFont;
    _displayFamily = spec.displayFont;
    _monoFamily = spec.monoFont;
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
        family: _displayFamily,
      ),
      // AlertDialog titles: without this the google_fonts base kept its
      // near-black default, unreadable on every dark preset.
      headlineSmall: _ui(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        height: 1.3,
        useGoogleFonts: useGoogleFonts,
        family: _displayFamily,
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
    return _font(
      DesignSpec.forId(palette.id).monoFont,
      TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
