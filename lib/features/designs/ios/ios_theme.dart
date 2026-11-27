import 'package:flutter/material.dart';
import 'package:tapload/core/theme/app_palette.dart';
import 'package:tapload/core/theme/theme_presets.dart';

import 'ios_glass.dart';

/// iOS's Material overrides, scoped to its desktop chrome: the dialogs,
/// menus, fields, buttons, switches and sheets the shared views still open
/// come out as frosted panels with capsule controls. Mobile never sees it.
class IosGlassTheme extends StatelessWidget {
  const IosGlassTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final base = Theme.of(context);
    // Floating panels sit over moving content: nearly opaque, no blur.
    final panel = t.dark ? const Color(0xF2171A23) : const Color(0xF7FFFFFF);
    final field = t.dark ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF);
    RoundedRectangleBorder round(double r) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: BorderSide(color: t.edge),
    );
    final label = iosText(t, weight: FontWeight.w600);
    WidgetStateProperty<Color?> hoverTint() => WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
          ? t.hover
          : null,
    );
    final capsule = WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: t.edge),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: t.blueFill,
          onPrimary: Colors.white,
          surface: panel,
          onSurface: t.text,
          error: t.redFill,
        ),
        dividerTheme: DividerThemeData(color: t.edge, thickness: 1),
        dialogTheme: DialogThemeData(
          backgroundColor: panel,
          surfaceTintColor: Colors.transparent,
          shape: round(28),
          titleTextStyle: iosText(
            t,
            size: 19,
            weight: FontWeight.w800,
            spacing: -0.3,
          ),
          contentTextStyle: iosText(t, size: 14, color: t.sub),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: panel,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          shape: round(18),
          textStyle: iosText(t),
          labelTextStyle: WidgetStatePropertyAll(iosText(t)),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(panel),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(round(18)),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: panel,
          surfaceTintColor: Colors.transparent,
          dragHandleColor: t.sub,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.edge),
          ),
          textStyle: iosText(t, size: 12),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled) ? t.sub : t.blue,
            ),
            overlayColor: hoverTint(),
            textStyle: WidgetStatePropertyAll(label),
            shape: capsule,
            minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(style: _filledStyle(t, label)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _filledStyle(t, label),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(t.text),
            backgroundColor: WidgetStatePropertyAll(t.glassTop),
            overlayColor: hoverTint(),
            side: WidgetStatePropertyAll(BorderSide(color: t.edge)),
            textStyle: WidgetStatePropertyAll(label),
            shape: capsule,
            minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(t.sub),
            overlayColor: hoverTint(),
            shape: const WidgetStatePropertyAll(CircleBorder()),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: field,
          isDense: true,
          labelStyle: iosText(t, color: t.sub),
          floatingLabelStyle: iosText(t, size: 12, color: t.blue),
          hintStyle: iosText(t, color: t.sub),
          helperStyle: iosText(t, size: 12, color: t.sub),
          prefixIconColor: t.sub,
          suffixIconColor: t.sub,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: BorderSide(color: t.blueFill, width: 1.5),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: t.blueFill,
          selectionColor: t.blueFill.withValues(alpha: 0.3),
          selectionHandleColor: t.blueFill,
        ),
        switchTheme: SwitchThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFF2FBF71)
                : t.track,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: hoverTint(),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.blueFill : null,
          ),
          checkColor: const WidgetStatePropertyAll(Colors.white),
          side: BorderSide(color: t.sub, width: 1.5),
          shape: const CircleBorder(),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.blueFill : t.sub,
          ),
        ),
        cardTheme: CardThemeData(
          color: t.glassTop,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: round(22),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          iconColor: t.sub,
          textColor: t.text,
          selectedColor: t.blue,
          selectedTileColor: t.hover,
          titleTextStyle: iosText(t, weight: FontWeight.w600),
          subtitleTextStyle: iosText(t, size: 12.5, color: t.sub),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: t.glassBottom,
          selectedColor: t.pillTop,
          checkmarkColor: t.blue,
          side: BorderSide(color: t.edge),
          shape: const StadiumBorder(),
          labelStyle: iosText(t, size: 12.5, weight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 5,
          activeTrackColor: t.blueFill,
          inactiveTrackColor: t.track,
          thumbColor: Colors.white,
          overlayColor: t.blueFill.withValues(alpha: 0.12),
          tickMarkShape: SliderTickMarkShape.noTickMark,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 11,
            elevation: 3,
            pressedElevation: 4,
          ),
          valueIndicatorColor: panel,
          valueIndicatorTextStyle: iosText(t, weight: FontWeight.w600),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: t.blueFill,
          linearTrackColor: t.track,
          circularTrackColor: t.track,
        ),
      ),
      child: child,
    );
  }
}

/// Today's view on iOS's glass: its scaffold turns transparent and its cards
/// translucent, so the page's ambient shows through instead of a solid slab.
class IosFramed extends StatelessWidget {
  const IosFramed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final base = Theme.of(context);
    final p = AppPalette.of(context).preset;
    final glass = ThemePreset(
      id: p.id,
      name: p.name,
      primary: p.primary,
      accent: p.accent,
      // Transparent but of the page's tone: blends stay light in light.
      background: t.base.withValues(alpha: 0),
      surface: t.dark ? const Color(0x14FFFFFF) : const Color(0x8CFFFFFF),
      surfaceHighlight: t.dark
          ? const Color(0x24FFFFFF)
          : const Color(0xD9FFFFFF),
      textPrimary: t.text,
      textSecondary: t.sub,
      textDisabled: t.sub.withValues(alpha: 0.7),
      border: t.edge,
      borderSubtle: t.edge.withValues(alpha: 0.5),
      success: p.success,
      error: p.error,
      warning: p.warning,
      info: p.info,
      inputBackground: t.dark
          ? const Color(0x1FFFFFFF)
          : const Color(0xB3FFFFFF),
      // Solid: the shared glass cards would each run a BackdropFilter
      // inside a scrolling view; here they are flat translucent panels.
      chrome: ThemeChrome.solid,
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        extensions: [
          for (final e in base.extensions.values)
            if (e is! AppPalette) e,
          AppPalette(glass),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

ButtonStyle _filledStyle(IosTokens t, TextStyle label) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? t.blueFill.withValues(alpha: 0.35)
        : t.blueFill,
  ),
  foregroundColor: const WidgetStatePropertyAll(Colors.white),
  overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
  elevation: const WidgetStatePropertyAll(0),
  textStyle: WidgetStatePropertyAll(
    label.copyWith(fontWeight: FontWeight.w700),
  ),
  shape: const WidgetStatePropertyAll(StadiumBorder()),
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
);
