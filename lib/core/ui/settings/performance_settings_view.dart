import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../providers/settings_provider.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/settings_app_bar.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class PerformanceSettingsView extends ConsumerWidget {
  const PerformanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    // OLED, and a design that draws switch tiles, use the shared tile.
    final useSwitchTile =
        useOledSettingsStyle(context) ||
        DesignSkin.of(context)?.switchTile != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsPerformance),
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
                        SectionTitle(l10n.settingsPerformance),
                        SliderTile(
                          title: l10n.simultaneousDownloads,
                          subtitle: l10n.simultaneousDownloadsDesc,
                          value: settings.maxConcurrent.toDouble().clamp(
                            1.0,
                            60.0,
                          ),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          onChanged: (v) =>
                              settingsNotifier.setMaxConcurrent(v.toInt()),
                          icon: Icons.layers_outlined,
                        ),
                        SliderTile(
                          title: l10n.threadsPerDownload,
                          subtitle: l10n.threadsPerDownloadDesc,
                          value: settings.concurrentFragments.toDouble().clamp(
                            1.0,
                            64.0,
                          ),
                          min: 1,
                          max: 64,
                          divisions: 63,
                          onChanged: (v) => settingsNotifier
                              .setConcurrentFragments(v.toInt()),
                          icon: Icons.bolt_rounded,
                        ),
                        if (useSwitchTile)
                          SwitchTile(
                            title: l10n.maxSpeedMode,
                            subtitle: l10n.maxSpeedModeDesc,
                            value: settings.maxSpeedMode,
                            onChanged: settingsNotifier.setMaxSpeedMode,
                            icon: Icons.rocket_launch_rounded,
                          )
                        else
                          SwitchListTile(
                            secondary: Icon(
                              Icons.rocket_launch_rounded,
                              color: AppColors.of(context).textSecondary,
                            ),
                            title: Text(
                              l10n.maxSpeedMode,
                              style: AppTypography.body.copyWith(
                                color: AppColors.of(context).textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              l10n.maxSpeedModeDesc,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.of(context).textSecondary,
                              ),
                            ),
                            value: settings.maxSpeedMode,
                            onChanged: settingsNotifier.setMaxSpeedMode,
                            contentPadding: EdgeInsets.zero,
                          ),
                        if (useSwitchTile)
                          SwitchTile(
                            title: l10n.reduceEffects,
                            subtitle: l10n.reduceEffectsDesc,
                            value: settings.reduceEffects,
                            onChanged: settingsNotifier.setReduceEffects,
                            icon: Icons.blur_off_rounded,
                          )
                        else
                          SwitchListTile(
                            secondary: Icon(
                              Icons.blur_off_rounded,
                              color: AppColors.of(context).textSecondary,
                            ),
                            title: Text(
                              l10n.reduceEffects,
                              style: AppTypography.body.copyWith(
                                color: AppColors.of(context).textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              l10n.reduceEffectsDesc,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.of(context).textSecondary,
                              ),
                            ),
                            value: settings.reduceEffects,
                            onChanged: settingsNotifier.setReduceEffects,
                            contentPadding: EdgeInsets.zero,
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
