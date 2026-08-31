import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import 'package:gap/gap.dart';
import '../../providers/settings_provider.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';
import '../../design_system/components/app_toast.dart';
import '../settings_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/binary_verifier.dart';

class AdvancedSettingsView extends ConsumerStatefulWidget {
  const AdvancedSettingsView({super.key});

  @override
  ConsumerState<AdvancedSettingsView> createState() =>
      _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends ConsumerState<AdvancedSettingsView> {
  BinaryStatus? _gobirdStatus;
  bool _gobirdStatusLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshGobirdStatus();
  }

  Future<void> _refreshGobirdStatus() async {
    setState(() => _gobirdStatusLoading = true);
    try {
      final status = await BinaryVerifier.checkGobird();
      if (!mounted) return;
      setState(() {
        _gobirdStatus = status;
        _gobirdStatusLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gobirdStatus = BinaryStatus(
          isInstalled: false,
          version: null,
          error: 'check_failed',
        );
        _gobirdStatusLoading = false;
      });
    }
  }

  Future<void> _onGobirdToggle(bool enabled) async {
    final l10n = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    if (!enabled) {
      notifier.setExperimentalXFeedGobirdEnabled(false);
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.experimentalXFeedConsentTitle),
        content: Text(l10n.experimentalXFeedConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.experimentalXFeedConsentConfirm),
          ),
        ],
      ),
    );
    if (accepted == true) {
      notifier.setExperimentalXFeedGobirdEnabled(true);
      try {
        await BinaryLocator().ensureGobirdStaged();
      } catch (_) {
        // Optional binary; status refresh below reports missing.
      }
      await _refreshGobirdStatus();
      if (!mounted) return;
      if (_gobirdStatus?.isInstalled != true) {
        AppToast.showError(context, l10n.gobirdBinaryMissing);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final colors = AppColors.of(context);

    final gobirdStatusSubtitle = _gobirdStatusLoading
        ? '…'
        : (_gobirdStatus?.isInstalled == true
              ? l10n.gobirdBinaryFound(_gobirdStatus!.version ?? 'ok')
              : l10n.gobirdBinaryMissing);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: const SizedBox(),
        backgroundColor: colors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          l10n.settingsAdvanced,
          style: AppTypography.h3.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: colors.border.withValues(alpha: 0.5),
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
                        SectionTitle(l10n.settingsAdvanced),
                        SwitchTile(
                          title: l10n.adultSites,
                          subtitle: l10n.adultSitesDesc,
                          value: settings.adultSitesEnabled,
                          onChanged: settingsNotifier.setAdultSitesEnabled,
                          icon: Icons.lock_open,
                        ),
                        SwitchTile(
                          title: l10n.clipboardMonitor,
                          subtitle: l10n.clipboardMonitorDesc,
                          value: settings.clipboardMonitorEnabled,
                          onChanged:
                              settingsNotifier.setClipboardMonitorEnabled,
                          icon: Icons.paste_rounded,
                        ),
                        SwitchTile(
                          title: l10n.minimizeToTray,
                          subtitle: l10n.minimizeToTrayDesc,
                          value: settings.minimizeToTray,
                          onChanged: settingsNotifier.setMinimizeToTray,
                          icon: Icons.arrow_downward_rounded,
                        ),
                        SwitchTile(
                          title: l10n.doNotDisturb,
                          subtitle: l10n.doNotDisturbDesc,
                          value: settings.doNotDisturb,
                          onChanged: settingsNotifier.setDoNotDisturb,
                          icon: Icons.notifications_off_outlined,
                        ),
                        DropdownTile(
                          title: l10n.cookiesFromBrowser,
                          value: settings.cookieBrowser,
                          options: const [
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
                        ActionTile(
                          title: l10n.extensionApiToken,
                          subtitle: settings.apiToken.isEmpty
                              ? l10n.generatedOnFirstLaunch
                              : settings.apiToken,
                          icon: Icons.vpn_key_outlined,
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: settings.apiToken),
                            );
                            if (context.mounted) {
                              AppToast.showSuccess(
                                context,
                                l10n.tokenCopiedHint,
                              );
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: l10n.copyToken,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: settings.apiToken),
                              );
                              if (context.mounted) {
                                AppToast.showSuccess(context, l10n.tokenCopied);
                              }
                            },
                          ),
                        ),
                        ActionTile(
                          title: l10n.localServerPort,
                          subtitle: l10n.serverPortRestartHint(
                            settings.serverPort,
                          ),
                          icon: Icons.lan_outlined,
                          onTap: () async {
                            final controller = TextEditingController(
                              text: settings.serverPort.toString(),
                            );
                            final next = await showDialog<int>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(l10n.localServerPort),
                                content: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: '6969',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(l10n.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final parsed = int.tryParse(
                                        controller.text.trim(),
                                      );
                                      Navigator.pop(context, parsed);
                                    },
                                    child: Text(l10n.save),
                                  ),
                                ],
                              ),
                            );
                            if (next != null && next > 0 && next < 65536) {
                              settingsNotifier.setServerPort(next);
                              if (context.mounted) {
                                AppToast.showSuccess(
                                  context,
                                  l10n.portSavedRestart,
                                );
                              }
                            }
                          },
                        ),

                        const Gap(AppSpacing.l),
                        SectionTitle(l10n.experimentalXFeedSection),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.m),
                          child: Text(
                            l10n.experimentalXFeedWarning,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.warning,
                            ),
                          ),
                        ),
                        SwitchTile(
                          title: l10n.experimentalXFeedGobird,
                          subtitle: l10n.experimentalXFeedGobirdDesc,
                          value: settings.experimentalXFeedGobirdEnabled,
                          onChanged: _onGobirdToggle,
                          icon: Icons.science_outlined,
                        ),
                        DropdownTile(
                          title: l10n.gobirdBrowser,
                          value: settings.gobirdBrowser,
                          options: const ['chrome', 'firefox'],
                          onChanged: settingsNotifier.setGobirdBrowser,
                          icon: Icons.web_asset,
                        ),
                        ActionTile(
                          title: l10n.gobirdBinaryStatus,
                          subtitle: gobirdStatusSubtitle,
                          icon: Icons.memory_outlined,
                          onTap: _refreshGobirdStatus,
                          trailing: settings.experimentalXFeedGobirdEnabled
                              ? TextButton(
                                  onPressed: () {
                                    settingsNotifier
                                        .setExperimentalXFeedGobirdEnabled(
                                          false,
                                        );
                                  },
                                  child: Text(l10n.gobirdDisableNow),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _refreshGobirdStatus,
                                ),
                        ),

                        const Gap(AppSpacing.l),
                        SectionTitle(l10n.dataAndHistory),
                        ActionTile(
                          title: l10n.backupHistory,
                          subtitle: l10n.exportHistoryDesc,
                          icon: Icons.upload_file_rounded,
                          onTap: () async {
                            String? outputFile = await FilePicker.platform
                                .saveFile(
                                  dialogTitle: l10n.saveHistoryBackup,
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
                                  l10n.historyExported,
                                );
                              }
                            }
                          },
                        ),
                        ActionTile(
                          title: l10n.restoreHistory,
                          subtitle: l10n.restoreHistoryDesc,
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
                                  l10n.historyRestored,
                                );
                              }
                            }
                          },
                        ),

                        const Gap(AppSpacing.l),
                        if (settings.adultSitesEnabled) ...[
                          SwitchTile(
                            title: l10n.useProxy,
                            subtitle: l10n.torBypassDesc,
                            value: settings.useTorProxy,
                            onChanged: settingsNotifier.setUseTorProxy,
                            icon: Icons.security,
                          ),
                          ActionTile(
                            title: l10n.cookiesFile,
                            subtitle: settings.cookiesFilePath.isEmpty
                                ? l10n.selectCookiesFile
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
                                      color: colors.error,
                                    ),
                                    onPressed: settingsNotifier.clearCookies,
                                    tooltip: l10n.clearCookies,
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
