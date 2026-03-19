import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import 'package:gap/gap.dart';
import '../../providers/settings_provider.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';
import '../../design_system/components/app_toast.dart';
import '../settings_view.dart';

class AdvancedSettingsView extends ConsumerWidget {
  const AdvancedSettingsView({super.key});

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
          "Advanced Settings",
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
                        const SectionTitle("Advanced"),
                        SwitchTile(
                          title: "Adult Sites",
                          subtitle: "Enable support for age-restricted content",
                          value: settings.adultSitesEnabled,
                          onChanged: settingsNotifier.setAdultSitesEnabled,
                          icon: Icons.lock_open,
                        ),
                        SwitchTile(
                          title: "Clipboard Monitor",
                          subtitle: "Auto-detect links copied to clipboard",
                          value: settings.clipboardMonitorEnabled,
                          onChanged:
                              settingsNotifier.setClipboardMonitorEnabled,
                          icon: Icons.paste_rounded,
                        ),
                        SwitchTile(
                          title: "Minimize to Tray",
                          subtitle: "Keep running in background when closed",
                          value: settings.minimizeToTray,
                          onChanged: settingsNotifier.setMinimizeToTray,
                          icon: Icons.arrow_downward_rounded,
                        ),
                        SwitchTile(
                          title: "Do Not Disturb",
                          subtitle: "Silence all app & extension notifications",
                          value: settings.doNotDisturb,
                          onChanged: settingsNotifier.setDoNotDisturb,
                          icon: Icons.notifications_off_outlined,
                        ),
                        DropdownTile(
                          title: "Cookies from Browser",
                          value: settings.cookieBrowser,
                          options: [
                            "firefox",
                            "chrome",
                            "edge",
                            "brave",
                            "vivaldi",
                            "opera",
                          ],
                          onChanged: settingsNotifier.setCookieBrowser,
                          icon: Icons.browser_updated_rounded,
                        ),

                        const Gap(AppSpacing.l),
                        const SectionTitle("Data & History"),
                        ActionTile(
                          title: "Backup History",
                          subtitle:
                              "Export your download history to a JSON file",
                          icon: Icons.upload_file_rounded,
                          onTap: () async {
                            String? outputFile = await FilePicker.platform
                                .saveFile(
                                  dialogTitle: 'Save History Backup',
                                  fileName: 'history_backup.json',
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                );

                            if (outputFile != null) {
                              await ref
                                  .read(downloadListProvider.notifier)
                                  .exportHistory(outputFile);
                              if (context.mounted) {
                                AppToast.showSuccess(
                                  context,
                                  "History exported successfully",
                                );
                              }
                            }
                          },
                        ),
                        ActionTile(
                          title: "Restore History",
                          subtitle: "Import downloads from a backup file",
                          icon: Icons.file_download_rounded,
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                );

                            if (result != null) {
                              await ref
                                  .read(downloadListProvider.notifier)
                                  .importHistory(result.files.single.path!);
                              if (context.mounted) {
                                AppToast.showSuccess(
                                  context,
                                  "History restored successfully",
                                );
                              }
                            }
                          },
                        ),

                        const Gap(AppSpacing.l),
                        if (settings.adultSitesEnabled) ...[
                          SwitchTile(
                            title: "Use Tor Proxy",
                            subtitle:
                                "Bypass geo-blocks via Tor (127.0.0.1:9050)",
                            value: settings.useTorProxy,
                            onChanged: settingsNotifier.setUseTorProxy,
                            icon: Icons.security,
                          ),
                          ActionTile(
                            title: "Cookies File",
                            subtitle: settings.cookiesFilePath.isEmpty
                                ? "Select cookies.txt"
                                : settings.cookiesFilePath,
                            icon: Icons.cookie_outlined,
                            onTap: () async {
                              var result = await FilePicker.platform
                                  .pickFiles();
                              if (result != null) {
                                settingsNotifier.setCookiesFilePath(
                                  result.files.single.path!,
                                );
                              }
                            },
                            trailing: settings.cookiesFilePath.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                    ),
                                    onPressed: settingsNotifier.clearCookies,
                                    tooltip: "Clear cookies",
                                  )
                                : null,
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
