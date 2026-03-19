import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart' as ds;
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../providers/settings_provider.dart';
import '../../theme/theme_presets.dart';
import '../settings_view.dart';

class AppearanceSettingsView extends ConsumerStatefulWidget {
  const AppearanceSettingsView({super.key});

  @override
  ConsumerState<AppearanceSettingsView> createState() =>
      _AppearanceSettingsViewState();
}

class _AppearanceSettingsViewState
    extends ConsumerState<AppearanceSettingsView> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: ds.AppColors.background,
      appBar: AppBar(
        leading: SizedBox(),
        backgroundColor: ds.AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "Appearance",
          style: AppTypography.h3.copyWith(
            color: ds.AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: ds.AppColors.border.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xl + 20,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        const SectionTitle("Theme Mode"),
                        DropdownTile(
                          title: "Theme",
                          value: settings.themeMode,
                          options: ["system", "dark", "light"],
                          onChanged: settingsNotifier.setThemeMode,
                          icon: Icons.brightness_4_rounded,
                        ),

                        SizedBox(height: AppSpacing.l),
                        const SectionTitle("Theme Preset"),
                        SizedBox(height: AppSpacing.s),

                        // Preset Grid
                        _ThemePresetGrid(
                          selected: settings.themePreset,
                          onSelect: (id) => settingsNotifier.setThemePreset(id),
                        ),

                        SizedBox(height: AppSpacing.l),
                        const SectionTitle("Accent Color"),
                        SizedBox(height: AppSpacing.s),

                        // Color Picker
                        _AccentColorPicker(
                          currentColor: Color(settings.customAccentColor),
                          onColorChanged: (color) {
                            settingsNotifier.setCustomAccentColor(
                              color.toARGB32(),
                            );
                          },
                        ),

                        SizedBox(height: AppSpacing.l),
                        const SectionTitle("Language"),
                        DropdownTile(
                          title: "Language",
                          value: settings.locale,
                          options: ["en", "fr", "ar"],
                          onChanged: settingsNotifier.setLocale,
                          icon: Icons.language_rounded,
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.1, end: 0, duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePresetGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _ThemePresetGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ThemePresets.all.map((preset) {
        final isSelected = preset.id == selected;
        return GestureDetector(
          onTap: () => onSelect(preset.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              color: preset.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? preset.primary : ds.AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: preset.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ColorDot(color: preset.primary, size: 14),
                    SizedBox(width: 4),
                    _ColorDot(color: preset.surface, size: 14),
                    SizedBox(width: 4),
                    _ColorDot(color: preset.textPrimary, size: 14),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  preset.name,
                  style: TextStyle(
                    color: preset.textPrimary,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  const _AccentColorPicker({
    required this.currentColor,
    required this.onColorChanged,
  });

  static const _presetColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF22C55E), // Green
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red
    Color(0xFFE040FB), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
    Color(0xFFEAB308), // Yellow
    Color(0xFFF43F5E), // Rose
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Fuchsia
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ds.AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ds.AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Color Preview
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Accent",
                    style: AppTypography.label.copyWith(
                      color: ds.AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: AppTypography.mono,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // Color Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((color) {
              final isSelected = color.toARGB32() == currentColor.toARGB32();
              return GestureDetector(
                onTap: () => onColorChanged(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
