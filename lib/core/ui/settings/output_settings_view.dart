import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';

import 'widgets/storage_chart.dart';
import '../../providers/settings_provider.dart';
import '../settings_view.dart';

class OutputSettingsView extends ConsumerWidget {
  const OutputSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: SizedBox(),
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "Output Settings",
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border.withValues(alpha: 0.5),
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
                        const SectionTitle("Output"),
                        StorageChart(path: settings.outputFolder),
                        const Gap(AppSpacing.l),
                        ActionTile(
                          title: "Download Folder",
                          subtitle: settings.outputFolder.isEmpty
                              ? "Select folder..."
                              : settings.outputFolder,
                          icon: Icons.folder_open_rounded,
                          onTap: () async {
                            String? path = await FilePicker.platform
                                .getDirectoryPath();
                            if (path != null) {
                              settingsNotifier.setOutputFolder(path);
                            }
                          },
                        ),
                        DropdownTile(
                          title: "Format",
                          value: settings.outputFormat,
                          options: ["mp4", "mkv", "webm"],
                          onChanged: settingsNotifier.setOutputFormat,
                          icon: Icons.video_file,
                        ),
                        SwitchTile(
                          title: "Organize by Site",
                          subtitle: "Create subfolders like Downloads/YouTube/",
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
