import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';
import 'app_typography.dart';
import 'design_spec.dart';
import 'design_transitions.dart';
import 'theme_presets.dart';
import 'theme_resolver.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData fromPalette(
    ThemePreset palette,
    Brightness brightness, {
    bool useGoogleFonts = true,
  }) {
    final isDark = brightness == Brightness.dark;
    final fieldRadius = palette.isIosChrome ? 14.0 : 8.0;
    final spec = DesignSpec.forId(palette.id);
    // The six desktop designs restyle shared Material pieces (dialogs,
    // toasts, menus, toggles) and their page transitions; OLED and iOS keep
    // the platform look they were built with.
    final designed = spec.nav != DesignNav.sidebar;
    final panel = BorderRadius.circular(
      spec.cardRadius.clamp(0, 24).toDouble(),
    );
    final control = BorderRadius.circular(
      spec.controlRadius.clamp(0, 20).toDouble(),
    );
    TextStyle font(double size, FontWeight weight, Color color, String family) {
      final style = TextStyle(fontSize: size, fontWeight: weight, color: color);
      if (!useGoogleFonts) return style;
      try {
        return GoogleFonts.getFont(family, textStyle: style);
      } catch (_) {
        return style;
      }
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.accent,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: palette.error,
        onError: Colors.white,
      ),
      textTheme: AppTypography.textThemeFor(
        palette,
        useGoogleFonts: useGoogleFonts,
      ),
      fontFamily: useGoogleFonts
          ? GoogleFonts.getFont(DesignSpec.forId(palette.id).uiFont).fontFamily
          : null,
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
      pageTransitionsTheme: designed ? designPageTransitions(spec) : null,
      dialogTheme: designed
          ? DialogThemeData(
              backgroundColor: palette.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 24,
              shape: RoundedRectangleBorder(
                borderRadius: panel,
                side: BorderSide(color: palette.border),
              ),
              titleTextStyle: font(
                20,
                FontWeight.w600,
                palette.textPrimary,
                spec.displayFont,
              ),
              contentTextStyle: font(
                14,
                FontWeight.w400,
                palette.textSecondary,
                spec.uiFont,
              ),
            )
          : null,
      snackBarTheme: designed
          ? SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: palette.textPrimary,
              contentTextStyle: font(
                13.5,
                FontWeight.w500,
                palette.background,
                spec.uiFont,
              ),
              // The toast is the text colour inverted: the page background
              // reads on it in every design.
              actionTextColor: palette.background,
              shape: RoundedRectangleBorder(borderRadius: control),
              elevation: 12,
            )
          : null,
      popupMenuTheme: designed
          ? PopupMenuThemeData(
              color: palette.surfaceHighlight,
              surfaceTintColor: Colors.transparent,
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  spec.cardRadius.clamp(0, 16).toDouble(),
                ),
                side: BorderSide(color: palette.border),
              ),
              textStyle: font(
                13.5,
                FontWeight.w400,
                palette.textPrimary,
                spec.uiFont,
              ),
            )
          : null,
      switchTheme: designed
          ? SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? palette.onPrimary
                    : palette.textSecondary,
              ),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? palette.primary
                    : palette.surfaceHighlight,
              ),
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.transparent
                    : palette.border,
              ),
            )
          : null,
      checkboxTheme: designed
          ? CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? palette.primary
                    : Colors.transparent,
              ),
              checkColor: WidgetStatePropertyAll(palette.onPrimary),
              side: BorderSide(color: palette.textSecondary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  spec.controlRadius == 0 ? 0 : 5,
                ),
              ),
            )
          : null,
      progressIndicatorTheme: designed
          ? ProgressIndicatorThemeData(
              color: palette.primary,
              linearTrackColor: palette.surfaceHighlight,
              circularTrackColor: Colors.transparent,
            )
          : null,
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
