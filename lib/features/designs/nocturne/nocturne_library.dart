import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/status_badge.dart'
    show downloadStatusLabel;
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart'
    show DownloadSearchFocus;
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_widgets.dart' show SignalThumb;
import 'nocturne_widgets.dart';
import 'package:modern_downloader/core/utils/file_reveal.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

void playDownload(WidgetRef ref, DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync()) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
  }
}

void revealDownload(DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync()) revealInFolder(path);
}

/// yt-dlp size strings ("54.1MiB") in the app's units; empty if none.
String sizeLabel(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}

bool _isFailed(DownloadItem i) =>
    i.status == DownloadStatus.failed || i.status == DownloadStatus.canceled;

bool _isBusy(DownloadItem i) =>
    isActiveDownload(i) ||
    i.status == DownloadStatus.queued ||
    i.status == DownloadStatus.paused;

bool _isAgeCheck(DownloadItem i) =>
    i.status == DownloadStatus.failed &&
    DownloadStatusGuard.isAgeVerificationFailure(
      error: i.error,
      url: i.request.url,
    );

/// The row's second line: progress and speed while busy, the readable
/// reason when it failed, else source · format · size.
String nocturneMetaOf(BuildContext context, DownloadItem item) {
  final l10n = context.l10n;
  if (_isFailed(item)) {
    final reason = item.status == DownloadStatus.failed
        ? downloadErrorReason(item.error)
        : '';
    return [
      item.status == DownloadStatus.canceled
          ? l10n.statusCanceled
          : l10n.designFailed,
      reason,
    ].where((s) => s.isNotEmpty).join(' · ');
  }
  if (_isBusy(item)) {
    final speed = parseSpeed(item.speed);
    final rate = formatSpeed(l10n, speed);
    return [
      '${(item.progress * 100).clamp(0, 100).round()} %',
      if (isActiveDownload(item) && speed != null)
        '${rate.value} ${rate.unit}'
      else
        downloadStatusLabel(context, item.status),
      sizeLabel(l10n, item.totalSize),
    ].where((s) => s.isNotEmpty).join(' · ');
  }
  final size = bytesOf(item);
  return [
    item.source,
    formatLabelOf(item),
    if (size > 0) localBytes(l10n, size),
  ].where((s) => s.isNotEmpty).join(' · ');
}

// ── Rows ────────────────────────────────────────────────────────────────────

/// A library row: thumbnail, title, status line, a progress ring while busy,
/// retry when it failed; play, folder and delete on hover or focus.
class NocturneDownloadRow extends ConsumerStatefulWidget {
  const NocturneDownloadRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  ConsumerState<NocturneDownloadRow> createState() =>
      _NocturneDownloadRowState();
}

class _NocturneDownloadRowState extends ConsumerState<NocturneDownloadRow> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final selected = widget.selected;
    final failed = _isFailed(item);
    final busy = _isBusy(item);
    final ageCheck = _isAgeCheck(item);
    final show = _hover || _focus;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onDoubleTap: () => playDownload(ref, item),
        onHover: (v) => setState(() => _hover = v),
        onFocusChange: (v) => setState(() => _focus = v),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: c.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: nocturneMotion(context, 180),
          curve: nocturneEase,
          transform: Matrix4.diagonal3Values(
            _pressed ? 0.99 : 1,
            _pressed ? 0.99 : 1,
            1,
          ),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected || _hover ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected || _focus
                  ? c.primary.withValues(alpha: _focus ? 0.9 : 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SignalThumb(
                url: item.thumbnailUrl,
                filePath: item.filePath,
                width: 96,
                height: 56,
                radius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleOf(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nocturneText(c, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (ageCheck)
                      _AgeCheckLink(item: item)
                    else
                      Text(
                        nocturneMetaOf(context, item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: busy
                            ? nocturneMono(c, size: 11.5)
                            : nocturneText(
                                c,
                                size: 12,
                                color: failed ? c.error : c.textDisabled,
                              ),
                      ),
                  ],
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 10),
                NocturneRing(
                  value: item.progress,
                  size: 36,
                  stroke: 4,
                  radius: 14,
                ),
              ],
              // A failed row always shows how to recover.
              if (failed) ...[
                const SizedBox(width: 10),
                NocturneButton(
                  label: l10n.retry,
                  icon: Icons.refresh_rounded,
                  height: 32,
                  radius: 10,
                  padding: 12,
                  fontSize: 12.5,
                  tooltip: l10n.retryDownload,
                  onTap: widget.onRetry,
                ),
              ],
              AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: nocturneMotion(context, 180),
                child: _RowActions(
                  item: item,
                  onRetry: widget.onRetry,
                  onDelete: widget.onDelete,
                  enabled: show,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({
    required this.item,
    required this.onRetry,
    required this.onDelete,
    required this.enabled,
  });

  final DownloadItem item;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final done = item.status == DownloadStatus.completed;
    final finished = done || _isFailed(item);
    return IgnorePointer(
      ignoring: !enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            NocturneIconButton(
              icon: Icons.play_arrow_rounded,
              tooltip: l10n.detailsPlayVideo,
              ghost: true,
              onTap: () => playDownload(ref, item),
            ),
            NocturneIconButton(
              icon: Icons.folder_open_rounded,
              tooltip: l10n.openFolder,
              ghost: true,
              onTap: () => revealDownload(item),
            ),
            NocturneIconButton(
              icon: Icons.restart_alt_rounded,
              tooltip: l10n.restartDownload,
              ghost: true,
              onTap: onRetry,
            ),
          ],
          if (finished)
            NocturneIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.remove,
              ghost: true,
              onTap: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Age-verification failure: the reason, tappable to the help dialog.
class _AgeCheckLink extends StatelessWidget {
  const _AgeCheckLink({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => AgeVerificationHelpDialog.show(context, item),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 13, color: c.warning),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${l10n.ageCheckRequired} · ${l10n.ageCheckSeeSolutions}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nocturneText(
                  c,
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The detailed view's card: a 16:9 thumbnail carrying the ring while
/// busy, title and status line, actions underneath.
class NocturneDownloadCard extends ConsumerStatefulWidget {
  const NocturneDownloadCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  ConsumerState<NocturneDownloadCard> createState() =>
      _NocturneDownloadCardState();
}

class _NocturneDownloadCardState extends ConsumerState<NocturneDownloadCard> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final failed = _isFailed(item);
    final busy = _isBusy(item);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onDoubleTap: () => playDownload(ref, item),
        onFocusChange: (v) => setState(() => _focus = v),
        borderRadius: BorderRadius.circular(18),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: c.primary.withValues(alpha: 0.04),
        splashColor: c.primary.withValues(alpha: 0.06),
        child: NocturneCard(
          highlight: widget.selected || _focus,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) => SignalThumb(
                        url: item.thumbnailUrl,
                        filePath: item.filePath,
                        width: box.maxWidth,
                        height: box.maxHeight,
                        radius: 13,
                      ),
                    ),
                    if (busy)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c.background.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: NocturneRing(
                            value: item.progress,
                            size: 52,
                            stroke: 5,
                            radius: 21,
                            child: Text(
                              '${(item.progress * 100).clamp(0, 100).round()}',
                              style: nocturneMono(
                                c,
                                size: 12,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                titleOf(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: nocturneText(c, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              if (_isAgeCheck(item))
                _AgeCheckLink(item: item)
              else
                Text(
                  nocturneMetaOf(context, item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nocturneText(
                    c,
                    size: 12,
                    color: failed ? c.error : c.textDisabled,
                  ),
                ),
              if (failed || item.status == DownloadStatus.completed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (failed)
                      NocturneButton(
                        label: l10n.retry,
                        icon: Icons.refresh_rounded,
                        height: 30,
                        radius: 10,
                        padding: 11,
                        fontSize: 12.5,
                        tooltip: l10n.retryDownload,
                        onTap: widget.onRetry,
                      )
                    else ...[
                      NocturneIconButton(
                        icon: Icons.play_arrow_rounded,
                        tooltip: l10n.detailsPlayVideo,
                        size: 30,
                        onTap: () => playDownload(ref, item),
                      ),
                      const SizedBox(width: 6),
                      NocturneIconButton(
                        icon: Icons.folder_open_rounded,
                        tooltip: l10n.openFolder,
                        size: 30,
                        ghost: true,
                        onTap: () => revealDownload(item),
                      ),
                      const SizedBox(width: 6),
                      NocturneIconButton(
                        icon: Icons.restart_alt_rounded,
                        tooltip: l10n.restartDownload,
                        size: 30,
                        ghost: true,
                        onTap: widget.onRetry,
                      ),
                    ],
                    const Spacer(),
                    NocturneIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l10n.remove,
                      size: 30,
                      ghost: true,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toolbar ─────────────────────────────────────────────────────────────────

/// Search (Ctrl+F, Escape clears), the queue's pause and start, sort and
/// view, more actions: what today's top bar offers, in Nocturne's wells.
class NocturneLibraryToolbar extends ConsumerWidget {
  const NocturneLibraryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 640;
        final veryCompact = box.maxWidth < 460;
        return Row(
          children: [
            const Expanded(child: NocturneSearchField()),
            if (!compact) ...[
              const SizedBox(width: 10),
              const _QueueControls(),
            ],
            const SizedBox(width: 10),
            const _SortViewMenu(),
            const SizedBox(width: 6),
            _MoreMenu(queueActions: compact, retryFailed: veryCompact),
          ],
        );
      },
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

class NocturneSearchField extends ConsumerStatefulWidget {
  const NocturneSearchField({super.key});

  @override
  ConsumerState<NocturneSearchField> createState() =>
      _NocturneSearchFieldState();
}

class _NocturneSearchFieldState extends ConsumerState<NocturneSearchField> {
  late final TextEditingController _controller;
  final _node = FocusNode(debugLabel: 'nocturne-search');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    );
    DownloadSearchFocus.attach(_node);
    _node.addListener(() {
      if (mounted) setState(() => _focused = _node.hasFocus);
    });
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_node);
    _node.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _set(String v) {
    ref.read(downloadSearchQueryProvider.notifier).state = v;
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _set('');
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(downloadSearchQueryProvider, (_, next) {
      if (_controller.text == next) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final query = _controller.text;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible =
        ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            query.isNotEmpty ? _clear() : _node.unfocus(),
      },
      child: AnimatedContainer(
        duration: nocturneMotion(context, 180),
        height: 40,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          color: c.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused
                ? c.primary.withValues(alpha: 0.7)
                : c.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: _focused ? c.primary : c.textDisabled,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _node,
                onChanged: _set,
                textInputAction: TextInputAction.search,
                style: nocturneText(c),
                cursorColor: c.primary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.searchDownloads,
                  hintStyle: nocturneText(c, color: c.textDisabled),
                ),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 8),
              Text(
                query.isNotEmpty
                    ? l10n.searchMatchCount(visible, total)
                    : '$total',
                style: nocturneMono(
                  c,
                  size: 11.5,
                  color: query.isNotEmpty && visible == 0
                      ? c.warning
                      : c.textDisabled,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (query.isNotEmpty)
              NocturneIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.searchClear,
                ghost: true,
                size: 32,
                onTap: _clear,
              ),
          ],
        ),
      ),
    );
  }
}

/// Pause the active downloads, start the queue: two halves of one well.
class _QueueControls extends ConsumerWidget {
  const _QueueControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final active = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    // Disabled when there is nothing to act on, so no "done" toast lies.
    final resumable = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const []).any(
          (i) =>
              i.status == DownloadStatus.queued ||
              i.status == DownloadStatus.paused ||
              i.status == DownloadStatus.failed,
        ),
      ),
    );
    final notifier = ref.read(downloadListProvider.notifier);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NocturneButton(
            label: active > 0 ? '$active' : '',
            icon: Icons.pause_rounded,
            kind: NocturneButtonKind.ghost,
            height: 32,
            radius: 9,
            padding: 10,
            fontSize: 12,
            tooltip: l10n.pauseActiveTooltip,
            onTap: active == 0
                ? null
                : () async {
                    await notifier.pauseAllActive();
                    if (context.mounted) {
                      _toast(context, l10n.activeDownloadsPaused);
                    }
                  },
          ),
          const SizedBox(width: 2),
          NocturneButton(
            label: '',
            icon: Icons.play_arrow_rounded,
            kind: NocturneButtonKind.ghost,
            height: 32,
            radius: 9,
            padding: 10,
            tooltip: l10n.startQueueTooltip,
            onTap: !resumable
                ? null
                : () async {
                    await notifier.resumeAllQueued();
                    if (context.mounted) _toast(context, l10n.queueStarted);
                  },
          ),
        ],
      ),
    );
  }
}

/// The square well that opens one of the toolbar's menus.
class _MenuWell extends StatelessWidget {
  const _MenuWell({required this.icon, this.trailing = false});

  final IconData icon;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: trailing ? 10 : 11),
      decoration: BoxDecoration(
        color: c.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: c.textPrimary),
          if (trailing) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: c.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

PopupMenuItem<String> _header(BuildContext context, String text) {
  final c = AppColors.of(context);
  return PopupMenuItem<String>(
    enabled: false,
    height: 32,
    child: Text(
      text,
      style: nocturneText(
        c,
        size: 11.5,
        weight: FontWeight.w700,
        color: c.textDisabled,
      ),
    ),
  );
}

class _SortViewMenu extends ConsumerWidget {
  const _SortViewMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.sortAndView,
      itemBuilder: (context) {
        final c = AppColors.of(context);
        final sort = ref.read(downloadSortProvider);
        final mode = ref.read(downloadViewModeProvider);
        final opened = ref.read(openedCreatorFolderKeyProvider);
        final contents = ref.read(folderContentsViewModeProvider);
        final inside = mode == DownloadViewMode.folders && opened != null;

        PopupMenuItem<String> field(
          String id,
          String label,
          DownloadSort desc,
          DownloadSort asc, {
          bool ascFirst = false,
        }) {
          final on = sort == desc || sort == asc;
          final up = ascFirst ? sort == desc : sort == asc;
          return PopupMenuItem<String>(
            value: id,
            onTap: () {
              final first = ascFirst ? asc : desc;
              final second = ascFirst ? desc : asc;
              ref.read(downloadSortProvider.notifier).state = sort == first
                  ? second
                  : first;
            },
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: on
                      ? Icon(Icons.check_rounded, size: 16, color: c.primary)
                      : null,
                ),
                Expanded(
                  child: Text(
                    label,
                    style: nocturneText(
                      c,
                      size: 13,
                      weight: on ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  on && up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 15,
                  color: on ? c.primary : c.textDisabled,
                ),
              ],
            ),
          );
        }

        void resetCountSort() {
          final s = ref.read(downloadSortProvider);
          if (s == DownloadSort.countDesc || s == DownloadSort.countAsc) {
            ref.read(downloadSortProvider.notifier).state =
                DownloadSort.dateDesc;
          }
        }

        PopupMenuItem<String> view(
          String id,
          String label,
          DownloadViewMode m,
        ) {
          final checked = m == DownloadViewMode.folders
              ? mode == m
              : (inside ? contents == m : mode == m);
          return PopupMenuItem<String>(
            value: id,
            onTap: () {
              if (m == DownloadViewMode.folders) {
                ref.read(downloadViewModeProvider.notifier).state = m;
                if (inside) {
                  ref.read(openedCreatorFolderKeyProvider.notifier).state =
                      null;
                }
                return;
              }
              if (inside) {
                ref.read(folderContentsViewModeProvider.notifier).state = m;
                return;
              }
              ref.read(downloadViewModeProvider.notifier).state = m;
              ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
              resetCountSort();
            },
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: checked
                      ? Icon(Icons.check_rounded, size: 16, color: c.primary)
                      : null,
                ),
                Text(
                  label,
                  style: nocturneText(
                    c,
                    size: 13,
                    weight: checked ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }

        return [
          _header(context, l10n.sortBy),
          field(
            'date',
            l10n.sortFieldDate,
            DownloadSort.dateDesc,
            DownloadSort.dateAsc,
          ),
          field(
            'name',
            l10n.sortFieldName,
            DownloadSort.nameDesc,
            DownloadSort.nameAsc,
            ascFirst: true,
          ),
          field(
            'size',
            l10n.sortFieldSize,
            DownloadSort.sizeDesc,
            DownloadSort.sizeAsc,
          ),
          if (mode == DownloadViewMode.folders)
            field(
              'count',
              l10n.sortVideoCount,
              DownloadSort.countDesc,
              DownloadSort.countAsc,
            ),
          const PopupMenuDivider(),
          _header(context, l10n.viewMode),
          view('list', l10n.viewList, DownloadViewMode.list),
          view('detailed', l10n.viewDetailed, DownloadViewMode.detailed),
          view('folders', l10n.viewFolders, DownloadViewMode.folders),
        ];
      },
      child: const _MenuWell(icon: Icons.sort_rounded, trailing: true),
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.queueActions, required this.retryFailed});

  final bool queueActions;
  final bool retryFailed;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          NocturneButton(
            label: l10n.cancel,
            kind: NocturneButtonKind.ghost,
            onTap: () => Navigator.pop(ctx, false),
          ),
          NocturneButton(
            label: action,
            kind: NocturneButtonKind.danger,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final notifier = ref.read(downloadListProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) async {
        switch (value) {
          case 'retry_failed':
            await notifier.retryAllFailed();
            if (context.mounted) {
              _toast(context, l10n.retryingFailed(counts.failed));
            }
          case 'pause_all':
            await notifier.pauseAllActive();
            if (context.mounted) _toast(context, l10n.activeDownloadsPaused);
          case 'resume_all':
            await notifier.resumeAllQueued();
            if (context.mounted) _toast(context, l10n.queueStarted);
          case 'refresh':
            await notifier.refreshLibrary();
            if (context.mounted) _toast(context, l10n.refreshLibrary);
          case 'clear_completed':
            if (!await _confirm(
              context,
              title: l10n.clearCompletedConfirm(counts.completed),
              body: l10n.filesDeletedFromDisk,
              action: l10n.delete,
            )) {
              return;
            }
            await notifier.clearCompleted();
            if (context.mounted) _toast(context, l10n.clearCompletedDone);
          case 'clear_failed':
            await notifier.clearFailed();
            if (context.mounted) _toast(context, l10n.clearFailedDone);
          case 'clear_history':
            if (!context.mounted) return;
            if (await _confirm(
              context,
              title: l10n.clearHistory,
              body: l10n.clearHistoryConfirm,
              action: l10n.clearHistory,
            )) {
              await notifier.clearHistory();
            }
        }
      },
      itemBuilder: (context) {
        final c = AppColors.of(context);
        PopupMenuItem<String> item(
          String id,
          IconData icon,
          String label, {
          bool enabled = true,
          Color? tone,
        }) => PopupMenuItem<String>(
          value: id,
          enabled: enabled,
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: !enabled ? c.textDisabled : (tone ?? c.textSecondary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: nocturneText(
                  c,
                  size: 13,
                  color: !enabled ? c.textDisabled : (tone ?? c.textPrimary),
                ),
              ),
            ],
          ),
        );
        String counted(String label, int n) => n > 0 ? '$label ($n)' : label;
        return [
          if (retryFailed && counts.failed > 0) ...[
            item(
              'retry_failed',
              Icons.replay_rounded,
              '${l10n.retryFailedAction} (${counts.failed})',
              tone: c.warning,
            ),
            const PopupMenuDivider(),
          ],
          if (queueActions) ...[
            item(
              'pause_all',
              Icons.pause_rounded,
              l10n.pauseActiveAction,
              enabled: counts.active > 0,
            ),
            item(
              'resume_all',
              Icons.play_arrow_rounded,
              l10n.startQueueAction,
              tone: c.primary,
            ),
            const PopupMenuDivider(),
          ],
          item('refresh', Icons.refresh_rounded, l10n.refreshLibrary),
          item(
            'clear_completed',
            Icons.done_all_rounded,
            counted(l10n.clearCompletedAction, counts.completed),
            enabled: counts.completed > 0,
          ),
          item(
            'clear_failed',
            Icons.error_outline_rounded,
            counted(l10n.clearFailedAction, counts.failed),
            enabled: counts.failed > 0,
          ),
          const PopupMenuDivider(),
          item(
            'clear_history',
            Icons.delete_sweep_outlined,
            l10n.clearHistory,
            tone: c.error,
          ),
        ];
      },
      child: const _MenuWell(icon: Icons.more_horiz_rounded),
    );
  }
}

// ── Creator folders ─────────────────────────────────────────────────────────

void openCreatorFolder(WidgetRef ref, String? key) {
  ref.read(openedCreatorFolderKeyProvider.notifier).state = key;
  ref.read(selectedDownloadIdProvider.notifier).state = null;
}

/// A creator folder: a tinted well holding up to four thumbnails, the
/// handle and the count.
class NocturneFolderTile extends StatelessWidget {
  const NocturneFolderTile({
    super.key,
    required this.folder,
    required this.onOpen,
  });

  final CreatorFolder folder;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final title = folder.isUnknown
        ? l10n.folderUnknownCreator
        : '@${folder.handle}';
    final urls = folder.previewUrls.take(4).toList();
    return Semantics(
      button: true,
      label: '$title, ${l10n.folderVideoCount(folder.count)}',
      child: Tooltip(
        message: l10n.folderOpenHint,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            hoverColor: Colors.transparent,
            focusColor: c.primary.withValues(alpha: 0.12),
            child: NocturneCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: nocturneTint(title.hashCode),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < 4; i++)
                            i < urls.length
                                ? LayoutBuilder(
                                    builder: (context, box) => SignalThumb(
                                      url: urls[i],
                                      width: box.maxWidth,
                                      height: box.maxHeight,
                                      radius: 8,
                                    ),
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.folderVideoCount(folder.count),
                    style: nocturneMono(c, color: c.textDisabled),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An opened creator folder: back, handle and count, list or cards.
class NocturneFolderHeader extends ConsumerWidget {
  const NocturneFolderHeader({super.key, required this.folder});

  final CreatorFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final title = folder.isUnknown
        ? l10n.folderUnknownCreator
        : '@${folder.handle}';
    return Row(
      children: [
        NocturneIconButton(
          icon: Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_rounded
              : Icons.arrow_back_rounded,
          tooltip: l10n.folderBack,
          onTap: () => openCreatorFolder(ref, null),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nocturneText(c, size: 17, weight: FontWeight.w700),
              ),
              Text(
                l10n.folderVideoCount(folder.count),
                style: nocturneMono(c, color: c.textDisabled),
              ),
            ],
          ),
        ),
        NocturneSegmented<DownloadViewMode>(
          height: 30,
          padding: 12,
          value: ref.watch(folderContentsViewModeProvider),
          onChanged: (m) =>
              ref.read(folderContentsViewModeProvider.notifier).state = m,
          segments: [
            NocturneSegment(DownloadViewMode.list, l10n.viewList),
            NocturneSegment(DownloadViewMode.detailed, l10n.viewDetailed),
          ],
        ),
      ],
    );
  }
}
