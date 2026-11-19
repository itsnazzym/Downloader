import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../download/download_path_resolver.dart';

import 'widgets/storage_chart.dart';
import 'widgets/library_migration_dialog.dart';
import '../../../features/downloader/presentation/views/dialogs/reorganize_library_dialog.dart';
import '../../../features/onboarding/presentation/onboarding_targets.dart';
import '../../providers/settings_provider.dart';
import 'widgets/settings_tiles.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'widgets/settings_app_bar.dart';

class OutputSettingsView extends ConsumerWidget {
  const OutputSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsOutput),
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
                        SectionTitle(l10n.settingsOutput),
                        StorageChart(
                          path:
                              DownloadPathResolver.resolve(
                                settingsOutputFolder: settings.outputFolder,
                                itemFolders: const [],
                                userProfile:
                                    Platform.environment['USERPROFILE'],
                                fallbackFolder: Platform.isAndroid
                                    ? '/storage/emulated/0/Download/ModernDownloader'
                                    : null,
                              ) ??
                              '',
                        ),
                        const Gap(AppSpacing.l),
                        ActionTile(
                          key: OnboardingTargets.outputFolder,
                          title: l10n.downloadFolder,
                          subtitle: settings.outputFolder.isEmpty
                              ? l10n.selectFolder
                              : settings.outputFolder,
                          icon: Icons.folder_open_rounded,
                          onTap: () async {
                            String? path = await FilePicker.platform
                                .getDirectoryPath();
                            if (path != null && context.mounted) {
                              // Ask if user wants to migrate existing downloads
                              final shouldMigrate = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(
                                    l10n.settingsOutputChangeFolderTitle,
                                  ),
                                  content: Text(
                                    l10n.settingsOutputChangeFolderBody,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(
                                        l10n.settingsOutputChangeFolderOnly,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(
                                        l10n.settingsOutputMigrateFiles,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldMigrate == true && context.mounted) {
                                await LibraryMigrationDialog.show(
                                  context,
                                  ref,
                                  targetFolder: path,
                                );
                              } else {
                                settingsNotifier.setOutputFolder(path);
                              }
                            }
                          },
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
