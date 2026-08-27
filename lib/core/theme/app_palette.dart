import 'package:flutter/material.dart';
import 'theme_presets.dart';

/// Theme-owned palette. Widgets with a [BuildContext] should read this
/// via [AppPalette.of] instead of mutating a global.
class AppPalette extends ThemeExtension<AppPalette> {
  final ThemePreset preset;

  const AppPalette(this.preset);

  Color get primary => preset.primary;
  Color get accent => preset.accent;
  Color get background => preset.background;
  Color get surface => preset.surface;
  Color get surfaceHighlight => preset.surfaceHighlight;
  Color get textPrimary => preset.textPrimary;
  Color get textSecondary => preset.textSecondary;
  Color get textDisabled => preset.textDisabled;
  Color get border => preset.border;
  Color get borderSubtle => preset.borderSubtle;
  Color get success => preset.success;
  Color get error => preset.error;
  Color get warning => preset.warning;
  Color get info => preset.info;
  Color get inputBackground => preset.inputBackground;

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ??
        const AppPalette(ThemePresets.midnight);
  }

  @override
  AppPalette copyWith({ThemePreset? preset}) {
    return AppPalette(preset ?? this.preset);
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(_lerpPreset(preset, other.preset, t));
  }
}

ThemePreset _lerpPreset(ThemePreset a, ThemePreset b, double t) {
  return ThemePreset(
    id: t < 0.5 ? a.id : b.id,
    name: t < 0.5 ? a.name : b.name,
    primary: Color.lerp(a.primary, b.primary, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    background: Color.lerp(a.background, b.background, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    surfaceHighlight: Color.lerp(a.surfaceHighlight, b.surfaceHighlight, t)!,
    textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
    textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
    textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t)!,
    success: Color.lerp(a.success, b.success, t)!,
    error: Color.lerp(a.error, b.error, t)!,
    warning: Color.lerp(a.warning, b.warning, t)!,
    info: Color.lerp(a.info, b.info, t)!,
    inputBackground: Color.lerp(a.inputBackground, b.inputBackground, t)!,
    chrome: t < 0.5 ? a.chrome : b.chrome,
    useMeshBackground: t < 0.5 ? a.useMeshBackground : b.useMeshBackground,
    useFloatingDock: t < 0.5 ? a.useFloatingDock : b.useFloatingDock,
  );
}
