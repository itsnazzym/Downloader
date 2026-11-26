import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'signal_home.dart' show designFreeSpaceProvider;
import 'signal_states.dart';
import 'signal_widgets.dart';

/// Signal's statistics (mockup Signal-Stats.dc.html): four figures, the
/// daily chart, sources, formats, top creators, then keyboard shortcuts.
class SignalStats extends ConsumerWidget {
  const SignalStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // Nothing downloaded yet: zeros and an empty chart say nothing.
    final empty = ref.watch(
      downloadStatsProvider.select((s) => s.totalDownloads == 0),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: signalPagePadding(constraints.maxWidth, top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.statistics,
                style: AppTypography.display(
                  28,
                  weight: FontWeight.w600,
                ).copyWith(color: colors.textPrimary, height: 1.15),
              ),
              const SizedBox(height: 20),
              if (empty)
                SignalStateCard(
                  title: context.l10n.signalStatsEmptyTitle,
                  body: context.l10n.signalStatsEmptyBody,
                  art: const SignalEmptyArt(),
                  actions: [
                    SignalButton(
                      label: context.l10n.newDownload,
                      icon: Icons.add_link_rounded,
                      onTap: () => context.go('/'),
                    ),
                  ],
                )
              else ...[
                _KpiRow(wide: wide),
                const SizedBox(height: 16),
                signalRow(
                  wide: wide,
                  flexes: const [8, 4],
                  children: const [_ChartCard(), _SourcesCard()],
                ),
                const SizedBox(height: 16),
                signalRow(
                  wide: wide,
                  flexes: const [5, 7],
                  children: const [_FormatCard(), _CreatorsCard()],
                ),
              ],
              const SizedBox(height: 16),
              const _ShortcutsCard(),
            ],
          ),
        );
      },
    );
  }
}

String _count(BuildContext context, int n) =>
    NumberFormat.decimalPattern(context.l10n.localeName).format(n);

/// "418 Go" -> ("418", "Go").
(String, String) _split(String sized) {
  final i = sized.lastIndexOf(' ');
  return i < 0 ? (sized, '') : (sized.substring(0, i), sized.substring(i + 1));
}

// ── Figures ─────────────────────────────────────────────────────────────────

class _KpiRow extends ConsumerWidget {
  const _KpiRow({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = ref.watch(
      downloadStatsProvider.select((s) => s.totalDownloads),
    );
    final bytes = ref.watch(
      downloadStatsProvider.select((s) => s.totalBytesDownloaded),
    );
    final today = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsToday),
    );
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final volume = _split(localBytes(l10n, bytes));
    final freeSplit = free == null ? ('…', '') : _split(localBytes(l10n, free));
    final cards = [
      _Kpi(label: l10n.downloads, value: _count(context, total)),
      _Kpi(label: l10n.signalStatsVolume, value: volume.$1, unit: volume.$2),
      _Kpi(label: l10n.statsToday, value: _count(context, today), live: true),
      // The mockup's average speed has no source: free space takes its place.
      _Kpi(label: l10n.freeSpace, value: freeSplit.$1, unit: freeSplit.$2),
    ];
    if (wide) {
      return Row(
        key: OnboardingTargets.stats,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      key: OnboardingTargets.stats,
      children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: cards[r * 2]),
              const SizedBox(width: 16),
              Expanded(child: cards[r * 2 + 1]),
            ],
          ),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    this.unit = '',
    this.live = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SignalCard(
      lift: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (live) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: SignalEyebrow(label)),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SignalFigure(value: value, unit: unit, size: 44),
          ),
        ],
      ),
    );
  }
}

// ── Daily chart ─────────────────────────────────────────────────────────────

class _ChartCard extends ConsumerStatefulWidget {
  const _ChartCard();

  @override
  ConsumerState<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends ConsumerState<_ChartCard> {
  int? _days;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final history = ref.watch(
      downloadStatsProvider.select((s) => s.dailyHistory),
    );
    final today = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsToday),
    );
    final now = DateTime.now();
    // Desktop keeps 7 days of history once rebuilt from the library: offer
    // 30 days only when the history really reaches back that far.
    final oldest = history.isEmpty
        ? now
        : history
              .map((d) => DateTime.tryParse(d.date) ?? now)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final periods = [7, if (now.difference(oldest).inDays >= 7) 30];
    final days = periods.contains(_days) ? _days! : periods.last;
    final byDay = {for (final d in history) d.date: d.downloads};
    final values = [
      for (var i = days - 1; i >= 0; i--)
        byDay[_key(now.subtract(Duration(days: i)))] ?? 0,
    ];
    values[days - 1] = today;
    final peak = values.fold<int>(1, (a, b) => b > a ? b : a);
    final axis = AppTypography.mono.copyWith(
      fontSize: 12,
      color: colors.textDisabled,
    );
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.downloads,
                    style: AppTypography.display(
                      22,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary, height: 1.25),
                  ),
                  Text(
                    l10n.signalStatsLastDays(days),
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in periods) ...[
                    if (p != periods.first) const SizedBox(width: 8),
                    SignalChip(
                      label: l10n.signalStatsPeriodDays(p),
                      selected: p == days,
                      onTap: () => setState(() => _days = p),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 192,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: Semantics(
              label: l10n.signalStatsLastDays(days),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days; i++) ...[
                    if (i > 0) SizedBox(width: days > 12 ? 5 : 14),
                    Expanded(
                      child: _Bar(
                        value: values[i],
                        factor: values[i] == 0
                            ? 0.02
                            : (values[i] / peak).clamp(0.06, 1.0),
                        today: i == days - 1,
                        delay: i,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(l10n.signalStatsDaysAgo(days), style: axis),
              const Spacer(),
              Text(l10n.signalStatsTodayAxis, style: axis),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatefulWidget {
  const _Bar({
    required this.value,
    required this.factor,
    required this.today,
    required this.delay,
  });

  final int value;
  final double factor;
  final bool today;
  final int delay;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = widget.today
        ? colors.primary
        : colors.textPrimary.withValues(alpha: _hover ? 0.24 : 0.09);
    return Tooltip(
      message: '${widget.value}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.1, end: 1),
          duration: signalMotion(context, 700 + widget.delay * 14),
          curve: signalEase,
          builder: (context, t, _) => FractionallySizedBox(
            heightFactor: widget.factor * t,
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: signalMotion(context, 180),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                  bottom: Radius.circular(2),
                ),
                boxShadow: widget.today
                    ? [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.22),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sources ─────────────────────────────────────────────────────────────────

class _SourcesCard extends ConsumerWidget {
  const _SourcesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bySource = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsBySource),
    );
    final sources =
        bySource.entries
            .where(
              (e) =>
                  e.value > 0 &&
                  e.key.isNotEmpty &&
                  e.key.toLowerCase() != 'local' &&
                  e.key.toLowerCase() != 'other',
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final total = sources.fold<int>(0, (a, e) => a + e.value);
    final top = sources.take(4).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SignalEyebrow(l10n.sidebarBySource)),
              Text(
                _count(context, total),
                style: AppTypography.mono.copyWith(
                  fontSize: 12.5,
                  color: colors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (top.isEmpty)
            Text(
              l10n.noSourceData,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          for (final e in top) ...[
            if (e != top.first) const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _count(context, e.value),
                  style: AppTypography.mono.copyWith(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(e.value * 100 / (total == 0 ? 1 : total)).round()} %',
                    textAlign: TextAlign.right,
                    style: AppTypography.mono.copyWith(
                      fontSize: 12,
                      color: colors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SignalMeter(value: e.value / max),
          ],
        ],
      ),
    );
  }
}

// ── Formats ─────────────────────────────────────────────────────────────────

/// Completed downloads per media kind; a record so `.select` skips progress.
final _kindCountsProvider = Provider.autoDispose<(int, int, int)>((ref) {
  return ref.watch(
    downloadListProvider.select((async) {
      var v = 0, a = 0, im = 0;
      for (final item in async.valueOrNull ?? const <DownloadItem>[]) {
        if (item.status != DownloadStatus.completed) continue;
        switch (mediaKindOf(item)) {
          case MediaKind.video:
            v++;
          case MediaKind.audio:
            a++;
          case MediaKind.image:
            im++;
        }
      }
      return (v, a, im);
    }),
  );
});

class _FormatCard extends ConsumerWidget {
  const _FormatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (video, audio, image) = ref.watch(_kindCountsProvider);
    final total = video + audio + image;
    int pct(int n) => total == 0 ? 0 : (n * 100 / total).round();
    final shades = [
      colors.textPrimary,
      colors.textDisabled,
      colors.textPrimary.withValues(alpha: 0.23),
    ];
    final counts = [video, audio, image];
    final labels = [
      l10n.designFilterVideo,
      l10n.designFilterAudio,
      l10n.designFilterImages,
    ];
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignalEyebrow(l10n.signalStatsByFormat),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SignalFigure(value: '${pct(video)}', unit: '%', size: 44, gap: 0),
              const SizedBox(width: 10),
              Text(
                l10n.signalStatsInVideo,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: [
              for (var i = 0; i < 3; i++) '${labels[i]} ${pct(counts[i])} %',
            ].join(', '),
            child: SizedBox(
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (total == 0)
                      Expanded(
                        child: ColoredBox(
                          color: colors.textPrimary.withValues(alpha: 0.07),
                        ),
                      ),
                    for (var i = 0; i < 3; i++)
                      if (counts[i] > 0) ...[
                        if (counts.take(i).any((c) => c > 0))
                          const SizedBox(width: 3),
                        Expanded(
                          flex: counts[i],
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: shades[i],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 3; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: shades[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${pct(counts[i])} %',
                      style: AppTypography.mono.copyWith(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top creators ────────────────────────────────────────────────────────────

/// The four creators with the most finished downloads, from the whole
/// library (the home's filters must not skew it).
final _topCreatorsProvider = Provider.autoDispose<List<(String, int)>>((ref) {
  final done = ref.watch(
    downloadListProvider.select(
      (async) => _IdList([
        for (final i in async.valueOrNull ?? const <DownloadItem>[])
          if (i.status == DownloadStatus.completed) i,
      ]),
    ),
  );
  return [
    for (final f in CreatorFolderGrouper.fromItems(
      done.items,
      order: CreatorFolderOrder.countDesc,
    ).where((f) => !f.isUnknown).take(4))
      (f.handle!, f.count),
  ];
});

/// Equality on ids and titles only, so live progress does not rebuild.
class _IdList {
  _IdList(this.items);

  final List<DownloadItem> items;

  @override
  bool operator ==(Object other) =>
      other is _IdList &&
      other.items.length == items.length &&
      Iterable.generate(items.length).every(
        (i) =>
            other.items[i].id == items[i].id &&
            other.items[i].title == items[i].title,
      );

  @override
  int get hashCode => Object.hashAll(items.map((i) => i.id));
}

class _CreatorsCard extends ConsumerWidget {
  const _CreatorsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final creators = ref.watch(_topCreatorsProvider);
    final max = creators.isEmpty ? 1 : creators.first.$2;
    final tints = [colors.success, colors.warning, colors.error, colors.info];
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SignalEyebrow(l10n.signalStatsTopCreators)),
              SignalEyebrow(l10n.downloads),
            ],
          ),
          const SizedBox(height: 14),
          if (creators.isEmpty)
            Text(
              l10n.signalStatsNoCreators,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          for (var i = 0; i < creators.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '0${i + 1}',
                    style: AppTypography.mono.copyWith(
                      fontSize: 12,
                      color: colors.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SignalAvatar(
                  name: creators[i].$1,
                  size: 32,
                  tint: tints[i % tints.length],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    creators[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: SignalMeter(value: creators[i].$2 / max),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Text(
                    _count(context, creators[i].$2),
                    textAlign: TextAlign.right,
                    style: AppTypography.mono.copyWith(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shortcuts (today's view keeps them on this page) ────────────────────────

class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final shortcuts = [
      ('Ctrl+N', l10n.newDownloadShortcut),
      ('Ctrl+,', l10n.settingsShortcut),
      ('Ctrl+D', l10n.dashboardShortcut),
      ('Esc', l10n.minimizeShortcut),
    ];
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignalEyebrow(l10n.keyboardShortcuts),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              for (final (keys, label) in shortcuts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Text(
                        keys,
                        style: AppTypography.mono.copyWith(
                          fontSize: 12,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
