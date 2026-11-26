import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_home.dart' show designFreeSpaceProvider;
import 'pastille_kit.dart';

/// Pastille's statistics (mockup Pastille-Stats.dc.html).
class PastilleStats extends ConsumerWidget {
  const PastilleStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PastillePage(
      gap: 24,
      children: [
        PastilleHeader(
          eyebrow: l10n.statistics.toLowerCase(),
          title: l10n.pastilleStatsTitle,
        ),
        KeyedSubtree(
          key: OnboardingTargets.stats,
          child: const PGrid(
            rowHeight: 150,
            rowHeights: {3: 173},
            cells: [
              PCell(_TotalTile()),
              PCell(_VolumeTile()),
              PCell(_TodayTile(), w: 2),
              PCell(_ChartTile(), w: 3, h: 2),
              PCell(_FreeTile()),
              PCell(_FormatTile()),
              PCell(_SourceTile(), w: 2),
              PCell(_ShortcutsTile(), w: 2),
            ],
          ),
        ),
      ],
    );
  }
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Downloads per day for the last [days] days, oldest first, today last.
List<int> _lastDays(DownloadStats stats, int days) {
  final byDay = {for (final d in stats.dailyHistory) d.date: d.downloads};
  final now = DateTime.now();
  return [
    for (var i = days - 1; i >= 0; i--)
      i == 0
          ? stats.downloadsToday
          : byDay[_dayKey(DateTime(now.year, now.month, now.day - i))] ?? 0,
  ];
}

int _level(int n, int peak) =>
    n <= 0 || peak <= 0 ? 0 : (4 * n / peak).ceil().clamp(1, 4);

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.caption, this.unit});

  final String value;
  final String? unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: pNum(56, color: pInk),
            ),
            if (unit != null) ...[
              const SizedBox(width: 8),
              Text(unit!, style: pNum(24, color: pInk)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pSub(context),
        ),
      ],
    );
  }
}

class _TotalTile extends ConsumerWidget {
  const _TotalTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = ref.watch(
      downloadStatsProvider.select((s) => s.totalDownloads),
    );
    return PTile(
      color: PTones.of(context).butter,
      semanticLabel: l10n.pastilleDownloads,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.download_rounded, text: l10n.pastilleDownloads),
            const Spacer(),
            _Big(value: '$total', caption: l10n.pastilleSinceStart),
          ],
        ),
      ),
    );
  }
}

class _VolumeTile extends ConsumerWidget {
  const _VolumeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bytes = ref.watch(
      downloadStatsProvider.select((s) => s.totalBytesDownloaded),
    );
    final (value, unit) = pSplitUnit(localBytes(l10n, bytes));
    return PTile(
      color: PTones.of(context).sky,
      delay: 60,
      semanticLabel: l10n.pastilleVolume,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.storage_rounded, text: l10n.pastilleVolume),
            const Spacer(),
            _Big(
              value: value,
              unit: unit,
              caption: l10n.pastilleDownloadedTotal,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTile extends ConsumerWidget {
  const _TodayTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final days = _lastDays(stats, 30);
    final peak = days.fold<int>(0, math.max);
    return PTile(
      color: PTones.of(context).rose,
      delay: 120,
      semanticLabel: l10n.statsToday,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.calendar_month_rounded,
              text: l10n.statsToday,
              trailing: Text(l10n.pastilleLast30),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Big(
                    value: '${stats.downloadsToday}',
                    caption: l10n.pastilleDownloadsWord,
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.bottomEnd,
                      child: SizedBox(
                        width: 240,
                        child: PDots(
                          count: 30,
                          columns: 10,
                          on: 0,
                          square: true,
                          gap: 5,
                          levels: [for (final n in days) _level(n, peak)],
                          semanticLabel: l10n.pastilleLast30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// No year: the stats keep 30 days of history.
enum _Period { week, month }

class _ChartTile extends ConsumerStatefulWidget {
  const _ChartTile();

  @override
  ConsumerState<_ChartTile> createState() => _ChartTileState();
}

class _ChartTileState extends ConsumerState<_ChartTile> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    late final List<int> data;
    late final List<String> axis;
    late final String caption;
    switch (_period) {
      case _Period.week:
        data = _lastDays(stats, 7);
        axis = [
          l10n.pastilleDaysAgo(6),
          l10n.pastilleDaysAgo(3),
          l10n.pastilleTodayShort,
        ];
        caption = l10n.pastilleLast7;
      case _Period.month:
        data = _lastDays(stats, 30);
        axis = [
          l10n.pastilleDaysAgo(29),
          l10n.pastilleDaysAgo(15),
          l10n.pastilleTodayShort,
        ];
        caption = l10n.pastilleLast30;
    }
    final peak = data.fold<int>(0, math.max);
    return PTile(
      color: PTones.of(context).cream,
      delay: 180,
      semanticLabel: l10n.pastilleChartTitle(caption),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: PLabel(
                    icon: Icons.bar_chart_rounded,
                    text: l10n.pastilleChartTitle(caption),
                  ),
                ),
                const SizedBox(width: 14),
                PSeg(
                  height: 36,
                  padH: 15,
                  fontSize: 13,
                  items: [
                    for (final (p, label) in [
                      (_Period.week, l10n.pastillePeriod7),
                      (_Period.month, l10n.pastillePeriod30),
                    ])
                      PSegItem(
                        label,
                        _period == p,
                        () => setState(() => _period = p),
                      ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Semantics(
              label: l10n.pastilleChartTitle(caption),
              child: PBars(
                key: ValueKey(_period),
                values: [for (final n in data) peak > 0 ? n / peak : 0],
                hi: data.length - 1,
                gap: 6,
                height: 186,
              ),
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final a in axis)
                    Text(a, style: pMono(size: 12, color: pSubInk)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeTile extends ConsumerWidget {
  const _FreeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final used = ref.watch(
      downloadListProvider.select(
        (v) => (v.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.completed)
            .fold<int>(0, (a, i) => a + bytesOf(i)),
      ),
    );
    final (value, unit) = pSplitUnit(localBytes(l10n, free ?? 0));
    return PTile(
      color: PTones.of(context).sage,
      delay: 240,
      semanticLabel: l10n.freeSpace,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.data_usage_rounded, text: l10n.freeSpace),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        free == null ? '—' : value,
                        style: pNum(52, color: pInk),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.designFree(unit), style: pSub(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 56,
                  child: PLiquid(
                    radius: 14,
                    fraction: free == null || free + used <= 0
                        ? 0
                        : free / (free + used),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends ConsumerWidget {
  const _FormatTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final byKind = {for (final k in MediaKind.values) k: 0};
    for (final i in items) {
      if (i.status != DownloadStatus.completed) continue;
      byKind[mediaKindOf(i)] =
          byKind[mediaKindOf(i)]! + math.max(1, bytesOf(i));
    }
    final total = byKind.values.fold<int>(0, (a, b) => a + b);
    final labels = [
      l10n.designFilterVideo,
      l10n.designFilterAudio,
      l10n.designFilterImages,
    ];
    return PTile(
      color: PTones.of(context).lav,
      delay: 300,
      semanticLabel: l10n.pastilleByFormat,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.category_outlined, text: l10n.pastilleByFormat),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final pct = total == 0
                              ? 0
                              : (byKind[MediaKind.values[i]]! * 100 / total)
                                    .round();
                          return Semantics(
                            label: '${labels[i]} $pct %',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: PLiquid(fraction: pct / 100)),
                                const SizedBox(height: 5),
                                Text(
                                  '$pct %',
                                  style: pMono(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: pInk,
                                  ).copyWith(height: 1.1),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: pSub(
                                    context,
                                    size: 12,
                                  ).copyWith(height: 1.1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

class _SourceTile extends ConsumerWidget {
  const _SourceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bySource = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsBySource),
    );
    final rows = bySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(4).toList();
    final peak = top.isEmpty ? 1 : top.first.value;
    return PTile(
      color: PTones.of(context).butter,
      delay: 360,
      semanticLabel: l10n.pastilleBySource,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.sort_rounded, text: l10n.pastilleBySource),
            const SizedBox(height: 8),
            const Spacer(),
            if (top.isEmpty) Text(l10n.noSourceData, style: pSub(context)),
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              SizedBox(
                height: 22,
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        top[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(
                          size: 13,
                          weight: FontWeight.w600,
                          color: pInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 16,
                        alignment: AlignmentDirectional.centerStart,
                        decoration: BoxDecoration(
                          color: pInk.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: LayoutBuilder(
                          builder: (context, c) =>
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: pMotion(context, 800 + i * 80),
                                curve: pEase,
                                builder: (context, t, _) => Container(
                                  width: math.max(
                                    16,
                                    c.maxWidth * top[i].value / peak * t,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pInk,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${top[i].value}',
                        textAlign: TextAlign.end,
                        style: pMono(
                          size: 13,
                          weight: FontWeight.w500,
                          color: pInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's stats page lists the keyboard shortcuts; the mockup's "Top
/// créateurs" has no data source, so this ink tile carries them instead.
class _ShortcutsTile extends StatelessWidget {
  const _ShortcutsTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final rows = [
      ('Ctrl+N', l10n.newDownloadShortcut, tones.sky),
      ('Ctrl+,', l10n.settingsShortcut, tones.rose),
      ('Ctrl+D', l10n.dashboardShortcut, tones.lav),
      ('Esc', l10n.minimizeShortcut, tones.sage),
    ];
    return PTile(
      color: pInkDeep,
      delay: 420,
      semanticLabel: l10n.keyboardShortcuts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PLabel(
            icon: Icons.keyboard_outlined,
            iconColor: tones.butter,
            text: l10n.keyboardShortcuts,
          ),
          const SizedBox(height: 8),
          const Spacer(),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            SizedBox(
              height: 22,
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      rows[i].$1,
                      style: pMono(size: 12, color: pMuted),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: rows[i].$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: pCream,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
