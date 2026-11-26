import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/services/disk_space_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_home.dart' show designFreeSpaceProvider;
import 'terminal_states.dart';
import 'terminal_widgets.dart';

/// Completed downloads only: the library's format split and top creators.
final _completedProvider = Provider<List<DownloadItem>>((ref) {
  final items = ref.watch(downloadListProvider).valueOrNull ?? const [];
  return [
    for (final i in items)
      if (i.status == DownloadStatus.completed) i,
  ];
});

/// Terminal's statistics (mockup Terminal-Stats.dc.html).
class TerminalStats extends ConsumerStatefulWidget {
  const TerminalStats({super.key});

  @override
  ConsumerState<TerminalStats> createState() => _TerminalStatsState();
}

class _TerminalStatsState extends ConsumerState<TerminalStats> {
  // 0: 7 days, 1: 30 days, 2: 12 months. Desktop keeps 7 days of history
  // today, so 30 days opens only when older days exist.
  late int _period = _hasOlderHistory() ? 1 : 0;

  bool _hasOlderHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return ref
        .read(downloadStatsProvider)
        .dailyHistory
        .any((d) => (DateTime.tryParse(d.date) ?? cutoff).isBefore(cutoff));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TerminalPageKeys(
      bindings: {
        for (var i = 0; i < 3; i++)
          '${i + 1}': () => setState(() => _period = i),
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TPrompt('stats', l10n.terminalFlagSummary),
                const SizedBox(height: 12),
                const _NoStats(),
                const _Kpis(),
                const SizedBox(height: 18),
                _ChartSection(
                  period: _period,
                  onPeriod: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 12),
                THints([('1 2 3', l10n.terminalPeriod)]),
                const SizedBox(height: 18),
                const _Breakdowns(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing counted yet: a typed headline over a flat, empty bar.
class _NoStats extends ConsumerWidget {
  const _NoStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final none = ref.watch(
      downloadStatsProvider.select(
        (s) => s.totalDownloads == 0 && s.dailyHistory.isEmpty,
      ),
    );
    if (!none) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TPanel(
        accentLeft: colors.primary,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TTyped(
              '## ${l10n.terminalStatsEmpty}',
              style: tm(colors.primary, size: 16, weight: FontWeight.w700),
              cursor: true,
            ),
            const SizedBox(height: 8),
            Text(l10n.terminalStatsEmptyBody, style: tm(colors.textSecondary)),
            const SizedBox(height: 14),
            const SizedBox(width: 280, child: TSeg(value: 0, height: 8)),
          ],
        ),
      ),
    );
  }
}

/// Columns of at least [min] px, like CSS `repeat(auto-fill, minmax())`.
class _AutoGrid extends StatelessWidget {
  const _AutoGrid({
    required this.min,
    required this.gap,
    required this.children,
  });

  final double min;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + gap) / (min + gap)).floor().clamp(1, 99);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

class _Kpis extends ConsumerWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    (String, String) split(int bytes) {
      final s = localBytes(l10n, bytes);
      final i = s.lastIndexOf(' ');
      return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 1));
    }

    final stored = split(stats.totalBytesDownloaded);
    final freeParts = free == null ? ('…', '') : split(free);
    final low = free != null && free < DiskSpaceService.minRequiredBytes;
    return KeyedSubtree(
      key: OnboardingTargets.stats,
      child: _AutoGrid(
        min: 180,
        gap: 10,
        children: [
          _Kpi(l10n.terminalKpiDownloads, number.format(stats.totalDownloads)),
          _Kpi(l10n.terminalKpiStorage, stored.$1, unit: stored.$2),
          _Kpi(
            l10n.terminalKpiToday,
            number.format(stats.downloadsToday),
            color: colors.primary,
          ),
          _Kpi(
            l10n.terminalKpiFree,
            freeParts.$1,
            unit: freeParts.$2,
            color: low ? colors.error : null,
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.unit = '', this.color});

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tm(colors.textSecondary)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: tm(colors.textSecondary, size: 14),
                  ),
              ],
            ),
            maxLines: 1,
            style: tm(
              color ?? colors.textPrimary,
              size: 26,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartSection extends ConsumerWidget {
  const _ChartSection({required this.period, required this.onPeriod});

  final int period;
  final ValueChanged<int> onPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final history = ref.watch(
      downloadStatsProvider.select((s) => s.dailyHistory),
    );
    final today = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsToday),
    );
    final byDay = {for (final d in history) d.date: d};
    final now = DateTime.now();
    final bars = <_Bar>[];
    if (period < 2) {
      final days = period == 0 ? 7 : 30;
      for (var i = days - 1; i >= 0; i--) {
        final d = byDay[_dayKey(now.subtract(Duration(days: i)))];
        bars.add(_Bar(i == 0 ? today : (d?.downloads ?? 0), d?.bytes ?? 0));
      }
    } else {
      for (var i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final prefix = _dayKey(month).substring(0, 7);
        var n = 0;
        var b = 0;
        for (final d in history) {
          if (d.date.startsWith(prefix)) {
            n += d.downloads;
            b += d.bytes;
          }
        }
        bars.add(_Bar(n, b));
      }
    }
    final labels = [
      (l10n.terminalPeriod7, '7j'),
      (l10n.terminalPeriod30, '30j'),
      (l10n.terminalPeriod12, '12m'),
    ];
    final n = bars.length;
    final axis = period < 2
        ? [
            l10n.terminalDaysAgo(n - 1),
            l10n.terminalDaysAgo(n ~/ 2),
            l10n.terminalToday,
          ]
        : [
            l10n.terminalMonthsAgo(11),
            l10n.terminalMonthsAgo(6),
            l10n.terminalThisMonth,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TPrompt(
                'stats',
                '${l10n.terminalFlagPeriod} ${labels[period].$2}',
              ),
            ),
            for (final (i, (label, _)) in labels.indexed) ...[
              if (i > 0) const SizedBox(width: 2),
              TKeyRow(
                keyHint: '${i + 1}',
                label: label,
                selected: period == i,
                expand: false,
                onTap: () => onPeriod(i),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '## ${period < 2 ? l10n.terminalPerDay : l10n.terminalPerMonth}',
                      style: tm(colors.textSecondary),
                    ),
                  ),
                  Text(
                    period < 2
                        ? l10n.terminalLastDays(n)
                        : l10n.terminalLastMonths(n),
                    style: tm(colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 210,
                child: bars.every((b) => b.count == 0)
                    ? Center(
                        child: Text(
                          '# ${l10n.noDownloadHistory}',
                          style: tm(colors.textDisabled),
                        ),
                      )
                    : _Chart(bars: bars),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final a in axis) Text(a, style: tm(colors.textDisabled)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Bar {
  const _Bar(this.count, this.bytes);

  final int count;
  final int bytes;
}

/// Bars of 4 px stripes over a 52 px grid; the last (now) is brighter.
class _Chart extends StatelessWidget {
  const _Chart({required this.bars});

  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final peak = bars.fold<int>(1, (a, b) => b.count > a ? b.count : a);
    return CustomPaint(
      painter: _GridPainter(colors.border),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, b) in bars.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: l10n.chartDownloadsTooltip(
                    b.count,
                    localBytes(l10n, b.bytes),
                  ),
                  child: FractionallySizedBox(
                    heightFactor: b.count / peak,
                    alignment: Alignment.bottomCenter,
                    child: CustomPaint(
                      painter: _StripePainter(
                        i == bars.length - 1
                            ? Color.lerp(colors.primary, Colors.white, 0.6)!
                            : colors.primary.withValues(alpha: 0.78),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = 51.0; y < size.height; y += 52) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = size.height; y > 0; y -= 6) {
      final top = (y - 4).clamp(0.0, size.height);
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

class _Breakdowns extends ConsumerWidget {
  const _Breakdowns();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bySource = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsBySource),
    );
    final done = ref.watch(_completedProvider);
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
    final sourcePeak = sources.isEmpty ? 1 : sources.first.value;

    final kinds = {for (final k in MediaKind.values) k: 0};
    for (final i in done) {
      kinds[mediaKindOf(i)] = kinds[mediaKindOf(i)]! + 1;
    }
    final kindTotal = done.isEmpty ? 1 : done.length;
    final kindLabels = {
      MediaKind.video: l10n.designFilterVideo,
      MediaKind.audio: l10n.designFilterAudio,
      MediaKind.image: l10n.designFilterImages,
    };

    final creators = CreatorFolderGrouper.fromItems(
      done,
      order: CreatorFolderOrder.countDesc,
    ).where((f) => !f.isUnknown).take(4).toList();
    final creatorPeak = creators.isEmpty ? 1 : creators.first.count;

    Widget empty(String text) =>
        Text('# $text', style: tm(colors.textDisabled));

    return _AutoGrid(
      min: 300,
      gap: 18,
      children: [
        _Block(
          flag: l10n.terminalFlagBySource,
          child: sources.isEmpty
              ? empty(l10n.noSourceData)
              : Column(
                  children: [
                    for (final e in sources.take(5))
                      _ShareRow(
                        label: e.key.toLowerCase(),
                        value: e.value / sourcePeak,
                        right: '${e.value}',
                      ),
                  ],
                ),
        ),
        _Block(
          flag: l10n.terminalFlagByFormat,
          child: done.isEmpty
              ? empty(l10n.noDownloadHistory)
              : Column(
                  children: [
                    for (final k in MediaKind.values)
                      _ShareRow(
                        label: kindLabels[k]!.toLowerCase(),
                        value: kinds[k]! / kindTotal,
                        right: '${(kinds[k]! * 100 / kindTotal).round()}%',
                      ),
                  ],
                ),
        ),
        _Block(
          flag: l10n.terminalFlagTopCreators,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: creators.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: empty(l10n.noSourceData),
                )
              : Column(
                  children: [
                    for (final (i, f) in creators.indexed)
                      _CreatorRow(
                        rank: i + 1,
                        name: f.handle!,
                        value: f.count / creatorPeak,
                        count: f.count,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.flag,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final String flag;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TPrompt('stats', flag),
        const SizedBox(height: 8),
        TPanel(padding: padding, child: child),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.value,
    required this.right,
  });

  final String label;
  final double value;
  final String right;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(colors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: TSeg(value: value)),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: tm(colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.count,
  });

  final int rank;
  final String name;
  final double value;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return THoverLine(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: tm(colors.textDisabled),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(colors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 110, child: TSeg(value: value, height: 8)),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: tm(colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
