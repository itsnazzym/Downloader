import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

import 'nocturne_widgets.dart';

/// Nocturne's Material overrides, scoped to its pages: the dialogs, menus,
/// fields, buttons, switches and sheets the shared views still open (rule
/// editor, confirmations, context menu) come out in the night palette.
class NocturneTheme extends StatelessWidget {
  const NocturneTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = Theme.of(context);
    final hairline = c.primary.withValues(alpha: 0.1);
    RoundedRectangleBorder round(double r, {Color? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side == null ? BorderSide.none : BorderSide(color: side),
        );
    final label = nocturneText(c, size: 13, weight: FontWeight.w600);
    WidgetStateProperty<Color?> hoverTint(Color color) =>
        WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
              ? color.withValues(alpha: 0.1)
              : (s.contains(WidgetState.pressed)
                    ? color.withValues(alpha: 0.16)
                    : null),
        );
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: hairline),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: c.primary,
          onPrimary: c.background,
          surface: c.surface,
          onSurface: c.textPrimary,
          error: c.error,
        ),
        dividerTheme: DividerThemeData(
          color: c.primary.withValues(alpha: 0.08),
          thickness: 1,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          shape: round(20, side: c.primary.withValues(alpha: 0.14)),
          titleTextStyle: nocturneText(c, size: 17, weight: FontWeight.w700),
          contentTextStyle: nocturneText(c, size: 13.5, color: c.textSecondary),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: c.surfaceHighlight,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shadowColor: Colors.black,
          shape: round(14, side: c.primary.withValues(alpha: 0.12)),
          textStyle: nocturneText(c, size: 13),
          labelTextStyle: WidgetStatePropertyAll(nocturneText(c, size: 13)),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(c.surfaceHighlight),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              round(14, side: c.primary.withValues(alpha: 0.12)),
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          dragHandleColor: c.textDisabled,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: c.surfaceHighlight,
          contentTextStyle: nocturneText(c, size: 13),
          actionTextColor: c.primary,
          behavior: SnackBarBehavior.floating,
          shape: round(14, side: c.primary.withValues(alpha: 0.14)),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: c.surfaceHighlight,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.primary.withValues(alpha: 0.14)),
          ),
          textStyle: nocturneText(c, size: 12),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.disabled) ? c.textDisabled : c.primary,
            ),
            overlayColor: hoverTint(c.primary),
            textStyle: WidgetStatePropertyAll(label),
            shape: WidgetStatePropertyAll(round(11)),
            minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _filled(c, label, round(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _filled(c, label, round(12)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(c.textPrimary),
            backgroundColor: WidgetStatePropertyAll(c.surfaceHighlight),
            overlayColor: hoverTint(c.primary),
            side: const WidgetStatePropertyAll(BorderSide.none),
            textStyle: WidgetStatePropertyAll(label),
            shape: WidgetStatePropertyAll(round(12)),
            minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(c.textSecondary),
            overlayColor: hoverTint(c.primary),
            shape: WidgetStatePropertyAll(round(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.inputBackground,
          isDense: true,
          labelStyle: nocturneText(c, size: 13, color: c.textSecondary),
          floatingLabelStyle: nocturneText(c, size: 12, color: c.primary),
          hintStyle: nocturneText(c, size: 13, color: c.textDisabled),
          helperStyle: nocturneText(c, size: 12, color: c.textDisabled),
          prefixIconColor: c.textDisabled,
          suffixIconColor: c.textDisabled,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: field,
          enabledBorder: field,
          focusedBorder: field.copyWith(
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.primary,
          selectionColor: c.primary.withValues(alpha: 0.3),
          selectionHandleColor: c.primary,
        ),
        switchTheme: SwitchThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? c.background
                : c.textSecondary,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? c.primary
                : Color.lerp(c.surface, c.primary, 0.155),
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.transparent
                : c.primary.withValues(alpha: 0.16),
          ),
          overlayColor: hoverTint(c.primary),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? c.primary
                : c.inputBackground,
          ),
          checkColor: WidgetStatePropertyAll(c.background),
          side: BorderSide(color: c.textDisabled, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.primary : c.textDisabled,
          ),
        ),
        cardTheme: CardThemeData(
          color: c.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: round(18, side: c.primary.withValues(alpha: 0.08)),
        ),
        listTileTheme: ListTileThemeData(
          shape: round(14),
          iconColor: c.textSecondary,
          textColor: c.textPrimary,
          selectedColor: c.primary,
          selectedTileColor: c.surfaceHighlight,
          titleTextStyle: nocturneText(c, weight: FontWeight.w600),
          subtitleTextStyle: nocturneText(c, size: 12.5, color: c.textDisabled),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: c.inputBackground,
          selectedColor: c.surfaceHighlight,
          checkmarkColor: c.primary,
          side: BorderSide(color: hairline),
          shape: round(11),
          labelStyle: nocturneText(c, size: 12.5, weight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 6,
          activeTrackColor: c.primary,
          inactiveTrackColor: nocturneTrack(c),
          thumbColor: c.primary,
          overlayColor: c.primary.withValues(alpha: 0.12),
          tickMarkShape: SliderTickMarkShape.noTickMark,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 9,
            elevation: 0,
            pressedElevation: 0,
          ),
          valueIndicatorColor: c.surfaceHighlight,
          valueIndicatorTextStyle: nocturneMono(c, color: c.textPrimary),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: c.primary,
          linearTrackColor: nocturneTrack(c),
          circularTrackColor: nocturneTrack(c),
        ),
      ),
      child: child,
    );
  }

  static ButtonStyle _filled(AppColors c, TextStyle label, OutlinedBorder s) =>
      ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled)
              ? c.primary.withValues(alpha: 0.35)
              : c.primary,
        ),
        foregroundColor: WidgetStatePropertyAll(c.background),
        overlayColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.1),
        ),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(
          label.copyWith(fontWeight: FontWeight.w700),
        ),
        shape: WidgetStatePropertyAll(s),
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
      );
}
