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

  static const midnight = ThemePreset(
    id: 'midnight',
    name: 'Midnight',
    primary: Color(0xFF0D9488),
    accent: Color(0xFFCCFBF1),
    background: Color(0xFF18181C),
    surface: Color(0xFF1F1F23),
    surfaceHighlight: Color(0xFF27272B),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textDisabled: Color(0xFF71717A),
    border: Color(0x1FFFFFFF),
    borderSubtle: Color(0x14FFFFFF),
    success: Color(0xFF34D399),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF38BDF8),
    inputBackground: Color(0xFF1C1C20),
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

  static const ocean = ThemePreset(
    id: 'ocean',
    name: 'Ocean',
    primary: Color(0xFF0EA5E9),
    accent: Color(0xFF38BDF8),
    background: Color(0xFF0C1222),
    surface: Color(0xFF111B2E),
    surfaceHighlight: Color(0xFF1A2740),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF7B8FA8),
    textDisabled: Color(0xFF3D4F65),
    border: Color(0xFF1E3048),
    borderSubtle: Color(0xFF162339),
    success: Color(0xFF22D3EE),
    error: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
    inputBackground: Color(0xFF0F192A),
  );

  static const sunset = ThemePreset(
    id: 'sunset',
    name: 'Sunset',
    primary: Color(0xFFF97316),
    accent: Color(0xFFFB923C),
    background: Color(0xFF1A1010),
    surface: Color(0xFF231515),
    surfaceHighlight: Color(0xFF2E1D1D),
    textPrimary: Color(0xFFFFF1E6),
    textSecondary: Color(0xFFB0877A),
    textDisabled: Color(0xFF5A3D35),
    border: Color(0xFF3D2420),
    borderSubtle: Color(0xFF2D1A17),
    success: Color(0xFF4ADE80),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFFFD93D),
    info: Color(0xFF93C5FD),
    inputBackground: Color(0xFF1E1212),
  );

  static const forest = ThemePreset(
    id: 'forest',
    name: 'Forest',
    primary: Color(0xFF22C55E),
    accent: Color(0xFF4ADE80),
    background: Color(0xFF0D1712),
    surface: Color(0xFF121E16),
    surfaceHighlight: Color(0xFF1A2B20),
    textPrimary: Color(0xFFE8F0EC),
    textSecondary: Color(0xFF7A9987),
    textDisabled: Color(0xFF3D5446),
    border: Color(0xFF1E3527),
    borderSubtle: Color(0xFF16271C),
    success: Color(0xFF34D399),
    error: Color(0xFFF87171),
    warning: Color(0xFFFDE68A),
    info: Color(0xFF67E8F9),
    inputBackground: Color(0xFF0F1A13),
  );

  static const neon = ThemePreset(
    id: 'neon',
    name: 'Neon',
    primary: Color(0xFFC026D3),
    accent: Color(0xFFF5D0FE),
    background: Color(0xFF12121A),
    surface: Color(0xFF1A1A24),
    surfaceHighlight: Color(0xFF242432),
    textPrimary: Color(0xFFF5F5FF),
    textSecondary: Color(0xFF9A9AB8),
    textDisabled: Color(0xFF5A5A78),
    border: Color(0xFF2E2E44),
    borderSubtle: Color(0xFF222236),
    success: Color(0xFF34D399),
    error: Color(0xFFF43F5E),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF818CF8),
    inputBackground: Color(0xFF16161E),
  );

  static const monochrome = ThemePreset(
    id: 'monochrome',
    name: 'Mono',
    primary: Color(0xFFAAAAAA),
    accent: Color(0xFFFFFFFF),
    background: Color(0xFF0E0E0E),
    surface: Color(0xFF161616),
    surfaceHighlight: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFE5E5E5),
    textSecondary: Color(0xFF808080),
    textDisabled: Color(0xFF404040),
    border: Color(0xFF2A2A2A),
    borderSubtle: Color(0xFF1F1F1F),
    success: Color(0xFFB0B0B0),
    error: Color(0xFFD4D4D4),
    warning: Color(0xFFC0C0C0),
    info: Color(0xFF8F8F8F),
    inputBackground: Color(0xFF131313),
  );

  static const List<ThemePreset> all = [
    midnight,
    ios,
    ocean,
    sunset,
    forest,
    neon,
    monochrome,
  ];

  static ThemePreset getById(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => midnight);
  }
}
