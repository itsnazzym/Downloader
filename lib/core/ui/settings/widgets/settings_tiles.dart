import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/services/binary/binary_verifier.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// True when the settings building blocks render in the OLED language
/// (hairline outlines, ink-filled selection, no glass): on phones, and when
/// the active preset is the OLED one. Desktop presets keep their own look.
bool useOledSettingsStyle(BuildContext context) =>
    PlatformInfo.isMobile || AppColors.of(context).preset.id == 'oled';

Map<String, String> languageOptionLabels(AppLocalizations l10n) {
  return {
    'en': l10n.languageEnglish,
    'fr': l10n.languageFrench,
    'ar': l10n.languageArabic,
  };
}

Map<String, String> themeModeOptionLabels(AppLocalizations l10n) {
  return {
    'system': l10n.systemMode,
    'dark': l10n.darkMode,
    'light': l10n.lightMode,
  };
}

Map<String, String> qualityOptionLabels(AppLocalizations l10n) {
  return {
    'best': l10n.bestQuality,
    'manual': l10n.qualityManual,
    'manual+': l10n.qualityManualPlus,
  };
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) {
      return Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.s,
          bottom: AppSpacing.s,
          left: 4,
        ),
        child: Text(
          title,
          style: OledText.ui(
            context,
            size: 13,
            weight: FontWeight.w600,
            color: OledTokens.of(context).ink2,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s,
        bottom: AppSpacing.m,
        left: 4,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final IconData icon;

  const SliderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    required this.icon,
  });

  Widget _buildOled(BuildContext context) {
    final t = OledTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: OledCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _OledLabel(title, subtitle)),
                const Gap(AppSpacing.s),
                Text(
                  value.toInt().toString(),
                  style: OledText.dot(context, size: 28),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                activeTrackColor: t.ink,
                inactiveTrackColor: t.lineStrong,
                thumbColor: t.ink,
                overlayColor: t.ink.withValues(alpha: 0.08),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.m,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(color: AppColors.of(context).border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.of(context).primary, size: 24),
              const Gap(AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.of(context).border.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  value.toInt().toString(),
                  style: AppTypography.mono.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.of(context).primary,
              inactiveTrackColor: AppColors.of(context).surfaceHighlight,
              thumbColor: Colors.white,
              overlayColor: AppColors.of(
                context,
              ).primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const SwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  Widget _buildOled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: OledCard(
        onTap: () => onChanged(!value),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: _OledLabel(title, subtitle)),
              const Gap(AppSpacing.s),
              OledToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(color: AppColors.of(context).border.withAlpha(128)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.of(context).primary, size: 24),
          const Gap(AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.of(context).primary,
            activeThumbColor: Colors.white,
            inactiveThumbColor: AppColors.of(context).textDisabled,
            inactiveTrackColor: AppColors.of(context).surfaceHighlight,
          ),
        ],
      ),
    );
  }
}

class DropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final Map<String, String>? optionLabels;

  const DropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.icon,
    this.optionLabels,
  });

  Widget _buildOled(BuildContext context) {
    final labels = <String, String>{
      for (final e in options) e: optionLabels?[e] ?? e,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: OledCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OledLabel(title, ''),
            const Gap(12),
            if (options.length <= 3 &&
                labels.values.every((label) => label.length <= 10))
              OledSegmented<String>(
                options: labels,
                value: value,
                onChanged: onChanged,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in options)
                    OledChip(
                      label: labels[e] ?? e,
                      selected: e == value,
                      onTap: () => onChanged(e),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(
          color: AppColors.of(context).border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.of(context).textSecondary, size: 24),
          const Gap(AppSpacing.m),
          Expanded(
            child: Text(
              title,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.of(context).background,
              borderRadius: AppRadius.controlOf(context),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              dropdownColor: AppColors.of(context).surface,
              // Without a colour the value fell back to a pale grey that was
              // unreadable on the light designs.
              style: AppTypography.body.copyWith(
                color: AppColors.of(context).textPrimary,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.of(context).textSecondary,
              ),
              items: options
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(optionLabels?[e] ?? e),
                    ),
                  )
                  .toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int subtitleMaxLines;

  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.subtitleMaxLines = 2,
  });

  Widget _buildOled(BuildContext context) {
    final t = OledTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: OledCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: _OledLabel(
                title,
                subtitle,
                subtitleMaxLines: subtitleMaxLines,
              ),
            ),
            const Gap(AppSpacing.xs),
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_right_rounded, color: t.ink3, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Material(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.panelOf(context),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.panelOf(context),
          hoverColor: AppColors.of(context).primary.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.of(context).border.withValues(alpha: 0.5),
              ),
              borderRadius: AppRadius.panelOf(context),
            ),
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.of(context).textSecondary,
                  size: 24,
                ),
                const Gap(AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.of(context).textSecondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: subtitleMaxLines,
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textDisabled,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusTile extends StatelessWidget {
  final String name;
  final BinaryStatus status;

  const StatusTile(this.name, this.status, {super.key});

  Widget _buildOled(BuildContext context) {
    final t = OledTokens.of(context);
    final ok = status.isInstalled;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: OledCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: ok ? t.ink : t.warn,
              size: 20,
            ),
            const Gap(12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(context, size: 15, weight: FontWeight.w600),
              ),
            ),
            const Gap(12),
            Flexible(
              child: Text(
                status.version ?? context.l10n.settingsTilesNotFound,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(
                  context,
                  size: 13,
                  color: ok ? t.ink2 : t.warn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.panelOf(context),
        border: Border.all(
          color: status.isInstalled
              ? AppColors.of(context).success.withValues(alpha: 0.3)
              : AppColors.of(context).error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isInstalled
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: status.isInstalled
                ? AppColors.of(context).success
                : AppColors.of(context).error,
            size: 20,
          ),
          const Gap(12),
          Flexible(
            child: Text(
              name,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.isInstalled
                    ? AppColors.of(context).success.withValues(alpha: 0.1)
                    : AppColors.of(context).error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.version ?? context.l10n.settingsTilesNotFound,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: status.isInstalled
                      ? AppColors.of(context).success
                      : AppColors.of(context).error,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title and optional description of an OLED settings row.
class _OledLabel extends StatelessWidget {
  const _OledLabel(this.title, this.subtitle, {this.subtitleMaxLines});

  final String title;
  final String subtitle;
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: OledText.ui(context, size: 15, weight: FontWeight.w600),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: subtitleMaxLines,
            overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            style: OledText.ui(
              context,
              size: 12,
              weight: FontWeight.w400,
              color: t.ink2,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
