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
import '../widgets/glass_setting_section.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

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
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: ds.AppColors.of(context).background,
      appBar: AppBar(
        leading: const SizedBox(),
        backgroundColor: ds.AppColors.of(
          context,
        ).background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          l10n.appearance,
          style: AppTypography.h3.copyWith(
            color: ds.AppColors.of(context).textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: ds.AppColors.of(context).border.withValues(alpha: 0.5),
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
                        SectionTitle(l10n.theme),
                        DropdownTile(
                          title: l10n.theme,
                          value: settings.themeMode,
                          options: const ["system", "dark", "light"],
                          optionLabels: themeModeOptionLabels(l10n),
                          onChanged: settingsNotifier.setThemeMode,
                          icon: Icons.brightness_4_rounded,
                        ),

                        const SizedBox(height: AppSpacing.l),

                        // Preset Grid
                        ds.AppColors.of(context).isIosChrome
                            ? GlassSettingSection(
                                title: l10n.theme,
                                icon: Icons.palette_outlined,
                                iconColor: ds.AppColors.of(context).primary,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _ThemePresetGrid(
                                      selected: settings.themePreset,
                                      onSelect: (id) =>
                                          settingsNotifier.setThemePreset(id),
                                    ),
                                  ),
                                ],
                              )
                            : _ThemePresetGrid(
                                selected: settings.themePreset,
                                onSelect: (id) =>
                                    settingsNotifier.setThemePreset(id),
                              ),

                        const SizedBox(height: AppSpacing.l),
                        SectionTitle(l10n.accentColor),
                        const SizedBox(height: AppSpacing.s),

                        // Color Picker
                        _AccentColorPicker(
                          currentColor: Color(settings.customAccentColor),
                          onColorChanged: (color) {
                            settingsNotifier.setCustomAccentColor(
                              color.toARGB32(),
                            );
                          },
                        ),

                        const SizedBox(height: AppSpacing.l),
                        SectionTitle(l10n.language),
                        DropdownTile(
                          title: l10n.language,
                          value: settings.locale,
                          options: const ["en", "fr", "ar"],
                          optionLabels: languageOptionLabels(l10n),
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
                color: isSelected
                    ? preset.primary
                    : ds.AppColors.of(context).border,
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
                    const SizedBox(width: 4),
                    _ColorDot(color: preset.surface, size: 14),
                    const SizedBox(width: 4),
                    _ColorDot(color: preset.textPrimary, size: 14),
                  ],
                ),
                const SizedBox(height: 8),
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
    Color(0xFF0D9488), // Teal
    Color(0xFF0A84FF), // iOS Blue
    Color(0xFF0EA5E9), // Sky
    Color(0xFF22C55E), // Green
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red
    Color(0xFFC026D3), // Fuchsia
    Color(0xFF6366F1), // Indigo
    Color(0xFFEAB308), // Yellow
    Color(0xFFF43F5E), // Rose
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ds.AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ds.AppColors.of(context).border),
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
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.currentAccent,
                    style: AppTypography.label.copyWith(
                      color: ds.AppColors.of(context).textPrimary,
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
          const SizedBox(height: 16),

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
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
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
