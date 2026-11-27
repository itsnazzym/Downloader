import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card_player.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'terminal_states.dart';
import 'terminal_widgets.dart';

/// Terminal's own archive pieces: the filter pane, the fullscreen feed's
/// frame, the import/sync hub and the indexing state.

/// A collection's filter key: its id, else its name (the filter takes both).
String tCollectionKey(TikTokCollectionItem c) => c.id ?? c.name;

/// `## filtres`: type, year and collection, each a list of `[x]` lines.
class TerminalFilterPane extends ConsumerStatefulWidget {
  const TerminalFilterPane({super.key});

  @override
  ConsumerState<TerminalFilterPane> createState() => _FilterPaneState();
}

class _FilterPaneState extends ConsumerState<TerminalFilterPane> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (catalog == null) return const SizedBox.shrink();
    final filter = state.filter;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final query = _search.text.trim().toLowerCase();
    final collections = [
      for (final c in catalog.collections)
        if (c.name.toLowerCase().contains(query)) c,
    ];
    Widget head(String text, {VoidCallback? clear}) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Row(
        children: [
          Expanded(child: Text('## $text', style: tm(colors.textDisabled))),
          if (clear != null)
            TLink(label: l10n.terminalClearFilters, onTap: clear),
        ],
      ),
    );
    Widget pick(String label, bool on, VoidCallback onTap, {String? count}) =>
        THoverLine(
          selected: on,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              Text(on ? '[x]' : '[ ]', style: tm(colors.primary)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tm(on ? colors.textPrimary : colors.textSecondary),
                ),
              ),
              if (count != null) Text(count, style: tm(colors.textDisabled)),
            ],
          ),
        );

    return TPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head(
            l10n.archiveMobileFilters.toLowerCase(),
            clear: () {
              notifier
                ..selectYear(null)
                ..selectCollection(null)
                ..setStatusFilter(TikTokStatusFilter.all)
                ..clearSelection();
            },
          ),
          head(l10n.archiveMobileType.toLowerCase()),
          for (final (f, label) in [
            (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
            (
              TikTokStatusFilter.favoritesOnly,
              l10n.archiveMobileFilterFavorites,
            ),
            (TikTokStatusFilter.likesOnly, l10n.archiveMobileFilterLikes),
          ])
            pick(
              label.toLowerCase(),
              filter.statusFilter == f,
              () => notifier.setStatusFilter(f),
            ),
          head(l10n.archiveMobileYear.toLowerCase()),
          pick(
            l10n.archiveMobileAllYears.toLowerCase(),
            filter.selectedYear == null,
            () => notifier.selectYear(null),
          ),
          for (final y in years)
            pick(
              '$y',
              filter.selectedYear == y,
              () => notifier.selectYear(filter.selectedYear == y ? null : y),
              count: '${catalog.yearCounts[y]}',
            ),
          head(
            '${l10n.terminalTabCollections} (${catalog.collections.length})',
            clear: filter.selectedCollection == null
                ? null
                : () => notifier.selectCollection(null),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
            child: SizedBox(
              height: 28,
              child: TField(
                controller: _search,
                prefix: '/',
                hint: l10n.archiveCollSearch,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final c in collections)
                  pick(
                    c.name,
                    filter.selectedCollection == tCollectionKey(c),
                    () => notifier.selectCollection(
                      filter.selectedCollection == tCollectionKey(c)
                          ? null
                          : tCollectionKey(c),
                    ),
                    count: '${c.videoCount}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The fullscreen feed: today's player in a square hairline frame, one
/// video per page; wheel, ↑ ↓ and Esc as today, `n/m` and keys printed.
class TerminalFeed extends ConsumerStatefulWidget {
  const TerminalFeed({super.key, required this.videos, required this.onClose});

  final List<TikTokArchiveItem> videos;
  final VoidCallback onClose;

  @override
  ConsumerState<TerminalFeed> createState() => _TerminalFeedState();
}

class _TerminalFeedState extends ConsumerState<TerminalFeed> {
  late final PageController _pages;
  int _page = 0;
  bool _wheelBusy = false;
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.videos.isNotEmpty) {
        ref
            .read(tiktokPreloadControllerProvider)
            .preloadAround(widget.videos, 0, lookAhead: 3);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 240);

  void _go(int target) {
    if (!_pages.hasClients) return;
    final t = target.clamp(0, widget.videos.length - 1);
    if (t == _page) return;
    unawaited(
      _pages.animateToPage(t, duration: _motion, curve: Curves.easeOutCubic),
    );
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      final now = DateTime.now();
      if (dy == 0 ||
          _wheelBusy ||
          now.difference(_lastWheel) < const Duration(milliseconds: 280) ||
          !_pages.hasClients) {
        return;
      }
      final target = (_page + (dy > 0 ? 1 : -1))
          .clamp(0, widget.videos.length - 1)
          .toInt();
      if (target == _page) return;
      _lastWheel = now;
      _wheelBusy = true;
      unawaited(
        _pages
            .animateToPage(
              target,
              duration: _motion,
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _wheelBusy = false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final total = widget.videos.length;
    return ColoredBox(
      color: colors.background,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _go(_page + 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _go(_page - 1),
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TPrompt(
                        'tiktok play',
                        total == 0 ? '--' : '${_page + 1}/$total',
                      ),
                    ),
                    THints([('↑ ↓', l10n.terminalFeedNavigate)]),
                    const SizedBox(width: 14),
                    TButton(
                      keyHint: 'Esc',
                      label: l10n.close,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: total == 0
                    ? Center(
                        child: Text(
                          '# ${l10n.archiveMobileNoVideos}',
                          style: tm(colors.textDisabled),
                        ),
                      )
                    : Listener(
                        onPointerSignal: _wheel,
                        child: PageView.builder(
                          controller: _pages,
                          scrollDirection: Axis.vertical,
                          itemCount: total,
                          onPageChanged: (i) {
                            setState(() => _page = i);
                            ref
                                .read(tiktokPreloadControllerProvider)
                                .preloadAround(widget.videos, i, lookAhead: 3);
                          },
                          itemBuilder: (context, i) => _FeedPage(
                            video: widget.videos[i],
                            active: i == _page,
                            onNext: i < total - 1 ? () => _go(i + 1) : null,
                            onPrevious: i > 0 ? () => _go(i - 1) : null,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({
    required this.video,
    required this.active,
    required this.onNext,
    required this.onPrevious,
  });

  final TikTokArchiveItem video;
  final bool active;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final d = video.date;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: active ? colors.primary : colors.border,
                    ),
                  ),
                  child: ClipRect(
                    child: TikTokVideoCardPlayer(
                      video: video,
                      isActive: active,
                      onNext: onNext,
                      onPrevious: onPrevious,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    if (video.collectionName != null)
                      TextSpan(
                        text: '${video.collectionName}  ',
                        style: tm(colors.primary),
                      ),
                    TextSpan(text: date),
                    if (video.isFavorite)
                      TextSpan(text: '  ★', style: tm(colors.warning)),
                    if (video.isLiked)
                      TextSpan(text: '  ♥', style: tm(colors.error)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The catalog is being read: a typed line over skeleton lines.
class TerminalArchiveLoading extends StatelessWidget {
  const TerminalArchiveLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TPrompt('tiktok', '--index'),
          const SizedBox(height: 12),
          TTyped(
            '# ${l10n.terminalArchiveIndexing}',
            style: tm(colors.textPrimary),
            cursor: true,
          ),
          const SizedBox(height: 4),
          Text(
            '# ${l10n.terminalArchiveIndexingNote}',
            style: tm(colors.textDisabled),
          ),
          const SizedBox(height: 12),
          const TSkeletonLines(leading: [70], trailing: [120]),
        ],
      ),
    );
  }
}

/// The import and sync hub, as two config blocks with key buttons: `i`
/// picks a JSON export, `y` asks the browser extension to sync.
class TerminalArchiveHub extends ConsumerWidget {
  const TerminalArchiveHub({super.key, this.showPrompt = true});

  /// False under the empty-archive banner, which prints its own prompt.
  final bool showPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        !showcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final catalog = state.catalog;
    final canImport = !showcase;
    final canSync = !showcase && connected && !syncing;
    void open() => notifier.setViewMode(TikTokViewMode.collections);

    Widget notice(String message, Color color) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TPanel(
        accentLeft: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(message, style: tm(color)),
      ),
    );
    Widget block(String title, String body, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '## ${title.toLowerCase()}',
              style: tm(colors.primary, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '# $body',
              style: tm(colors.textSecondary).copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );

    return TerminalPageKeys(
      bindings: {
        if (canImport) 'i': notifier.pickAndImportFile,
        if (canSync) 'y': notifier.triggerExtensionSync,
        if (state.hasCatalog) 'o': open,
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showPrompt) ...[
                  TPrompt('archive', '--import'),
                  const SizedBox(height: 12),
                ],
                Text(
                  l10n.archiveMobileTitle,
                  style: tm(
                    colors.textPrimary,
                    size: 16,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.archiveDeskIntro,
                  style: tm(colors.textSecondary).copyWith(height: 1.5),
                ),
                if (state.hasCatalog && catalog != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TPanel(
                      accentLeft: colors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.archiveMobileVideoCount(catalog.videos.length)} · '
                              '${l10n.archiveHubCollections(catalog.collections.length)}',
                              style: tm(
                                colors.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TButton(
                            keyHint: 'o',
                            label: l10n.archiveHubOpen,
                            kind: TButtonKind.primary,
                            onTap: open,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.errorMessage != null)
                  notice(state.errorMessage!, colors.error),
                block(l10n.archiveDeskImportTitle, l10n.archiveDeskImportBody, [
                  TButton(
                    keyHint: 'i',
                    label: l10n.archiveDeskPickJson,
                    kind: TButtonKind.primary,
                    onTap: canImport ? notifier.pickAndImportFile : null,
                  ),
                ]),
                block(
                  l10n.archiveDeskSyncTitle,
                  connected
                      ? l10n.archiveDeskSyncConnected
                      : l10n.archiveDeskSyncDisconnected,
                  [
                    Row(
                      children: [
                        TButton(
                          keyHint: 'y',
                          label: syncing
                              ? l10n.archiveDeskSyncing
                              : l10n.archiveDeskSyncAction,
                          onTap: canSync ? notifier.triggerExtensionSync : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          connected
                              ? '● ${l10n.terminalExtensionOnline}'
                              : '· ${l10n.terminalExtensionOffline}',
                          style: tm(
                            connected ? colors.primary : colors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    if (syncing) ...[
                      const SizedBox(height: 10),
                      const _Pulse(),
                      const SizedBox(height: 6),
                      Text(
                        '# ${l10n.archiveMobileSyncWaiting}',
                        style: tm(colors.textSecondary),
                      ),
                    ] else if (state.syncMessage != null)
                      notice(
                        state.syncMessage!,
                        state.syncStatus == TikTokSyncStatus.failed
                            ? colors.error
                            : state.syncStatus == TikTokSyncStatus.partial
                            ? colors.warning
                            : colors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '# ${l10n.archiveDeskSyncManual}',
                  style: tm(colors.textDisabled).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An indeterminate segmented bar: a lit run of cells walks left to right
/// (still when animations are off).
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
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
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final x = (w + 80) * _c.value - 80;
        return Stack(
          children: [
            const TSeg(value: 0, height: 8),
            Positioned(
              left: x.clamp(0.0, w),
              width: (x + 80).clamp(0.0, w) - x.clamp(0.0, w),
              top: 0,
              height: 8,
              child: const TSeg(value: 1, height: 8),
            ),
          ],
        );
      },
    ),
  );
}
