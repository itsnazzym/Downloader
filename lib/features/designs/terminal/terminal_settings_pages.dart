import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/download/download_path_resolver.dart';
import 'package:modern_downloader/core/plugins/builtin/smart_organizer_plugin.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/plugins/feature_catalog.dart';
import 'package:modern_downloader/core/plugins/plugin_manager.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/browser_extension_installer.dart';
import 'package:modern_downloader/core/services/disk_space_service.dart';
import 'package:modern_downloader/core/services/folder_size_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/extension_install_guide_dialog.dart';
import 'package:modern_downloader/core/ui/settings/widgets/library_migration_dialog.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/reorganize_library_dialog.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_disk_space/universal_disk_space.dart';
import 'package:uuid/uuid.dart';

import 'terminal_library.dart' show compactBytes;
import 'terminal_states.dart';
import 'terminal_widgets.dart';

/// The settings sections Terminal draws itself because today's views paint
/// their own cards and pills: same settings, providers and actions, drawn as
/// config lines (the shared tiles they reuse go through the skin).

/// The body of a config file section: lines on the panel, scrolling.
class _Body extends StatelessWidget {
  const _Body({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
    children: children,
  );
}

/// `## title` and its `# hint`, between config blocks.
class _Head extends StatelessWidget {
  const _Head(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${title.toLowerCase()}]',
            style: tm(colors.primary, weight: FontWeight.w700),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text('# $hint', style: tm(colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

// ── output ──────────────────────────────────────────────────────────────────

class TerminalOutputPage extends ConsumerWidget {
  const TerminalOutputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final path =
        DownloadPathResolver.resolve(
          settingsOutputFolder: s.outputFolder,
          itemFolders: const [],
          userProfile: Platform.environment['USERPROFILE'],
        ) ??
        '';
    return _Body(
      children: [
        SectionTitle(l10n.settingsOutput),
        _Storage(path: path),
        ActionTile(
          key: OnboardingTargets.outputFolder,
          title: l10n.downloadFolder,
          subtitle: s.outputFolder.isEmpty ? l10n.selectFolder : s.outputFolder,
          icon: Icons.folder_open_rounded,
          onTap: () => pickOutputFolder(context, ref),
        ),
        ActionTile(
          title: l10n.settingsOutputMigrateLibraryTitle,
          subtitle: l10n.settingsOutputMigrateLibraryDesc,
          icon: Icons.drive_file_move_rounded,
          onTap: () => LibraryMigrationDialog.show(context, ref),
        ),
        ActionTile(
          title: l10n.settingsOutputReorganizeTitle,
          subtitle: l10n.settingsOutputReorganizeDesc,
          icon: Icons.folder_shared_rounded,
          onTap: () => ReorganizeLibraryDialog.show(context),
        ),
        DropdownTile(
          title: l10n.formatLabel,
          value: s.outputFormat,
          options: const ['mp4', 'mkv', 'webm'],
          onChanged: n.setOutputFormat,
          icon: Icons.video_file,
        ),
        SwitchTile(
          title: l10n.organizeBySite,
          subtitle: l10n.organizeBySiteDesc,
          value: s.organizeBySite,
          onChanged: n.setOrganizeBySite,
          icon: Icons.folder_copy_rounded,
        ),
        SwitchTile(
          title: l10n.organizeByCreator,
          subtitle: l10n.organizeByCreatorDesc,
          value: s.organizeByCreator,
          onChanged: n.setOrganizeByCreator,
          icon: Icons.person_rounded,
        ),
      ],
    );
  }
}

/// `df -h` for the output drive and `du` for the folder, as today's storage
/// chart measures them (cached folder scan, `r` rescans).
class _Storage extends StatefulWidget {
  const _Storage({required this.path});

  final String path;

  @override
  State<_Storage> createState() => _StorageState();
}

class _StorageState extends State<_Storage> {
  final _folders = FolderSizeService();
  int? _total;
  int? _free;
  bool _diskLoading = true;
  FolderSizeSnapshot? _snapshot;
  bool _folderError = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _load(force: false);
  }

  @override
  void didUpdateWidget(covariant _Storage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _snapshot = null;
      _folderError = false;
      _load(force: false);
    }
  }

  // Same lookup as today's chart: the disk holding the folder, else the
  // free-space service with a nominal total.
  Future<(int, int)> _disk(String path) async {
    try {
      final space = DiskSpace();
      await space.scan();
      final win = Platform.isWindows;
      final target = win ? path.replaceAll('/', '\\') : path;
      Disk? hit;
      for (final d in space.disks) {
        final dp = win ? d.devicePath.replaceAll('/', '\\') : d.devicePath;
        if (target.toUpperCase().startsWith(dp.toUpperCase())) {
          hit = d;
          break;
        }
      }
      hit ??= space.disks.isNotEmpty ? space.disks.first : null;
      if (hit != null && hit.totalSize > 0) {
        return (hit.totalSize, hit.availableSpace);
      }
    } catch (e) {
      debugPrint('universal_disk_space scan failed: $e');
    }
    final free =
        await DiskSpaceService.getFreeDiskSpace() ?? 10 * 1024 * 1024 * 1024;
    return (math.max(free * 2, 64 * 1024 * 1024 * 1024), free);
  }

  Future<void> _load({required bool force}) async {
    final path = widget.path;
    unawaited(
      _disk(path)
          .then((d) {
            if (!mounted) return;
            setState(() {
              _total = d.$1;
              _free = d.$2;
              _diskLoading = false;
            });
          })
          .catchError((Object _) {
            if (mounted) setState(() => _diskLoading = false);
          }),
    );
    if (!force) {
      final peeked = _folders.peek(path);
      if (peeked != null) {
        setState(() => _snapshot = peeked);
        if (_folders.isFresh(peeked)) return;
      }
    }
    setState(() => _scanning = true);
    try {
      final r = await _folders.getSize(path, force: force);
      if (!mounted || widget.path != path) return;
      setState(() {
        _scanning = false;
        switch (r) {
          case FolderSizeOk(:final snapshot):
            _snapshot = snapshot;
            _folderError = false;
          case FolderSizeError():
            _folderError = true;
        }
      });
    } catch (_) {
      if (!mounted || widget.path != path) return;
      setState(() {
        _scanning = false;
        if (_snapshot == null) _folderError = true;
      });
    }
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final total = _total;
    final free = _free;
    final snap = _snapshot;
    final caption = _folderError
        ? l10n.storageScanError
        : snap == null && _scanning
        ? l10n.storageScanInProgress
        : snap != null && _scanning
        ? l10n.storageScanCached
        : snap != null
        ? l10n.storageLastScanned(_hhmm(snap.scannedAt))
        : null;
    String pct(int part, int of) =>
        of <= 0 ? '0.0' : (part / of * 100).toStringAsFixed(1);
    Widget row(String label, int bytes, int of, Color color) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: tm(colors.textSecondary)),
          ),
          Expanded(
            child: TSeg(
              value: of <= 0 ? 0 : bytes / of,
              height: 8,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              '${compactBytes(bytes)} ${pct(bytes, of)}%',
              textAlign: TextAlign.right,
              style: tm(colors.textPrimary),
            ),
          ),
        ],
      ),
    );

    final Widget body;
    if (_diskLoading && total == null) {
      body = TTyped(
        '# ${l10n.terminalLoading}',
        style: tm(colors.textDisabled),
        cursor: true,
      );
    } else if (total == null || free == null) {
      body = Text(
        '# ${l10n.storageInfoUnavailable}',
        style: tm(colors.textDisabled),
      );
    } else {
      final used = math.max(0, total - free);
      final folder = snap == null ? 0 : math.min(snap.totalBytes, used);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snap != null) ...[
            row(l10n.storageFolder, folder, total, colors.warning),
            row(
              l10n.storageOtherUsed,
              math.max(0, used - folder),
              total,
              colors.primary,
            ),
          ] else
            row(l10n.storageUsed, used, total, colors.primary),
          row(l10n.storageFree, free, total, colors.textSecondary),
          const SizedBox(height: 6),
          Text(
            '# ${l10n.storageTotalLabel(compactBytes(total))}',
            style: tm(colors.textDisabled),
          ),
          if (snap != null) ...[
            const SizedBox(height: 8),
            Text(
              '${compactBytes(snap.totalBytes)} · ${l10n.storageFolderOfUsed(pct(snap.totalBytes, used))} · ${l10n.storageFileCount(snap.fileCount)}',
              style: tm(colors.textPrimary),
            ),
            row(
              l10n.storageTypeVideo,
              snap.videoBytes,
              snap.totalBytes,
              colors.primary,
            ),
            row(
              l10n.storageTypeAudio,
              snap.audioBytes,
              snap.totalBytes,
              colors.warning,
            ),
            row(
              l10n.storageTypeOther,
              snap.otherBytes,
              snap.totalBytes,
              colors.textSecondary,
            ),
            if (snap.topSubfolders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '## ${l10n.storageTopSubfolders.toLowerCase()}',
                style: tm(colors.textDisabled),
              ),
              for (final e in snap.topSubfolders)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.name}/',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tm(colors.textSecondary),
                        ),
                      ),
                      Text(
                        compactBytes(e.bytes),
                        style: tm(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ] else if (_folderError)
            Text('# ${l10n.storageScanError}', style: tm(colors.error)),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: TPanel(
        color: colors.background,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '\$ df -h  # ${l10n.storageUsage.toLowerCase()}',
                    style: tm(colors.textSecondary),
                  ),
                ),
                if (caption != null) ...[
                  Text(caption, style: tm(colors.textDisabled)),
                  const SizedBox(width: 10),
                ],
                TButton(
                  label: 'r',
                  square: true,
                  height: 26,
                  tooltip: l10n.storageUsage,
                  onTap: _scanning && snap == null
                      ? null
                      : () => _load(force: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

// ── appearance ──────────────────────────────────────────────────────────────

const _accents = [
  Color(0xFF0D9488),
  Color(0xFF0A84FF),
  Color(0xFF0EA5E9),
  Color(0xFF22C55E),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFC026D3),
  Color(0xFF6366F1),
  Color(0xFFEAB308),
  Color(0xFFF43F5E),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];

class TerminalAppearancePage extends ConsumerWidget {
  const TerminalAppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final accent = Color(s.customAccentColor);
    final hex = accent
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return _Body(
      children: [
        SectionTitle(l10n.theme),
        // Only the iOS look follows light/dark; the designs and OLED don't.
        if (DesignSpec.forId(
              ThemePresets.migrateId(s.themePreset),
            ).brightness ==
            null)
          DropdownTile(
            title: l10n.theme,
            value: s.themeMode,
            options: const ['system', 'dark', 'light'],
            optionLabels: themeModeOptionLabels(l10n),
            onChanged: n.setThemeMode,
            icon: Icons.brightness_4_rounded,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = ((c.maxWidth + 8) / 120).floor().clamp(1, 8);
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in ThemePresets.all)
                    SizedBox(
                      width: w,
                      child: TDesignThumb(
                        id: p.id,
                        selected: p.id == s.themePreset,
                        onTap: () => n.setThemePreset(p.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (s.themePreset != 'oled') ...[
          SectionTitle(l10n.accentColor),
          TConfLine(
            body: TKeyValue(l10n.currentAccent, '#$hex'),
            control: Container(width: 22, height: 22, color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _accents)
                  _Swatch(
                    color: c,
                    selected: c.toARGB32() == accent.toARGB32(),
                    onTap: () => n.setCustomAccentColor(c.toARGB32()),
                    border: colors.textPrimary,
                  ),
              ],
            ),
          ),
        ],
        SectionTitle(l10n.language),
        DropdownTile(
          title: l10n.language,
          value: s.locale,
          options: const ['en', 'fr', 'ar'],
          optionLabels: languageOptionLabels(l10n),
          onChanged: n.setLocale,
          icon: Icons.language_rounded,
        ),
      ],
    );
  }
}

/// A square colour cell: the picked one is outlined and marked `x`.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.border,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return Semantics(
      button: true,
      selected: selected,
      label: '#$hex',
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: tMotion(context),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: selected ? border : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? Text('x', style: tm(Colors.white, weight: FontWeight.w700))
              : null,
        ),
      ),
    );
  }
}

/// `.th`: a mini page in the design's own colours, `[x] Name`.
class TDesignThumb extends StatefulWidget {
  const TDesignThumb({
    super.key,
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<TDesignThumb> createState() => _TDesignThumbState();
}

class _TDesignThumbState extends State<TDesignThumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = ThemePresets.getById(widget.id);
    final on = widget.selected;
    final fg = on || _hover ? colors.textPrimary : colors.textSecondary;
    Widget bar(double f, Color c) => FractionallySizedBox(
      widthFactor: f,
      alignment: AlignmentDirectional.centerStart,
      child: Container(height: 4, color: c),
    );
    return Semantics(
      selected: on,
      button: true,
      label: p.name,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        focusColor: colors.primary.withValues(alpha: 0.2),
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: tMotion(context),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(
              color: on
                  ? colors.primary
                  : (_hover ? colors.textSecondary : colors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.all(8),
                color: p.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(0.4, p.primary),
                    const SizedBox(height: 5),
                    bar(0.75, p.surfaceHighlight),
                    const SizedBox(height: 5),
                    bar(0.55, p.surfaceHighlight),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: on ? '[x]' : '[ ]',
                      style: tm(colors.primary, size: 12),
                    ),
                    TextSpan(text: ' ${p.name}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(fg, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── performance ─────────────────────────────────────────────────────────────

class TerminalPerformancePage extends ConsumerWidget {
  const TerminalPerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return _Body(
      children: [
        SectionTitle(l10n.settingsPerformance),
        SliderTile(
          title: l10n.simultaneousDownloads,
          subtitle: l10n.simultaneousDownloadsDesc,
          value: s.maxConcurrent.toDouble().clamp(1.0, 60.0),
          min: 1,
          max: 60,
          divisions: 59,
          onChanged: (v) => n.setMaxConcurrent(v.toInt()),
          icon: Icons.layers_outlined,
        ),
        SliderTile(
          title: l10n.threadsPerDownload,
          subtitle: l10n.threadsPerDownloadDesc,
          value: s.concurrentFragments.toDouble().clamp(1.0, 64.0),
          min: 1,
          max: 64,
          divisions: 63,
          onChanged: (v) => n.setConcurrentFragments(v.toInt()),
          icon: Icons.bolt_rounded,
        ),
        SwitchTile(
          title: l10n.maxSpeedMode,
          subtitle: l10n.maxSpeedModeDesc,
          value: s.maxSpeedMode,
          onChanged: n.setMaxSpeedMode,
          icon: Icons.rocket_launch_rounded,
        ),
        SwitchTile(
          title: l10n.reduceEffects,
          subtitle: l10n.reduceEffectsDesc,
          value: s.reduceEffects,
          onChanged: n.setReduceEffects,
          icon: Icons.blur_off_rounded,
        ),
      ],
    );
  }
}

// ── plugins ─────────────────────────────────────────────────────────────────

class TerminalPluginsPage extends ConsumerWidget {
  const TerminalPluginsPage({super.key, this.pluginId});

  /// A plugin a web page asked to install (`?plugin=`).
  final String? pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final lifecycle = ref.watch(pluginManagerProvider);
    final catalog = ref.watch(featureCatalogProvider);
    final activation = ref.watch(featureActivationProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final platform = Platform.isAndroid ? 'android' : 'windows';
    if (!lifecycle.isLoaded) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          '# ${l10n.terminalLoading}',
          style: tm(colors.textDisabled),
        ),
      );
    }
    final request = pluginId == null ? null : catalog.byId[pluginId];
    return _Body(
      children: [
        if (request != null && request.supportsPlatform(platform))
          _InstallRequest(plugin: request, locale: locale),
        _Head(l10n.pluginFeaturesTitle, hint: l10n.pluginFeaturesHint),
        for (final m in catalog.modules)
          if (m.supportsPlatform(platform))
            TConfLine(
              comment: m.descriptionFor(locale),
              onTap: m.isCore
                  ? null
                  : () => ref
                        .read(featureActivationProvider.notifier)
                        .setEnabled(m.id, !activation.isEnabled(m)),
              body: TKeyValue(m.nameFor(locale), '${activation.isEnabled(m)}'),
              control: m.isCore
                  ? Text(
                      '[${l10n.pluginRequired.toLowerCase()}]',
                      style: tm(colors.primary),
                    )
                  : TSwitch(
                      value: activation.isEnabled(m),
                      label: m.nameFor(locale),
                      onChanged: (v) => ref
                          .read(featureActivationProvider.notifier)
                          .setEnabled(m.id, v),
                    ),
            ),
        _Head(l10n.pluginsSectionTitle, hint: l10n.pluginsSectionHint),
        if (lifecycle.plugins.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Text(
              '# ${l10n.noPluginsInstalled}',
              style: tm(colors.textDisabled),
            ),
          )
        else
          for (final e in lifecycle.plugins)
            _HookLine(
              entry: e,
              descriptor: catalog.byId[e.plugin.id],
              locale: locale,
            ),
        if (!ref.watch(showcaseModeProvider))
          KeyedSubtree(
            key: OnboardingTargets.extensions,
            child: const _Extensions(),
          ),
      ],
    );
  }
}

class _HookLine extends ConsumerWidget {
  const _HookLine({
    required this.entry,
    required this.descriptor,
    required this.locale,
  });

  final PluginEntry entry;
  final FeaturePluginDescriptor? descriptor;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final name = descriptor?.nameFor(locale) ?? entry.plugin.name;
    void toggle(bool v) => ref
        .read(pluginManagerProvider.notifier)
        .togglePlugin(entry.plugin.id, v);
    return TConfLine(
      comment: [
        descriptor?.descriptionFor(locale) ?? entry.plugin.description,
        if (entry.error != null) l10n.pluginError('${entry.error}'),
      ].join(' · '),
      onTap: () => toggle(!entry.isEnabled),
      body: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$name = '),
            TextSpan(text: '${entry.isEnabled}', style: tm(colors.warning)),
            TextSpan(
              text:
                  '  v${entry.plugin.version}'
                  '${entry.plugin.isBuiltIn ? ' · ${l10n.builtIn.toLowerCase()}' : ''}',
              style: tm(colors.textDisabled),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tm(entry.error != null ? colors.error : colors.textPrimary),
      ),
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.plugin.id == 'builtin_smart_organizer') ...[
            TButton(
              keyHint: 'm',
              label: l10n.configurePlugin,
              height: 26,
              onTap: () => context.push('/settings/smart_organizer'),
            ),
            const SizedBox(width: 8),
          ],
          TSwitch(value: entry.isEnabled, onChanged: toggle, label: name),
        ],
      ),
    );
  }
}

/// A web page asked for a plugin: what it is and the one step to get it.
class _InstallRequest extends ConsumerWidget {
  const _InstallRequest({required this.plugin, required this.locale});

  final FeaturePluginDescriptor plugin;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final lifecycle = ref.watch(pluginManagerProvider);
    final enabled = plugin.isModule
        ? ref.watch(featureActivationProvider).isEnabled(plugin)
        : lifecycle.plugins.any((e) => e.plugin.id == plugin.id && e.isEnabled);
    VoidCallback? onTap;
    var label = l10n.pluginActivate;
    if (plugin.isModule) {
      if (enabled) {
        label = l10n.pluginOpen;
        onTap = () => context.go(plugin.route);
      } else {
        onTap = () async {
          await ref
              .read(featureActivationProvider.notifier)
              .setEnabled(plugin.id, true);
          if (context.mounted) context.go(plugin.route);
        };
      }
    } else if (plugin.isDownloadHook) {
      if (enabled) {
        label = l10n.configurePlugin;
        onTap = () => context.go('/settings/plugins');
      } else if (lifecycle.isLoaded) {
        onTap = () => ref
            .read(pluginManagerProvider.notifier)
            .togglePlugin(plugin.id, true);
      }
    } else if (plugin.isExternalExtension) {
      final chrome = plugin.id == 'chrome_extension';
      label = chrome ? l10n.installInChrome : l10n.installInFirefox;
      onTap = () => ExtensionInstallGuideDialog.show(
        context,
        chrome
            ? ExtensionInstallFlow.chromeInstall
            : ExtensionInstallFlow.firefoxInstall,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: TPanel(
        accentLeft: colors.primary,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '## ${plugin.nameFor(locale)}',
              style: tm(colors.primary, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '# ${plugin.isExternalExtension ? l10n.pluginExternalHint : l10n.pluginWebRequest}',
              style: tm(colors.textSecondary),
            ),
            const SizedBox(height: 10),
            TButton(label: label, kind: TButtonKind.primary, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// Browser extensions: Chrome and Firefox flows, and the API token.
class _Extensions extends ConsumerWidget {
  const _Extensions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final token = ref.watch(settingsProvider.select((s) => s.apiToken));
    Widget browser(
      String title,
      String steps,
      String primary,
      ExtensionInstallFlow install,
      String secondary,
      ExtensionInstallFlow other,
    ) => TConfLine(
      comment: steps,
      commentMaxLines: 4,
      body: Text(
        '› $title',
        style: tm(colors.textPrimary, weight: FontWeight.w600),
      ),
      control: Wrap(
        spacing: 6,
        children: [
          TButton(
            label: primary,
            height: 26,
            kind: TButtonKind.primary,
            onTap: () => ExtensionInstallGuideDialog.show(context, install),
          ),
          TButton(
            label: secondary,
            height: 26,
            onTap: () => ExtensionInstallGuideDialog.show(context, other),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(l10n.browserExtensionsTitle, hint: l10n.browserExtensionsHint),
        browser(
          l10n.chromeExtensionTitle,
          l10n.chromeExtensionSteps,
          l10n.installInChrome,
          ExtensionInstallFlow.chromeInstall,
          l10n.downloadExtensionZip,
          ExtensionInstallFlow.chromeZip,
        ),
        browser(
          l10n.firefoxExtensionTitle,
          l10n.firefoxExtensionSteps,
          l10n.installInFirefox,
          ExtensionInstallFlow.firefoxInstall,
          l10n.firefoxManualInstall,
          ExtensionInstallFlow.firefoxManual,
        ),
        TConfLine(
          body: TKeyValue(
            l10n.extensionApiToken,
            token.isEmpty ? l10n.generatedOnFirstLaunch : token,
          ),
          control: TButton(
            label: l10n.copyToken,
            height: 26,
            onTap: token.isEmpty
                ? null
                : () async {
                    try {
                      await BrowserExtensionInstaller.copyPath(token);
                      if (context.mounted) {
                        AppToast.showSuccess(context, l10n.tokenCopiedHint);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppToast.showError(
                          context,
                          l10n.extensionInstallFailed,
                        );
                      }
                    }
                  },
          ),
        ),
      ],
    );
  }
}

// ── smart organization ──────────────────────────────────────────────────────

/// Rules and smart guess, stored under the same preference keys as today's
/// view (the organizer plugin reads them when it files a download).
class TerminalSmartPage extends ConsumerStatefulWidget {
  const TerminalSmartPage({super.key});

  @override
  ConsumerState<TerminalSmartPage> createState() => _SmartPageState();
}

class _SmartPageState extends ConsumerState<TerminalSmartPage> {
  static const _rulesKey = 'smart_organizer_rules';
  static const _guessKey = 'smart_organizer_smart_guess';
  List<OrganizationRule> _rules = [];
  bool _guess = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_rulesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _rules = [for (final r in raw) OrganizationRule.fromJson(jsonDecode(r))];
      _guess = prefs.getBool(_guessKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_rulesKey, [
      for (final r in _rules) jsonEncode(r.toJson()),
    ]);
    await prefs.setBool(_guessKey, _guess);
  }

  Future<void> _put(OrganizationRule rule) async {
    setState(() {
      final i = _rules.indexWhere((r) => r.id == rule.id);
      if (i >= 0) {
        _rules[i] = rule;
      } else {
        _rules.add(rule);
      }
    });
    await _save();
  }

  Future<void> _remove(String id) async {
    setState(() => _rules.removeWhere((r) => r.id == id));
    await _save();
  }

  Future<void> _addPresets() async {
    for (final p in SmartOrganizerPlugin.defaultPresets) {
      if (!_rules.any((r) => r.id == p.id)) _rules.add(p);
    }
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _edit([OrganizationRule? rule]) async {
    final next = await showDialog<OrganizationRule>(
      context: context,
      builder: (_) => _RuleDialog(rule: rule),
    );
    if (next != null) await _put(next);
  }

  Future<void> _organizeFolder() async {
    final l10n = context.l10n;
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    final entry = ref
        .read(pluginManagerProvider)
        .plugins
        .firstWhere(
          (p) => p.plugin is SmartOrganizerPlugin,
          orElse: () => throw Exception('Smart Organizer plugin not found'),
        );
    final plugin = entry.plugin as SmartOrganizerPlugin;
    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => TDialog(
          title: l10n.organizeExistingFiles,
          body: const _Working(),
          actions: const [],
        ),
      ),
    );
    var moved = 0;
    var total = 0;
    try {
      await for (final e in dir.list()) {
        if (e is File) {
          total++;
          if (await plugin.organizeFile(e) != null) moved++;
        }
      }
    } catch (e) {
      debugPrint('Error during bulk organization: $e');
    } finally {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.organizationCompleteDetail(total, moved)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          '# ${l10n.terminalLoading}',
          style: tm(colors.textDisabled),
        ),
      );
    }
    return _Body(
      children: [
        SectionTitle(l10n.smartOrganization),
        TConfLine(
          comment: l10n.smartGuessDesc,
          onTap: () {
            setState(() => _guess = !_guess);
            _save();
          },
          body: TKeyValue(l10n.smartGuessTitle, '$_guess'),
          control: TSwitch(
            value: _guess,
            label: l10n.smartGuessTitle,
            onChanged: (v) {
              setState(() => _guess = v);
              _save();
            },
          ),
        ),
        if (_guess)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 6),
            child: Text(
              '# ${l10n.aiModeOffline}',
              style: tm(colors.textSecondary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '[${l10n.customRules.toLowerCase()}]',
                  style: tm(colors.primary, weight: FontWeight.w700),
                ),
              ),
              TButton(
                label: l10n.settingsSmartRecommendedRules,
                height: 26,
                onTap: _addPresets,
              ),
              const SizedBox(width: 6),
              TButton(
                keyHint: '+',
                label: l10n.addRule,
                height: 26,
                kind: TButtonKind.primary,
                onTap: _edit,
              ),
            ],
          ),
        ),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Text(
              '# ${l10n.noRulesDefined}',
              style: tm(colors.textDisabled),
            ),
          ),
        for (final r in _rules)
          TConfLine(
            comment:
                '${r.isRegex ? 're' : 'txt'}  ${r.pattern} -> ${r.targetFolder}',
            onTap: () => _edit(r),
            body: Text(
              r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(
                r.active ? colors.textPrimary : colors.textDisabled,
                weight: FontWeight.w600,
              ),
            ),
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TSwitch(
                  value: r.active,
                  label: r.name,
                  onChanged: (v) => _put(
                    OrganizationRule(
                      id: r.id,
                      name: r.name,
                      pattern: r.pattern,
                      isRegex: r.isRegex,
                      targetFolder: r.targetFolder,
                      active: v,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TButton(
                  label: '×',
                  square: true,
                  height: 26,
                  kind: TButtonKind.danger,
                  tooltip: l10n.delete,
                  onTap: () => _remove(r.id),
                ),
              ],
            ),
          ),
        SectionTitle(l10n.toolsSection),
        ActionTile(
          title: l10n.organizeExistingFiles,
          subtitle: l10n.organizeExistingFilesDesc,
          icon: Icons.drive_file_move,
          onTap: _organizeFolder,
        ),
      ],
    );
  }
}

class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 24, child: _Indeterminate());
}

/// A segmented bar filling and emptying while the folder is filed.
class _Indeterminate extends StatefulWidget {
  const _Indeterminate();

  @override
  State<_Indeterminate> createState() => _IndeterminateState();
}

class _IndeterminateState extends State<_Indeterminate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Center(child: TSeg(value: _c.value, height: 10)),
  );
}

/// New or edited rule: name, pattern (text or regex), target folder, active.
class _RuleDialog extends StatefulWidget {
  const _RuleDialog({this.rule});

  final OrganizationRule? rule;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final TextEditingController _name;
  late final TextEditingController _pattern;
  late final TextEditingController _target;
  late bool _regex;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.rule?.name);
    _pattern = TextEditingController(text: widget.rule?.pattern);
    _target = TextEditingController(text: widget.rule?.targetFolder);
    _regex = widget.rule?.isRegex ?? false;
    _active = widget.rule?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.isEmpty || _pattern.text.isEmpty || _target.text.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      OrganizationRule(
        id: widget.rule?.id ?? const Uuid().v4(),
        name: _name.text,
        pattern: _pattern.text,
        isRegex: _regex,
        targetFolder: _target.text,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    Widget field(String label, TextEditingController c, {String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$label =', style: tm(colors.textSecondary)),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: TField(controller: c, prefix: '›'),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text('# $hint', style: tm(colors.textDisabled)),
              ],
            ],
          ),
        );
    return TDialog(
      title: widget.rule == null ? l10n.newRule : l10n.editRule,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(l10n.nameLabel, _name),
          field(
            l10n.patternKeywordOrRegex,
            _pattern,
            hint: _regex ? l10n.regexpPattern : l10n.containsText,
          ),
          TConfLine(
            onTap: () => setState(() => _regex = !_regex),
            body: TKeyValue(l10n.isRegex, '$_regex'),
            control: TSwitch(
              value: _regex,
              label: l10n.isRegex,
              onChanged: (v) => setState(() => _regex = v),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: field(l10n.targetSubfolder, _target)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TButton(
                  label: '…',
                  square: true,
                  tooltip: l10n.targetSubfolder,
                  onTap: () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir != null) _target.text = dir;
                  },
                ),
              ),
            ],
          ),
          TConfLine(
            onTap: () => setState(() => _active = !_active),
            body: TKeyValue(l10n.active, '$_active'),
            control: TSwitch(
              value: _active,
              label: l10n.active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ),
        ],
      ),
      actions: [
        TButton(
          keyHint: 'Esc',
          label: l10n.cancel,
          onTap: () => Navigator.pop(context),
        ),
        TButton(label: l10n.save, kind: TButtonKind.primary, onTap: _submit),
      ],
    );
  }
}
