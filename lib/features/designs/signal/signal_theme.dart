import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Signal's look for the Material pieces of the shared views it frames
/// (settings sub-pages, archive tools, dialogs they open): pill buttons and
/// fields, the 44x26 switch, cream checkboxes, 20px cards.
class SignalMaterial extends StatelessWidget {
  const SignalMaterial({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: signalMaterialTheme(context), child: child);
}

ThemeData signalMaterialTheme(BuildContext context) {
  final base = Theme.of(context);
  final c = AppColors.of(context);
  final hair = BorderSide(color: c.textPrimary.withValues(alpha: 0.1));
  const pill = StadiumBorder();
  final label = AppTypography.body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  Color on(Set<WidgetState> s, Color yes, Color no) =>
      s.contains(WidgetState.selected) ? yes : no;
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: hair,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.error,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => on(s, c.onPrimary, c.textSecondary),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => on(s, c.primary, c.inputBackground),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => on(s, c.primary, c.textPrimary.withValues(alpha: 0.12)),
      ),
      thumbIcon: const WidgetStatePropertyAll(null),
      overlayColor: WidgetStatePropertyAll(c.primary.withValues(alpha: 0.12)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => on(s, c.textPrimary, Colors.transparent),
      ),
      checkColor: WidgetStatePropertyAll(c.background),
      side: BorderSide(color: c.textPrimary.withValues(alpha: 0.3), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => on(s, c.primary, c.textSecondary),
      ),
    ),
    sliderTheme: signalSliderTheme(c),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.inputBackground,
      circularTrackColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.textPrimary.withValues(alpha: 0.08)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
      titleTextStyle: AppTypography.body.copyWith(
        fontWeight: FontWeight.w500,
        color: c.textPrimary,
      ),
      subtitleTextStyle: AppTypography.body.copyWith(
        fontSize: 12.5,
        color: c.textDisabled,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.inputBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      hintStyle: AppTypography.body.copyWith(
        fontSize: 13,
        color: c.textDisabled,
      ),
      labelStyle: AppTypography.body.copyWith(
        fontSize: 13,
        color: c.textSecondary,
      ),
      prefixIconColor: c.textSecondary,
      suffixIconColor: c.textSecondary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: 0.3),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.textPrimary,
        shape: pill,
        textStyle: label,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        shape: pill,
        textStyle: label,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        shape: pill,
        textStyle: label,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.textPrimary.withValues(alpha: 0.16)),
        shape: pill,
        textStyle: label,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.textSecondary,
        hoverColor: c.surfaceHighlight,
        shape: const CircleBorder(),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      elevation: 12,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.textPrimary.withValues(alpha: 0.1)),
      ),
      textStyle: AppTypography.body.copyWith(
        fontSize: 13.5,
        color: c.textPrimary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.textPrimary.withValues(alpha: 0.1)),
      ),
      titleTextStyle: AppTypography.display(
        22,
        weight: FontWeight.w600,
      ).copyWith(color: c.textPrimary),
      contentTextStyle: AppTypography.body.copyWith(color: c.textSecondary),
    ),
    dividerTheme: DividerThemeData(
      color: c.textPrimary.withValues(alpha: 0.07),
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: c.textPrimary,
      labelStyle: AppTypography.body.copyWith(
        fontSize: 13,
        color: c.textSecondary,
      ),
      secondaryLabelStyle: AppTypography.body.copyWith(
        fontSize: 13,
        color: c.background,
      ),
      side: BorderSide(color: c.textPrimary.withValues(alpha: 0.1)),
      shape: pill,
      checkmarkColor: c.background,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      textStyle: AppTypography.body.copyWith(fontSize: 12, color: c.background),
    ),
  );
}

/// 6px sunken track, accent fill, cream knob (the Reglages mockup's meter).
SliderThemeData signalSliderTheme(AppColors c) => SliderThemeData(
  trackHeight: 6,
  activeTrackColor: c.primary,
  inactiveTrackColor: c.inputBackground,
  thumbColor: c.textPrimary,
  overlayColor: c.primary.withValues(alpha: 0.14),
  thumbShape: const RoundSliderThumbShape(
    enabledThumbRadius: 9,
    elevation: 0,
    pressedElevation: 0,
  ),
  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
  trackShape: const RoundedRectSliderTrackShape(),
  tickMarkShape: SliderTickMarkShape.noTickMark,
  showValueIndicator: ShowValueIndicator.never,
);
