import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../design_system/foundation/colors.dart';
import '../design_system/foundation/spacing.dart';
import '../design_system/foundation/typography.dart';
import '../design_system/components/app_toast.dart';
import '../services/binary/binary_verifier.dart';
import '../providers/settings_provider.dart';
import 'settings/widgets/library_migration_dialog.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

Map<String, String> languageOptionLabels(AppLocalizations l10n) {
  return {
    'en': l10n.languageEnglish,
    'fr': l10n.languageFrench,
    'ar': l10n.languageArabic,
  };
}

Map<String, String> themeModeOptionLabels(AppLocalizations l10n) {
  return {
    'system': l10n.systemMode,
    'dark': l10n.darkMode,
    'light': l10n.lightMode,
  };
}

Map<String, String> qualityOptionLabels(AppLocalizations l10n) {
  return {
    'best': l10n.bestQuality,
    'manual': l10n.qualityManual,
    'manual+': l10n.qualityManualPlus,
  };
}

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  BinaryStatus? _ytDlpStatus;
  BinaryStatus? _ffmpegStatus;
  BinaryStatus? _aria2cStatus;
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true, // For glass effect if we wanted
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
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
          l10n.settings,
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
        iconTheme: IconThemeData(color: AppColors.of(context).textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xl + 20, // Add top padding for AppBar
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        SectionTitle(l10n.settingsGeneral),
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

                        const Gap(AppSpacing.xl),
                        SectionTitle(l10n.settingsOutput),
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

                        const Gap(AppSpacing.xl),
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
                        if (settings.adultSitesEnabled) ...[
                          SwitchTile(
                            title: l10n.useProxy,
                            subtitle: l10n.useProxyDesc,
                            value: settings.useTorProxy,
                            onChanged: settingsNotifier.setUseTorProxy,
                            icon: Icons.security,
                          ),
                          ActionTile(
                            title: l10n.cookiesFile,
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
                                      color: AppColors.of(context).error,
                                    ),
                                    onPressed: settingsNotifier.clearCookies,
                                    tooltip: "Clear cookies",
                                  )
                                : null,
                          ),
                        ],

                        const Gap(AppSpacing.xl),
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

                        const Gap(AppSpacing.xl),
                        SectionTitle(l10n.settingsSystem),
                        ActionTile(
                          title: l10n.checkDependencies,
                          subtitle: _isVerifying
                              ? l10n.verifyingBinaries
                              : l10n.checkDependenciesDesc,
                          icon: Icons.build_circle_outlined,
                          onTap: _isVerifying ? null : _verifyBinaries,
                        ),
                        if (_ytDlpStatus != null) ...[
                          const Gap(AppSpacing.s),
                          StatusTile("yt-dlp", _ytDlpStatus!),
                        ],
                        if (_ffmpegStatus != null)
                          StatusTile("ffmpeg", _ffmpegStatus!),
                        if (_aria2cStatus != null)
                          StatusTile("aria2c", _aria2cStatus!),
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

  Future<void> _verifyBinaries() async {
    setState(() => _isVerifying = true);
    final ytdlp = await BinaryVerifier.checkYtDlp();
    final ffmpeg = await BinaryVerifier.checkFfmpeg();
    final aria2c = await BinaryVerifier.checkAria2c();

    if (mounted) {
      setState(() {
        _ytDlpStatus = ytdlp;
        _ffmpegStatus = ffmpeg;
        _aria2cStatus = aria2c;
        _isVerifying = false;
      });
      AppToast.showSuccess(context, context.l10n.dependenciesVerified);
    }
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s,
        bottom: AppSpacing.m,
        left: 4, // Slight indentation for alignment
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final IconData icon;

  const SliderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.m,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.of(context).primary, size: 24),
              const Gap(AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.of(context).border.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  value.toInt().toString(),
                  style: AppTypography.mono.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.of(context).primary,
              inactiveTrackColor: AppColors.of(context).surfaceHighlight,
              thumbColor: Colors.white,
              overlayColor: AppColors.of(
                context,
              ).primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const SwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border.withAlpha(128)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.of(context).primary, size: 24),
          const Gap(AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.of(context).primary,
            activeThumbColor: Colors.white,
            inactiveThumbColor: AppColors.of(context).textDisabled,
            inactiveTrackColor: AppColors.of(context).surfaceHighlight,
          ),
        ],
      ),
    );
  }
}

class DropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final Map<String, String>? optionLabels;

  const DropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.icon,
    this.optionLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.of(context).border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.of(context).textSecondary, size: 24),
          const Gap(AppSpacing.m),
          Expanded(
            child: Text(
              title,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.of(context).background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              dropdownColor: AppColors.of(context).surface,
              style: AppTypography.body,
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.of(context).textSecondary,
              ),
              items: options
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(optionLabels?[e] ?? e),
                    ),
                  )
                  .toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Material(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),

        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.of(context).primary.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.of(context).border.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.of(context).textSecondary,
                  size: 24,
                ),
                const Gap(AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.of(context).textSecondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textDisabled,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusTile extends StatelessWidget {
  final String name;
  final BinaryStatus status;

  const StatusTile(this.name, this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.isInstalled
              ? AppColors.of(context).success.withValues(alpha: 0.3)
              : AppColors.of(context).error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isInstalled
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: status.isInstalled
                ? AppColors.of(context).success
                : AppColors.of(context).error,
            size: 20,
          ),
          const Gap(12),
          Flexible(
            child: Text(
              name,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.isInstalled
                    ? AppColors.of(context).success.withValues(alpha: 0.1)
                    : AppColors.of(context).error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.version ?? "Not found",
                textAlign: TextAlign.right,
                maxLines: 1,
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: status.isInstalled
                      ? AppColors.of(context).success
                      : AppColors.of(context).error,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
