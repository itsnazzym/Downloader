import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/services/binary/binary_verifier.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              dropdownColor: AppColors.of(context).surface,
              style: AppTypography.body,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Material(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.of(context).primary.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.of(context).border.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
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
                status.version ?? "Not found",
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
