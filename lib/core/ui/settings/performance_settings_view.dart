import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../providers/settings_provider.dart';
import '../settings_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class PerformanceSettingsView extends ConsumerWidget {
  const PerformanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        leading: const SizedBox(),
        backgroundColor: AppColors.of(
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
          l10n.settingsPerformance,
          style: AppTypography.h3.copyWith(
            color: AppColors.of(context).textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.of(context).border.withValues(alpha: 0.5),
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
