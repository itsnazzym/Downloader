import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/shell/desktop_destinations.dart';
import 'package:tapload/core/utils/format_utils.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/download_search_field.dart'
    show DownloadSearchFocus;
import 'package:tapload/features/downloader/presentation/views/widgets/toolbar/download_more_actions_menu.dart';
import 'package:tapload/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'ios_glass.dart';
import 'ios_states.dart';
import 'ios_theme.dart';

/// Media kind shown by « Tout / Vidéo / Audio / Images ».
final iosKindFilterProvider = StateProvider<MediaKind?>((ref) => null);

/// iOS's library (mockups iOS-Accueil and iOS-Accueil-Clair): the title of
/// the sidebar filter, search, new download, the download in progress over
/// its own picture, then every matching download as a poster. Selecting one
/// opens today's inspector in a glass panel.
class IosHome extends ConsumerWidget {
  const IosHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDownloadIdProvider);
    final narrow = MediaQuery.sizeOf(context).width < 1100;
    // Narrow windows: the inspector opens as a sheet, like today's library.
    ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
      if (!narrow || next == null || next == previous) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: DownloadInspector(downloadId: next),
        ),
      ).whenComplete(() {
        if (ref.read(selectedDownloadIdProvider) == next) {
          ref.read(selectedDownloadIdProvider.notifier).state = null;
        }
      });
    });
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              DownloadSearchFocus.request,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              DownloadSearchFocus.request,
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _HomeScroll()),
            if (selected != null && !narrow)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 14, 14, 14),
                child: SizedBox(
                  width: 380,
                  child: IosGlass(
                    radius: 28,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: IosFramed(
                        child: DownloadInspector(downloadId: selected),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the library is: still loading, unreadable, empty or filled.
enum _Phase { loading, error, empty, ready }

_Phase _phaseOf(AsyncValue<List<DownloadItem>> s) {
  if (s.hasValue) return s.requireValue.isEmpty ? _Phase.empty : _Phase.ready;
  return s.hasError ? _Phase.error : _Phase.loading;
}

class _HomeScroll extends ConsumerStatefulWidget {
  const _HomeScroll();

  @override
  ConsumerState<_HomeScroll> createState() => _HomeScrollState();
}

class _HomeScrollState extends ConsumerState<_HomeScroll>
    with SingleTickerProviderStateMixin {
  /// The skeletons' breathing, running only while loading.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse(_Phase phase) {
    final still = MediaQuery.disableAnimationsOf(context);
    if (phase == _Phase.loading && !still) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Phase changes only: progress ticks never rebuild the page.
    final phase = ref.watch(downloadListProvider.select(_phaseOf));
    _syncPulse(phase);
    final status = ref.watch(downloadStatusFilterProvider);
    final title = switch (status) {
      DownloadStatusFilter.active => l10n.designInProgress,
      DownloadStatusFilter.failed => l10n.iosFailures,
      DownloadStatusFilter.completed => l10n.sidebarCompleted,
      _ => l10n.librarySection,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        // Content capped at 1240 on very wide windows.
        final side = width > 1296 ? (width - 1240) / 2 : 28.0;
        final inner = width - 2 * side;
        final columns = ((inner + 20) / (220 + 20)).floor().clamp(1, 6);
        final posterWidth = (inner - 20 * (columns - 1)) / columns;
        EdgeInsets pad(double top, double bottom) =>
            EdgeInsets.fromLTRB(side, top, side, bottom);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: pad(22, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  title: title,
                  narrow: inner < 620,
                  // No filters while empty: onboarding points at the title.
                  markLibrary: phase == _Phase.empty || phase == _Phase.error,
                ),
              ),
            ),
            SliverPadding(
              padding: pad(22, 0),
              sliver: SliverToBoxAdapter(
                child: switch (phase) {
                  _Phase.ready => const _Hero(),
                  _Phase.loading => IosBone(
                    pulse: _pulse,
                    radius: 32,
                    height: 268,
                  ),
                  // Onboarding points at the list: here, the state card.
                  _Phase.empty => KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: const IosEmptyLibrary(),
                  ),
                  _Phase.error => KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: IosLoadError(
                      error: ref.read(downloadListProvider).error ?? '',
                    ),
                  ),
                },
              ),
            ),
            if (phase == _Phase.ready || phase == _Phase.loading)
              SliverPadding(
                padding: pad(22, 14),
                sliver: const SliverToBoxAdapter(child: _RecentBar()),
              ),
            if (phase == _Phase.loading)
              SliverPadding(
                padding: pad(6, 28),
                sliver: SliverGrid.count(
                  crossAxisCount: columns,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 4 / 3,
                  children: [
                    for (var i = 0; i < columns * 2; i++)
                      IosBone(pulse: _pulse),
                  ],
                ),
              )
            else if (phase == _Phase.ready)
              SliverPadding(
                padding: pad(6, 28),
                sliver: _Posters(
                  columns: columns,
                  extent: posterWidth * 3 / 4 + 58,
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.narrow,
    required this.markLibrary,
  });

  final String title;
  final bool narrow;
  final bool markLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = KeyedSubtree(
      key: OnboardingTargets.topBar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!narrow) ...[
            const SizedBox(width: 260, child: _SearchField()),
            const SizedBox(width: 12),
          ],
          const _SortMenu(),
          const SizedBox(width: 10),
          DownloadMoreActionsMenu(
            showQueueActions: true,
            showRetryFailed: true,
            child: const _RoundGlyph(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: 10),
          KeyedSubtree(
            key: OnboardingTargets.newDownload,
            child: IosRoundButton(
              icon: Icons.add_rounded,
              tooltip: l10n.newDownload,
              primary: true,
              onTap: () => openNewDownload(context),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: markLibrary
                  ? KeyedSubtree(
                      key: OnboardingTargets.library,
                      child: IosTitle(title),
                    )
                  : IosTitle(title),
            ),
            const SizedBox(width: 12),
            actions,
          ],
        ),
        if (narrow) ...[const SizedBox(height: 14), const _SearchField()],
      ],
    );
  }
}

/// A round glass glyph a popup menu opens from (it handles the tap).
class _RoundGlyph extends StatelessWidget {
  const _RoundGlyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return SizedBox.square(
      dimension: 44,
      child: IosGlass(
        radius: 22,
        child: Center(child: Icon(icon, size: 19, color: t.text)),
      ),
    );
  }
}

/// The glass search capsule (Ctrl+F focuses it).
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _controller = TextEditingController(
    text: ref.read(downloadSearchQueryProvider),
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    DownloadSearchFocus.attach(_focus);
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    // « Effacer les filtres » elsewhere empties the field too.
    ref.listen<String>(downloadSearchQueryProvider, (previous, next) {
      if (next != _controller.text) _controller.text = next;
    });
    return SizedBox(
      height: 44,
      child: IosGlass(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: t.sub),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: (v) {
                  ref.read(downloadSearchQueryProvider.notifier).state = v;
                  setState(() {});
                },
                style: iosText(t, size: 15, weight: FontWeight.w500),
                cursorColor: t.blueFill,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.search,
                  hintStyle: iosText(
                    t,
                    size: 15,
                    weight: FontWeight.w500,
                    color: t.sub,
                  ),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IosTap(
                onTap: () {
                  _controller.clear();
                  ref.read(downloadSearchQueryProvider.notifier).state = '';
                  setState(() {});
                },
                tooltip: l10n.iosClearSearch,
                semanticLabel: l10n.iosClearSearch,
                builder: (context, hover) => Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: hover ? t.text : t.sub,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sort = ref.watch(downloadSortProvider);
    final options = {
      DownloadSort.dateDesc: l10n.sortDateNewest,
      DownloadSort.dateAsc: l10n.sortDateOldest,
      DownloadSort.nameAsc: l10n.sortNameAsc,
      DownloadSort.sizeDesc: l10n.sortSizeLargest,
    };
    return PopupMenuButton<DownloadSort>(
      tooltip: l10n.sortBy,
      initialValue: sort,
      position: PopupMenuPosition.under,
      onSelected: (s) => ref.read(downloadSortProvider.notifier).state = s,
      itemBuilder: (context) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == sort,
            child: Text(e.value),
          ),
      ],
      child: const _RoundGlyph(Icons.swap_vert_rounded),
    );
  }
}

// ── Hero: the download in progress ──────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    // Live copies: this card is the only one that follows progress ticks.
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final main =
        active.firstOrNull ??
        items.where((i) => i.status == DownloadStatus.paused).firstOrNull;
    if (main == null) {
      return _Idle(
        failed: items.where((i) => i.status == DownloadStatus.failed).length,
      );
    }
    return _Current(item: main);
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.failed});

  final int failed;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    return IosGlass(
      radius: 32,
      padding: const EdgeInsets.fromLTRB(26, 22, 22, 22),
      child: Row(
        children: [
          const IosStateArt(icon: Icons.check_rounded, size: 76),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.designNothingActive,
                  style: iosText(
                    t,
                    size: 19,
                    weight: FontWeight.w800,
                    spacing: -0.4,
                  ),
                ),
                if (failed > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.iosFailedCount(failed),
                    style: iosText(t, size: 13.5, color: t.red),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          IosButton(
            label: l10n.newDownload,
            icon: Icons.add_rounded,
            kind: IosButtonKind.primary,
            height: 44,
            onTap: () => openNewDownload(context),
          ),
        ],
      ),
    );
  }
}

class _Current extends ConsumerWidget {
  const _Current({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(downloadListProvider.notifier);
    final paused = item.status == DownloadStatus.paused;
    final percent = (item.progress * 100).clamp(0, 100).round();
    final source = item.source;
    const white = Colors.white;
    final t = IosTokens.of(context);
    return Semantics(
      container: true,
      label: l10n.designInProgress,
      child: Container(
        height: 268,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 70,
              offset: Offset(0, 30),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IosThumb(
                url: item.thumbnailUrl,
                filePath: item.filePath,
                seed: 6,
                decodeWidth: 1400,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00040812), Color(0xB8040812)],
                    stops: [0.3, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Chip(
                            label: [
                              paused
                                  ? l10n.statusPaused
                                  : l10n.designInProgress,
                              if (source.isNotEmpty) source,
                            ].join(' · '),
                            live: !paused,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            titleOf(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: iosText(
                              t,
                              size: 30,
                              weight: FontWeight.w800,
                              spacing: -0.9,
                              color: white,
                            ).copyWith(height: 1.05),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  value: '$percent %',
                                  child: IosBar(
                                    value: item.progress,
                                    height: 8,
                                    color: white,
                                    track: const Color(0x38FFFFFF),
                                    glow: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$percent %',
                                style: iosText(
                                  t,
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _line(l10n, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: iosText(
                              t,
                              size: 13,
                              color: const Color(0xD1FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    IosRoundButton(
                      icon: paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      tooltip: paused ? l10n.resume : l10n.pause,
                      size: 54,
                      onImage: true,
                      onTap: () => paused
                          ? notifier.resumeDownload(item.id)
                          : notifier.pauseDownload(item.id),
                    ),
                    const SizedBox(width: 10),
                    IosRoundButton(
                      icon: Icons.close_rounded,
                      tooltip: l10n.cancel,
                      size: 54,
                      onImage: true,
                      onTap: () => notifier.cancelDownload(item.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "54,1 Mo sur 87,3 Mo · 6,2 Mo/s · reste 5 s".
  static String _line(AppLocalizations l10n, DownloadItem item) {
    String size(String raw) {
      final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
      return bytes > 0 ? localBytes(l10n, bytes) : '';
    }

    final done = size(item.downloadedSize);
    final total = size(item.totalSize);
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final rate = formatSpeed(l10n, speed);
    return [
      if (total.isNotEmpty)
        done.isEmpty ? total : l10n.nocturneSizeOf(done, total),
      if (item.status == DownloadStatus.paused)
        l10n.statusPaused
      else if (phase != null)
        livePhaseLabel(l10n, phase)
      else if (speed != null)
        '${rate.value} ${rate.unit}',
      if (item.eta.isNotEmpty && isActiveDownload(item))
        l10n.iosEtaLeft(etaLabel(l10n, item.eta)),
    ].join(' · ');
  }
}

/// The frosted chip over the picture: « ● En cours · YouTube ».
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return CustomPaint(
      painter: IosGlassPainter(
        top: const Color(0x3DFFFFFF),
        bottom: const Color(0x24FFFFFF),
        edge: const Color(0x4DFFFFFF),
        highlight: const Color(0x80FFFFFF),
        radius: 13,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? const Color(0xFF5CF28E) : const Color(0xFFFFD60A),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: iosText(
                t,
                size: 12,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Posters ─────────────────────────────────────────────────────────────────

/// « Récents » and the media-kind capsule.
class _RecentBar extends ConsumerWidget {
  const _RecentBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ref.watch(iosKindFilterProvider);
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          IosHeading(l10n.iosRecent),
          IosSegmented<MediaKind?>(
            value: kind,
            onChanged: (k) =>
                ref.read(iosKindFilterProvider.notifier).state = k,
            segments: [
              (null, l10n.designFilterAll),
              (MediaKind.video, l10n.designFilterVideo),
              (MediaKind.audio, l10n.designFilterAudio),
              (MediaKind.image, l10n.designFilterImages),
            ],
          ),
        ],
      ),
    );
  }
}

class _Posters extends ConsumerWidget {
  const _Posters({required this.columns, required this.extent});

  final int columns;
  final double extent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(iosKindFilterProvider);
    final all =
        ref.watch(filteredDownloadsProvider).valueOrNull ??
        const <DownloadItem>[];
    final items = kind == null
        ? all
        : [
            for (final i in all)
              if (mediaKindOf(i) == kind) i,
          ];
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: KeyedSubtree(
          key: OnboardingTargets.creatorList,
          child: IosNoResults(
            onClear: () {
              ref.read(downloadSearchQueryProvider.notifier).state = '';
              ref.read(downloadStatusFilterProvider.notifier).state =
                  DownloadStatusFilter.all;
              ref.read(downloadSourceFilterProvider.notifier).state = null;
              ref.read(iosKindFilterProvider.notifier).state = null;
            },
          ),
        ),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: extent,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final poster = IosPoster(
          key: ValueKey(items[index].id),
          base: items[index],
        );
        // The onboarding points at the list through its first poster.
        return index == 0
            ? KeyedSubtree(key: OnboardingTargets.creatorList, child: poster)
            : poster;
      }, childCount: items.length),
    );
  }
}

/// One download as a poster: its picture (4:3, radius 22), the title and a
/// line of detail; lifts on hover. Tap selects, double tap plays.
class IosPoster extends ConsumerWidget {
  const IosPoster({super.key, required this.base});

  final DownloadItem base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(downloadRuntimeItemProvider(base.id)) ?? base;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final busy =
        isActiveDownload(item) ||
        item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.queued;
    final kind = mediaKindOf(item);
    return DownloadItemContextMenu(
      item: item,
      child: IosTap(
        radius: 22,
        selected: selected,
        semanticLabel: titleOf(item),
        onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
            selected ? null : item.id,
        onDoubleTap: () {
          final path = item.filePath;
          if (path != null && File(path).existsSync()) {
            ref.read(mediaPlayerProvider.notifier).openFile(path);
          }
        },
        builder: (context, hover) => AnimatedContainer(
          duration: iosMotion(context, 350),
          curve: iosEase,
          transform: hover && !reduce
              ? (Matrix4.translationValues(0, -6, 0)
                  ..multiply(Matrix4.diagonal3Values(1.015, 1.015, 1)))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x47000000),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? t.blueFill
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IosThumb(
                        url: item.thumbnailUrl,
                        filePath: item.filePath,
                        seed: item.id.hashCode,
                        icon: switch (kind) {
                          MediaKind.audio => Icons.graphic_eq_rounded,
                          MediaKind.image => Icons.image_outlined,
                          MediaKind.video => null,
                        },
                      ),
                      if (busy)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: IosBar(
                            value: item.progress,
                            color: Colors.white,
                            track: const Color(0x52000000),
                            glow: isActiveDownload(item),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (failed) ...[
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.redFill,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '!',
                        style: iosText(
                          t,
                          size: 12,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      titleOf(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: iosText(
                        t,
                        size: 15,
                        weight: FontWeight.w700,
                        spacing: -0.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _meta(l10n, item, failed),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: iosText(t, size: 13, color: failed ? t.red : t.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _meta(AppLocalizations l10n, DownloadItem item, bool failed) {
    if (failed) {
      final reason = downloadErrorReason(item.error);
      return reason.isEmpty ? l10n.designFailed : reason;
    }
    if (item.status == DownloadStatus.queued) return l10n.statusQueued;
    if (item.status == DownloadStatus.paused) return l10n.statusPaused;
    if (isActiveDownload(item)) {
      final rate = formatSpeed(l10n, parseSpeed(item.speed));
      return [
        '${(item.progress * 100).clamp(0, 100).round()} %',
        if (rate.unit.isNotEmpty) '${rate.value} ${rate.unit}',
      ].join(' · ');
    }
    final size = bytesOf(item);
    return [
      item.source,
      if (size > 0) localBytes(l10n, size),
    ].where((s) => s.isNotEmpty).join(' · ');
  }
}
