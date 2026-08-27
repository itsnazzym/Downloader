import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_theme.dart' as core;
import 'package:modern_downloader/core/theme/theme_presets.dart';

/// Facade over the live design system. Selecting the iOS preset in
/// Appearance is what actually switches chrome; this keeps the old
/// `theme/app_theme.dart` import path working.
class AppTheme {
  static ThemeData get darkTheme =>
      core.AppTheme.fromPalette(ThemePresets.ios, Brightness.dark);

  static ThemeData get lightTheme =>
      core.AppTheme.fromPalette(ThemePresets.ios, Brightness.light);
}
