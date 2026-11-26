import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/core/ui/shell/shell_strips.dart'
    show libraryFilterSources;
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_top_bar.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_widgets.dart' show SignalThumb;
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
            if (selected != null)
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
                child: DownloadInspector(downloadId: selected),
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

class _HomeScrollState extends ConsumerState<_HomeScroll> {
  final _libraryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // The rail's "En cours" sets the active filter: bring the library in view.
    ref.listen<DownloadStatusFilter>(downloadStatusFilterProvider, (prev, next) {
      if (next != DownloadStatusFilter.active) return;
      final target = _libraryKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: nocturneMotion(context, 350),
        curve: nocturneEase,
      );
    });
    final mode = ref.watch(downloadViewModeProvider);
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
                          const _ActiveTitle(),
                        ],
                      ),
                    ),
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
                ),
              ),
            ),
            SliverPadding(
              padding: pad(26, 0),
              sliver: SliverToBoxAdapter(child: _HeroCard(wide: wide)),
            ),
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
            if (mode == DownloadViewMode.list)
              SliverPadding(
                padding: pad(0, 48),
                sliver: _LibraryGrid(columns: wide ? 2 : 1),
              )
            else
              // Detailed cards and creator folders: today's list, unchanged.
              SliverPadding(
                padding: pad(0, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: true,
                  child: KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: const DownloadList(),
                  ),
                ),
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final main = active.isNotEmpty
        ? active.first
        : (paused.isNotEmpty ? paused.first : null);
    final next = [
      ...active.skip(1),
      ...paused.where((p) => p != main),
      ...queued,
    ].firstOrNull;

    final current = main == null
        ? _Idle(l10n: l10n)
        : _Current(item: main);
    final ring = NocturneRing(
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
          if (main != null && main.eta.isNotEmpty && isActiveDownload(main))
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

class _Idle extends StatelessWidget {
  const _Idle({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.designNothingActive,
          style: nocturneText(c, size: 15, weight: FontWeight.w600),
        ),
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
          TitleCleanerService.clean(item.title ?? item.request.url),
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
            next == null
                ? l10n.designQueueEmpty
                : TitleCleanerService.clean(next.title ?? next.request.url),
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
    final done =
        [
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
                  SizedBox(width: w, child: _RecentCard(item: item)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentCard extends ConsumerWidget {
  const _RecentCard({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final failed = item.status != DownloadStatus.completed;
    final size = bytesOf(item);
    return DownloadItemContextMenu(
      item: item,
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedDownloadIdProvider.notifier).state = item.id,
        onDoubleTap: () => playDownload(ref, item),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: NocturneCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SignalThumb(
                  url: item.thumbnailUrl,
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
                        TitleCleanerService.clean(
                          item.title ?? item.request.url,
                        ),
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
                              style: nocturneText(
                                c,
                                size: 12,
                                color: c.error,
                              ),
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
    final adult = ref.watch(settingsProvider.select((s) => s.adultSitesEnabled));
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
        const SizedBox(height: 8),
        // Today's toolbar: search (Ctrl+F), failed badge, queue controls,
        // sort and view modes, more actions. Already in the palette.
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DownloadTopBar(key: OnboardingTargets.topBar),
        ),
      ],
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(filteredDownloadsProvider).valueOrNull ??
        const <DownloadItem>[];
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            key: OnboardingTargets.creatorList,
            l10n.designLibraryEmpty,
            style: nocturneText(c, color: c.textSecondary),
          ),
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
        final row = _LibraryRow(itemId: items[index].id, base: items[index]);
        // The onboarding points at the list through its first row.
        return index == 0
            ? KeyedSubtree(key: OnboardingTargets.creatorList, child: row)
            : row;
      }, childCount: items.length),
    );
  }
}

class _LibraryRow extends ConsumerStatefulWidget {
  const _LibraryRow({required this.itemId, required this.base});

  final String itemId;
  final DownloadItem base;

  @override
  ConsumerState<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends ConsumerState<_LibraryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final item =
        ref.watch(downloadRuntimeItemProvider(widget.itemId)) ?? widget.base;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final busy =
        isActiveDownload(item) ||
        item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.paused;
    final size = bytesOf(item);
    final meta = failed
        ? '${l10n.designFailed} · ${(item.error ?? '').split('\n').first}'
        : [
            item.source,
            formatLabelOf(item),
            if (size > 0) localBytes(l10n, size),
          ].where((s) => s.isNotEmpty).join(' · ');
    return DownloadItemContextMenu(
      item: item,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
              selected ? null : item.id,
          onDoubleTap: () => playDownload(ref, item),
          child: AnimatedContainer(
            duration: nocturneMotion(context, 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected || _hover ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? c.primary.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SignalThumb(
                  url: item.thumbnailUrl,
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
                        TitleCleanerService.clean(
                          item.title ?? item.request.url,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nocturneText(c, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nocturneText(
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
                AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: nocturneMotion(context, 180),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (failed)
                        NocturneIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: l10n.retry,
                          ghost: true,
                          onTap: () => ref
                              .read(downloadListProvider.notifier)
                              .retryDownload(item),
                        )
                      else if (item.status == DownloadStatus.completed) ...[
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
                      ],
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

void playDownload(WidgetRef ref, DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync()) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
  }
}

void revealDownload(DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync() && Platform.isWindows) {
    Process.run('explorer', ['/select,', path]);
  }
}

/// yt-dlp size strings ("54.1MiB") in the app's units; empty if none.
String sizeLabel(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}
