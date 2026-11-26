import 'package:flutter/material.dart';

import 'app_palette.dart';

/// How a design lays out the desktop navigation around the pages.
enum DesignNav {
  /// The classic grouped sidebar (OLED, iOS).
  sidebar,

  /// Signal: a top bar with a sliding pill under the active tab.
  topTabs,

  /// Porcelaine: a floating capsule centred above the content.
  centerDock,

  /// Studio: a text-only sidebar with hairline separators.
  textSidebar,

  /// Terminal: a command bar, a keyed sidebar and a status footer.
  keySidebar,

  /// Nocturne: a narrow rail of rounded icons.
  iconRail,

  /// Pastille: a floating dock at the bottom of the window.
  bottomDock,
}

/// How a design draws download progress.
enum DesignProgress { bar, sheen, line, dots, segments, ring }

/// Everything a design changes beyond its colours ([ThemePreset]). Looked up
/// by preset id so the preset copies (accent, brightness, lerp) never drop it.
@immutable
class DesignSpec {
  const DesignSpec({
    required this.id,
    required this.displayFont,
    required this.uiFont,
    required this.monoFont,
    required this.cardRadius,
    required this.controlRadius,
    required this.nav,
    required this.progress,
    this.brightness,
    this.tiles = const [],
    this.uppercaseLabels = false,
  });

  final String id;

  /// Fixed brightness of the design; null follows the light/dark setting.
  final Brightness? brightness;
  final String displayFont;
  final String uiFont;
  final String monoFont;
  final double cardRadius;
  final double controlRadius;
  final DesignNav nav;
  final DesignProgress progress;

  /// Solid tile colours (Pastille). Text on them is always the dark ink.
  final List<Color> tiles;
  final bool uppercaseLabels;

  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get controlBorderRadius => BorderRadius.circular(controlRadius);

  static const signal = DesignSpec(
    id: 'signal',
    brightness: Brightness.dark,
    displayFont: 'Bricolage Grotesque',
    uiFont: 'Geist',
    monoFont: 'Geist Mono',
    cardRadius: 20,
    controlRadius: 999,
    nav: DesignNav.topTabs,
    progress: DesignProgress.sheen,
  );

  static const porcelaine = DesignSpec(
    id: 'porcelaine',
    brightness: Brightness.light,
    displayFont: 'Plus Jakarta Sans',
    uiFont: 'Inter',
    monoFont: 'IBM Plex Mono',
    cardRadius: 28,
    controlRadius: 16,
    nav: DesignNav.centerDock,
    progress: DesignProgress.sheen,
  );

  static const pastille = DesignSpec(
    id: 'pastille',
    brightness: Brightness.dark,
    displayFont: 'Sora',
    uiFont: 'DM Sans',
    monoFont: 'DM Mono',
    cardRadius: 30,
    controlRadius: 999,
    nav: DesignNav.bottomDock,
    progress: DesignProgress.dots,
    tiles: [
      Color(0xFFB9A8F5),
      Color(0xFFA8C686),
      Color(0xFFF5B3C8),
      Color(0xFF9ACDF5),
      Color(0xFFF4DA7A),
      Color(0xFFF4EFE6),
    ],
  );

  static const studio = DesignSpec(
    id: 'studio',
    brightness: Brightness.light,
    displayFont: 'Inter Tight',
    uiFont: 'Inter',
    monoFont: 'JetBrains Mono',
    cardRadius: 12,
    controlRadius: 8,
    nav: DesignNav.textSidebar,
    progress: DesignProgress.line,
  );

  static const terminal = DesignSpec(
    id: 'terminal',
    brightness: Brightness.dark,
    displayFont: 'JetBrains Mono',
    uiFont: 'JetBrains Mono',
    monoFont: 'JetBrains Mono',
    cardRadius: 0,
    controlRadius: 0,
    nav: DesignNav.keySidebar,
    progress: DesignProgress.segments,
  );

  static const nocturne = DesignSpec(
    id: 'nocturne',
    brightness: Brightness.dark,
    displayFont: 'Manrope',
    uiFont: 'Manrope',
    monoFont: 'JetBrains Mono',
    cardRadius: 18,
    controlRadius: 14,
    nav: DesignNav.iconRail,
    progress: DesignProgress.ring,
  );

  static const oled = DesignSpec(
    id: 'oled',
    brightness: Brightness.dark,
    displayFont: 'Instrument Sans',
    uiFont: 'Instrument Sans',
    monoFont: 'JetBrains Mono',
    cardRadius: 12,
    controlRadius: 8,
    nav: DesignNav.sidebar,
    progress: DesignProgress.bar,
  );

  static const ios = DesignSpec(
    id: 'ios',
    displayFont: 'Inter',
    uiFont: 'Inter',
    monoFont: 'JetBrains Mono',
    cardRadius: 16,
    controlRadius: 14,
    nav: DesignNav.sidebar,
    progress: DesignProgress.bar,
  );

  static const all = [
    signal,
    porcelaine,
    pastille,
    studio,
    terminal,
    nocturne,
    oled,
    ios,
  ];

  static DesignSpec forId(String id) {
    for (final spec in all) {
      if (spec.id == id) return spec;
    }
    return signal;
  }

  static DesignSpec of(BuildContext context) =>
      forId(AppPalette.of(context).preset.id);
}
