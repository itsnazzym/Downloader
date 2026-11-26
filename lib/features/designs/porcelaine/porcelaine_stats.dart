import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:modern_downloader/core/download/media_source_resolver.dart';
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
import 'porcelaine_states.dart' show PEmptyRows;
import 'porcelaine_widgets.dart';

/// Porcelaine's statistics (Porcelaine-Stats.dc.html): four figures, the
/// daily chart, sources, formats, top creators, then the keyboard
/// shortcuts today's page lists.
class PorcelaineStats extends StatelessWidget {
  const PorcelaineStats({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final gap = wide ? 20.0 : 14.0;
        Widget row(List<(int, Widget)> cells) {
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (_, w)) in cells.indexed) ...[
                  if (i > 0) SizedBox(height: gap),
                  w,
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (flex, w)) in cells.indexed) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(flex: flex, child: w),
                ],
              ],
            ),
          );
        }

        const figures = [_Downloads(), _Volume(), _Today(), _FreeSpace()];
        return PPage(
          children: [
            PPageTitle(title: context.l10n.statistics),
            const SizedBox(height: 26),
            KeyedSubtree(
              key: OnboardingTargets.stats,
              child: wide
                  ? row([for (final f in figures) (3, f)])
                  : Column(
                      children: [
                        for (var i = 0; i < 4; i += 2) ...[
                          if (i > 0) SizedBox(height: gap),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: figures[i]),
                                SizedBox(width: gap),
                                Expanded(child: figures[i + 1]),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            SizedBox(height: gap),
            row([(8, const _Chart()), (4, const _Sources())]),
            SizedBox(height: gap),
            row([(4, _Formats(fill: wide)), (8, const _Creators())]),
            SizedBox(height: gap),
            const _Shortcuts(),
          ],
        );
      },
    );
  }
}

/// `.wg` with the stats page's 24px padding and a 128px floor.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 128),
    child: PCard(child: child),
  );
}

Widget _figure(
  AppColors colors,
  String number, {
  String? unit,
  bool dispUnit = true,
}) => Text.rich(
  TextSpan(
    text: number,
    style: pDisp(44, color: colors.textPrimary).copyWith(height: 0.9),
    children: [
      if (unit != null && unit.isNotEmpty)
        TextSpan(
          text: ' $unit',
          style: dispUnit
              ? pDisp(22, color: colors.textDisabled)
              : pBody(
                  colors,
                  color: colors.textSecondary,
                ).copyWith(letterSpacing: 0),
        ),
    ],
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

/// "1 284": grouped thousands in the user's language.
String _count(String locale, int n) =>
    NumberFormat.decimalPattern(locale).format(n).replaceAll(' ', ' ');

class _Downloads extends ConsumerWidget {
  const _Downloads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final n = ref.watch(downloadStatsProvider.select((s) => s.totalDownloads));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PHead(
            icon: Icons.download_rounded,
            label: l10n.porcelaineStatsDownloads,
            tint: colors.primary,
            bottom: 16,
          ),
          const Spacer(),
          _figure(colors, _count(l10n.localeName, n)),
        ],
      ),
    );
  }
}

class _Volume extends ConsumerWidget {
  const _Volume();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bytes = ref.watch(
      downloadStatsProvider.select((s) => s.totalBytesDownloaded),
    );
    final text = localBytes(l10n, bytes);
    final i = text.lastIndexOf(' ');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PHead(
            icon: Icons.storage_rounded,
            label: l10n.porcelaineStatsVolume,
            tint: pPink,
            bottom: 16,
          ),
          const Spacer(),
          _figure(colors, text.substring(0, i), unit: text.substring(i + 1)),
        ],
      ),
    );
  }
}

class _Today extends ConsumerWidget {
  const _Today();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final n = ref.watch(downloadStatsProvider.select((s) => s.downloadsToday));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PHead(
            icon: Icons.schedule_rounded,
            label: l10n.statsToday,
            tint: pSlate,
            bottom: 16,
          ),
          const Spacer(),
          _figure(
            colors,
            '$n',
            unit: l10n.porcelaineStatsDownloadsUnit,
            dispUnit: false,
          ),
        ],
      ),
    );
  }
}

/// The mockup's « Débit moyen » has no source (speeds are not recorded):
/// the free space today's page shows takes its place.
class _FreeSpace extends ConsumerWidget {
  const _FreeSpace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final low = free != null && free < DiskSpaceService.minRequiredBytes;
    final text = free == null ? '— ' : localBytes(l10n, free);
    final i = text.lastIndexOf(' ');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PHead(
            icon: Icons.speed_rounded,
            label: l10n.freeSpace,
            tint: low ? colors.error : pGreen,
            bottom: 16,
          ),
          const Spacer(),
          _figure(colors, text.substring(0, i), unit: text.substring(i + 1)),
        ],
      ),
    );
  }
}

// ── Daily chart ────────────────────────────────────────────────────────────

class _Chart extends ConsumerStatefulWidget {
  const _Chart();

  @override
  ConsumerState<_Chart> createState() => _ChartState();
}

class _ChartState extends ConsumerState<_Chart> {
  int _days = 30;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final byDay = {for (final d in stats.dailyHistory) d.date: d};
    final now = DateTime.now();
    final days = [
      for (var i = _days - 1; i >= 0; i--) now.subtract(Duration(days: i)),
    ];
    final counts = [for (final d in days) byDay[_key(d)]?.downloads ?? 0];
    counts[counts.length - 1] = stats.downloadsToday;
    final peak = counts.fold<int>(1, math.max);
    final axis = _days == 7
        ? [
            for (final d in days)
              DateFormat.E(l10n.localeName).format(d).toLowerCase(),
          ]
        : [
            l10n.porcelaineDaysAgo(30),
            l10n.porcelaineDaysAgo(15),
            l10n.porcelaineTodayAxis,
          ];
    final title = _days == 7 ? l10n.last7DaysShort : l10n.porcelaineLast30Days;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PHead(
                  icon: Icons.bar_chart_rounded,
                  label: l10n.porcelaineStatsChartTitle(title),
                  tint: colors.primary,
                  bottom: 0,
                ),
              ),
              PSegmented<int>(
                options: [
                  (7, l10n.porcelaineDaysShort(7)),
                  (30, l10n.porcelaineDaysShort(30)),
                ],
                value: _days,
                onChanged: (v) => setState(() => _days = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: l10n.porcelaineStatsChartTitle(title),
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _GridPainter(colors.textPrimary),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < counts.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _Bar(
                            factor: counts[i] == 0 ? 0.02 : counts[i] / peak,
                            today: i == counts.length - 1,
                            tooltip: l10n.chartDownloadsTooltip(
                              counts[i],
                              localBytes(
                                l10n,
                                byDay[_key(days[i])]?.bytes ?? 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < axis.length; i++)
                  Expanded(
                    child: Text(
                      axis[i],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: axis.length == 3
                          ? (i == 0
                                ? TextAlign.start
                                : i == 2
                                ? TextAlign.end
                                : TextAlign.center)
                          : TextAlign.center,
                      style: pMono(
                        colors,
                        size: 11,
                        color: colors.textDisabled,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = ink.withValues(alpha: 0.06);
    for (var i = 0; i < 4; i++) {
      final y = (size.height * i / 4).floorToDouble();
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = ink.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.ink != ink;
}

class _Bar extends StatefulWidget {
  const _Bar({
    required this.factor,
    required this.today,
    required this.tooltip,
  });

  final double factor;
  final bool today;
  final String tooltip;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tint = Color.alphaBlend(
      colors.primary.withValues(alpha: _hover ? 0.4 : 0.18),
      colors.surface,
    );
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.1, end: 1),
          duration: pMotion(context, 600),
          curve: pEase,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: (widget.factor * t).clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: pMotion(context, 200),
              decoration: BoxDecoration(
                color: widget.today ? colors.primary : tint,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sources ────────────────────────────────────────────────────────────────

class _Sources extends ConsumerWidget {
  const _Sources();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final by = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsBySource),
    );
    final merged = <String, int>{};
    for (final e in by.entries) {
      final k = e.key.toLowerCase();
      if (e.value <= 0 || k.isEmpty || k == 'local' || k == 'other') continue;
      final name =
          MediaSourceResolver.resolve(
            url: 'https://${e.key}',
            filePath: null,
          ) ??
          e.key;
      merged[name] = (merged[name] ?? 0) + e.value;
    }
    final total = merged.values.fold<int>(0, (a, b) => a + b);
    final top = merged.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final tints = [colors.textPrimary, colors.primary, pPink, pSlate];
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.sort_rounded,
            label: l10n.porcelaineBySource,
            bottom: 20,
          ),
          if (top.isEmpty) PEmptyRows(text: l10n.noSourceData),
          for (var i = 0; i < top.length && i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    top[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(colors, weight: FontWeight.w500),
                  ),
                ),
                Text(
                  _count(l10n.localeName, top[i].value),
                  style: pMono(colors, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 7),
            PBar(value: top[i].value / total, height: 7, color: tints[i]),
          ],
        ],
      ),
    );
  }
}

// ── Formats ────────────────────────────────────────────────────────────────

class _Formats extends ConsumerWidget {
  const _Formats({required this.fill});

  /// In a row of equal-height cards the donut centres in the space left.
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final byKind = {for (final k in MediaKind.values) k: 0};
    for (final i in items) {
      if (i.status == DownloadStatus.completed) {
        byKind[mediaKindOf(i)] = byKind[mediaKindOf(i)]! + 1;
      }
    }
    final total = byKind.values.fold<int>(0, (a, b) => a + b);
    final tints = [colors.primary, pPink, pSlate];
    final labels = [
      l10n.designFilterVideo,
      l10n.designFilterAudio,
      l10n.designFilterImages,
    ];
    final shares = [
      for (final k in MediaKind.values) total == 0 ? 0.0 : byKind[k]! / total,
    ];
    final pct = [for (final s in shares) '${(s * 100).round()} %'];
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.donut_large_rounded,
            label: l10n.porcelaineByFormat,
            tint: pPink,
            bottom: 16,
          ),
          _expand(
            fill,
            Row(
              children: [
                Semantics(
                  label: [
                    for (var i = 0; i < 3; i++) '${labels[i]} ${pct[i]}',
                  ].join(', '),
                  child: SizedBox(
                    width: 124,
                    height: 124,
                    child: CustomPaint(
                      painter: _DonutPainter(
                        shares,
                        tints,
                        pTrack(colors),
                        colors.surface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: tints[i],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(labels[i], style: pBody(colors)),
                              ),
                              Text(
                                pct[i],
                                style: pDisp(20, color: colors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _expand(bool fill, Widget child) =>
    fill ? Expanded(child: child) : child;

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares, this.tints, this.track, this.hole);

  final List<double> shares;
  final List<Color> tints;
  final Color track;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = track);
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        true,
        Paint()..color = tints[i],
      );
      start += sweep;
    }
    canvas.drawCircle(c, 42, Paint()..color = hole);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.shares.join() != shares.join() || old.hole != hole;
}

// ── Top creators ───────────────────────────────────────────────────────────

class _Creators extends ConsumerWidget {
  const _Creators();

  static const _tones = [
    Color(0xFFC9D3CC),
    Color(0xFFD8CFBD),
    Color(0xFFCDCAD8),
    Color(0xFFD5CEC4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final done = [
      for (final i in items)
        if (i.status == DownloadStatus.completed) i,
    ];
    final folders = [
      for (final f in CreatorFolderGrouper.fromItems(
        done,
        order: CreatorFolderOrder.countDesc,
      ))
        if (!f.isUnknown) f,
    ];
    final top = folders.take(4).toList();
    final peak = top.isEmpty ? 1 : top.first.count;
    String initials(String name) {
      final words = name
          .replaceAll('@', '')
          .split(RegExp(r'[\s._-]+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) return '?';
      final a = words.first.characters.first;
      final b = words.length > 1
          ? words[1].characters.first
          : (words.first.characters.length > 1
                ? words.first.characters.elementAt(1)
                : '');
      return (a + b).toUpperCase();
    }

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.person_outline_rounded,
            label: l10n.porcelaineTopCreators,
            tint: pGreen,
            bottom: 16,
            trailing: Expanded(
              child: Text(
                l10n.porcelaineStatsDownloadsUnit,
                textAlign: TextAlign.end,
                style: pBody(
                  colors,
                  size: 13,
                  weight: FontWeight.w500,
                  color: colors.textDisabled,
                ),
              ),
            ),
          ),
          if (top.isEmpty)
            PEmptyRows(text: l10n.noDownloadHistory, numbered: true),
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: pMono(colors, color: colors.textDisabled),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tones[i % _tones.length],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    initials(top[i].handle!),
                    style: pBody(colors, size: 12, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: SizedBox(
                      width: 220,
                      child: Text(
                        top[i].handle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(colors, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: PBar(
                    value: top[i].count / peak,
                    height: 7,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${top[i].count}',
                    textAlign: TextAlign.end,
                    style: pMono(colors, size: 14, color: colors.textPrimary),
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

// ── Keyboard shortcuts (today's page lists them) ───────────────────────────

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.keyboard_rounded,
            label: l10n.keyboardShortcuts,
            tint: pSlate,
            bottom: 16,
          ),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              for (final (keys, label) in [
                ('Ctrl+N', l10n.newDownloadShortcut),
                ('Ctrl+,', l10n.settingsShortcut),
                ('Ctrl+D', l10n.dashboardShortcut),
                ('Esc', l10n.minimizeShortcut),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        keys,
                        style: pMono(colors, color: colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: pBody(
                        colors,
                        size: 13,
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
