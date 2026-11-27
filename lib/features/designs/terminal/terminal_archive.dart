import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/tiktok_video_url.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'terminal_archive_parts.dart';
import 'terminal_states.dart';
import 'terminal_widgets.dart';

/// TikTok ids of the library's finished downloads (the catalog's own
/// `isDownloaded` is never set). Same matching as the purge: id in the URL,
/// else the `[id]` yt-dlp writes in the file name.
final _downloadedIdsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(downloadListProvider).valueOrNull ?? const [];
  final ids = <String>{};
  for (final i in items) {
    if (i.status != DownloadStatus.completed) continue;
    final id =
        TikTokVideoUrl.extractVideoId(i.request.url) ??
        DownloadFileResolver.extractBracketId(i.filePath);
    if (id != null) ids.add(id);
  }
  return ids;
});

String _keyOf(TikTokCollectionItem c) => tCollectionKey(c);

// The two virtual folders the catalog carries next to real collections:
// views over favourites and likes, never purged, reset or deleted.
const _liked = 'Vidéos Likées';
const _unsorted = 'Favoris non classés';

bool _isVirtual(TikTokCollectionItem c) =>
    c.name == _liked || c.name == _unsorted;

/// Same membership rules as today's collections grid.
bool _inCollection(TikTokArchiveItem v, TikTokCollectionItem c) {
  if (c.name == _liked) return v.isLiked;
  if (c.name == _unsorted) {
    return v.isFavorite &&
        v.collectionIds.isEmpty &&
        (v.collectionName == null ||
            v.collectionName == _unsorted ||
            v.collectionName == _liked);
  }
  return (c.id != null && v.collectionIds.contains(c.id)) ||
      (v.collectionName?.split(' · ').contains(c.name) ?? false);
}

/// Each collection's available videos, recomputed only when the catalog or
/// the unavailable ids change (not on batch progress).
final _collectionVideosProvider =
    Provider<Map<String, List<TikTokArchiveItem>>>((ref) {
      final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog));
      if (catalog == null) return const {};
      final unavailable =
          ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
          ref.watch(tiktokVideoCacheServiceProvider).unavailableIds;
      return {
        for (final c in catalog.collections)
          _keyOf(c): [
            for (final v in catalog.videos)
              if (!unavailable.contains(v.id) && _inCollection(v, c)) v,
          ],
      };
    });

/// Terminal's TikTok archive (mockup Terminal-Archives.dc.html), with its own
/// import and sync hub, loading state, filter pane and fullscreen feed.
class TerminalArchive extends ConsumerStatefulWidget {
  const TerminalArchive({super.key, required this.current});

  final Widget current;

  @override
  ConsumerState<TerminalArchive> createState() => _TerminalArchiveState();
}

enum _Tab { videos, collections, favorites, likes }

class _TerminalArchiveState extends ConsumerState<TerminalArchive> {
  bool _selecting = false;
  final Set<String> _picked = {};
  bool _purging = false;
  final _collSearch = TextEditingController();

  @override
  void dispose() {
    _collSearch.dispose();
    super.dispose();
  }

  TikTokArchiveNotifier get _notifier =>
      ref.read(tikTokArchiveProvider.notifier);

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openTab(_Tab tab) {
    setState(() {
      _selecting = false;
      _picked.clear();
    });
    if (tab == _Tab.collections) {
      _notifier.setViewMode(TikTokViewMode.collections);
      return;
    }
    _notifier
      ..setViewMode(TikTokViewMode.list)
      ..setStatusFilter(switch (tab) {
        _Tab.favorites => TikTokStatusFilter.favoritesOnly,
        _Tab.likes => TikTokStatusFilter.likesOnly,
        _ => TikTokStatusFilter.all,
      });
  }

  void _openCollection(TikTokCollectionItem c) {
    _notifier
      ..setStatusFilter(TikTokStatusFilter.all)
      ..selectCollection(_keyOf(c))
      ..setViewMode(TikTokViewMode.list);
  }

  void _play(List<TikTokArchiveItem> videos) {
    if (videos.isEmpty || ref.read(showcaseModeProvider)) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: TerminalFeed(
          videos: videos,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TDialog(
        title: title,
        body: Text(body),
        actions: [
          TButton(
            keyHint: 'Esc',
            label: l10n.cancel,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          TButton(
            label: action,
            kind: TButtonKind.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _purge(Set<String> keys) async {
    if (keys.isEmpty || _purging) return;
    final l10n = context.l10n;
    final preview = _notifier.purgePreview(keys);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TDialog(
        title: l10n.archivePurgeTitle(keys.length),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.archivePurgeBody(preview.videos, preview.files)),
            if (preview.keptShared > 0) ...[
              const SizedBox(height: 12),
              Text(
                '# ${l10n.archivePurgeKept(preview.keptShared)}',
                style: tm(AppColors.of(ctx).textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TButton(
            keyHint: 'Esc',
            label: l10n.cancel,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          TButton(
            label: l10n.delete,
            kind: TButtonKind.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _purging = true);
    try {
      final r = await _notifier.purgeCollections(keys);
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _picked.clear();
      });
      _notice(l10n.archivePurgeDone(r.filesDeleted, r.videosRemoved));
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  Future<void> _clearArchive() async {
    final l10n = context.l10n;
    if (await _confirm(
      l10n.archiveCollClear,
      l10n.archiveCollClearBody,
      l10n.archiveCollClearConfirm,
    )) {
      await _notifier.clearCatalog();
      if (mounted) _notice(l10n.archiveCollClearDone);
    }
  }

  Future<void> _collectionMenu(
    TikTokCollectionItem c,
    List<TikTokArchiveItem> videos,
    Offset at,
  ) async {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final batch = ref.read(tikTokArchiveProvider).isBatchDownloading;
    final key = _keyOf(c);
    final choice = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      items: [
        _menuItem(0, l10n.archiveCollShowVideos),
        if (videos.isNotEmpty && !ref.read(showcaseModeProvider))
          _menuItem(1, l10n.archiveMobilePlayFullscreen),
        if (videos.isNotEmpty && !batch)
          _menuItem(2, l10n.archiveCollDownloadAll(videos.length)),
        if (!_isVirtual(c)) ...[
          _menuItem(3, l10n.archiveCollReset),
          _menuItem(4, l10n.archivePurgeMenu, danger: true),
          _menuItem(5, l10n.archiveCollDelete, danger: true),
        ],
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 0:
        _openCollection(c);
      case 1:
        _play(videos);
      case 2:
        await _notifier.downloadBatch(videos, limit: videos.length);
      case 3:
        if (await _confirm(
          l10n.archiveCollResetTitle,
          l10n.archiveCollResetBody(videos.length, c.name),
          l10n.archiveCollResetConfirm,
        )) {
          await _notifier.resetCollectionToUnclassified(key);
          if (mounted) _notice(l10n.archiveCollResetDone(c.name));
        }
      case 4:
        await _purge({key});
      case 5:
        if (await _confirm(
          l10n.archiveCollDelete,
          l10n.archiveCollDeleteBody(videos.length, c.name),
          l10n.archiveCollDeleteConfirm,
        )) {
          await _notifier.deleteCollection(key);
          if (mounted) _notice(l10n.archiveCollDeleteDone(c.name));
        }
    }
  }

  PopupMenuItem<int> _menuItem(int v, String label, {bool danger = false}) {
    final colors = AppColors.of(context);
    return PopupMenuItem<int>(
      value: v,
      height: 36,
      child: Text(label, style: tm(danger ? colors.error : colors.textPrimary)),
    );
  }

  Future<void> _reviewSuggestions(List<TikTokCollectionSuggestion> all) async {
    final keys = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _SuggestionsDialog(suggestions: all),
    );
    if (keys == null || keys.isEmpty) return;
    await _notifier.applyCollectionSuggestions(keys);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (!state.isLoading && !state.hasCatalog) {
      return const _NoArchive(child: TerminalArchiveHub(showPrompt: false));
    }
    if (state.isLoading) return const TerminalArchiveLoading();
    if (catalog == null ||
        !state.hasCatalog ||
        state.viewMode == TikTokViewMode.hub) {
      return const TerminalArchiveHub();
    }
    final filtered = ref.watch(filteredTikTokVideosProvider);
    final tab = state.viewMode == TikTokViewMode.collections
        ? _Tab.collections
        : switch (state.filter.statusFilter) {
            TikTokStatusFilter.favoritesOnly => _Tab.favorites,
            TikTokStatusFilter.likesOnly => _Tab.likes,
            TikTokStatusFilter.all => _Tab.videos,
          };
    final collections = tab == _Tab.collections;
    final bindings = <String, VoidCallback>{
      'v': () => _openTab(_Tab.videos),
      'c': () => _openTab(_Tab.collections),
      'f': () => _openTab(_Tab.favorites),
      'l': () => _openTab(_Tab.likes),
      'r': () => _notifier.setViewMode(TikTokViewMode.hub),
      if (!state.isBatchDownloading && filtered.isNotEmpty)
        'd': () => _notifier.downloadBatch(filtered, limit: filtered.length),
      if (collections) ...{
        'x': () => setState(() {
          _selecting = !_selecting;
          _picked.clear();
        }),
        if (_selecting) 'delete': () => _purge({..._picked}),
      } else ...{
        'a': () => _notifier.selectAll(filtered),
        'p': () => _play(filtered),
      },
    };
    return TerminalPageKeys(
      bindings: bindings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TPrompt('tiktok', context.l10n.terminalFlagArchive),
                  const SizedBox(height: 12),
                  _Header(
                    state: state,
                    filtered: filtered,
                    onClear: _clearArchive,
                  ),
                  const SizedBox(height: 18),
                  _tabs(context, catalog, tab),
                  const SizedBox(height: 12),
                  Expanded(
                    child: collections
                        ? _collectionsBody(context, catalog)
                        : _VideosBody(
                            state: state,
                            videos: filtered,
                            onPlay: () => _play(filtered),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context, TikTokArchiveCatalog catalog, _Tab tab) {
    final l10n = context.l10n;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final tabs = [
      (_Tab.videos, 'v', l10n.terminalTabVideos, catalog.totalUniqueVideos),
      (
        _Tab.collections,
        'c',
        l10n.terminalTabCollections,
        catalog.collections.length,
      ),
      (_Tab.favorites, 'f', l10n.terminalTabFavorites, catalog.totalFavorites),
      (_Tab.likes, 'l', l10n.terminalTabLikes, catalog.totalLikes),
    ];
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final (t, k, label, n) in tabs)
                TKeyRow(
                  keyHint: k,
                  label: label,
                  count: number.format(n),
                  selected: t == tab,
                  expand: false,
                  height: 30,
                  onTap: () => _openTab(t),
                ),
            ],
          ),
        ),
        if (tab == _Tab.collections)
          TButton(
            keyHint: 'x',
            label: _selecting ? l10n.terminalFinish : l10n.archivePurgeSelect,
            tooltip: l10n.archivePurgeSelectTooltip,
            onTap: () => setState(() {
              _selecting = !_selecting;
              _picked.clear();
            }),
          ),
      ],
    );
  }

  Widget _collectionsBody(BuildContext context, TikTokArchiveCatalog catalog) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final downloaded = ref.watch(_downloadedIdsProvider);
    final byKey = ref.watch(_collectionVideosProvider);
    final query = _collSearch.text.trim().toLowerCase();
    final cols = [
      for (final c in catalog.collections)
        if (query.isEmpty || c.name.toLowerCase().contains(query)) c,
    ];
    final suggestions = catalog.suggestions;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TPrompt(
                  'tiktok ls',
                  l10n.terminalFlagCollections,
                  comment: l10n.terminalCollectionsCount(cols.length),
                ),
              ),
              SizedBox(
                width: 240,
                height: 30,
                child: TField(
                  controller: _collSearch,
                  prefix: '/',
                  hint: l10n.archiveCollSearch,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '# ${l10n.terminalSuggestions(suggestions.length)}',
                  style: tm(colors.textSecondary),
                ),
                const SizedBox(width: 10),
                TLink(
                  label: l10n.terminalReview,
                  onTap: () => _reviewSuggestions(suggestions),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (cols.isEmpty)
            Text('# ${l10n.archiveCollEmpty}', style: tm(colors.textDisabled))
          else
            LayoutBuilder(
              builder: (context, c) {
                final n = ((c.maxWidth + 10) / 230).floor().clamp(1, 99);
                final w = (c.maxWidth - 10 * (n - 1)) / n;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final col in cols)
                      SizedBox(
                        width: w,
                        child: Builder(
                          builder: (context) {
                            final videos = byKey[_keyOf(col)] ?? const [];
                            final done = videos
                                .where((v) => downloaded.contains(v.id))
                                .length;
                            final key = _keyOf(col);
                            return _CollectionCard(
                              name: col.name,
                              count: videos.length,
                              done: done,
                              selecting: _selecting,
                              picked: _picked.contains(key),
                              onTap: () => _selecting
                                  ? _isVirtual(col)
                                        ? null
                                        : setState(() {
                                            if (!_picked.remove(key)) {
                                              _picked.add(key);
                                            }
                                          })
                                  : _openCollection(col),
                              onMenu: (at) => _collectionMenu(col, videos, at),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          if (_selecting) ...[
            const SizedBox(height: 12),
            TPanel(
              accentLeft: colors.error,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_picked.length}',
                          style: tm(colors.primary),
                        ),
                        TextSpan(
                          text:
                              ' ${l10n.archiveMobileSelectedLabel(_picked.length)}',
                        ),
                      ],
                    ),
                    style: tm(colors.textPrimary),
                  ),
                  Text('·', style: tm(colors.textDisabled)),
                  TButton(
                    keyHint: 'Suppr',
                    label: l10n.archivePurgeAction,
                    kind: TButtonKind.danger,
                    onTap: _picked.isEmpty || _purging
                        ? null
                        : () => _purge({..._picked}),
                  ),
                  Text(
                    '# ${l10n.terminalPurgeNote}',
                    style: tm(colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          THints([
            ('x', l10n.terminalSelection),
            if (_selecting) ('Suppr', l10n.delete.toLowerCase()),
            (l10n.terminalRightClick, l10n.terminalActions),
          ]),
        ],
      ),
    );
  }
}

/// No archive imported yet: Terminal's frame (prompt, typed headline, an
/// empty `tree`) over the import hub.
class _NoArchive extends StatelessWidget {
  const _NoArchive({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TPrompt('archive', '--import'),
              const SizedBox(height: 12),
              TPanel(
                accentLeft: colors.primary,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TTyped(
                      '## ${l10n.terminalArchiveEmpty}',
                      style: tm(
                        colors.primary,
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                      cursor: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.terminalArchiveEmptyBody,
                      style: tm(colors.textSecondary).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '~/tiktok\n'
                      '├── ${l10n.terminalTabVideos}/      0\n'
                      '├── ${l10n.terminalTabCollections}/ 0\n'
                      '└── ${l10n.terminalTabFavorites}/     0',
                      style: tm(colors.textDisabled).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.filtered,
    required this.onClear,
  });

  final TikTokArchiveState state;
  final List<TikTokArchiveItem> filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = state.catalog!;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final downloaded = ref.watch(_downloadedIdsProvider);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final done = catalog.videos.where((v) => downloaded.contains(v.id)).length;
    String n(int v) => number.format(v);
    TextSpan strong(String t) =>
        TextSpan(text: t, style: tm(colors.textPrimary));

    final Widget status;
    if (state.isBatchDownloading) {
      final total = state.batchTotalCount;
      status = Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _Dot(),
          Text(
            '${l10n.archiveMobileBatchRunning} '
            '${state.batchCompletedCount}/$total',
            style: tm(colors.textSecondary),
          ),
          SizedBox(
            width: 160,
            child: TSeg(
              value: total == 0 ? 0 : state.batchCompletedCount / total,
              height: 8,
            ),
          ),
          if (state.batchSkippedCount > 0)
            Text(
              l10n.archiveMobileSkippedVideos(state.batchSkippedCount),
              style: tm(colors.textDisabled),
            ),
          TButton(
            label: l10n.archiveMobileStopBatch,
            height: 26,
            onTap: notifier.stopBatch,
          ),
        ],
      );
    } else {
      final sync = switch (state.syncStatus) {
        TikTokSyncStatus.waiting => l10n.archiveMobileSyncWaiting,
        TikTokSyncStatus.idle => null,
        _ => state.syncMessage,
      };
      status = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '● ', style: tm(colors.primary)),
            TextSpan(
              text:
                  sync ??
                  l10n.terminalDownloadedOf(done, catalog.totalUniqueVideos),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tm(
          state.syncStatus == TikTokSyncStatus.failed
              ? colors.error
              : colors.textDisabled,
        ),
      );
    }

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'tiktok',
            style: tm(colors.textPrimary, size: 18, weight: FontWeight.w700),
            children: [
              TextSpan(
                text: '  (${l10n.terminalLocalArchive})',
                style: tm(colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              strong(n(catalog.totalUniqueVideos)),
              TextSpan(text: ' ${l10n.terminalTabVideos} · '),
              strong(n(catalog.collections.length)),
              TextSpan(text: ' ${l10n.terminalTabCollections} · '),
              strong(n(catalog.totalFavorites)),
              TextSpan(text: ' ${l10n.terminalTabFavorites}'),
            ],
          ),
          style: tm(colors.textSecondary),
        ),
        const SizedBox(height: 6),
        status,
      ],
    );
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TButton(label: l10n.archiveCollClear, onTap: onClear),
        TButton(
          keyHint: 'r',
          label: l10n.archiveMobileSyncTooltip,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        TButton(
          keyHint: 'd',
          label: l10n.terminalDownloadAll,
          kind: TButtonKind.primary,
          onTap: state.isBatchDownloading || filtered.isEmpty
              ? null
              : () => notifier.downloadBatch(filtered, limit: filtered.length),
        ),
      ],
    );
    return TPanel(
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 900
            ? Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 24),
                  buttons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const SizedBox(height: 14), buttons],
              ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) =>
      Text('●', style: tm(AppColors.of(context).primary));
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.name,
    required this.count,
    required this.done,
    required this.selecting,
    required this.picked,
    required this.onTap,
    required this.onMenu,
  });

  final String name;
  final int count;
  final int done;
  final bool selecting;
  final bool picked;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMenu;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final share = widget.count == 0 ? 0.0 : widget.done / widget.count;
    final complete = widget.count > 0 && widget.done == widget.count;
    final (status, statusColor) = complete
        ? ('ok ${l10n.terminalAllDownloaded}', colors.primary)
        : widget.done > 0
        ? (l10n.terminalDownloadedPct((share * 100).round()), colors.primary)
        : ('— ${l10n.terminalToDownload}', colors.textSecondary);
    final line = widget.picked
        ? colors.primary
        : (_hover ? colors.textSecondary : colors.border);
    return Semantics(
      button: true,
      selected: widget.picked,
      label: widget.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: (d) => widget.onMenu(d.globalPosition),
          onLongPressStart: (d) => widget.onMenu(d.globalPosition),
          child: AnimatedContainer(
            duration: tMotion(context),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.picked
                  ? colors.primary.withValues(alpha: 0.06)
                  : colors.surface,
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      widget.picked ? '[x]' : '[ ]',
                      style: tm(colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tm(colors.textPrimary, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.terminalVidCount(widget.count),
                      style: tm(colors.textDisabled),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TSeg(value: share, height: 8),
                const SizedBox(height: 10),
                Text(status, style: tm(statusColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Videos, favourites, likes: the filter pane (year, collection,
/// status) beside a terminal list with selection and batch download.
class _VideosBody extends ConsumerStatefulWidget {
  const _VideosBody({
    required this.state,
    required this.videos,
    required this.onPlay,
  });

  final TikTokArchiveState state;
  final List<TikTokArchiveItem> videos;
  final VoidCallback onPlay;

  @override
  ConsumerState<_VideosBody> createState() => _VideosBodyState();
}

class _VideosBodyState extends ConsumerState<_VideosBody> {
  late final _search = TextEditingController(
    text: ref.read(tikTokArchiveProvider).filter.searchQuery,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = widget.state;
    final videos = widget.videos;
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final downloaded = ref.watch(_downloadedIdsProvider);
    final selected = state.selectedIds;
    final opened = state.filter.selectedCollection;
    final openedName = opened == null
        ? null
        : state.catalog!.collections
                  .where((c) => _keyOf(c) == opened)
                  .firstOrNull
                  ?.name ??
              opened;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TPrompt(
                'tiktok ls',
                openedName == null
                    ? l10n.terminalFlagVideos
                    : '--collection "$openedName"',
                comment: l10n.terminalVideosCount(videos.length),
              ),
            ),
            if (opened != null) ...[
              TLink(
                label: '← ${l10n.terminalAllCollections}',
                onTap: () => notifier.selectCollection(null),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: 240,
              height: 30,
              child: TField(
                controller: _search,
                prefix: '/',
                hint: l10n.archiveMobileSearchHint,
                onChanged: notifier.setSearchQuery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TButton(
              keyHint: 'a',
              label: l10n.archiveMobileSelectAll,
              onTap: videos.isEmpty ? null : () => notifier.selectAll(videos),
            ),
            TButton(
              label: l10n.archiveMobileClearSelection,
              onTap: selected.isEmpty ? null : notifier.clearSelection,
            ),
            TButton(
              keyHint: 'p',
              label: l10n.archiveMobilePlayFullscreen,
              onTap: videos.isEmpty || ref.read(showcaseModeProvider)
                  ? null
                  : widget.onPlay,
            ),
            TButton(
              label: l10n.terminalDownloadSelection(selected.length),
              kind: TButtonKind.primary,
              onTap: selected.isEmpty || state.isBatchDownloading
                  ? null
                  : notifier.downloadSelected,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TPanel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: videos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Text(
                          '# ${l10n.archiveMobileNoVideos}',
                          style: tm(colors.textDisabled),
                        ),
                        const SizedBox(width: 12),
                        TLink(
                          label: l10n.clearSearchAndFilters.toLowerCase(),
                          onTap: () {
                            _search.clear();
                            notifier.resetFilters();
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: videos.length,
                    itemExtent: 38,
                    itemBuilder: (context, i) => _VideoLine(
                      video: videos[i],
                      selected: selected.contains(videos[i].id),
                      downloaded: downloaded.contains(videos[i].id),
                      onToggle: () => notifier.toggleSelection(videos[i].id),
                      onDownload: ref.read(showcaseModeProvider)
                          ? null
                          : () => notifier.downloadBatch([videos[i]], limit: 1),
                    ),
                  ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TButton(
                  label: l10n.archiveMobileFilters,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const Dialog(
                      shape: RoundedRectangleBorder(),
                      child: SizedBox(
                        width: 320,
                        height: 520,
                        child: TerminalFilterPane(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: list),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 260, child: TerminalFilterPane()),
            const SizedBox(width: 18),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

class _VideoLine extends StatelessWidget {
  const _VideoLine({
    required this.video,
    required this.selected,
    required this.downloaded,
    required this.onToggle,
    required this.onDownload,
  });

  final TikTokArchiveItem video;
  final bool selected;
  final bool downloaded;
  final VoidCallback onToggle;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final date = DateFormat.yMd(l10n.localeName).format(video.date);
    return THoverLine(
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onTap: onToggle,
      child: Row(
        children: [
          Text(selected ? '[x]' : '[ ]', style: tm(colors.primary)),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              l10n.archiveVideoTitle(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(colors.textPrimary, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              video.collectionName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(colors.textSecondary),
            ),
          ),
          SizedBox(
            width: 40,
            child: Row(
              children: [
                if (video.isFavorite)
                  Icon(Icons.star_rounded, size: 14, color: colors.warning),
                if (video.isLiked)
                  Icon(Icons.favorite_rounded, size: 13, color: colors.error),
              ],
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              downloaded ? l10n.terminalStateOk : '',
              style: tm(colors.primary),
            ),
          ),
          _Act(
            icon: Icons.link_rounded,
            tooltip: l10n.terminalCopyLink,
            onTap: () {
              Clipboard.setData(ClipboardData(text: video.url));
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(l10n.urlCopied)));
            },
          ),
          _Act(
            icon: Icons.open_in_new_rounded,
            tooltip: l10n.terminalOpenBrowser,
            onTap: () => openInBrowser(video.url),
          ),
          _Act(
            icon: Icons.download_rounded,
            tooltip: l10n.archiveMobileDownload,
            onTap: onDownload,
          ),
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        hoverColor: colors.primary.withValues(alpha: 0.08),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? colors.textDisabled : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Today's grouped review, as a checklist: apply only what is ticked.
class _SuggestionsDialog extends StatefulWidget {
  const _SuggestionsDialog({required this.suggestions});

  final List<TikTokCollectionSuggestion> suggestions;

  @override
  State<_SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<_SuggestionsDialog> {
  late final Set<String> _keys = {for (final s in widget.suggestions) s.key};

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return TDialog(
      title: l10n.terminalSuggestions(widget.suggestions.length),
      body: SizedBox(
        width: 520,
        height: 360,
        child: ListView(
          children: [
            for (final s in widget.suggestions)
              THoverLine(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onTap: () => setState(() {
                  if (!_keys.remove(s.key)) _keys.add(s.key);
                }),
                child: Row(
                  children: [
                    Text(
                      _keys.contains(s.key) ? '[x]' : '[ ]',
                      style: tm(colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.videoId} → ${s.collectionName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tm(colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        s.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tm(colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TButton(
          keyHint: 'Esc',
          label: l10n.cancel,
          onTap: () => Navigator.of(context).pop(),
        ),
        TButton(
          label: l10n.terminalApply(_keys.length),
          kind: TButtonKind.primary,
          onTap: _keys.isEmpty ? null : () => Navigator.of(context).pop(_keys),
        ),
      ],
    );
  }
}
