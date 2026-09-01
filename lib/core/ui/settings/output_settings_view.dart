import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../download/download_path_resolver.dart';

import 'widgets/storage_chart.dart';
import 'widgets/library_migration_dialog.dart';
import '../../providers/settings_provider.dart';
import '../settings_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

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
          l10n.settingsOutput,
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
                                  title: const Text('Modifier le dossier'),
                                  content: const Text(
                                    'Souhaitez-vous migrer automatiquement toutes vos vidéos et miniatures existantes vers ce nouveau dossier ?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text(
                                        'Changer uniquement le dossier',
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Migrer les fichiers'),
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
                          title: 'Migrer la bibliothèque',
                          subtitle:
                              'Déplacer toutes les vidéos et miniatures vers un autre disque/dossier',
                          icon: Icons.drive_file_move_rounded,
                          onTap: () =>
                              LibraryMigrationDialog.show(context, ref),
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
