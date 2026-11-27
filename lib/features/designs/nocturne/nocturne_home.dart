import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/core/ui/shell/shell_strips.dart'
    show libraryFilterSources;
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_row_host.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_widgets.dart' show SignalThumb;
import 'nocturne_inspector.dart';
import 'nocturne_library.dart';
import 'nocturne_states.dart';
import 'nocturne_widgets.dart';

/// Nocturne's home (mockup Nocturne.dc.html): greeting, the download in
/// progress as a ring, what comes next, the latest finished, then the whole
/// library (filters, search, sort, list, inspector, context menu).
class NocturneHome extends ConsumerWidget {
  const NocturneHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDownloadIdProvider);
    final colors = AppColors.of(context);
    // Narrow windows: the inspector opens as a sheet, like today's library.
    final narrow = MediaQuery.sizeOf(context).width < 1000;
    ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
      if (!narrow || next == null || next == previous) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: NocturneInspector(downloadId: next),
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
          children: [
            const Expanded(child: _HomeScroll()),
            if (selected != null && !narrow)
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    left: BorderSide(
                      color: colors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: NocturneInspector(downloadId: selected),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeScroll extends ConsumerStatefulWidget {
  const _HomeScroll();

  @override
  ConsumerState<_HomeScroll> createState() => _HomeScrollState();
}

/// What the library is: still loading, unreadable, empty or filled.
enum _Phase { loading, error, empty, ready }

_Phase _phaseOf(AsyncValue<List<DownloadItem>> s) {
  if (s.hasValue) return s.requireValue.isEmpty ? _Phase.empty : _Phase.ready;
  return s.hasError ? _Phase.error : _Phase.loading;
}

class _HomeScrollState extends ConsumerState<_HomeScroll>
    with TickerProviderStateMixin {
  final _libraryKey = GlobalKey();

  /// One-shot rise of the first rows, played once the library is filled.
  late final AnimationController _entrance;
  bool _entranceStarted = false;

  /// The skeletons' moonlight sweep, running only while loading.
  late final AnimationController _shimmer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _syncMotion(_Phase phase) {
    final still = MediaQuery.disableAnimationsOf(context);
    if (phase == _Phase.loading && !still) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else if (_shimmer.isAnimating) {
      _shimmer.stop();
    }
    if (phase == _Phase.ready && !_entranceStarted) {
      _entranceStarted = true;
      if (still) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrance.forward();
      });
    }
  }

  void _showLibrary() {
    final target = _libraryKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: nocturneMotion(context, 350),
      curve: nocturneEase,
    );
  }

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // "En cours" clicked from another page: the filter is already set.
    if (ref.read(downloadStatusFilterProvider) == DownloadStatusFilter.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLibrary();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The rail's "En cours" sets the active filter: bring the library in view.
    ref.listen<DownloadStatusFilter>(downloadStatusFilterProvider, (
      prev,
      next,
    ) {
      if (next == DownloadStatusFilter.active) _showLibrary();
    });
    final mode = ref.watch(downloadViewModeProvider);
    // Phase changes only: progress ticks never rebuild the page.
    final phase = ref.watch(downloadListProvider.select(_phaseOf));
    _syncMotion(phase);
    final filled = phase == _Phase.ready;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 900;
        // 40px gutters, content capped at 1240 on very wide windows.
        final side = width > 1320 ? (width - 1240) / 2 : (wide ? 40.0 : 20.0);
        EdgeInsets pad(double top, double bottom) =>
            EdgeInsets.fromLTRB(side, top, side, bottom);
        final columns = ((width - 2 * side + 14) / (260 + 14)).floor().clamp(
          1,
          6,
        );
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: pad(34, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(context.l10n),
                            style: nocturneText(
                              AppColors.of(context),
                              size: 13,
                              color: AppColors.of(context).textDisabled,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (phase == _Phase.loading)
                            NocturneTitleSkeleton(shimmer: _shimmer)
                          else
                            const _ActiveTitle(),
                        ],
                      ),
                    ),
                    // The empty state carries the one "new download" action.
                    if (phase != _Phase.empty) ...[
                      const SizedBox(width: 16),
                      NocturneButton(
                        label: context.l10n.newDownload,
                        kind: NocturneButtonKind.primary,
                        height: 42,
                        radius: 14,
                        fontSize: 13.5,
                        padding: 20,
                        onTap: () => openNewDownload(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: pad(26, 0),
              sliver: SliverToBoxAdapter(
                child: switch (phase) {
                  _Phase.ready => _HeroCard(wide: wide),
                  _Phase.loading => NocturneHeroSkeleton(shimmer: _shimmer),
                  // Onboarding points at the list: here, the state card.
                  _Phase.empty => KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: const NocturneEmptyLibrary(),
                  ),
                  _Phase.error => KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: NocturneLoadError(
                      error: ref.read(downloadListProvider).error ?? '',
                    ),
                  ),
                },
              ),
            ),
            if (filled)
              SliverPadding(
                padding: pad(26, 0),
                sliver: SliverToBoxAdapter(child: _Recent(columns: columns)),
              ),
            SliverPadding(
              padding: pad(40, 14),
              sliver: SliverToBoxAdapter(
                child: KeyedSubtree(key: _libraryKey, child: const _Toolbar()),
              ),
            ),
            if (phase == _Phase.loading)
              SliverPadding(
                padding: pad(0, 48),
                sliver: SliverToBoxAdapter(
                  child: NocturneRowsSkeleton(
                    shimmer: _shimmer,
                    columns: wide ? 2 : 1,
                  ),
                ),
              )
            else if (!filled)
              const SliverToBoxAdapter(child: SizedBox(height: 48))
            else if (mode == DownloadViewMode.list)
              SliverPadding(
                padding: pad(0, 48),
                sliver: _LibraryGrid(
                  columns: wide ? 2 : 1,
                  entrance: _entrance,
                ),
              )
            else
              // Detailed cards and creator folders, drawn as Nocturne cards.
              SliverPadding(
                padding: pad(0, 48),
                sliver: _LibraryOther(mode: mode, columns: columns),
              ),
          ],
        );
      },
    );
  }

  static String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return l10n.nocturneGreetingMorning;
    if (hour >= 12 && hour < 18) return l10n.nocturneGreetingAfternoon;
    return l10n.nocturneGreetingEvening;
  }
}

/// "2 téléchargements en cours": status changes only, not progress ticks.
class _ActiveTitle extends ConsumerWidget {
  const _ActiveTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      downloadListProvider.select(
        (s) => (s.valueOrNull ?? const <DownloadItem>[])
            .where(isActiveDownload)
            .length,
      ),
    );
    return Text(
      context.l10n.nocturneActiveTitle(count),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: nocturneDisplay(AppColors.of(context)),
    );
  }
}

// ── Hero: the download in progress ──────────────────────────────────────────

class _HeroCard extends ConsumerStatefulWidget {
  const _HeroCard({required this.wide});

  final bool wide;

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

/// Key of the finish moment's bloom (tests look for it).
const nocturneFinishBloomKey = ValueKey('nocturne-finish-bloom');

class _HeroCardState extends ConsumerState<_HeroCard>
    with SingleTickerProviderStateMixin {
  /// The finish moment: the ring closes to 100 %, a check settles in and a
  /// soft bloom spreads from the ring, under a second.
  late final AnimationController _finish;
  DownloadItem? _finished;
  double _from = 0;
  String? _shownId;
  double _shownProgress = 0;

  @override
  void initState() {
    super.initState();
    _finish = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _finish.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _finished = null);
      }
    });
  }

  @override
  void dispose() {
    _finish.dispose();
    super.dispose();
  }

  /// An item that was active a moment ago and is now completed.
  void _onList(
    AsyncValue<List<DownloadItem>>? previous,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final before = previous?.valueOrNull;
    final after = next.valueOrNull;
    if (before == null || after == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final wasActive = {
      for (final i in before)
        if (isActiveDownload(i)) i.id,
    };
    final done = after.where(
      (i) => i.status == DownloadStatus.completed && wasActive.contains(i.id),
    );
    if (done.isEmpty) return;
    final item = done.first;
    setState(() {
      _finished = item;
      _from = item.id == _shownId ? _shownProgress : 0.9;
    });
    _finish.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(downloadListProvider, _onList);
    final wide = widget.wide;
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    // Live copies: this card is the only one that follows progress ticks.
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final paused = [
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final queued = [
      for (final i in items)
        if (i.status == DownloadStatus.queued) i,
    ];
    final failedCount = items
        .where((i) => i.status == DownloadStatus.failed)
        .length;
    final finished = _finished;
    final main = active.isNotEmpty
        ? active.first
        : (paused.isNotEmpty ? paused.first : null);
    final next = [
      if (finished != null && main != null) main,
      ...active.skip(1),
      ...paused.where((p) => p != main),
      ...queued,
    ].firstOrNull;
    _shownId = main?.id;
    _shownProgress = main?.progress ?? 0;

    final current = finished != null
        ? _Finished(item: finished)
        : main == null
        ? _Idle(l10n: l10n, failedCount: failedCount)
        : _Current(item: main);
    final ring = finished != null
        ? _FinishRing(animation: _finish, from: _from)
        : NocturneRing(
            value: main?.progress ?? 0,
            size: 112,
            stroke: 8,
            radius: 46,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${((main?.progress ?? 0) * 100).clamp(0, 100).round()}%',
                  style: nocturneMono(
                    c,
                    size: 22,
                    color: c.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                if (main != null &&
                    main.eta.isNotEmpty &&
                    isActiveDownload(main))
                  Text(
                    etaLabel(l10n, main.eta),
                    style: nocturneText(c, size: 11, color: c.textDisabled),
                  ),
              ],
            ),
          );
    final after = _Next(item: next);
    return NocturneCard(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: wide
          ? Row(
              children: [
                ring,
                const SizedBox(width: 28),
                Expanded(flex: 51, child: current),
                const SizedBox(width: 28),
                Expanded(flex: 39, child: after),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ring,
                    const SizedBox(width: 24),
                    Expanded(child: current),
                  ],
                ),
                const SizedBox(height: 22),
                after,
              ],
            ),
    );
  }
}

class _Idle extends ConsumerWidget {
  const _Idle({required this.l10n, required this.failedCount});

  final AppLocalizations l10n;
  final int failedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.designNothingActive,
          style: nocturneText(c, size: 15, weight: FontWeight.w600),
        ),
        if (failedCount > 1) ...[
          const SizedBox(height: 4),
          Text(
            l10n.nocturneFailedCount(failedCount),
            style: nocturneText(c, size: 12.5, color: c.error),
          ),
        ],
        const SizedBox(height: 16),
        NocturneButton(
          label: l10n.newDownload,
          height: 34,
          radius: 11,
          padding: 14,
          weight: FontWeight.w400,
          onTap: () => openNewDownload(context),
        ),
      ],
    );
  }
}

/// The hero's text while the finish moment plays.
class _Finished extends StatelessWidget {
  const _Finished({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final size = bytesOf(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statusCompleted,
          style: nocturneText(
            c,
            size: 12,
            weight: FontWeight.w600,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titleOf(item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nocturneText(
            c,
            size: 19,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: -0.3),
        ),
        const SizedBox(height: 6),
        Text(
          [
            item.source,
            formatLabelOf(item),
            if (size > 0) localBytes(l10n, size),
          ].where((s) => s.isNotEmpty).join(' · '),
          style: nocturneMono(c),
        ),
      ],
    );
  }
}

/// The ring closing from [from] to 100 %, the check settling in, then a
/// soft bloom spreading and fading around it.
class _FinishRing extends StatelessWidget {
  const _FinishRing({required this.animation, required this.from});

  final Animation<double> animation;
  final double from;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final close = Curves.easeOutCubic.transform((t / 0.45).clamp(0, 1));
          final check = Curves.easeOutBack.transform(
            ((t - 0.35) / 0.3).clamp(0, 1),
          );
          final bloom = Curves.easeOut.transform(((t - 0.4) / 0.6).clamp(0, 1));
          return SizedBox.square(
            dimension: 112,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  key: nocturneFinishBloomKey,
                  scale: 0.9 + bloom * 0.55,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.primary.withValues(alpha: 0.45 * (1 - bloom)),
                          c.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                NocturneRing(
                  value: from + (1 - from) * close,
                  size: 112,
                  stroke: 8,
                  radius: 46,
                ),
                Transform.scale(
                  scale: check,
                  child: Icon(Icons.check_rounded, size: 40, color: c.primary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Current extends ConsumerWidget {
  const _Current({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(downloadListProvider.notifier);
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final rate = formatSpeed(l10n, speed);
    final done = sizeLabel(l10n, item.downloadedSize);
    final total = sizeLabel(l10n, item.totalSize);
    final paused = item.status == DownloadStatus.paused;
    final line = [
      if (total.isNotEmpty)
        done.isEmpty ? total : l10n.nocturneSizeOf(done, total),
      if (paused)
        l10n.statusPaused
      else if (phase != null)
        livePhaseLabel(l10n, phase)
      else if (speed != null)
        '${rate.value} ${rate.unit}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            item.source,
            formatLabelOf(item),
          ].where((s) => s.isNotEmpty).join(' · '),
          style: nocturneText(
            c,
            size: 12,
            weight: FontWeight.w600,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titleOf(item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nocturneText(
            c,
            size: 19,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: -0.3),
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(line, style: nocturneMono(c)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            NocturneButton(
              label: paused ? l10n.resume : l10n.pause,
              height: 34,
              radius: 11,
              padding: 14,
              weight: FontWeight.w400,
              onTap: () => paused
                  ? notifier.resumeDownload(item.id)
                  : notifier.pauseDownload(item.id),
            ),
            const SizedBox(width: 8),
            NocturneButton(
              label: l10n.cancel,
              kind: NocturneButtonKind.ghost,
              height: 34,
              radius: 11,
              padding: 14,
              weight: FontWeight.w400,
              onTap: () => notifier.cancelDownload(item.id),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Ensuite": the next download (second active, paused or queued).
class _Next extends StatelessWidget {
  const _Next({required this.item});

  final DownloadItem? item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final next = item;
    String meta() {
      if (next == null) return '';
      if (next.status == DownloadStatus.queued) return l10n.statusQueued;
      if (next.status == DownloadStatus.paused) return l10n.statusPaused;
      final rate = formatSpeed(l10n, parseSpeed(next.speed));
      return '${(next.progress * 100).round()} % · ${rate.value} ${rate.unit}'
          .trim();
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(start: 22),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: c.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.nocturneNext,
            style: nocturneText(c, size: 12, color: c.textDisabled),
          ),
          const SizedBox(height: 10),
          Text(
            next == null ? l10n.designQueueEmpty : titleOf(next),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nocturneText(
              c,
              weight: next == null ? FontWeight.w400 : FontWeight.w600,
              color: next == null ? c.textSecondary : c.textPrimary,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            NocturneBar(value: next.progress),
            const SizedBox(height: 10),
            Text(meta(), style: nocturneMono(c)),
          ],
        ],
      ),
    );
  }
}

// ── Latest finished ─────────────────────────────────────────────────────────

class _Recent extends ConsumerWidget {
  const _Recent({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    // No dates on downloads: the newest finished (or failed) by sort order.
    final done = [
      for (final i in items)
        if (i.status == DownloadStatus.completed ||
            i.status == DownloadStatus.failed ||
            i.status == DownloadStatus.canceled)
          i,
    ]..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    final shown = done.take(columns >= 4 ? 4 : columns * 2).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.nocturneRecent,
          style: nocturneText(c, size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final item in shown)
                  SizedBox(
                    width: w,
                    child: _RecentCard(item: item),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentCard extends ConsumerStatefulWidget {
  const _RecentCard({required this.item});

  final DownloadItem item;

  @override
  ConsumerState<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends ConsumerState<_RecentCard> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final failed = item.status != DownloadStatus.completed;
    final size = bytesOf(item);
    return DownloadItemContextMenu(
      item: item,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () =>
              ref.read(selectedDownloadIdProvider.notifier).state = item.id,
          onDoubleTap: () => playDownload(ref, item),
          onFocusChange: (v) => setState(() => _focus = v),
          borderRadius: BorderRadius.circular(18),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: c.primary.withValues(alpha: 0.04),
          splashColor: c.primary.withValues(alpha: 0.06),
          child: NocturneCard(
            highlight: _focus,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SignalThumb(
                  url: item.thumbnailUrl,
                  filePath: item.filePath,
                  width: 64,
                  height: 64,
                  radius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleOf(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nocturneText(c, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (failed)
                        Row(
                          children: [
                            Text(
                              '${l10n.designFailed} · ',
                              style: nocturneText(c, size: 12, color: c.error),
                            ),
                            _Link(
                              label: l10n.retry,
                              onTap: () => ref
                                  .read(downloadListProvider.notifier)
                                  .retryDownload(item),
                            ),
                          ],
                        )
                      else
                        Text(
                          [
                            item.source,
                            if (mediaKindOf(item) == MediaKind.audio)
                              l10n.designFilterAudio.toLowerCase(),
                            if (size > 0) localBytes(l10n, size),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nocturneText(
                            c,
                            size: 12,
                            color: c.textDisabled,
                          ),
                        ),
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

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: nocturneText(c, size: 12, color: c.error).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: c.error,
          ),
        ),
      ),
    );
  }
}

// ── Library ─────────────────────────────────────────────────────────────────

/// Title, status and source filters, then today's toolbar (search, failed
/// badge, queue controls, sort and view, more actions).
class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );
    final sources = libraryFilterSources(counts.sourceCounts, adult);
    void setStatus(DownloadStatusFilter s) {
      ref.read(downloadSourceFilterProvider.notifier).state = null;
      ref.read(downloadStatusFilterProvider.notifier).state = s;
    }

    void setSource(String s) {
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
      ref.read(downloadSourceFilterProvider.notifier).state = source == s
          ? null
          : s;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: OnboardingTargets.library,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.librarySection,
                    style: nocturneText(c, size: 15, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${counts.total}',
                    style: nocturneMono(c, size: 12, color: c.textDisabled),
                  ),
                  const Spacer(),
                  // Several failures: one tap relaunches them all, whatever
                  // else is downloading.
                  if (counts.failed > 1)
                    NocturneButton(
                      label: '${l10n.retryFailedAction} (${counts.failed})',
                      kind: NocturneButtonKind.danger,
                      icon: Icons.refresh_rounded,
                      height: 32,
                      radius: 11,
                      padding: 13,
                      onTap: () => ref
                          .read(downloadListProvider.notifier)
                          .retryAllFailed(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    NocturneSegmented<DownloadStatusFilter?>(
                      height: 32,
                      padding: 13,
                      value: source == null ? status : null,
                      onChanged: (s) => setStatus(s!),
                      segments: [
                        NocturneSegment(
                          DownloadStatusFilter.all,
                          l10n.designFilterAll,
                          count: '${counts.total}',
                        ),
                        NocturneSegment(
                          DownloadStatusFilter.active,
                          l10n.designInProgress,
                          count: '${counts.active}',
                        ),
                        NocturneSegment(
                          DownloadStatusFilter.completed,
                          l10n.sidebarCompleted,
                          count: '${counts.completed}',
                        ),
                        NocturneSegment(
                          DownloadStatusFilter.failed,
                          l10n.sidebarFailed,
                          count: '${counts.failed}',
                        ),
                      ],
                    ),
                    if (sources.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      NocturneSegmented<String?>(
                        height: 32,
                        padding: 13,
                        value: source,
                        onChanged: (s) => setSource(s!),
                        segments: [
                          for (final s in sources)
                            NocturneSegment(
                              s,
                              s,
                              count: '${counts.sourceCounts[s]}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Search (Ctrl+F), queue controls, sort and view modes, more actions.
        NocturneLibraryToolbar(key: OnboardingTargets.topBar),
      ],
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.columns, required this.entrance});

  final int columns;

  /// The page's one-shot entrance; only the first rows read it.
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(filteredDownloadsProvider).valueOrNull ??
        const <DownloadItem>[];
    // Only shown once the library is filled: nothing here means no match.
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: NocturneNoResults(key: OnboardingTargets.creatorList),
        ),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 76,
        crossAxisSpacing: 14,
        mainAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        Widget row = _LibraryRow(itemId: items[index].id, base: items[index]);
        if (index < 12) {
          // Staggered fade and 10px rise, all within the 380ms entrance.
          final start = index * 0.04;
          // drive(): no listener left on the controller per built row.
          final curve = entrance.drive(
            CurveTween(
              curve: Interval(start, start + 0.52, curve: nocturneEase),
            ),
          );
          row = FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.14),
                end: Offset.zero,
              ).animate(curve),
              child: row,
            ),
          );
        }
        // The onboarding points at the list through its first row.
        return index == 0
            ? KeyedSubtree(key: OnboardingTargets.creatorList, child: row)
            : row;
      }, childCount: items.length),
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.itemId, required this.base});

  final String itemId;
  final DownloadItem base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(downloadRuntimeItemProvider(itemId)) ?? base;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final notifier = ref.read(downloadListProvider.notifier);
    return DownloadItemContextMenu(
      item: item,
      child: NocturneDownloadRow(
        item: item,
        selected: selected,
        onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
            selected ? null : item.id,
        // Failed rows have no file to lose: retry at once.
        onRetry: () => notifier.retryDownload(item),
        onDelete: () async {
          if (await confirmFileDeletion(
            context,
            item,
            actionLabel: context.l10n.delete,
          )) {
            await notifier.deleteDownload(item.id);
          }
        },
      ),
    );
  }
}

/// Detailed cards and creator folders. Rows go through the shared row host
/// (context menu, selection, delete confirmation), drawn by Nocturne's skin.
class _LibraryOther extends ConsumerWidget {
  const _LibraryOther({required this.mode, required this.columns});

  final DownloadViewMode mode;
  final int columns;

  static const _cards = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 300,
    mainAxisExtent: 262,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
  );

  Widget _rows(List<String> ids, {required bool grid}) {
    Widget host(int i) =>
        DownloadRowHost(key: ValueKey(ids[i]), id: ids[i], useGridCard: grid);
    // The onboarding points at the list through its first row.
    Widget at(BuildContext context, int i) => i == 0
        ? KeyedSubtree(key: OnboardingTargets.creatorList, child: host(i))
        : host(i);
    if (grid) {
      return SliverGrid(
        gridDelegate: _cards,
        delegate: SliverChildBuilderDelegate(at, childCount: ids.length),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns >= 3 ? 2 : 1,
        mainAxisExtent: 76,
        crossAxisSpacing: 14,
        mainAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate(at, childCount: ids.length),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // As the shared list did: leave a folder when the view or its content
    // changes under it.
    ref.listen(downloadViewModeProvider, (previous, next) {
      if (next != DownloadViewMode.folders) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    ref.listen(creatorFoldersProvider, (previous, next) {
      final opened = ref.read(openedCreatorFolderKeyProvider);
      if (opened != null && !next.folders.any((f) => f.key == opened)) {
        ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      }
    });
    final ids = ref.watch(filteredDownloadIdListProvider).ids;
    if (ids.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: NocturneNoResults(key: OnboardingTargets.creatorList),
        ),
      );
    }
    if (mode == DownloadViewMode.detailed) return _rows(ids, grid: true);
    final opened = ref.watch(openedCreatorFolderProvider);
    if (opened != null) {
      final inside = ref.watch(openedCreatorFolderItemIdsProvider).ids;
      final grid =
          ref.watch(folderContentsViewModeProvider) ==
          DownloadViewMode.detailed;
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NocturneFolderHeader(folder: opened),
            ),
          ),
          _rows(inside, grid: grid),
        ],
      );
    }
    final folders = ref.watch(creatorFoldersProvider).folders;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 236,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final tile = NocturneFolderTile(
          key: ValueKey(folders[i].key),
          folder: folders[i],
          onOpen: () => openCreatorFolder(ref, folders[i].key),
        );
        return i == 0
            ? KeyedSubtree(key: OnboardingTargets.creatorList, child: tile)
            : tile;
      }, childCount: folders.length),
    );
  }
}
