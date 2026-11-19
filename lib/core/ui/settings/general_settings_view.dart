import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../providers/settings_provider.dart';
import 'widgets/settings_tiles.dart';
import '../../setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/mobile/mobile_onboarding.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../platform/platform_info.dart';

import 'widgets/settings_app_bar.dart';

class GeneralSettingsView extends ConsumerWidget {
  const GeneralSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: !PlatformInfo.isMobile,
      backgroundColor: AppColors.of(context).background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsGeneral),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          // Phones have no section title under the bar: start closer to it.
          PlatformInfo.isMobile ? AppSpacing.m : AppSpacing.xl + 20,
          AppSpacing.l,
          AppSpacing.xl + 20,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        // The app bar already carries the title on phones.
                        if (!PlatformInfo.isMobile)
                          SectionTitle(l10n.settingsGeneral),
                        if (!PlatformInfo.isMobile) ...[
                          ActionTile(
                            title: l10n.previewSetup,
                            subtitle: l10n.previewSetupDesc,
                            icon: Icons.install_desktop_outlined,
                            onTap: () {
                              ref
                                  .read(dependencyBootstrapProvider.notifier)
                                  .ensureReady();
                            },
                          ),
                          ActionTile(
                            title: l10n.onboardingReplay,
                            subtitle: l10n.onboardingReplayDesc,
                            icon: Icons.replay_outlined,
                            onTap: () {
                              context.go('/');
                              ref
                                  .read(onboardingControllerProvider.notifier)
                                  .replay();
                            },
                          ),
                          ActionTile(
                            title: l10n.smartOrganization,
                            subtitle: l10n.smartOrganizationDesc,
                            icon: Icons.auto_awesome_motion,
                            onTap: () =>
                                context.push('/settings/smart_organizer'),
                          ),
                        ],
                        if (PlatformInfo.isMobile)
                          ActionTile(
                            title: l10n.onboardingReplay,
                            subtitle: l10n.onboardingReplayDesc,
                            icon: Icons.replay_outlined,
                            onTap: () {
                              context.go('/');
                              ref
                                  .read(mobileOnboardingProvider.notifier)
                                  .replay();
                            },
                          ),
                        SwitchTile(
                          title: l10n.audioOnly,
                          subtitle: l10n.audioOnlyDesc,
                          value: settings.audioOnly,
                          onChanged: settingsNotifier.setAudioOnly,
                          icon: Icons.audiotrack,
                        ),
                        SwitchTile(
                          title: l10n.autoStart,
                          subtitle: l10n.autoStartDesc,
                          value: settings.autoStart,
                          onChanged: settingsNotifier.setAutoStart,
                          icon: Icons.play_arrow_rounded,
                        ),
                        DropdownTile(
                          title: l10n.preferredQuality,
                          value: settings.preferredQuality,
                          options: const ["best", "manual", "manual+"],
                          optionLabels: qualityOptionLabels(l10n),
                          onChanged: settingsNotifier.setPreferredQuality,
                          icon: Icons.high_quality,
                        ),
                        // The phone has no Performance page: speed lives here.
                        if (PlatformInfo.isMobile) ...[
                          SliderTile(
                            title: l10n.threadsPerDownload,
                            subtitle: l10n.threadsPerDownloadDesc,
                            value: settings.concurrentFragments
                                .toDouble()
                                .clamp(1.0, 64.0),
                            min: 1,
                            max: 64,
                            divisions: 63,
                            onChanged: (v) => settingsNotifier
                                .setConcurrentFragments(v.toInt()),
                            icon: Icons.bolt_rounded,
                          ),
                          SwitchTile(
                            title: l10n.maxSpeedMode,
                            subtitle: l10n.maxSpeedModeDesc,
                            value: settings.maxSpeedMode,
                            onChanged: settingsNotifier.setMaxSpeedMode,
                            icon: Icons.rocket_launch_rounded,
                          ),
                        ],
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
