import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../download/download_path_resolver.dart';

import 'widgets/storage_chart.dart';
import 'widgets/library_migration_dialog.dart';
import 'widgets/output_folder_picker.dart';
import '../../platform/platform_info.dart';
import '../../../features/downloader/presentation/views/dialogs/reorganize_library_dialog.dart';
import '../../../features/onboarding/presentation/onboarding_targets.dart';
import '../../providers/settings_provider.dart';
import 'widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'widgets/settings_app_bar.dart';

class OutputSettingsView extends ConsumerWidget {
  const OutputSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: !PlatformInfo.isMobile,
      backgroundColor: AppColors.of(context).background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsOutput),
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
                          SectionTitle(l10n.settingsOutput),
                        // Phones already show free space on the settings hub.
                        if (!PlatformInfo.isMobile) ...[
                          StorageChart(
                            path:
                                DownloadPathResolver.resolve(
                                  settingsOutputFolder: settings.outputFolder,
                                  itemFolders: const [],
                                  userProfile:
                                      Platform.environment['USERPROFILE'],
                                  fallbackFolder: Platform.isAndroid
                                      ? '/storage/emulated/0/Download/TapLoad'
                                      : null,
                                ) ??
                                '',
                          ),
                          const Gap(AppSpacing.l),
                        ],
                        ActionTile(
                          key: OnboardingTargets.outputFolder,
                          title: l10n.downloadFolder,
                          subtitle: settings.outputFolder.isEmpty
                              ? l10n.selectFolder
                              : settings.outputFolder,
                          icon: Icons.folder_open_rounded,
                          onTap: () => pickOutputFolder(context, ref),
                        ),
                        ActionTile(
                          title: l10n.settingsOutputMigrateLibraryTitle,
                          subtitle: l10n.settingsOutputMigrateLibraryDesc,
                          icon: Icons.drive_file_move_rounded,
                          onTap: () =>
                              LibraryMigrationDialog.show(context, ref),
                        ),
                        ActionTile(
                          title: l10n.settingsOutputReorganizeTitle,
                          subtitle: l10n.settingsOutputReorganizeDesc,
                          icon: Icons.folder_shared_rounded,
                          onTap: () => ReorganizeLibraryDialog.show(context),
                        ),
                        DropdownTile(
                          title: l10n.formatLabel,
                          value: settings.outputFormat,
                          options: const ["mp4", "mkv", "webm"],
                          onChanged: settingsNotifier.setOutputFormat,
                          icon: Icons.video_file,
                        ),
                        SwitchTile(
                          title: l10n.organizeBySite,
                          subtitle: l10n.organizeBySiteDesc,
                          value: settings.organizeBySite,
                          onChanged: settingsNotifier.setOrganizeBySite,
                          icon: Icons.folder_copy_rounded,
                        ),
                        SwitchTile(
                          title: l10n.organizeByCreator,
                          subtitle: l10n.organizeByCreatorDesc,
                          value: settings.organizeByCreator,
                          onChanged: settingsNotifier.setOrganizeByCreator,
                          icon: Icons.person_rounded,
                        ),
                        if (PlatformInfo.isMobile)
                          ActionTile(
                            title: l10n.smartOrganization,
                            subtitle: l10n.smartOrganizationDesc,
                            icon: Icons.auto_awesome_motion,
                            onTap: () =>
                                context.push('/settings/smart_organizer'),
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
