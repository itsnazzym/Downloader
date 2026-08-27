import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';
import 'app_typography.dart';
import 'theme_presets.dart';
import 'theme_resolver.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData fromPalette(ThemePreset palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final fieldRadius = palette.isIosChrome ? 14.0 : 8.0;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.primary,
        onPrimary: Colors.white,
        secondary: palette.accent,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: palette.error,
        onError: Colors.white,
      ),
      textTheme: AppTypography.textThemeFor(palette),
      fontFamily: GoogleFonts.outfit().fontFamily,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 18),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBackground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: palette.textDisabled,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceHighlight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.borderSubtle),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
      ),
      extensions: <ThemeExtension<dynamic>>[AppPalette(palette)],
    );
  }

  static ThemeData get darkTheme =>
      fromPalette(ThemePresets.midnight, Brightness.dark);

  static ThemeData get lightTheme => fromPalette(
    ThemeResolver.forBrightness(ThemePresets.midnight, Brightness.light),
    Brightness.light,
  );
}
