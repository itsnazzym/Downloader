import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../providers/settings_provider.dart';
import 'widgets/settings_tiles.dart';
import '../../setup/dependency_bootstrap_provider.dart';
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
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsGeneral),
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
