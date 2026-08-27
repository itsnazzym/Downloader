import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';

/// Static iOS token mirror of [ThemePresets.ios]. Widgets with a
/// [BuildContext] should prefer [AppColors]. These constants stay in sync
/// so leftover iOS chrome compiles and matches the iOS preset.
class Palette {
  static const Color backgroundDeep = Color(0xFF1C1C1E);
  static const Color backgroundSoft = Color(0xFF2C2C2E);

  static const List<Color> meshGradient1 = [
    Color(0xFF1C1C1E),
    Color(0xFF1A2740),
    Color(0xFF16213E),
    Color(0xFF121214),
  ];

  static const List<Color> meshGradient2 = [
    Color(0xFF2C2C2E),
    Color(0xFF252530),
    Color(0xFF1C1C1E),
  ];

  static const Color neonBlue = Color(0xFF0A84FF);
  static const Color neonPurple = Color(0xFFBF5AF2);
  static const Color neonPink = Color(0xFFFF2D55);
  static const Color neonCyan = Color(0xFF64D2FF);
  static const Color neonGreen = Color(0xFF30D158);

  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassWhiteHover = Color(0x26FFFFFF);
  static const Color glassBlack = Color(0x80000000);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0x99EBEBF5);
  static const Color textQuaternary = Color(0x4DEBEBF5);

  static const Color success = Color(0xFF30D158);
  static const Color error = Color(0xFFFF453A);
  static const Color warning = Color(0xFFFFD60A);

  static const Color borderWhite = Color(0x33FFFFFF);

  static ThemePreset get iosPreset => ThemePresets.ios;
}
