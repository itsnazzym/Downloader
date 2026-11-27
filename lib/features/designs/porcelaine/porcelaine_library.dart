import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/status_badge.dart'
    show downloadStatusLabel;
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/download_queue_controller.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/layout/pane_layout_provider.dart';
import 'package:tapload/core/ui/shell/shell_strips.dart'
    show libraryFilterSources;
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/widgets/resizable_width_pane.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/video_preview_widget.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_row_host.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_search_field.dart'
    show DownloadSearchFocus;
import 'package:tapload/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:tapload/features/downloader/presentation/widgets/download_item_display.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'porcelaine_states.dart';
import 'porcelaine_widgets.dart';

/// Porcelaine's library, drawn in its own language: the rows and grid cards
/// (through the skin), the toolbar (search, queue, sort and view, more),
/// the creator folders and the inspector card. Same data and actions as
/// today's `DownloadView`.

// ── Data ───────────────────────────────────────────────────────────────────

String _titleOf(BuildContext context, DownloadItem item) =>
    item.status == DownloadStatus.extracting &&
        ExtractionPlaceholders.isGenericTitle(item.title)
    ? context.l10n.extractingTitle
    : titleOf(item);

bool _busy(DownloadStatus s) =>
    s == DownloadStatus.downloading ||
    s == DownloadStatus.extracting ||
    s == DownloadStatus.processing;

bool _finished(DownloadStatus s) =>
    s == DownloadStatus.failed ||
    s == DownloadStatus.canceled ||
    s == DownloadStatus.completed;

bool _ageCheck(DownloadItem item) =>
    item.status == DownloadStatus.failed &&
    DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );

/// Source, size (done / total while downloading), speed and time left,
/// like today's row.
String _meta(BuildContext context, DownloadItem item) {
  final downloading = item.status == DownloadStatus.downloading;
  final size = DownloadFileResolver.displaySize(
    storedTotalSize: item.totalSize,
    filePath: item.filePath,
    unknownLabel: '',
  );
  return [
    DownloadItemDisplay.source(context, item),
    if (size.isNotEmpty)
      downloading && item.downloadedSize.isNotEmpty
          ? '${item.downloadedSize} / $size'
          : size
    else if (item.downloadedSize.isNotEmpty)
      item.downloadedSize,
    if (downloading && item.speed.isNotEmpty) item.speed,
    if (downloading && item.eta.isNotEmpty)
      context.l10n.porcelaineEta(item.eta),
  ].where((s) => s.isNotEmpty).join(' · ');
}

Color _statusTint(AppColors colors, DownloadStatus s) => switch (s) {
  DownloadStatus.completed => pGreen,
  DownloadStatus.failed => colors.error,
  DownloadStatus.downloading ||
  DownloadStatus.extracting ||
  DownloadStatus.processing => colors.primary,
  _ => pSlate,
};

// ── Rows ───────────────────────────────────────────────────────────────────

/// The skin's row builder: a list row or, in the detailed view, a card.
Widget porcelaineRow(BuildContext context, DesignRow row) {
  if (row.grid) return _PGridCard(row: row);
  // A reorderable list puts its drag handle over the row's end on desktop:
  // keep the actions clear of it.
  final handle =
      SliverReorderableList.maybeOf(context) != null &&
      switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };
  final card = _PRow(row: row);
  return handle
      ? Padding(padding: const EdgeInsetsDirectional.only(end: 28), child: card)
      : card;
}

/// The status as a tinted pill with its dot; the full error as its tooltip,
/// like today's status badge.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.error});

  final DownloadStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tint = _statusTint(colors, status);
    final pill = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.1), colors.surface),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            downloadStatusLabel(context, status),
            maxLines: 1,
            style: pBody(
              colors,
              size: 11.5,
              weight: FontWeight.w600,
              color: tint,
            ).copyWith(height: 1.1),
          ),
        ],
      ),
    );
    final e = error;
    return e == null || e.trim().isEmpty
        ? pill
        : Tooltip(message: e, child: pill);
  }
}

/// The age-verification help, as a pill that opens the solutions.
class _AgePill extends StatelessWidget {
  const _AgePill({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => AgeVerificationHelpDialog.show(context, item),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.warning.withValues(alpha: 0.14),
              colors.surface,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 13, color: colors.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.ageCheckSeeSolutions,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(colors, size: 12, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The thumbnail, with today's spinner while the link is being read.
Widget _thumb(
  DownloadItem item, {
  double? width,
  required double height,
  double radius = 12,
}) {
  final picture = PThumb(
    url: item.thumbnailUrl,
    filePath: item.filePath,
    seed: item.id,
    width: width,
    height: height,
    radius: radius,
  );
  if (!ExtractionPlaceholders.showThumbnailSpinner(
    status: item.status,
    thumbnailUrl: item.thumbnailUrl,
  )) {
    return picture;
  }
  return Stack(
    alignment: Alignment.center,
    children: [
      picture,
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ],
  );
}

/// Retry and remove (and the age help) on a finished download.
List<Widget> _rowActions(BuildContext context, DesignRow row) {
  final l10n = context.l10n;
  if (!_finished(row.item.status)) return const [];
  return [
    if (_ageCheck(row.item))
      PIconBtn(
        icon: Icons.shield_outlined,
        tooltip: l10n.ageCheckSeeSolutions,
        onTap: () => AgeVerificationHelpDialog.show(context, row.item),
      ),
    const SizedBox(width: 4),
    PIconBtn(
      icon: Icons.refresh_rounded,
      tooltip: l10n.retryDownload,
      color: AppColors.of(context).primary,
      onTap: row.onRetry,
    ),
    const SizedBox(width: 4),
    PIconBtn(
      icon: Icons.delete_outline_rounded,
      tooltip: l10n.remove,
      danger: true,
      onTap: row.onCancel,
    ),
  ];
}

/// Hover lift, the cobalt ring when selected, the keyboard focus ring.
class _Lift extends StatefulWidget {
  const _Lift({
    required this.selected,
    required this.onTap,
    required this.radius,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final double radius;
  final Widget child;

  @override
  State<_Lift> createState() => _LiftState();
}

class _LiftState extends State<_Lift> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = _hover && !widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: pMotion(context, 260),
        curve: pEase,
        transform: Matrix4.translationValues(0, up ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.selected
              ? Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.04),
                  colors.surface,
                )
              : colors.surface,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            if (widget.selected) ...[
              BoxShadow(color: colors.primary, spreadRadius: 2),
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.14),
                spreadRadius: 6,
              ),
            ] else if (_focus)
              BoxShadow(color: colors.primary, spreadRadius: 2),
            ...pCardShadow(colors, up: up),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: BorderRadius.circular(widget.radius),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: colors.primary.withValues(alpha: 0.05),
            highlightColor: colors.textPrimary.withValues(alpha: 0.03),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _PRow extends StatelessWidget {
  const _PRow({required this.row});

  final DesignRow row;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = row.item;
    final busy = _busy(item.status);
    final reason = item.status == DownloadStatus.failed && !_ageCheck(item)
        ? downloadErrorReason(item.error)
        : '';
    return _Lift(
      selected: row.isSelected,
      onTap: row.onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
        child: Row(
          children: [
            _thumb(item, width: 96, height: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _titleOf(context, item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      colors,
                      weight: FontWeight.w600,
                      color: row.isSelected ? colors.primary : null,
                    ).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  if (busy) ...[
                    Row(
                      children: [
                        Expanded(child: PBar(value: item.progress, height: 6)),
                        const SizedBox(width: 10),
                        Text(
                          '${(item.progress * 100).toStringAsFixed(1)} %',
                          style: pMono(
                            colors,
                            size: 11.5,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    _meta(context, item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: busy
                        ? pMono(colors, size: 11.5)
                        : pBody(
                            colors,
                            size: 12.5,
                            color: colors.textSecondary,
                          ).copyWith(height: 1.3),
                  ),
                  if (reason.isNotEmpty)
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(
                        colors,
                        size: 12.5,
                        color: colors.error,
                      ).copyWith(height: 1.3),
                    ),
                  if (_ageCheck(item)) ...[
                    const SizedBox(height: 4),
                    _AgePill(item: item),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusPill(status: item.status, error: item.error),
            ..._rowActions(context, row),
          ],
        ),
      ),
    );
  }
}

class _PGridCard extends StatelessWidget {
  const _PGridCard({required this.row});

  final DesignRow row;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = row.item;
    final busy = _busy(item.status);
    final reason = item.status == DownloadStatus.failed && !_ageCheck(item)
        ? downloadErrorReason(item.error)
        : '';
    final actions = _rowActions(context, row);
    return _Lift(
      selected: row.isSelected,
      onTap: row.onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumb(item, height: double.infinity, radius: 14),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: _StatusPill(status: item.status, error: item.error),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _titleOf(context, item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      colors,
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: row.isSelected ? colors.primary : null,
                    ).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  if (busy) ...[
                    PBar(value: item.progress, height: 6),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    reason.isNotEmpty ? reason : _meta(context, item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      colors,
                      size: 12,
                      color: reason.isNotEmpty
                          ? colors.error
                          : colors.textSecondary,
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────────────────────

/// Search, queue, sort and view, more actions: today's top bar in
/// Porcelaine. Under 700 px the queue moves into the « … » menu.
class PLibraryToolbar extends ConsumerWidget {
  const PLibraryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 700;
        return Row(
          children: [
            const Expanded(child: _Search()),
            const SizedBox(width: 10),
            if (!compact) ...[const _QueueSeg(), const SizedBox(width: 8)],
            _SortButton(compact: compact),
            const SizedBox(width: 8),
            _MoreButton(showQueue: compact),
          ],
        );
      },
    );
  }
}

/// All / active / done / failed and each source, as Porcelaine `.pill`s in a
/// `.seg` (today's `LibraryFilterStrip`, same rules).
class PLibraryFilters extends ConsumerWidget {
  const PLibraryFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );
    void setStatus(DownloadStatusFilter v) {
      ref.read(downloadStatusFilterProvider.notifier).state = v;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
    }

    void setSource(String v) {
      ref.read(downloadSourceFilterProvider.notifier).state = v;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
    }

    final pills = <(String, int?, bool, VoidCallback)>[
      (
        l10n.allDownloads,
        counts.total,
        status == DownloadStatusFilter.all && source == null,
        () => setStatus(DownloadStatusFilter.all),
      ),
      (
        l10n.sidebarActive,
        counts.active,
        status == DownloadStatusFilter.active,
        () => setStatus(DownloadStatusFilter.active),
      ),
      (
        l10n.sidebarCompleted,
        counts.completed,
        status == DownloadStatusFilter.completed,
        () => setStatus(DownloadStatusFilter.completed),
      ),
      (
        l10n.sidebarFailed,
        counts.failed,
        status == DownloadStatusFilter.failed,
        () => setStatus(DownloadStatusFilter.failed),
      ),
      for (final s in libraryFilterSources(counts.sourceCounts, adult))
        (s, counts.sourceCounts[s], source == s, () => setSource(s)),
    ];
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colors.surface.withValues(alpha: 0.7),
                colors.background,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.07),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                for (final (i, (label, n, on, tap)) in pills.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  PPill(
                    label: label,
                    trailing: n == null ? null : '$n',
                    selected: on,
                    transparent: true,
                    onTap: tap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Search extends ConsumerStatefulWidget {
  const _Search();

  @override
  ConsumerState<_Search> createState() => _SearchState();
}

class _SearchState extends ConsumerState<_Search> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(downloadSearchQueryProvider),
    );
    _focus = FocusNode(debugLabel: 'porcelaine-search');
    DownloadSearchFocus.attach(_focus);
    _focus.addListener(_redraw);
    _controller.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _set(String value) =>
      ref.read(downloadSearchQueryProvider.notifier).state = value;

  void _clear() {
    _controller.clear();
    _set('');
    _focus.requestFocus();
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final hasQuery = _controller.text.isNotEmpty;
    final total =
        ref.watch(downloadListProvider.select((s) => s.valueOrNull?.length)) ??
        0;
    final visible =
        ref.watch(filteredDownloadListPhaseProvider).valueOrNull ?? 0;
    final focused = _focus.hasFocus;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            hasQuery ? _clear() : _focus.unfocus(),
      },
      child: AnimatedContainer(
        duration: pMotion(context, 160),
        height: 42,
        padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
        decoration: BoxDecoration(
          color: focused ? colors.surface : colors.inputBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused
                ? colors.primary
                : colors.textPrimary.withValues(alpha: 0.08),
            width: focused ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _set,
                textInputAction: TextInputAction.search,
                cursorColor: colors.primary,
                style: pBody(colors, size: 13.5),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.searchDownloads,
                  hintStyle: pBody(
                    colors,
                    size: 13.5,
                    color: colors.textDisabled,
                  ),
                ),
              ),
            ),
            if (total > 0)
              IgnorePointer(
                child: Text(
                  hasQuery ? l10n.searchMatchCount(visible, total) : '$total',
                  style: pMono(
                    colors,
                    size: 12,
                    color: hasQuery && visible == 0
                        ? colors.error
                        : colors.textDisabled,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            if (hasQuery)
              PIconBtn(
                icon: Icons.close_rounded,
                tooltip: l10n.searchClear,
                size: 28,
                onTap: _clear,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

Future<void> _pauseAll(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  await ref.read(downloadListProvider.notifier).pauseAllActive();
  if (context.mounted) pNotice(context, l10n.activeDownloadsPaused);
}

Future<void> _resumeAll(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  await ref.read(downloadListProvider.notifier).resumeAllQueued();
  if (context.mounted) pNotice(context, l10n.queueStarted);
}

/// Pause what downloads, start the queue: a white `.seg` of two buttons.
class _QueueSeg extends ConsumerWidget {
  const _QueueSeg();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final active = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.active),
    );
    // Disabled when there is nothing to act on, so no « done » note lies.
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
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.1),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PIconBtn(
            icon: Icons.pause_rounded,
            tooltip: l10n.pauseActiveTooltip,
            size: 34,
            filled: false,
            color: active > 0 ? colors.textPrimary : null,
            onTap: active == 0 ? null : () => _pauseAll(context, ref),
          ),
          if (active > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Text(
                '$active',
                style: pMono(colors, size: 12, color: colors.primary),
              ),
            ),
          Container(width: 1, height: 18, color: pTrack(colors)),
          PIconBtn(
            icon: Icons.play_arrow_rounded,
            tooltip: l10n.startQueueTooltip,
            size: 34,
            filled: false,
            color: resumable ? colors.primary : null,
            onTap: resumable ? () => _resumeAll(context, ref) : null,
          ),
        ],
      ),
    );
  }
}

/// « Tri et affichage »: the sort field (again flips the direction) and
/// the view (list, detailed, creator folders; inside a folder, its own).
class _SortButton extends ConsumerWidget {
  const _SortButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Builder(
      builder: (button) => PBtn(
        label: compact ? '' : l10n.sortAndView,
        tooltip: compact ? l10n.sortAndView : null,
        icon: Icons.sort_rounded,
        height: 42,
        padding: compact ? 13 : 16,
        onTap: () async {
          final action = await pShowMenu<VoidCallback>(
            button,
            _sortItems(button, ref),
          );
          action?.call();
        },
      ),
    );
  }

  List<PopupMenuEntry<VoidCallback>> _sortItems(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final sort = ref.read(downloadSortProvider);
    final mode = ref.read(downloadViewModeProvider);
    final inside =
        mode == DownloadViewMode.folders &&
        ref.read(openedCreatorFolderKeyProvider) != null;
    final contents = ref.read(folderContentsViewModeProvider);
    void setSort(DownloadSort v) =>
        ref.read(downloadSortProvider.notifier).state = v;

    PopupMenuItem<VoidCallback> field(
      String label,
      DownloadSort desc,
      DownloadSort asc, {
      bool upWhenDesc = false,
    }) {
      final on = sort == desc || sort == asc;
      // Name reads A→Z as « up »: its arrow shows the other way.
      final up = upWhenDesc ? sort == desc : sort == asc;
      return pMenuItem(
        context,
        value: () => setSort(sort == desc ? asc : desc),
        label: label,
        checked: on,
        trailing: Icon(
          on && up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 15,
          color: on ? colors.primary : colors.textDisabled,
        ),
      );
    }

    void setView(DownloadViewMode v) {
      if (inside && v != DownloadViewMode.folders) {
        ref.read(folderContentsViewModeProvider.notifier).state = v;
        return;
      }
      ref.read(downloadViewModeProvider.notifier).state = v;
      if (v == DownloadViewMode.folders) {
        if (inside)
          ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
        return;
      }
      ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      final s = ref.read(downloadSortProvider);
      if (s == DownloadSort.countDesc || s == DownloadSort.countAsc) {
        setSort(DownloadSort.dateDesc);
      }
    }

    final shown = inside ? contents : mode;
    return [
      pMenuLabel(context, l10n.sortBy),
      field(l10n.sortFieldDate, DownloadSort.dateDesc, DownloadSort.dateAsc),
      field(
        l10n.sortFieldName,
        DownloadSort.nameAsc,
        DownloadSort.nameDesc,
        upWhenDesc: false,
      ),
      field(l10n.sortFieldSize, DownloadSort.sizeDesc, DownloadSort.sizeAsc),
      if (mode == DownloadViewMode.folders)
        field(
          l10n.sortVideoCount,
          DownloadSort.countDesc,
          DownloadSort.countAsc,
        ),
      const PopupMenuDivider(height: 9),
      pMenuLabel(context, l10n.viewMode),
      pMenuItem(
        context,
        value: () => setView(DownloadViewMode.list),
        label: l10n.viewList,
        icon: Icons.view_agenda_outlined,
        checked: shown == DownloadViewMode.list,
      ),
      pMenuItem(
        context,
        value: () => setView(DownloadViewMode.detailed),
        label: l10n.viewDetailed,
        icon: Icons.grid_view_rounded,
        checked: shown == DownloadViewMode.detailed,
      ),
      pMenuItem(
        context,
        value: () => setView(DownloadViewMode.folders),
        label: l10n.viewFolders,
        icon: Icons.folder_outlined,
        checked: mode == DownloadViewMode.folders,
      ),
    ];
  }
}

/// « … »: refresh, clear finished / failed / history (and the queue when
/// the bar is too narrow for it).
class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.showQueue});

  final bool showQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Builder(
      builder: (button) => PBtn(
        label: '',
        icon: Icons.more_horiz_rounded,
        tooltip: l10n.moreActions,
        height: 42,
        padding: 13,
        onTap: () async {
          final c = ref.read(downloadLibraryCountsProvider);
          final action = await pShowMenu<String>(button, [
            if (showQueue) ...[
              pMenuItem(
                button,
                value: 'pause_all',
                label: l10n.pauseActiveAction,
                icon: Icons.pause_rounded,
                enabled: c.active > 0,
              ),
              pMenuItem(
                button,
                value: 'resume_all',
                label: l10n.startQueueAction,
                icon: Icons.play_arrow_rounded,
              ),
              const PopupMenuDivider(height: 9),
            ],
            pMenuItem(
              button,
              value: 'refresh',
              label: l10n.refreshLibrary,
              icon: Icons.refresh_rounded,
            ),
            pMenuItem(
              button,
              value: 'clear_completed',
              label: c.completed > 0
                  ? '${l10n.clearCompletedAction} (${c.completed})'
                  : l10n.clearCompletedAction,
              icon: Icons.done_all_rounded,
              enabled: c.completed > 0,
            ),
            pMenuItem(
              button,
              value: 'clear_failed',
              label: c.failed > 0
                  ? '${l10n.clearFailedAction} (${c.failed})'
                  : l10n.clearFailedAction,
              icon: Icons.error_outline_rounded,
              enabled: c.failed > 0,
            ),
            const PopupMenuDivider(height: 9),
            pMenuItem(
              button,
              value: 'clear_history',
              label: l10n.clearHistory,
              icon: Icons.delete_sweep_outlined,
              danger: true,
            ),
          ]);
          if (action == null || !context.mounted) return;
          await _run(context, ref, action, c.completed);
        },
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String action,
    int completed,
  ) async {
    final l10n = context.l10n;
    final notifier = ref.read(downloadListProvider.notifier);
    switch (action) {
      case 'pause_all':
        await _pauseAll(context, ref);
      case 'resume_all':
        await _resumeAll(context, ref);
      case 'refresh':
        await notifier.refreshLibrary();
        if (context.mounted) pNotice(context, l10n.refreshLibrary);
      case 'clear_completed':
        if (!await pConfirm(
          context,
          title: l10n.clearCompletedConfirm(completed),
          body: l10n.filesDeletedFromDisk,
          action: l10n.delete,
          icon: Icons.delete_outline_rounded,
        )) {
          return;
        }
        await notifier.clearCompleted();
        if (context.mounted) pNotice(context, l10n.clearCompletedDone);
      case 'clear_failed':
        await notifier.clearFailed();
        if (context.mounted) pNotice(context, l10n.clearFailedDone);
      case 'clear_history':
        if (await pConfirm(
          context,
          title: l10n.clearHistory,
          body: l10n.clearHistoryConfirm,
          action: l10n.clearHistory,
        )) {
          await notifier.clearHistory();
        }
    }
  }
}

// ── Body: list or folders, and the inspector ───────────────────────────────

/// The list sheet and, when a download is selected, the inspector card
/// beside it (resizable, collapsible to a rail, both remembered); under
/// 620 px the inspector rises as a sheet instead.
class PLibraryBody extends ConsumerWidget {
  const PLibraryBody({super.key, required this.noResults});

  /// The search or filters match nothing: Porcelaine's panel, not the list.
  final bool noResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 684;
    if (narrow) {
      ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
        if (next == null || next == previous) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: PInspector(downloadId: next, inSheet: true),
          ),
        ).whenComplete(() {
          if (ref.read(selectedDownloadIdProvider) == next) {
            ref.read(selectedDownloadIdProvider.notifier).state = null;
          }
        });
      });
    }
    final folders = ref.watch(
      downloadViewModeProvider.select((m) => m == DownloadViewMode.folders),
    );
    final Widget list = noResults
        ? const PNoResults()
        : folders
        ? KeyedSubtree(
            key: OnboardingTargets.creatorList,
            child: const _Folders(),
          )
        : DownloadList(key: OnboardingTargets.creatorList);
    final sheet = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pCardFill(colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: pCardShadow(colors),
      ),
      child: Material(type: MaterialType.transparency, child: list),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: sheet),
        if (!narrow) const _InspectorPane(),
      ],
    );
  }
}

class _InspectorPane extends ConsumerWidget {
  const _InspectorPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedDownloadIdProvider);
    if (id == null) return const SizedBox.shrink();
    final layout = ref.watch(paneLayoutProvider);
    final pane = ref.read(paneLayoutProvider.notifier);
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: ResizableWidthPane(
        width: layout.visibleInspectorWidth,
        minWidth: PaneLayout.inspectorRail,
        maxWidth: PaneLayout.inspectorMax,
        contentMinWidth: PaneLayout.inspectorMin,
        resizeFrom: PaneResizeFrom.leading,
        onWidthChanged: pane.setInspectorWidth,
        onDragActive: (active) =>
            ref.read(paneResizeActiveProvider.notifier).state = active,
        onResizeEnd: () {
          ref.read(paneResizeActiveProvider.notifier).state = false;
          pane.commitInspectorDrag();
          pane.persist();
        },
        onToggleCollapse: () {
          pane.toggleInspectorCollapsed();
          pane.persist();
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: pCardShadow(colors),
          ),
          child: layout.inspectorCollapsed
              ? Center(
                  child: PIconBtn(
                    icon: Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    tooltip: context.l10n.expandInspector,
                    onTap: () {
                      pane.expandInspector();
                      pane.persist();
                    },
                  ),
                )
              : PInspector(downloadId: id),
        ),
      ),
    );
  }
}

// ── Creator folders ────────────────────────────────────────────────────────

class _Folders extends ConsumerWidget {
  const _Folders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A folder that empties (filter, deletion) closes, like today's list.
    ref.listen(creatorFoldersProvider, (_, next) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (opened != null && !next.folders.any((f) => f.key == opened)) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    final opened = ref.watch(openedCreatorFolderProvider);
    if (opened != null) return _FolderContents(folder: opened);
    final folders = ref.watch(creatorFoldersProvider).folders;
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 236,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: folders.length,
      itemBuilder: (context, i) => _FolderCard(
        key: ValueKey(folders[i].key),
        folder: folders[i],
        onOpen: () {
          ref.read(openedCreatorFolderKeyProvider.notifier).state =
              folders[i].key;
          ref.read(selectedDownloadIdProvider.notifier).state = null;
        },
      ),
    );
  }
}

String _folderName(BuildContext context, CreatorFolder f) =>
    f.isUnknown ? context.l10n.folderUnknownCreator : '@${f.handle}';

/// A creator as a collection card: the 2×2 mosaic, the name, the count.
class _FolderCard extends StatelessWidget {
  const _FolderCard({super.key, required this.folder, required this.onOpen});

  final CreatorFolder folder;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final name = _folderName(context, folder);
    final urls = folder.previewUrls;
    Widget cell(int i) {
      final thumb = PThumb(
        url: i < urls.length ? urls[i] : null,
        seed: '${folder.key}$i',
        height: double.infinity,
        radius: 10,
      );
      if (i != 3 || folder.overflowCount == 0) return thumb;
      return Stack(
        fit: StackFit.expand,
        children: [
          thumb,
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.textPrimary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '+${folder.overflowCount}',
                style: pBody(
                  colors,
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: '$name, ${l10n.folderVideoCount(folder.count)}',
      child: Tooltip(
        message: l10n.folderOpenHint,
        child: _Lift(
          selected: false,
          onTap: onOpen,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final r in [0, 2]) ...[
                        if (r > 0) const SizedBox(height: 4),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: cell(r)),
                              const SizedBox(width: 4),
                              Expanded(child: cell(r + 1)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pBody(colors, weight: FontWeight.w600),
                        ),
                      ),
                      Text('${folder.count}', style: pMono(colors)),
                    ],
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

class _FolderContents extends ConsumerWidget {
  const _FolderContents({required this.folder});

  final CreatorFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final ids = ref.watch(openedCreatorFolderItemIdsProvider).ids;
    final mode = ref.watch(folderContentsViewModeProvider);
    final grid = mode == DownloadViewMode.detailed;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(
            children: [
              PIconBtn(
                icon: rtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                tooltip: l10n.folderBack,
                size: 36,
                onTap: () {
                  ref.read(openedCreatorFolderKeyProvider.notifier).state =
                      null;
                  ref.read(selectedDownloadIdProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _folderName(context, folder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pDisp(22, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.folderVideoCount(folder.count),
                      style: pMono(colors),
                    ),
                  ],
                ),
              ),
              PSegmented<DownloadViewMode>(
                options: [
                  (DownloadViewMode.list, l10n.viewList),
                  (DownloadViewMode.detailed, l10n.viewDetailed),
                ],
                value: grid ? DownloadViewMode.detailed : DownloadViewMode.list,
                onChanged: (m) =>
                    ref.read(folderContentsViewModeProvider.notifier).state = m,
              ),
            ],
          ),
        ),
        Expanded(
          child: grid
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: ids.length,
                  itemBuilder: (context, i) => DownloadRowHost(
                    key: ValueKey(ids[i]),
                    id: ids[i],
                    useGridCard: true,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      DownloadRowHost(key: ValueKey(ids[i]), id: ids[i]),
                ),
        ),
      ],
    );
  }
}

// ── Inspector ──────────────────────────────────────────────────────────────

void _openInFolder(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(path).parent.path]);
    }
  } catch (e) {
    debugPrint('Error revealing file: $e');
  }
}

/// Media in the built-in player, anything else with the system.
void _openMedia(WidgetRef ref, String path) {
  if (DownloadFileResolver.isMediaPath(path)) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
    return;
  }
  try {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  } catch (e) {
    debugPrint('Error opening file: $e');
  }
}

/// Today's inspector as a Porcelaine card: the preview (the player itself,
/// framed), play, the facts as `.row` lines, copy link and show in folder,
/// the failure (or the age-verification help), the item's actions, logs.
class PInspector extends ConsumerWidget {
  const PInspector({super.key, required this.downloadId, this.inSheet = false});

  final String downloadId;
  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(downloadId));
    if (item == null) {
      return Center(
        child: Text(
          l10n.selectDownload,
          style: pBody(colors, color: colors.textSecondary),
        ),
      );
    }
    // This build reruns on every progress tick, and the resolver may scan
    // folders: no playable file exists until the download ends anyway.
    final path = DownloadQueueController.isBusy(item.status)
        ? null
        : DownloadFileResolver.resolvePlayablePath(
            item.filePath,
            title: item.title,
            outputFolder: item.request.outputFolder,
          );
    final notifier = ref.read(downloadListProvider.notifier);
    final busy = _busy(item.status);
    final finished = _finished(item.status);

    Widget preview() {
      if (path != null &&
          DownloadFileResolver.isMediaPath(path) &&
          !DownloadFileResolver.isAudioPath(path)) {
        // The fullscreen player owns the video device: unmount this one.
        if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen))) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.35,
                child: _thumb(item, height: 190, radius: 18),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 48,
                color: colors.surface.withValues(alpha: 0.8),
              ),
            ],
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: VideoPreviewWidget(
            filePath: path,
            thumbnailUrl: item.thumbnailUrl,
            onFullscreen: () => _openMedia(ref, path),
          ),
        );
      }
      return Stack(
        alignment: Alignment.center,
        children: [
          _thumb(item, height: 190, radius: 18),
          if (path != null)
            Material(
              color: colors.surface.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openMedia(ref, path),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 28,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget fact(String label, String value, {bool mono = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: pBody(colors, size: 12, color: colors.textDisabled),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            maxLines: 3,
            style: mono
                ? pMono(colors, size: 12.5, color: colors.textPrimary)
                : pBody(colors, size: 13.5),
          ),
        ],
      ),
    );

    final age = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    Widget? failure;
    if (item.error != null) {
      final tint = age ? colors.warning : colors.error;
      failure = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint.withValues(alpha: 0.08), colors.surface),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  age ? Icons.shield_outlined : Icons.error_outline_rounded,
                  size: 18,
                  color: age ? colors.textPrimary : colors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    age ? l10n.ageCheckRequired : l10n.designFailed,
                    style: pBody(
                      colors,
                      weight: FontWeight.w600,
                      color: age ? null : colors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              item.error!,
              style: pBody(colors, size: 12.5, color: colors.textSecondary),
            ),
            if (age) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PBtn(
                  label: l10n.ageCheckSeeSolutions,
                  icon: Icons.help_outline_rounded,
                  kind: PBtnKind.dark,
                  height: 36,
                  onTap: () => AgeVerificationHelpDialog.show(context, item),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final actions = <Widget>[
      if (busy) ...[
        PBtn(
          label: l10n.pause,
          icon: Icons.pause_rounded,
          height: 36,
          onTap: () => notifier.pauseDownload(item.id),
        ),
        PBtn(
          label: l10n.cancel,
          icon: Icons.close_rounded,
          kind: PBtnKind.ghost,
          height: 36,
          onTap: () => notifier.cancelDownload(item.id),
        ),
      ],
      if (item.status == DownloadStatus.paused)
        PBtn(
          label: l10n.resume,
          icon: Icons.play_arrow_rounded,
          kind: PBtnKind.accent,
          height: 36,
          onTap: () => notifier.resumeDownload(item.id),
        ),
      if (finished)
        PBtn(
          label: item.status == DownloadStatus.completed
              ? l10n.restartDownload
              : l10n.retry,
          icon: Icons.restart_alt_rounded,
          height: 36,
          onTap: () async {
            if (await confirmFileDeletion(
              context,
              item,
              actionLabel: l10n.restartDownload,
            )) {
              await notifier.retryDownload(item);
            }
          },
        ),
      PBtn(
        label: l10n.delete,
        icon: Icons.delete_outline_rounded,
        kind: PBtnKind.ghost,
        height: 36,
        onTap: () async {
          if (await confirmFileDeletion(
            context,
            item,
            actionLabel: l10n.delete,
          )) {
            await notifier.deleteDownload(item.id);
          }
        },
      ),
    ];

    final logs = [
      l10n.porcelaineLogInit(item.id),
      if (item.status != DownloadStatus.queued) l10n.porcelaineLogStarted,
      if (item.step.isNotEmpty) l10n.porcelaineLogStep(item.step),
      if (item.speed.isNotEmpty && !item.speed.toLowerCase().contains('retry'))
        l10n.porcelaineLogSpeed(item.speed),
      if (item.error != null) l10n.porcelaineLogError(item.error!),
      if (item.status == DownloadStatus.completed && item.error == null)
        l10n.porcelaineLogDone,
      if (item.status == DownloadStatus.canceled) l10n.porcelaineLogCanceled,
    ];
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return TweenAnimationBuilder<double>(
      key: ValueKey(downloadId),
      tween: Tween(begin: 0, end: 1),
      duration: pMotion(context, 260),
      curve: pEase,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((rtl ? -12 : 12) * (1 - t), 0),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 12, 6),
            child: PHead(
              icon: Icons.tune_rounded,
              label: l10n.inspector,
              tint: colors.primary,
              bottom: 0,
              trailing: Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!inSheet)
                      PIconBtn(
                        icon: rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        tooltip: l10n.collapseInspector,
                        filled: false,
                        onTap: () {
                          final pane = ref.read(paneLayoutProvider.notifier);
                          pane.toggleInspectorCollapsed();
                          pane.persist();
                        },
                      ),
                    PIconBtn(
                      icon: Icons.close_rounded,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      filled: false,
                      onTap: () {
                        if (inSheet) {
                          Navigator.of(context).maybePop();
                        } else {
                          ref.read(selectedDownloadIdProvider.notifier).state =
                              null;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  preview(),
                  if (path != null) ...[
                    const SizedBox(height: 12),
                    PBtn(
                      label: l10n.inspectorPlayMedia,
                      icon: Icons.play_arrow_rounded,
                      kind: PBtnKind.accent,
                      height: 42,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _openMedia(ref, path);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _titleOf(context, item),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: pDisp(
                      20,
                      color: colors.textPrimary,
                    ).copyWith(height: 1.2, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatusPill(status: item.status, error: item.error),
                      const SizedBox(width: 10),
                      Text(
                        '${(item.progress * 100).toStringAsFixed(1)} %',
                        style: pMono(colors, size: 12),
                      ),
                    ],
                  ),
                  if (busy) ...[
                    const SizedBox(height: 10),
                    PBar(value: item.progress, height: 6),
                  ],
                  const SizedBox(height: 14),
                  fact(l10n.inspectorId, item.id, mono: true),
                  fact(l10n.inspectorSourceUrl, item.request.url, mono: true),
                  if (path != null)
                    fact(l10n.inspectorLocalFile, path, mono: true),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PBtn(
                        label: l10n.copyUrl,
                        icon: Icons.link_rounded,
                        height: 36,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(
                            ClipboardData(text: item.request.url),
                          );
                          pNotice(context, l10n.urlCopied);
                        },
                      ),
                      if (path != null)
                        PBtn(
                          label: l10n.showInFolder,
                          icon: Icons.folder_open_rounded,
                          height: 36,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openInFolder(path);
                          },
                        ),
                    ],
                  ),
                  if (failure != null) ...[const SizedBox(height: 18), failure],
                  const SizedBox(height: 18),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                  const SizedBox(height: 22),
                  Text(
                    l10n.logs,
                    style: pBody(colors, size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      logs.join('\n'),
                      style: pMono(colors, size: 11.5).copyWith(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
