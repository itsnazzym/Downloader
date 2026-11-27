import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';

/// OLED's desktop look, "Émission" (mockups Main, OLED-*.dc.html): pure
/// black, only what is alive lights up, in a single "ion" colour.
abstract final class OledInk {
  static const bg = Color(0xFF000000);
  static const ink = Color(0xFFF2F2F2);
  static const bright = Color(0xFFFFFFFF);

  /// Ghost buttons' text and the soft links.
  static const soft = Color(0xFFBDBDBD);
  static const mute = Color(0xFF8C8C8C);

  /// Hairlines between areas and around rows.
  static const line = Color(0xFF141414);
  static const lineHover = Color(0xFF2A2A2A);

  /// Field, thumbnail and value-pill outlines.
  static const edge = Color(0xFF262626);
  static const ghost = Color(0xFF333333);

  /// Unlit dots and bar tracks.
  static const unlit = Color(0xFF1C1C1C);
  static const track = Color(0xFF161616);
  static const knobOff = Color(0xFF5E5E5E);
  static const err = Color(0xFFFF6B6B);

  /// The one live colour. The OLED preset does not take the accent setting
  /// (Appearance hides its picker), so ion is fixed.
  static const ion = Color(0xFF3CF2FF);
  static const ionGlow = Color(0x663CF2FF);
}

Duration oledMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// Instrument Sans, the UI face (the design's uiFont).
TextStyle oledText({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = OledInk.ink,
  double height = 1.3,
  double? spacing,
}) => AppTypography.body.copyWith(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

/// IBM Plex Mono for figures and metadata (the design's monoFont).
TextStyle oledMono({
  double size = 12,
  Color color = OledInk.mute,
  FontWeight weight = FontWeight.w400,
  double? spacing,
}) => AppTypography.mono.copyWith(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: 1.35,
  letterSpacing: spacing,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Small upper-case mono label ("EN COURS · 1 SUR 2").
TextStyle oledEyebrow() => oledMono(size: 11, spacing: 1.5);

/// Doto, the dot-matrix display face: hero figures, page titles, the logo.
TextStyle oledDoto(
  double size, {
  Color color = OledInk.ink,
  FontWeight weight = FontWeight.w900,
  double height = 0.9,
  List<Shadow>? glow,
}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    shadows: glow,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  try {
    return GoogleFonts.getFont('Doto', textStyle: base);
  } catch (_) {
    return base.copyWith(fontFamily: 'monospace');
  }
}

/// The ion glow of a lit figure (`text-shadow: 0 0 28px ion66`).
List<Shadow> oledGlow(double blur) => [
  Shadow(color: OledInk.ionGlow, blurRadius: blur),
];

/// OLED's Material overrides, scoped to its chrome: the dialogs, menus,
/// fields, buttons and switches the shared views still open come out black
/// with hairlines and the ion accent.
class OledTheme extends StatelessWidget {
  const OledTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    RoundedRectangleBorder round(double r, {Color? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side == null ? BorderSide.none : BorderSide(color: side),
        );
    final label = oledText(size: 13.5, weight: FontWeight.w600);
    final hover = WidgetStateProperty.resolveWith<Color?>(
      (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
          ? OledInk.ink.withValues(alpha: 0.08)
          : null,
    );
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: OledInk.edge),
    );
    final pill = WidgetStatePropertyAll(round(999, side: OledInk.ghost));
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: OledInk.bg,
        colorScheme: base.colorScheme.copyWith(
          primary: OledInk.ion,
          onPrimary: OledInk.bg,
          secondary: OledInk.ion,
          surface: OledInk.bg,
          onSurface: OledInk.ink,
          error: OledInk.err,
        ),
        dividerTheme: const DividerThemeData(color: OledInk.line, thickness: 1),
        dialogTheme: DialogThemeData(
          backgroundColor: OledInk.bg,
          surfaceTintColor: Colors.transparent,
          shape: round(16, side: OledInk.edge),
          titleTextStyle: oledText(size: 18, weight: FontWeight.w600),
          contentTextStyle: oledText(size: 13.5, color: OledInk.soft),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: OledInk.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: round(12, side: OledInk.edge),
          textStyle: oledText(size: 13.5),
          labelTextStyle: WidgetStatePropertyAll(oledText(size: 13.5)),
        ),
        menuTheme: const MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(OledInk.bg),
            surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: OledInk.bg,
          surfaceTintColor: Colors.transparent,
          dragHandleColor: OledInk.ghost,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: OledInk.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OledInk.edge),
          ),
          textStyle: oledText(size: 12),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(OledInk.ink),
            overlayColor: hover,
            textStyle: WidgetStatePropertyAll(label),
            shape: WidgetStatePropertyAll(round(999)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(OledInk.ion),
            foregroundColor: const WidgetStatePropertyAll(OledInk.bg),
            textStyle: WidgetStatePropertyAll(label),
            shape: WidgetStatePropertyAll(round(999)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(OledInk.bg),
            foregroundColor: const WidgetStatePropertyAll(OledInk.ink),
            elevation: const WidgetStatePropertyAll(0),
            overlayColor: hover,
            textStyle: WidgetStatePropertyAll(label),
            shape: pill,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(OledInk.soft),
            overlayColor: hover,
            side: const WidgetStatePropertyAll(
              BorderSide(color: OledInk.ghost),
            ),
            textStyle: WidgetStatePropertyAll(label),
            shape: pill,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(OledInk.mute),
            overlayColor: hover,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: OledInk.bg,
          isDense: true,
          labelStyle: oledText(size: 13, color: OledInk.mute),
          floatingLabelStyle: oledText(size: 12, color: OledInk.ion),
          hintStyle: oledText(size: 13.5, color: OledInk.mute),
          prefixIconColor: OledInk.mute,
          suffixIconColor: OledInk.mute,
          border: field,
          enabledBorder: field,
          focusedBorder: field.copyWith(
            borderSide: const BorderSide(color: OledInk.ink),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: OledInk.ion,
          selectionColor: OledInk.ion.withValues(alpha: 0.3),
          selectionHandleColor: OledInk.ion,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? OledInk.ion
                : OledInk.knobOff,
          ),
          trackColor: const WidgetStatePropertyAll(OledInk.bg),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? OledInk.ion : OledInk.ghost,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? OledInk.ion
                : Colors.transparent,
          ),
          checkColor: const WidgetStatePropertyAll(OledInk.bg),
          side: const BorderSide(color: OledInk.knobOff, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? OledInk.ion
                : OledInk.knobOff,
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 2,
          activeTrackColor: OledInk.ion,
          inactiveTrackColor: OledInk.unlit,
          thumbColor: OledInk.ion,
          overlayColor: const Color(0x1F3CF2FF),
          tickMarkShape: SliderTickMarkShape.noTickMark,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: OledInk.ion,
          linearTrackColor: OledInk.track,
          circularTrackColor: OledInk.track,
        ),
        cardTheme: CardThemeData(
          color: OledInk.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: round(14, side: OledInk.line),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: OledInk.bg,
          selectedColor: OledInk.bg,
          checkmarkColor: OledInk.ion,
          side: const BorderSide(color: OledInk.ghost),
          shape: round(999),
          labelStyle: oledText(size: 12.5),
        ),
      ),
      child: child,
    );
  }
}
