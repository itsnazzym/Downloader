import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/ui/shell/desktop_destinations.dart';
import 'package:tapload/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'ios_glass.dart';
import 'ios_states.dart';

/// iOS's statistics (mockup iOS-Stats.dc.html): the period's count and its
/// daily bars, three concentric activity rings, storage by kind and the
/// sources. Only what the app records: the history holds 30 days at most,
/// so there is no « Année ».
class IosStats extends ConsumerStatefulWidget {
  const IosStats({super.key});

  @override
  ConsumerState<IosStats> createState() => _IosStatsState();
}

class _IosStatsState extends ConsumerState<IosStats> {
  int _days = 30;

  /// A month only when the history holds a day older than a week.
  static bool _covers30(DownloadStats stats) {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    return stats.dailyHistory.any(
      (d) => DateTime.tryParse(d.date)?.isBefore(limit) ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final month = _covers30(stats);
    final days = month ? _days : 7;
    final header = Row(
      children: [
        Expanded(child: IosTitle(l10n.statistics)),
        if (stats.totalDownloads > 0) ...[
          const SizedBox(width: 12),
          IosSegmented<int>(
            value: days,
            height: 34,
            fontSize: 13.5,
            onChanged: (d) => setState(() => _days = d),
            segments: [(7, l10n.iosWeek), if (month) (30, l10n.iosMonth)],
          ),
        ],
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 18),
          if (stats.totalDownloads == 0)
            KeyedSubtree(
              key: OnboardingTargets.stats,
              child: IosStateCard(
                icon: Icons.bar_chart_rounded,
                title: l10n.iosStatsEmptyTitle,
                body: l10n.iosStatsEmptyBody,
                actions: [
                  IosButton(
                    label: l10n.newDownload,
                    icon: Icons.add_rounded,
                    kind: IosButtonKind.primary,
                    height: 44,
                    onTap: () => openNewDownload(context),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 820;
                Widget pair(Widget a, Widget b) => wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: a),
                            const SizedBox(width: 18),
                            Expanded(child: b),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [a, const SizedBox(height: 18), b],
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pair(
                      KeyedSubtree(
                        key: OnboardingTargets.stats,
                        child: _Period(stats: stats, days: days),
                      ),
                      _Rings(stats: stats, days: days),
                    ),
                    const SizedBox(height: 18),
                    pair(_Storage(stats: stats), _Sources(stats: stats)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The last [days] days, oldest first (null: nothing recorded that day).
List<DailyStats?> _series(DownloadStats stats, int days, {int offset = 0}) {
  final byDay = {for (final d in stats.dailyHistory) d.date: d};
  final today = DateTime.now();
  return [
    for (var i = days - 1 + offset; i >= offset; i--)
      byDay[_key(today.subtract(Duration(days: i)))],
  ];
}

class _Period extends StatelessWidget {
  const _Period({required this.stats, required this.days});

  final DownloadStats stats;
  final int days;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final series = _series(stats, days);
    final count = series.fold<int>(0, (s, d) => s + (d?.downloads ?? 0));
    // The period before, only when the history reaches back that far.
    final oldest = DateTime.now().subtract(Duration(days: days * 2 - 1));
    final reaches = stats.dailyHistory.any(
      (d) => !(DateTime.tryParse(d.date)?.isAfter(oldest) ?? true),
    );
    final before = _series(
      stats,
      days,
      offset: days,
    ).fold<int>(0, (s, d) => s + (d?.downloads ?? 0));
    final delta = reaches && before > 0
        ? ((count - before) / before * 100).round()
        : null;
    final max = series.fold<int>(1, (m, d) => math.max(m, d?.downloads ?? 0));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.MMMd(locale);
    final now = DateTime.now();
    return IosGlass(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nocturneLastDays(days),
                    style: iosText(
                      t,
                      size: 13,
                      weight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                  Text(
                    '$count',
                    style: iosText(
                      t,
                      size: 64,
                      weight: FontWeight.w900,
                      spacing: -2.56,
                    ).copyWith(height: 1.0),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      text: l10n.iosDownloadsWord(count),
                      children: [
                        if (delta != null) ...[
                          const TextSpan(text: '\n'),
                          TextSpan(
                            text: '${delta >= 0 ? '↑' : '↓'} ${delta.abs()} %',
                            style: TextStyle(
                              color: delta >= 0 ? t.green : t.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' ${l10n.iosVsBefore}'),
                        ],
                      ],
                    ),
                    style: iosText(t, size: 14, color: t.soft),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: l10n.iosBarsLabel(days, series.last?.downloads ?? 0),
            child: SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++) ...[
                    if (i > 0) SizedBox(width: days > 7 ? 5 : 14),
                    Expanded(
                      child: _Bar(
                        day: series[i],
                        ratio: (series[i]?.downloads ?? 0) / max,
                        today: i == series.length - 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in [
                date.format(now.subtract(Duration(days: days - 1))),
                date.format(now.subtract(Duration(days: days ~/ 2))),
                l10n.statsToday,
              ])
                Text(label, style: iosText(t, size: 11.5, color: t.sub)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.ratio, required this.today});

  final DailyStats? day;
  final double ratio;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final count = day?.downloads ?? 0;
    final light = Color.lerp(t.blueFill, Colors.white, 0.55)!;
    return Tooltip(
      message: l10n.chartDownloadsTooltip(
        count,
        localBytes(l10n, day?.bytes ?? 0),
      ),
      child: Container(
        // Empty days keep a 6px stub so the rhythm of the days stays.
        height: math.max(6, 170 * ratio),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: today
                // White glows on the dark glass; on the pale one, full blue.
                ? (t.dark ? [Colors.white, light] : [light, t.blueFill])
                : [
                    light.withValues(alpha: 0.85),
                    t.blueFill.withValues(alpha: 0.55),
                  ],
          ),
          boxShadow: today
              ? [BoxShadow(color: light.withValues(alpha: 0.8), blurRadius: 18)]
              : null,
        ),
      ),
    );
  }
}

/// Réussite, today against the period's best day, and the space the
/// downloads take next to what is left.
class _Rings extends ConsumerWidget {
  const _Rings({required this.stats, required this.days});

  final DownloadStats stats;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final ended = counts.completed + counts.failed;
    final success = ended == 0 ? 0.0 : counts.completed / ended;
    final best = _series(
      stats,
      days,
    ).fold<int>(1, (m, d) => math.max(m, d?.downloads ?? 0));
    final today = stats.downloadsToday / best;
    final used = stats.totalBytesDownloaded;
    final space = free == null || used + free == 0 ? 0.0 : used / (used + free);
    final rings = [
      (const Color(0xFFFF4D6D), const Color(0xFFFF8DA1), success),
      (const Color(0xFF5CF2B0), const Color(0xFF7FF5C2), today.clamp(0.0, 1.0)),
      (const Color(0xFF5AC8FF), const Color(0xFF8FD8FF), space),
    ];
    final rows = [
      (l10n.iosSuccess, '${(success * 100).round()} %'),
      (l10n.statsToday, '${stats.downloadsToday}'),
      (l10n.iosSpaceUsed, localBytes(l10n, used)),
    ];
    return IosGlass(
      radius: 30,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Semantics(
            label: [for (final (k, v) in rows) '$k $v'].join(', '),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: iosMotion(context, 900),
              curve: iosEase,
              builder: (context, grow, _) => CustomPaint(
                size: const Size.square(190),
                painter: _RingsPainter([
                  for (final (c, _, v) in rings) (c, v * grow),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: iosText(
                        t,
                        weight: FontWeight.w600,
                        color: t.dark
                            ? rings[i].$2
                            : Color.lerp(rings[i].$1, Colors.black, 0.25),
                      ),
                    ),
                  ),
                  Text(rows[i].$2, style: iosText(t, weight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Three rings 21px thick, a pale track under each, round caps.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings);

  final List<(Color, double)> rings;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final centre = size.center(Offset.zero);
    var radius = size.shortestSide / 2 - stroke / 2;
    for (final (color, value) in rings) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: 0.18),
      );
      if (value > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * value.clamp(0.0, 0.999),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      radius -= stroke + 2;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.rings.toString() != rings.toString();
}

/// « Stockage »: the free space, and what each kind of download takes.
class _Storage extends ConsumerWidget {
  const _Storage({required this.stats});

  final DownloadStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
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
      (l10n.designFilterVideo, kinds.$1, IosTints.blue),
      (l10n.designFilterAudio, kinds.$2, IosTints.pink),
      (
        l10n.designFilterImages,
        kinds.$3,
        (const Color(0xFFFFC46B), const Color(0xFFE07A12)),
      ),
    ];
    final whole = kinds.$1 + kinds.$2 + kinds.$3 + (free ?? 0);
    return IosGlass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.iosStorage,
                  style: iosText(t, weight: FontWeight.w700),
                ),
              ),
              Text(
                free == null ? '—' : l10n.iosFreeLeft(localBytes(l10n, free)),
                style: iosText(t, color: t.soft),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 16,
              color: t.track,
              child: Row(
                children: [
                  for (final (_, bytes, tint) in parts)
                    if (whole > 0 && bytes > 0)
                      Flexible(
                        flex: math.max(1, (bytes / whole * 1000).round()),
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(end: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [tint.$1, tint.$2],
                            ),
                          ),
                        ),
                      ),
                  if (whole > 0 && (free ?? 0) > 0)
                    Spacer(
                      flex: math.max(1, ((free ?? 0) / whole * 1000).round()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              for (final (label, bytes, tint) in parts)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '● ',
                        style: TextStyle(color: tint.$1),
                      ),
                      TextSpan(text: '$label ${localBytes(l10n, bytes)}'),
                    ],
                  ),
                  style: iosText(t, size: 13, color: t.soft),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.stats});

  final DownloadStats stats;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final entries = stats.downloadsBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return IosGlass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Text(l10n.noSourceData, style: iosText(t, color: t.sub)),
          for (final e in entries.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sourceName(e.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: iosText(t, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    NumberFormat.decimalPattern(
                      l10n.localeName,
                    ).format(e.value),
                    style: iosText(t, color: t.soft),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "youtube.com" -> "YouTube": the domain without its suffix.
  static String _sourceName(String raw) {
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
}
