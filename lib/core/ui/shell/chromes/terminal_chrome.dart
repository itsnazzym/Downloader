import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/services/hotkey_service.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/shared/design_data.dart';
import 'package:tapload/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:tapload/features/designs/terminal/terminal_widgets.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart' show libraryFilterSources;
import 'signal_chrome.dart' show PulsingDot;

/// Terminal (mockups Terminal*.dc.html): a command bar that takes a URL, a
/// keyed sidebar (status filters, tools, sources) with real single-key
/// shortcuts, the page, and a status line that follows the page.
class TerminalChrome extends ConsumerStatefulWidget {
  const TerminalChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  ConsumerState<TerminalChrome> createState() => _TerminalChromeState();
}

class _TerminalChromeState extends ConsumerState<TerminalChrome> {
  List<DesktopDestination> _destinations = const [];

  static const _statusKeys = {
    '1': DownloadStatusFilter.all,
    '2': DownloadStatusFilter.active,
    '3': DownloadStatusFilter.completed,
    '4': DownloadStatusFilter.failed,
  };

  // A global handler, not a Focus: HotkeyHandler above us holds the primary
  // focus, so key events never bubble through a Focus placed in the chrome.
  // HardwareKeyboard calls every handler, so page keys go through here too
  // (TerminalPageKeys) and win over the sidebar's.
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final kb = HardwareKeyboard.instance;
    if (kb.isControlPressed || kb.isAltPressed || kb.isMetaPressed) {
      return false;
    }
    if (HotkeyHandler.isEditingText()) return false;
    // A dialog on top, or the player overlay (it binds bare letters).
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (ref.read(mediaPlayerProvider).isOpen) return false;

    final key = terminalKeyName(event);
    if (key == null) return false;
    if (kb.isShiftPressed && key != '?' && key != '+') return false;

    final page = TerminalPageKeys.lookup(key);
    if (page != null) {
      page();
      return true;
    }
    if (key == '?') {
      _showHelp();
      return true;
    }
    final status = _statusKeys[key];
    if (status != null) {
      _setStatus(status);
      return true;
    }
    for (final d in _destinations) {
      if (d.id != 'library' && d.shortcut == key) {
        d.onTap();
        return true;
      }
    }
    return false;
  }

  void _showHelp() =>
      showDialog<void>(context: context, builder: (_) => const _HelpDialog());

  // Same rules as LibraryFilterStrip: a status clears the source and back.
  void _setStatus(DownloadStatusFilter value) {
    ref.read(downloadStatusFilterProvider.notifier).state = value;
    ref.read(downloadSourceFilterProvider.notifier).state = null;
    if (widget.location != '/') context.go('/');
  }

  void _setSource(String value) {
    ref.read(downloadSourceFilterProvider.notifier).state = value;
    ref.read(downloadStatusFilterProvider.notifier).state =
        DownloadStatusFilter.all;
    if (widget.location != '/') context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    _destinations = desktopDestinations(context, ref, widget.location);
    final divider = BorderSide(color: colors.border);
    // Material: the command bar's TextField needs one whatever wraps us.
    return Material(
      color: colors.background,
      child: Column(
        children: [
          KeyedSubtree(
            key: OnboardingTargets.newDownload,
            child: _CommandBar(onHelp: _showHelp),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Below 900 px the sidebar narrows; the page keeps the room.
                final width = constraints.maxWidth < 900 ? 180.0 : 221.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: width,
                      decoration: BoxDecoration(border: Border(right: divider)),
                      child: _Sidebar(
                        location: widget.location,
                        destinations: _destinations,
                        onStatus: _setStatus,
                        onSource: _setSource,
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                );
              },
            ),
          ),
          _StatusLine(location: widget.location, onHelp: _showHelp),
        ],
      ),
    );
  }
}

/// `tapload ~/folder › [url] ▮  Entrée télécharger`: Enter opens the add
/// dialog with the pasted URL.
class _CommandBar extends ConsumerStatefulWidget {
  const _CommandBar({required this.onHelp});

  final VoidCallback onHelp;

  @override
  ConsumerState<_CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends ConsumerState<_CommandBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild only when the cursor's visibility can change.
    _controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return;
    _controller.clear();
    _focus.unfocus();
    showDialog(
      context: context,
      builder: (_) => AddDownloadDialog(initialUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final folder = ref.watch(settingsProvider.select((s) => s.outputFolder));
    final idle = _controller.text.isEmpty && !_focus.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text('tapload', style: tm(colors.primary, weight: FontWeight.w700)),
          if (folder.isNotEmpty) ...[
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                _homeRelative(folder),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textDisabled),
              ),
            ),
          ],
          const SizedBox(width: 14),
          Expanded(
            // The whole box focuses the field, not just its text line.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focus.requestFocus,
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    border: Border.all(
                      color: _focus.hasFocus ? colors.primary : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('›', style: tm(colors.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          onSubmitted: _submit,
                          cursorColor: colors.primary,
                          cursorWidth: 8,
                          style: tm(colors.textPrimary),
                          // The theme's input box would draw inside ours.
                          decoration: InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: l10n.terminalCommandHint,
                            hintStyle: tm(colors.textDisabled),
                          ),
                        ),
                      ),
                      if (idle) const _BlockCursor(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${l10n.terminalEnterKey} ${l10n.terminalEnterDownload}',
            style: tm(colors.textDisabled),
          ),
        ],
      ),
    );
  }

  /// "C:\Users\me\Vidéos\TapLoad" -> "~/Vidéos/TapLoad".
  static String _homeRelative(String path) {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    var p = path;
    if (home != null &&
        home.isNotEmpty &&
        p.toLowerCase().startsWith(home.toLowerCase())) {
      p = '~${p.substring(home.length)}';
    }
    return p.replaceAll('\\', '/');
  }
}

/// The idle terminal cursor: a 2 Hz timer rather than a ticker so it costs
/// two frames a second; mounted only while idle, still when effects are off.
class _BlockCursor extends StatefulWidget {
  const _BlockCursor();

  @override
  State<_BlockCursor> createState() => _BlockCursorState();
}

class _BlockCursorState extends State<_BlockCursor> {
  Timer? _timer;
  bool _on = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = null;
    _on = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() => _on = !_on),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 8,
        height: 15,
        child: _on ? ColoredBox(color: AppColors.of(context).primary) : null,
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.location,
    required this.destinations,
    required this.onStatus,
    required this.onSource,
  });

  final String location;
  final List<DesktopDestination> destinations;
  final ValueChanged<DownloadStatusFilter> onStatus;
  final ValueChanged<String> onSource;

  static const _toolOrder = ['stats', 'transfer', 'archive'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    // Counts compare by value, so progress ticks do not rebuild this.
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );
    final inLibrary = location == '/';
    final tools =
        destinations
            .where((d) => d.id != 'library' && d.id != 'settings')
            .toList()
          ..sort(
            (a, b) =>
                _toolOrder.indexOf(a.id).compareTo(_toolOrder.indexOf(b.id)),
          );
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    final sources = libraryFilterSources(counts.sourceCounts, adult);

    final statuses = [
      (l10n.terminalAll, counts.total, DownloadStatusFilter.all),
      (l10n.terminalActive, counts.active, DownloadStatusFilter.active),
      (l10n.terminalDone, counts.completed, DownloadStatusFilter.completed),
      (l10n.terminalFailed, counts.failed, DownloadStatusFilter.failed),
    ];

    Widget row(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 2), child: child);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _Heading(l10n.librarySection, first: true),
                KeyedSubtree(
                  key: OnboardingTargets.library,
                  child: Column(
                    children: [
                      for (final (i, (label, count, value)) in statuses.indexed)
                        row(
                          TKeyRow(
                            keyHint: '${i + 1}',
                            label: label,
                            count: '$count',
                            countColor:
                                value == DownloadStatusFilter.failed &&
                                    count > 0
                                ? colors.error
                                : null,
                            selected:
                                inLibrary &&
                                status == value &&
                                (value != DownloadStatusFilter.all ||
                                    source == null),
                            onTap: () => onStatus(value),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tools.isNotEmpty) ...[
                  _Heading(l10n.settingsToolsSection),
                  for (final d in tools)
                    row(
                      TKeyRow(
                        keyHint: d.shortcut ?? '·',
                        label: _snake(d.label),
                        selected: d.selected,
                        onTap: d.onTap,
                      ),
                    ),
                ],
                if (sources.isNotEmpty) ...[
                  _Heading(l10n.sourcesSection),
                  for (final s in sources)
                    row(
                      TKeyRow(
                        keyHint: '·',
                        label: s.toLowerCase(),
                        count: '${counts.sourceCounts[s] ?? 0}',
                        selected: inLibrary && source == s,
                        onTap: () => onSource(s),
                      ),
                    ),
                ],
              ],
            ),
          ),
          TKeyRow(
            keyHint: settings.shortcut ?? '·',
            label: settings.label.toLowerCase(),
            selected: settings.selected,
            onTap: settings.onTap,
          ),
        ],
      ),
    );
  }

  static String _snake(String label) =>
      label.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, first ? 6 : 14, 10, 6),
      child: Text(
        '## ${text.toLowerCase()}',
        style: tm(AppColors.of(context).textDisabled),
      ),
    );
  }
}

/// The status line: what the current page is about, free space, help.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.location, required this.onHelp});

  final String location;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final Widget left;
    if (location == '/stats') {
      left = const _StatsStatus();
    } else if (location == '/archive') {
      left = const _ArchiveStatus();
    } else if (location == '/transfer') {
      left = const _TransferStatus();
    } else if (location.startsWith('/settings')) {
      left = _StatusItems([
        (null, 'config.toml'),
        (null, '[${_settingsSection(l10n, location)}]'),
        (null, l10n.terminalDesignLine('terminal')),
      ], live: false);
    } else {
      left = const _LibraryStatus();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: left,
            ),
          ),
          const _FreeSpace(),
          const SizedBox(width: 18),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onHelp,
              child: Text(
                '? ${l10n.terminalHelp}',
                style: tm(colors.textDisabled),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _settingsSection(AppLocalizations l10n, String location) {
    final label = switch (location) {
      '/settings/output' => l10n.settingsOutput,
      '/settings/appearance' => l10n.settingsAppearance,
      '/settings/performance' => l10n.settingsPerformance,
      '/settings/advanced' => l10n.settingsAdvanced,
      '/settings/system' => l10n.settingsSystem,
      '/settings/plugins' => l10n.settingsPlugins,
      '/settings/smart_organizer' => l10n.smartOrganization,
      _ => l10n.settingsGeneral,
    };
    return label.toLowerCase();
  }
}

/// `● a · b · c` with 18 px gaps; the dot pulses when [live].
class _StatusItems extends StatelessWidget {
  const _StatusItems(this.items, {required this.live});

  final List<(Color?, String)> items;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live)
          const PulsingDot(size: 7)
        else
          Text('●', style: tm(colors.primary)),
        const SizedBox(width: 8),
        for (final (i, (color, text)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 18),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(color ?? colors.textDisabled),
            ),
          ),
        ],
      ],
    );
  }
}

class _LibraryStatus extends ConsumerWidget {
  const _LibraryStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Running only: the library's "active" filter also counts the queue.
    final running = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const <DownloadItem>[])
            .where(isActiveDownload)
            .length,
      ),
    );
    final queued = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.queued)
            .length,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _StatusItems([
            (null, l10n.terminalActiveCount(running)),
            (null, l10n.terminalQueuedCount(queued)),
          ], live: running > 0),
        ),
        if (running > 0) ...[const SizedBox(width: 18), const _LiveSpeed()],
      ],
    );
  }
}

/// Total speed: the only part of the line that rebuilds on progress ticks.
class _LiveSpeed extends ConsumerWidget {
  const _LiveSpeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final speed = formatSpeed(context.l10n, aggregateSpeed(active));
    return Text(
      '${speed.value} ${speed.unit}'.trim(),
      style: tm(AppColors.of(context).textDisabled),
    );
  }
}

class _StatsStatus extends ConsumerWidget {
  const _StatsStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = ref.watch(
      downloadStatsProvider.select((s) => s.totalDownloads),
    );
    final bytes = ref.watch(
      downloadStatsProvider.select((s) => s.totalBytesDownloaded),
    );
    return _StatusItems([
      (null, l10n.terminalDownloadsCount(total)),
      (null, localBytes(l10n, bytes)),
    ], live: false);
  }
}

class _ArchiveStatus extends ConsumerWidget {
  const _ArchiveStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final videos = ref.watch(
      tikTokArchiveProvider.select((s) => s.catalog?.totalUniqueVideos ?? 0),
    );
    final collections = ref.watch(
      tikTokArchiveProvider.select((s) => s.catalog?.collections.length ?? 0),
    );
    return _StatusItems([
      (null, l10n.terminalLocalArchive),
      (null, l10n.terminalVideosCount(videos)),
      (null, l10n.terminalCollectionsCount(collections)),
    ], live: false);
  }
}

class _TransferStatus extends ConsumerWidget {
  const _TransferStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(transferControllerProvider);
    final p = s.progress;
    final sending =
        p != null &&
        p.phase != TransferPhase.idle &&
        p.phase != TransferPhase.done &&
        p.phase != TransferPhase.failed;
    final speed = formatSpeed(l10n, sending ? p.bytesPerSecond : null);
    return _StatusItems([
      (null, l10n.terminalLocalWifi),
      if (s.lanIp != null) (null, '${s.lanIp}:${s.port ?? ''}'),
      if (sending) (null, l10n.terminalSending),
      if (sending) (null, '${speed.value} ${speed.unit}'.trim()),
    ], live: sending);
  }
}

class _FreeSpace extends ConsumerWidget {
  const _FreeSpace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    if (free == null) return const SizedBox.shrink();
    final drive = driveOf(
      ref.watch(settingsProvider.select((s) => s.outputFolder)),
    );
    return Text(
      [
        if (drive != null) '$drive\\',
        l10n.designFree(localBytes(l10n, free)),
      ].join(' '),
      style: tm(AppColors.of(context).textDisabled),
    );
  }
}

/// `? aide`: every bare key of the chrome plus the app-wide shortcuts.
class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final rows = [
      (l10n.terminalEnterKey, l10n.terminalEnterDownload),
      ('1 2 3 4', l10n.terminalKeyFilters),
      ('s t a', l10n.terminalKeyTools),
      (',', l10n.settings),
      ('Ctrl F', l10n.terminalKeySearch),
      ('Ctrl N', l10n.newDownloadShortcut),
      ('Ctrl ,', l10n.settingsShortcut),
      ('Ctrl D', l10n.dashboardShortcut),
      ('Esc', l10n.minimizeShortcut),
      ('?', l10n.terminalHelp),
    ];
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '## ${l10n.keyboardShortcuts.toLowerCase()}',
                style: tm(colors.textDisabled),
              ),
              const SizedBox(height: 12),
              for (final (k, label) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(k, style: tm(colors.primary)),
                      ),
                      Expanded(
                        child: Text(label, style: tm(colors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TButton(
                  keyHint: 'Esc',
                  label: l10n.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
