import 'package:flutter/material.dart';

import 'theme_presets.dart';

@immutable
class AppPalette {
  final Brightness brightness;
  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color borderSubtle;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color inputBackground;
  final Color overlay;
  final Color onPrimary;
  final Color onSecondary;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderSubtle,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.inputBackground,
    required this.overlay,
    required this.onPrimary,
    required this.onSecondary,
  });
}

class AppThemeRuntime {
  AppThemeRuntime._();

  static AppPalette _activePalette = resolvePalette(
    themePreset: ThemePresets.midnight.id,
    accentValue: ThemePresets.midnight.primary.toARGB32(),
    brightness: Brightness.dark,
  );

  static AppPalette get activePalette => _activePalette;

  static void setActivePalette({
    required String themePreset,
    required int accentValue,
    required Brightness brightness,
  }) {
    _activePalette = resolvePalette(
      themePreset: themePreset,
      accentValue: accentValue,
      brightness: brightness,
    );
  }

  static AppPalette resolvePalette({
    required String themePreset,
    required int accentValue,
    required Brightness brightness,
  }) {
    final preset = ThemePresets.getById(themePreset);
    final accentColor = Color(accentValue);

    if (brightness == Brightness.light) {
      return _buildLightPalette(accentColor);
    }

    return _buildDarkPalette(preset, accentColor);
  }

  static AppPalette _buildDarkPalette(ThemePreset preset, Color accentColor) {
    final strongAccent = accentColor;
    final secondaryAccent = _shiftLightness(accentColor, 0.10);

    return AppPalette(
      brightness: Brightness.dark,
      primary: strongAccent,
      accent: secondaryAccent,
      background: preset.background,
      surface: preset.surface,
      surfaceHighlight: Color.alphaBlend(
        strongAccent.withValues(alpha: 0.08),
        preset.surfaceHighlight,
      ),
      textPrimary: preset.textPrimary,
      textSecondary: preset.textSecondary,
      textDisabled: preset.textDisabled,
      border: Color.alphaBlend(
        strongAccent.withValues(alpha: 0.12),
        preset.border,
      ),
      borderSubtle: Color.alphaBlend(
        strongAccent.withValues(alpha: 0.06),
        preset.borderSubtle,
      ),
      success: preset.success,
      error: preset.error,
      warning: preset.warning,
      info: preset.info,
      inputBackground: Color.alphaBlend(
        strongAccent.withValues(alpha: 0.04),
        preset.inputBackground,
      ),
      overlay: const Color(0x66000000),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );
  }

  static AppPalette _buildLightPalette(Color accentColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );
    final background = Color.alphaBlend(
      accentColor.withValues(alpha: 0.03),
      const Color(0xFFF6F7FB),
    );
    final surface = Color.alphaBlend(
      accentColor.withValues(alpha: 0.02),
      Colors.white,
    );

    return AppPalette(
      brightness: Brightness.light,
      primary: scheme.primary,
      accent: scheme.secondary,
      background: background,
      surface: surface,
      surfaceHighlight: Color.alphaBlend(
        accentColor.withValues(alpha: 0.05),
        const Color(0xFFF1F4F9),
      ),
      textPrimary: const Color(0xFF101828),
      textSecondary: const Color(0xFF475467),
      textDisabled: const Color(0xFF98A2B3),
      border: const Color(0xFFD0D5DD),
      borderSubtle: const Color(0xFFE4E7EC),
      success: const Color(0xFF12B76A),
      error: const Color(0xFFD92D20),
      warning: const Color(0xFFDC6803),
      info: const Color(0xFF1570EF),
      inputBackground: const Color(0xFFF8FAFC),
      overlay: const Color(0x1A000000),
      onPrimary: scheme.onPrimary,
      onSecondary: scheme.onSecondary,
    );
  }

  static Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
