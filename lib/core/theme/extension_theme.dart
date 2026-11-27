import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import 'design_spec.dart';
import 'theme_presets.dart';
import 'theme_resolver.dart';

/// The `THEME` message sent to the browser extension so its popup, panel and
/// sync card wear the desktop app's current design.
///
/// Colours are opaque `#RRGGBB` strings: the extension is plain CSS and the
/// design borders (translucent in the app) are composited over the canvas here.
class ExtensionTheme {
  const ExtensionTheme._();

  static const messageType = 'THEME';

  /// The preset the desktop app really draws for [settings] (mirrors app.dart).
  static ThemePreset effectivePreset(AppSettings settings) {
    if (settings.themePreset == 'oled') return ThemePresets.oled;
    return ThemeResolver.resolve(
      presetId: settings.themePreset,
      customAccentArgb: settings.customAccentColor,
    );
  }

  static Map<String, dynamic> fromSettings(
    AppSettings settings, {
    Brightness platformBrightness = Brightness.dark,
  }) {
    final resolved = effectivePreset(settings);
    final fixed = DesignSpec.forId(resolved.id).brightness;
    final brightness =
        fixed ??
        switch (settings.themeMode) {
          'light' => Brightness.light,
          'dark' => Brightness.dark,
          _ => platformBrightness,
        };
    return build(
      ThemeResolver.forBrightness(resolved, brightness),
      brightness: brightness,
    );
  }

  static Map<String, dynamic> build(
    ThemePreset preset, {
    required Brightness brightness,
  }) {
    final spec = DesignSpec.forId(preset.id);
    final canvas = preset.background;
    final tiles = _tiles(preset, spec);
    return {
      'type': messageType,
      'id': preset.id,
      'dark': brightness == Brightness.dark,
      'canvas': _hex(canvas),
      'panel': _hex(preset.surface),
      'panel2': _hex(preset.surfaceHighlight),
      'line': _hex(_over(preset.border, canvas)),
      'ink': _hex(preset.textPrimary),
      'sub': _hex(_legible(preset.textSecondary, preset.textPrimary, preset.surface)),
      'mute': _hex(preset.textDisabled),
      'tiles': [
        for (final tile in tiles) {'bg': _hex(tile), 'on': _hex(_on(tile))},
      ],
      'ok': {'bg': _hex(preset.success), 'on': _hex(_on(preset.success))},
      'bad': {'bg': _hex(preset.error), 'on': _hex(_on(preset.error))},
      'cardRadius': spec.cardRadius.round(),
      'controlRadius': spec.controlRadius.round(),
    };
  }

  /// Three distinct action colours: the design's own tiles (Pastille), else its
  /// primary followed by the next palette colours that differ from it.
  static List<Color> _tiles(ThemePreset preset, DesignSpec spec) {
    final picked = <Color>[];
    void add(Color color) {
      if (picked.length < 3 && picked.every((c) => _apart(c, color))) {
        picked.add(color);
      }
    }

    spec.tiles.forEach(add);
    for (final color in [
      preset.primary,
      preset.accent,
      preset.warning,
      preset.info,
      preset.success,
      preset.textPrimary,
    ]) {
      add(color);
    }
    return picked;
  }

  static bool _apart(Color a, Color b) =>
      ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs()) * 255 > 60;

  /// The extension sets small text in this colour, so pull it toward the main
  /// text colour until it reaches 4.5:1 on the panels.
  static Color _legible(Color text, Color strong, Color panel) {
    var color = text;
    for (var i = 0; i < 6 && _contrast(color, panel) < 4.5; i++) {
      color = Color.lerp(color, strong, 0.25)!;
    }
    return color;
  }

  static double _contrast(Color a, Color b) {
    final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
    final lo = identical(hi, a) ? b : a;
    return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
  }

  /// Black or white, whichever reads better (same cut-off as the app).
  static Color _on(Color background) =>
      background.computeLuminance() > 0.179 ? Colors.black : Colors.white;

  static Color _over(Color foreground, Color background) {
    final a = foreground.a;
    return Color.from(
      alpha: 1,
      red: foreground.r * a + background.r * (1 - a),
      green: foreground.g * a + background.g * (1 - a),
      blue: foreground.b * a + background.b * (1 - a),
    );
  }

  static String _hex(Color c) {
    String two(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}';
  }
}
