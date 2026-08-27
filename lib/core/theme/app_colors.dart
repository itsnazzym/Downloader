import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'theme_presets.dart';

/// Palette colors from [ThemeData.extensions]. Always look up via [of].
class AppColors {
  const AppColors._(this.preset);

  final ThemePreset preset;

  static AppColors of(BuildContext context) {
    return AppColors._(AppPalette.of(context).preset);
  }

  Color get background => preset.background;
  Color get surface => preset.surface;
  Color get surfaceHighlight => preset.surfaceHighlight;

  Color get primary => preset.primary;
  Color get primaryVariant => Color.lerp(preset.primary, Colors.black, 0.15)!;
  Color get accent => preset.accent;
  Color get onPrimary => Colors.white;

  Color get textPrimary => preset.textPrimary;
  Color get textSecondary => preset.textSecondary;
  Color get textDisabled => preset.textDisabled;

  Color get border => preset.border;
  Color get borderSubtle => preset.borderSubtle;

  Color get success => preset.success;
  Color get error => preset.error;
  Color get warning => preset.warning;
  Color get info => preset.info;

  Color get inputBackground => preset.inputBackground;
  Color get overlay => const Color(0x66000000);

  bool get isIosChrome => preset.isIosChrome;
  bool get useMeshBackground => preset.useMeshBackground;
  bool get useFloatingDock => preset.useFloatingDock;

  Color get glassFill =>
      Colors.white.withValues(alpha: isIosChrome ? 0.10 : 0.04);

  Color get glassBorder =>
      Colors.white.withValues(alpha: isIosChrome ? 0.18 : 0.08);

  Color get glassHighlight => Colors.white.withValues(alpha: 0.22);

  List<BoxShadow> get tintedShadow => [
    BoxShadow(
      color: background.withValues(alpha: 0.45),
      blurRadius: isIosChrome ? 24 : 12,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: primary.withValues(alpha: isIosChrome ? 0.12 : 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
