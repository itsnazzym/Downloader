import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/hotkey_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';
import 'signal_chrome.dart' show PulsingDot;

TextStyle _mono(Color color, {FontWeight weight = FontWeight.w400}) =>
    AppTypography.mono.copyWith(
      fontSize: 12.5,
      color: color,
      fontWeight: weight,
    );

/// Terminal: a command bar that takes a URL, a key sidebar (status filters,
/// tools, sources) with real single-key shortcuts, the page, a status line.
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

  static final _statusKeys = {
    PhysicalKeyboardKey.digit1: DownloadStatusFilter.all,
    PhysicalKeyboardKey.digit2: DownloadStatusFilter.active,
    PhysicalKeyboardKey.digit3: DownloadStatusFilter.completed,
    PhysicalKeyboardKey.digit4: DownloadStatusFilter.failed,
    PhysicalKeyboardKey.numpad1: DownloadStatusFilter.all,
    PhysicalKeyboardKey.numpad2: DownloadStatusFilter.active,
    PhysicalKeyboardKey.numpad3: DownloadStatusFilter.completed,
    PhysicalKeyboardKey.numpad4: DownloadStatusFilter.failed,
  };

  // A global handler, not a Focus: HotkeyHandler above us holds the primary
  // focus, so key events never bubble through a Focus placed in the chrome.
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
    if (kb.isControlPressed ||
        kb.isAltPressed ||
        kb.isMetaPressed ||
        kb.isShiftPressed) {
      return false;
    }
    if (HotkeyHandler.isEditingText()) return false;
    // A dialog on top, or the player overlay (it binds bare letters).
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (ref.read(mediaPlayerProvider).isOpen) return false;

    // Physical digits so the top row works on AZERTY without Shift.
    final status = _statusKeys[event.physicalKey];
    if (status != null) {
      _setStatus(status);
      return true;
    }
    final label = event.logicalKey.keyLabel.toLowerCase();
    for (final d in _destinations) {
      if (d.id != 'library' && d.shortcut == label) {
        d.onTap();
        return true;
      }
    }
    return false;
  }

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
    final divider = BorderSide(color: colors.borderSubtle);
    // Material: the command bar's TextField needs one whatever wraps us.
    return Material(
      color: colors.background,
      child: Column(
        children: [
          KeyedSubtree(
            key: OnboardingTargets.newDownload,
            child: const _CommandBar(),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 248,
                  decoration: BoxDecoration(border: Border(right: divider)),
                  child: _Sidebar(
                    location: widget.location,
                    destinations: _destinations,
                    onStatus: _setStatus,
                    onSource: _setSource,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.location.startsWith('/settings'))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SettingsSectionStrip(
                              location: widget.location,
                            ),
                          ),
                        ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _StatusLine(),
        ],
      ),
    );
  }
}

/// « tapload › [url] »: Enter opens the add dialog with the pasted URL.
class _CommandBar extends StatefulWidget {
  const _CommandBar();

  @override
  State<_CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<_CommandBar> {
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
    final idle = _controller.text.isEmpty && !_focus.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          Text(
            'tapload',
            style: _mono(colors.primary, weight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          Expanded(
            // The whole box focuses the field, not just its text line.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focus.requestFocus,
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    border: Border.all(
                      color: _focus.hasFocus
                          ? colors.primary
                          : colors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('›', style: _mono(colors.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          onSubmitted: _submit,
                          cursorColor: colors.primary,
                          cursorWidth: 8,
                          style: _mono(colors.textPrimary),
                          decoration: InputDecoration.collapsed(
                            hintText: context.l10n.pasteUrl,
                            hintStyle: _mono(colors.textDisabled),
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
        ],
      ),
    );
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
    final tools = destinations
        .where((d) => d.id != 'library' && d.id != 'settings')
        .toList();
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    final sources = libraryFilterSources(counts.sourceCounts, adult);

    final statuses = [
      (l10n.allDownloads, counts.total, DownloadStatusFilter.all),
      (l10n.sidebarActive, counts.active, DownloadStatusFilter.active),
      (l10n.sidebarCompleted, counts.completed, DownloadStatusFilter.completed),
      (l10n.sidebarFailed, counts.failed, DownloadStatusFilter.failed),
    ];

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
                        _KeyRow(
                          keyHint: '${i + 1}',
                          label: label.toLowerCase(),
                          count: count,
                          countColor:
                              value == DownloadStatusFilter.failed && count > 0
                              ? colors.error
                              : null,
                          selected:
                              inLibrary &&
                              status == value &&
                              (value != DownloadStatusFilter.all ||
                                  source == null),
                          onTap: () => onStatus(value),
                        ),
                    ],
                  ),
                ),
                if (tools.isNotEmpty) ...[
                  _Heading(l10n.settingsToolsSection),
                  for (final d in tools)
                    _KeyRow(
                      keyHint: d.shortcut ?? '·',
                      label: d.label.toLowerCase(),
                      selected: d.selected,
                      onTap: d.onTap,
                    ),
                ],
                if (sources.isNotEmpty) ...[
                  _Heading(l10n.sourcesSection),
                  for (final s in sources)
                    _KeyRow(
                      keyHint: '·',
                      label: s.toLowerCase(),
                      count: counts.sourceCounts[s],
                      selected: inLibrary && source == s,
                      onTap: () => onSource(s),
                    ),
                ],
              ],
            ),
          ),
          _KeyRow(
            keyHint: settings.shortcut ?? '·',
            label: settings.label.toLowerCase(),
            selected: settings.selected,
            onTap: settings.onTap,
          ),
        ],
      ),
    );
  }
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
        style: _mono(AppColors.of(context).textDisabled),
      ),
    );
  }
}

/// One sidebar line: key hint, label, optional count. Selected = filled
/// primary with background-coloured bold text.
class _KeyRow extends StatefulWidget {
  const _KeyRow({
    required this.keyHint,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.countColor,
  });

  final String keyHint;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? countColor;

  @override
  State<_KeyRow> createState() => _KeyRowState();
}

class _KeyRowState extends State<_KeyRow> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final weight = on ? FontWeight.w700 : FontWeight.w400;
    final fg = on
        ? colors.background
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _focused = v),
          hoverColor: colors.primary.withValues(alpha: 0.06),
          focusColor: colors.primary.withValues(alpha: 0.2),
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // The fill hides focus ink, so keyboard focus gets an outline.
            decoration: BoxDecoration(
              color: on ? colors.primary : Colors.transparent,
              border: _focused
                  ? Border.all(color: on ? colors.background : colors.primary)
                  : null,
            ),
            child: Row(
              children: [
                Text(
                  widget.keyHint,
                  style: _mono(
                    on ? colors.background : colors.primary,
                    weight: weight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mono(fg, weight: weight),
                  ),
                ),
                if (widget.count != null)
                  Text(
                    '${widget.count}',
                    style: _mono(
                      on
                          ? colors.background
                          : (widget.countColor ?? colors.textDisabled),
                      weight: weight,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line status: active (green dot), completed, failed. Real counts only.
class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final active = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    final completed = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.completed),
    );
    final failed = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.failed),
    );
    final muted = _mono(colors.textSecondary);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          if (active > 0)
            const PulsingDot(size: 7)
          else
            Text('●', style: _mono(colors.textDisabled)),
          const SizedBox(width: 8),
          Text('$active ${l10n.sidebarActive.toLowerCase()}', style: muted),
          const SizedBox(width: 18),
          Text(
            '$completed ${l10n.sidebarCompleted.toLowerCase()}',
            style: muted,
          ),
          const SizedBox(width: 18),
          Text(
            '$failed ${l10n.sidebarFailed.toLowerCase()}',
            style: _mono(failed > 0 ? colors.error : colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
