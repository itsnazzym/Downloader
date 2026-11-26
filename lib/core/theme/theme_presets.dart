import 'package:flutter/material.dart';

/// Visual chrome. Solid is the default cockpit. iOS enables glass, mesh, dock.
enum ThemeChrome { solid, ios }

/// A named theme preset with all colors needed by the app.
class ThemePreset {
  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color borderSubtle;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color inputBackground;
  final ThemeChrome chrome;
  final bool useMeshBackground;
  final bool useFloatingDock;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderSubtle,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.inputBackground,
    this.chrome = ThemeChrome.solid,
    this.useMeshBackground = false,
    this.useFloatingDock = false,
  });

  bool get isIosChrome => chrome == ThemeChrome.ios;

  /// Black or white, whichever reads better on [primary]. 0.179 is the
  /// luminance where both give the same contrast (a 0.5 cut-off put white on
  /// light accents such as periwinkle, at 2.3:1).
  Color get onPrimary =>
      primary.computeLuminance() > 0.179 ? Colors.black : Colors.white;

  /// Create a copy with a custom accent/primary override
  ThemePreset withAccent(Color newPrimary) {
    return ThemePreset(
      id: id,
      name: name,
      primary: newPrimary,
      accent: accent,
      background: background,
      surface: surface,
      surfaceHighlight: surfaceHighlight,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textDisabled: textDisabled,
      border: border,
      borderSubtle: borderSubtle,
      success: success,
      error: error,
      warning: warning,
      info: info,
      inputBackground: inputBackground,
      chrome: chrome,
      useMeshBackground: useMeshBackground,
      useFloatingDock: useFloatingDock,
    );
  }
}

class ThemePresets {
  const ThemePresets._();

  /// Signal, the default desktop design: a darkroom where only what is being
  /// captured lights up, in signal chartreuse.
  static const signal = ThemePreset(
    id: 'signal',
    name: 'Signal',
    primary: Color(0xFFD2F34C),
    accent: Color(0xFFF2F0E6),
    background: Color(0xFF0F0F0D),
    surface: Color(0xFF191916),
    surfaceHighlight: Color(0xFF22221E),
    textPrimary: Color(0xFFF2F0E6),
    textSecondary: Color(0xFFB8B6AB),
    textDisabled: Color(0xFF8A887E),
    border: Color(0x24F2F0E6),
    borderSubtle: Color(0x14F2F0E6),
    success: Color(0xFF9BD58A),
    error: Color(0xFFFF6A55),
    warning: Color(0xFFF2C14E),
    info: Color(0xFFB8B6AB),
    inputBackground: Color(0xFF0B0B0A),
  );

  /// Former default; kept as an alias so older call sites and saved
  /// settings land on Signal.
  static const midnight = signal;

  /// Porcelaine: light, frosted white cards on stone, cobalt for action.
  static const porcelaine = ThemePreset(
    id: 'porcelaine',
    name: 'Porcelaine',
    primary: Color(0xFF2747F5),
    accent: Color(0xFF16171A),
    background: Color(0xFFECEAE5),
    surface: Color(0xFFFFFFFF),
    surfaceHighlight: Color(0xFFF4F3F0),
    textPrimary: Color(0xFF16171A),
    textSecondary: Color(0xFF55575E),
    textDisabled: Color(0xFF62646B),
    border: Color(0x1F16171A),
    borderSubtle: Color(0x1016171A),
    success: Color(0xFF1E7A45),
    error: Color(0xFFB42D1B),
    warning: Color(0xFF8A5F00),
    info: Color(0xFF2747F5),
    inputBackground: Color(0xFFF4F3F0),
  );

  /// Pastille: solid pastel tiles on espresso, data drawn as dots.
  static const pastille = ThemePreset(
    id: 'pastille',
    name: 'Pastille',
    primary: Color(0xFFF4DA7A),
    accent: Color(0xFFB9A8F5),
    background: Color(0xFF191715),
    surface: Color(0xFF24211E),
    surfaceHighlight: Color(0xFF2E2A26),
    textPrimary: Color(0xFFF4EFE6),
    textSecondary: Color(0xFFB5ADA3),
    textDisabled: Color(0xFF8F877D),
    border: Color(0x1FF4EFE6),
    borderSubtle: Color(0x12F4EFE6),
    success: Color(0xFFA8C686),
    error: Color(0xFFFF8F7A),
    warning: Color(0xFFF4DA7A),
    info: Color(0xFF9ACDF5),
    inputBackground: Color(0xFF1E1C1A),
  );

  /// Studio: ink on paper; the only colour is a recording red for what runs.
  static const studio = ThemePreset(
    id: 'studio',
    name: 'Studio',
    primary: Color(0xFF17171A),
    accent: Color(0xFFE5483B),
    background: Color(0xFFF5F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceHighlight: Color(0xFFEBE9E4),
    textPrimary: Color(0xFF17171A),
    textSecondary: Color(0xFF55534E),
    textDisabled: Color(0xFF6B6963),
    border: Color(0xFFE2E0DB),
    borderSubtle: Color(0xFFECEAE5),
    success: Color(0xFF2F7D4F),
    error: Color(0xFFC2362A),
    warning: Color(0xFF8A6400),
    info: Color(0xFF3A5BA0),
    inputBackground: Color(0xFFFFFFFF),
  );

  /// Terminal: everything monospaced, phosphor green on near-black.
  static const terminal = ThemePreset(
    id: 'terminal',
    name: 'Terminal',
    primary: Color(0xFF8BE9A0),
    accent: Color(0xFFE8C468),
    background: Color(0xFF0A0D0B),
    surface: Color(0xFF0F1411),
    surfaceHighlight: Color(0xFF1C241E),
    textPrimary: Color(0xFFE3EAE4),
    textSecondary: Color(0xFF9AA59B),
    textDisabled: Color(0xFF7A867B),
    border: Color(0xFF1C241E),
    borderSubtle: Color(0xFF151B17),
    success: Color(0xFF8BE9A0),
    error: Color(0xFFFF8A73),
    warning: Color(0xFFE8C468),
    info: Color(0xFF9AA59B),
    inputBackground: Color(0xFF0F1411),
  );

  /// Nocturne: deep night blue, periwinkle accent, progress as rings.
  static const nocturne = ThemePreset(
    id: 'nocturne',
    name: 'Nocturne',
    primary: Color(0xFF8EA7FF),
    accent: Color(0xFFAEB9D6),
    background: Color(0xFF0A0F1E),
    surface: Color(0xFF111831),
    surfaceHighlight: Color(0xFF18213A),
    textPrimary: Color(0xFFEEF1FA),
    textSecondary: Color(0xFFAEB9D6),
    textDisabled: Color(0xFF8A96B8),
    border: Color(0x298EA7FF),
    borderSubtle: Color(0x148EA7FF),
    success: Color(0xFF7FE0B0),
    error: Color(0xFFFF9C8A),
    warning: Color(0xFFF2C66B),
    info: Color(0xFF8EA7FF),
    inputBackground: Color(0xFF0C1224),
  );

  /// Pure black for OLED screens. Ink-white primary, red reserved for live
  /// activity (see OledTokens.live).
  static const oled = ThemePreset(
    id: 'oled',
    name: 'OLED',
    primary: Color(0xFFF4F4F2),
    accent: Color(0xFFFF4A3D),
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0B),
    surfaceHighlight: Color(0xFF161616),
    textPrimary: Color(0xFFF4F4F2),
    textSecondary: Color(0xFFA1A1A0),
    textDisabled: Color(0xFF7C7C7B),
    border: Color(0x1FFFFFFF),
    borderSubtle: Color(0x14FFFFFF),
    success: Color(0xFFF4F4F2),
    error: Color(0xFFFF6B5E),
    warning: Color(0xFFE9B44C),
    info: Color(0xFFA1A1A0),
    inputBackground: Color(0xFF000000),
  );

  static const ios = ThemePreset(
    id: 'ios',
    name: 'iOS',
    primary: Color(0xFF0A84FF),
    accent: Color(0xFF64D2FF),
    background: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    surfaceHighlight: Color(0xFF3A3A3C),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF8E8E93),
    textDisabled: Color(0xFF636366),
    border: Color(0x33FFFFFF),
    borderSubtle: Color(0x1AFFFFFF),
    success: Color(0xFF30D158),
    error: Color(0xFFFF453A),
    warning: Color(0xFFFFD60A),
    info: Color(0xFF64D2FF),
    inputBackground: Color(0xFF1C1C1E),
    chrome: ThemeChrome.ios,
    useMeshBackground: true,
    useFloatingDock: true,
  );

  /// The six desktop designs first, then the platform looks.
  static const List<ThemePreset> all = [
    signal,
    porcelaine,
    pastille,
    studio,
    terminal,
    nocturne,
    oled,
    ios,
  ];

  /// Themes that were only recolours, mapped to the design that replaced them.
  static const Map<String, String> legacyIds = {
    'midnight': 'signal',
    'ocean': 'nocturne',
    'forest': 'nocturne',
    'sunset': 'pastille',
    'neon': 'terminal',
    'monochrome': 'studio',
  };

  static String migrateId(String id) => legacyIds[id] ?? id;

  static ThemePreset getById(String id) {
    final current = migrateId(id);
    return all.firstWhere((t) => t.id == current, orElse: () => signal);
  }
}
