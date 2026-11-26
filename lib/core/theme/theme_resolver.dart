import 'package:flutter/material.dart';
import 'design_spec.dart';
import 'theme_presets.dart';

class ThemeResolver {
  static ThemePreset resolve({
    required String presetId,
    required int customAccentArgb,
  }) {
    final preset = ThemePresets.getById(presetId);
    // A recolour theme that was retired: its stored accent is the old
    // theme's own colour, not a choice the user made for the new design.
    if (ThemePresets.legacyIds.containsKey(presetId)) return preset;
    final accent = Color(customAccentArgb);
    if (accent.toARGB32() != preset.primary.toARGB32()) {
      return preset.withAccent(accent);
    }
    return preset;
  }

  static ThemePreset forBrightness(ThemePreset preset, Brightness brightness) {
    // A design with its own brightness keeps its colours in both modes.
    if (brightness == Brightness.dark ||
        DesignSpec.forId(preset.id).brightness != null) {
      return preset;
    }
    return ThemePreset(
      id: preset.id,
      name: preset.name,
      primary: preset.primary,
      accent: preset.accent,
      background: const Color(0xFFF4F4F7),
      surface: const Color(0xFFFFFFFF),
      surfaceHighlight: const Color(0xFFE8E8EE),
      textPrimary: const Color(0xFF121214),
      textSecondary: const Color(0xFF5C5C66),
      textDisabled: const Color(0xFF9A9AA3),
      border: const Color(0xFFD8D8E0),
      borderSubtle: const Color(0xFFE8E8EE),
      success: preset.success,
      error: preset.error,
      warning: preset.warning,
      info: preset.info,
      inputBackground: const Color(0xFFF0F0F4),
      chrome: preset.chrome,
      useMeshBackground: preset.useMeshBackground,
      useFloatingDock: preset.useFloatingDock,
    );
  }
}
