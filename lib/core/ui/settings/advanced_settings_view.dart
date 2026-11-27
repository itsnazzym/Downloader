import 'dart:io';
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
import 'widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/core/ui/settings/widgets/paired_browsers_panel.dart';
import 'package:tapload/core/services/binary/binary_locator.dart';
import 'package:tapload/core/services/binary/binary_verifier.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/services/tor/tor_proxy_service.dart';
import 'widgets/settings_app_bar.dart';

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
    if (!PlatformInfo.isMobile) {
      _refreshGobirdStatus();
    } else {
      _gobirdStatusLoading = false;
    }
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
    final torState = ref.watch(torProxyServiceProvider);
    final torStatusMessage = switch (torState.status) {
      TorRuntimeStatus.disabled => l10n.torProxyStopped,
      TorRuntimeStatus.starting => l10n.torProxyStarting,
      TorRuntimeStatus.ready =>
        torState.usingExistingService
            ? l10n.torProxyExisting
            : l10n.torProxyReady,
      TorRuntimeStatus.failed =>
        '${l10n.torProxyFailed}: ${torState.message ?? ''}',
    };
    final colors = AppColors.of(context);

    final gobirdStatusSubtitle = _gobirdStatusLoading
        ? '…'
        : (_gobirdStatus?.isInstalled == true
              ? l10n.gobirdBinaryFound(_gobirdStatus!.version ?? 'ok')
              : l10n.gobirdBinaryMissing);

    return Scaffold(
      extendBodyBehindAppBar: !PlatformInfo.isMobile,
      backgroundColor: colors.background,
      appBar: buildSettingsAppBar(context, title: l10n.settingsAdvanced),
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
                        if (!PlatformInfo.isMobile) ...[
                          SectionTitle(l10n.settingsAdvanced),
                          // Desktop only: the phone has no clipboard watcher.
                          SwitchTile(
                            title: l10n.clipboardMonitor,
                            subtitle: l10n.clipboardMonitorDesc,
                            value: settings.clipboardMonitorEnabled,
                            onChanged:
                                settingsNotifier.setClipboardMonitorEnabled,
                            icon: Icons.paste_rounded,
                          ),
                        ],
                        SwitchTile(
                          title: l10n.doNotDisturb,
                          subtitle: l10n.doNotDisturbDesc,
                          value: settings.doNotDisturb,
                          onChanged: settingsNotifier.setDoNotDisturb,
                          icon: Icons.notifications_off_outlined,
                        ),
                        if (!PlatformInfo.isMobile) ...[
                          SwitchTile(
                            title: l10n.minimizeToTray,
                            subtitle: l10n.minimizeToTrayDesc,
                            value: settings.minimizeToTray,
                            onChanged: settingsNotifier.setMinimizeToTray,
                            icon: Icons.arrow_downward_rounded,
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
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: PairedBrowsersPanel(),
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.m,
                            ),
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
                        ],

                        const Gap(AppSpacing.l),
                        SectionTitle(l10n.dataAndHistory),
                        ActionTile(
                          title: l10n.backupHistory,
                          subtitle: l10n.exportHistoryDesc,
                          icon: Icons.upload_file_rounded,
                          onTap: () async {
                            final exporter = ref.read(
                              downloadListProvider.notifier,
                            );
                            String? outputFile;
                            if (PlatformInfo.isMobile) {
                              // On phones the picker writes the bytes itself.
                              final temp = File(
                                '${Directory.systemTemp.path}/history_backup.json',
                              );
                              await exporter.exportHistory(temp.path);
                              outputFile = await FilePicker.platform.saveFile(
                                dialogTitle: l10n.saveHistoryBackup,
                                fileName: 'history_backup.json',
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                                bytes: await temp.readAsBytes(),
                              );
                              await temp.delete();
                            } else {
                              outputFile = await FilePicker.platform.saveFile(
                                dialogTitle: l10n.saveHistoryBackup,
                                fileName: 'history_backup.json',
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                              );
                              if (outputFile != null) {
                                await exporter.exportHistory(outputFile);
                              }
                            }

                            if (outputFile != null) {
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

                        if (!PlatformInfo.isMobile) ...[
                          const Gap(AppSpacing.l),
                          // The Tor bundle only exists on Windows.
                          SwitchTile(
                            title: l10n.useProxy,
                            subtitle:
                                '${l10n.torBypassDesc}\n$torStatusMessage',
                            value: settings.useTorProxy,
                            onChanged: settingsNotifier.setUseTorProxy,
                            icon: Icons.security,
                          ),
                        ],
                        ActionTile(
                          title: l10n.cookiesFile,
                          subtitle: settings.cookiesFilePath.isEmpty
                              ? l10n.selectCookiesFile
                              : settings.cookiesFilePath,
                          icon: Icons.cookie_outlined,
                          onTap: () async {
                            var result = await FilePicker.platform.pickFiles();
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
