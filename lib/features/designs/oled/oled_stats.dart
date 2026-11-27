import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'oled_states.dart';
import 'oled_theme.dart';
import 'oled_widgets.dart';

/// OLED's statistics (mockup OLED-Stats.dc.html): the period's downloads as
/// one huge Doto figure with volume, today, success and free space under
/// it; the days as columns of dots (one dot, one download); sources; and
/// the space used by kind. The mockup's month-over-month line and average
/// speed are not recorded: today's count and the success rate take their
/// place.
class OledStats extends ConsumerStatefulWidget {
  const OledStats({super.key});

  @override
  ConsumerState<OledStats> createState() => _OledStatsState();
}

/// 7 days, 30 days, or everything (null).
class _OledStatsState extends ConsumerState<OledStats> {
  int? _days = 30;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final days = _days;
    final today = DateTime.now();
    final byDay = {for (final d in stats.dailyHistory) d.date: d};
    // The history keeps the last 30 days; "Tout" reads the totals.
    final shown = [
      for (var i = (days ?? 30) - 1; i >= 0; i--)
        byDay[_key(today.subtract(Duration(days: i)))],
    ];
    final downloads = days == null
        ? stats.totalDownloads
        : shown.fold<int>(0, (s, d) => s + (d?.downloads ?? 0));
    final bytes = days == null
        ? stats.totalBytesDownloaded
        : shown.fold<int>(0, (s, d) => s + (d?.bytes ?? 0));
    final finished = counts.completed + counts.failed;
    final success = finished == 0
        ? null
        : (counts.completed * 100 / finished).round();
    (String, String) split(String s) {
      final i = s.lastIndexOf(' ');
      return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 1));
    }

    final period = Wrap(
      spacing: 18,
      children: [
        for (final (d, label) in [
          (7, l10n.oledDaysShort(7)),
          (30, l10n.oledDaysShort(30)),
          (null, l10n.designFilterAll),
        ])
          OledTextLink(
            label: label,
            size: 13,
            selectedWeight: FontWeight.w500,
            selected: _days == d,
            onTap: () => setState(() => _days = d),
          ),
      ],
    );
    if (stats.totalDownloads == 0) {
      return Center(
        child: SingleChildScrollView(
          child: OledState(
            title: l10n.oledStatsEmptyTitle,
            body: l10n.oledStatsEmptyBody,
            action: OledPill(
              label: l10n.newDownload,
              kind: OledPillKind.outline,
              onTap: () => openNewDownload(context),
            ),
          ),
        ),
      );
    }

    final volume = split(localBytes(l10n, bytes));
    final freeLabel = free == null ? ('—', '') : split(localBytes(l10n, free));
    Widget fact(String label, String value, String unit) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: oledText(size: 12, color: OledInk.mute)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: oledDoto(16, weight: FontWeight.w800),
                  ),
              ],
            ),
            style: oledDoto(34, weight: FontWeight.w800, height: 1),
          ),
        ),
      ],
    );
    final summary = KeyedSubtree(
      key: OnboardingTargets.stats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (days == null ? l10n.designFilterAll : l10n.oledLastDays(days))
                .toUpperCase(),
            style: oledEyebrow(),
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text('$downloads', style: oledDoto(196, height: 0.8)),
          ),
          const SizedBox(height: 16),
          Text(
            days == null
                ? l10n.oledDownloadsInAll(downloads)
                : l10n.oledDownloadsInDays(downloads, days),
            style: oledText(size: 15),
          ),
          const SizedBox(height: 6),
          Text(l10n.oledTodayCount(stats.downloadsToday), style: oledMono()),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OledInk.line)),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              crossAxisSpacing: 24,
              childAspectRatio: 2.6,
              children: [
                fact(l10n.oledVolume, volume.$1, volume.$2),
                fact(l10n.statsToday, '${stats.downloadsToday}', ''),
                fact(l10n.oledSuccess, success == null ? '—' : '$success', '%'),
                fact(l10n.oledFree, freeLabel.$1, freeLabel.$2),
              ],
            ),
          ),
        ],
      ),
    );
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DotHistogram(series: shown, days: days ?? 30),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, box) {
            final children = [_Sources(stats: stats), const _SpaceUsed()];
            if (box.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  children[0],
                  const SizedBox(height: 28),
                  children[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 32),
                Expanded(child: children[1]),
              ],
            );
          },
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final side = wide ? 40.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, 26, side, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerEnd, child: period),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: summary),
                    const SizedBox(width: 40),
                    Expanded(flex: 8, child: chart),
                  ],
                )
              else ...[
                summary,
                const SizedBox(height: 36),
                chart,
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The days as columns of dots, today's lit in ion. A column holds at most
/// [_maxDots]: beyond that each dot stands for several downloads.
class _DotHistogram extends StatelessWidget {
  const _DotHistogram({required this.series, required this.days});

  final List<DailyStats?> series;
  final int days;

  static const _maxDots = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final max = series.fold<int>(0, (m, d) {
      final n = d?.downloads ?? 0;
      return n > m ? n : m;
    });
    final per = max <= _maxDots ? 1 : (max / _maxDots).ceil();
    final today = DateTime.now();
    final fmt = DateFormat.MMMd(l10n.localeName);
    final total = series.fold<int>(0, (s, d) => s + (d?.downloads ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          children: [
            Text(l10n.oledLastDays(days), style: oledText(size: 13)),
            Text(l10n.oledPerDot(per), style: oledMono(size: 12)),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          label: l10n.oledHistogramLabel(days, total),
          child: ExcludeSemantics(
            child: Container(
              height: 300,
              padding: const EdgeInsets.only(bottom: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OledInk.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++) ...[
                    if (i > 0) SizedBox(width: days > 7 ? 6 : 18),
                    Expanded(
                      child: _Column(
                        count: series[i]?.downloads ?? 0,
                        per: per,
                        now: i == series.length - 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              fmt.format(today.subtract(Duration(days: days - 1))),
              style: oledMono(size: 11),
            ),
            const Spacer(),
            Text(
              fmt.format(today.subtract(Duration(days: days ~/ 2))),
              style: oledMono(size: 11),
            ),
            const Spacer(),
            Text(
              l10n.oledTodayWord,
              style: oledMono(size: 11, color: OledInk.ion),
            ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.count, required this.per, required this.now});

  final int count;
  final int per;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final dots = count == 0 ? 1 : (count / per).ceil();
    final color = count == 0
        ? OledInk.track
        : (now ? OledInk.ion : OledInk.ink);
    return Tooltip(
      message: '$count',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < dots; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: now && count > 0
                    ? const [BoxShadow(color: OledInk.ion, blurRadius: 10)]
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "youtube.com" -> "YouTube": the domain without its suffix.
String _sourceName(String raw) {
  const known = {
    'youtube': 'YouTube',
    'youtu': 'YouTube',
    'tiktok': 'TikTok',
    'instagram': 'Instagram',
    'x': 'X',
    'twitter': 'Twitter',
    'vimeo': 'Vimeo',
    'twitch': 'Twitch',
    'facebook': 'Facebook',
  };
  final host = raw.replaceFirst(RegExp(r'^www\.'), '').split('.').first;
  return known[host.toLowerCase()] ??
      (host.isEmpty ? raw : host[0].toUpperCase() + host.substring(1));
}

class _Sources extends StatelessWidget {
  const _Sources({required this.stats});

  final DownloadStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = stats.downloadsBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.oledSources, style: oledText(size: 13)),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Text(
            l10n.noSourceData,
            style: oledText(size: 13, color: OledInk.mute),
          ),
        for (final (i, e) in entries.take(4).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _sourceName(e.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: oledText(size: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OledBar(
                    // A 2 % stub keeps the smallest sources visible.
                    value: (e.value / max).clamp(0.02, 1.0),
                    color: i == 0 ? OledInk.ion : OledInk.ink,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  child: Text(
                    number.format(e.value),
                    textAlign: TextAlign.end,
                    style: oledMono(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Video, audio and images on the disk, then the free space, as one bar.
class _SpaceUsed extends ConsumerWidget {
  const _SpaceUsed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull ?? 0;
    // Kinds change with the catalogue, not with progress ticks.
    final kinds = ref.watch(
      downloadListProvider.select((s) {
        final bytes = <MediaKind, int>{};
        for (final DownloadItem i in s.valueOrNull ?? const []) {
          if (i.status != DownloadStatus.completed) continue;
          bytes[mediaKindOf(i)] = (bytes[mediaKindOf(i)] ?? 0) + bytesOf(i);
        }
        return (
          bytes[MediaKind.video] ?? 0,
          bytes[MediaKind.audio] ?? 0,
          bytes[MediaKind.image] ?? 0,
        );
      }),
    );
    final parts = [
      (kinds.$1, OledInk.ink, l10n.designFilterVideo),
      (kinds.$2, OledInk.mute, l10n.designFilterAudio),
      (kinds.$3, const Color(0xFF4A4A4A), l10n.designFilterImages),
    ];
    final total = kinds.$1 + kinds.$2 + kinds.$3 + free;
    int flex(int bytes) => total == 0 ? 0 : (bytes * 1000 / total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.oledSpaceUsed, style: oledText(size: 13)),
        const SizedBox(height: 14),
        SizedBox(
          height: 14,
          child: Row(
            children: [
              for (final (bytes, color, _) in parts)
                if (flex(bytes) > 0) ...[
                  Expanded(
                    flex: flex(bytes),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
              Expanded(
                flex: total == 0 ? 1 : flex(free).clamp(1, 1000),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: OledInk.ghost),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            for (final (bytes, color, label) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, color: color),
                  const SizedBox(width: 6),
                  Text(
                    '$label ${localBytes(l10n, bytes)}',
                    style: oledText(size: 12, color: OledInk.mute),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
