import 'package:flutter/material.dart';

import 'runtime_palette.dart';

class AppColors {
  const AppColors._();

  static AppPalette get _palette => AppThemeRuntime.activePalette;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceHighlight => _palette.surfaceHighlight;
  static Color get primary => _palette.primary;
  static Color get primaryVariant => _palette.accent;
  static Color get accent => _palette.accent;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textDisabled => _palette.textDisabled;
  static Color get border => _palette.border;
  static Color get borderSubtle => _palette.borderSubtle;
  static Color get success => _palette.success;
  static Color get error => _palette.error;
  static Color get warning => _palette.warning;
  static Color get info => _palette.info;
  static Color get inputBackground => _palette.inputBackground;
  static Color get overlay => _palette.overlay;
}
