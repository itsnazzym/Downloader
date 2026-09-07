import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';

class Palette {
  const Palette._();

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

class IOSTheme {
  const IOSTheme._();

  static const Color systemBlue = Palette.neonBlue;
  static const Color systemGreen = Palette.neonGreen;
  static const Color systemRed = Palette.error;
  static const Color systemOrange = Color(0xFFFF9F0A);
  static const Color systemYellow = Palette.warning;
  static const Color systemPurple = Palette.neonPurple;
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFF636366);
  static const Color systemGray3 = Color(0xFF48484A);
  static const Color systemGray4 = Color(0xFF3A3A3C);
  static const Color systemGray5 = Color(0xFF2C2C2E);
  static const Color systemGray6 = Color(0xFF1C1C1E);

  static const Color background = Palette.backgroundDeep;
  static const Color secondaryBackground = Palette.backgroundSoft;

  static const Color label = Palette.textPrimary;
  static const Color secondaryLabel = Palette.textSecondary;
  static const Color tertiaryLabel = Palette.textQuaternary;

  static TextTheme get textTheme {
    return GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.1,
        color: label,
      ),
      displayMedium: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.15,
        color: label,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: label,
      ),
      bodyLarge: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: label,
      ),
      bodyMedium: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: label,
      ),
      labelSmall: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondaryLabel,
      ),
    );
  }

  static const double kPad = 20.0;
  static const double kRadiusLarge = 20.0;
  static const double kRadiusMedium = 14.0;
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
          color: Palette.backgroundDeep.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration glassDecorationFor(
    BuildContext context, {
    double radius = kRadiusLarge,
  }) {
    final colors = AppColors.of(context);
    return BoxDecoration(
      color: colors.glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.glassBorder),
      boxShadow: colors.tintedShadow,
    );
  }
}
