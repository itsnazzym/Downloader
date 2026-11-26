import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'studio_widgets.dart';

/// Studio's statistics (mockup Studio-Stats.dc.html): four figures in one
/// panel, the daily bars, by source / by format, top creators, then today's
/// keyboard shortcuts reference.
class StudioStats extends StatelessWidget {
  const StudioStats({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
        final split = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, 30, side, 40),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.statistics, style: studioTitle(c)),
                  const SizedBox(height: 6),
                  Text(
                    l10n.studioStatsSubtitle,
                    style: studioText(c, color: c.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: OnboardingTargets.stats,
                    child: const _Kpis(),
                  ),
                  const SizedBox(height: 20),
                  const _Chart(),
                  const SizedBox(height: 20),
                  if (split)
                    const IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _BySource()),
                          SizedBox(width: 16),
                          Expanded(child: _ByFormat()),
                        ],
                      ),
                    )
                  else ...[
                    const _BySource(),
                    const SizedBox(height: 16),
                    const _ByFormat(),
                  ],
                  const SizedBox(height: 20),
                  const _TopCreators(),
                  const SizedBox(height: 20),
                  const _Shortcuts(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _count(AppLocalizations l10n, int n) =>
    NumberFormat.decimalPattern(l10n.localeName).format(n);

/// "418" + " Go" for a big figure with a small unit.
(String, String) _split(String label) {
  final i = label.lastIndexOf(' ');
  return i < 0 ? (label, '') : (label.substring(0, i), label.substring(i));
}

class _Kpis extends ConsumerWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (total, today, bytes) = ref.watch(
      downloadStatsProvider.select(
        (s) => (s.totalDownloads, s.downloadsToday, s.totalBytesDownloaded),
      ),
    );
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    // No average speed is recorded: « Débit moyen » becomes the free space.
    final kpis = [
      (l10n.downloads, (_count(l10n, total), '')),
      (l10n.studioStorage, _split(localBytes(l10n, bytes))),
      (l10n.statsToday, (_count(l10n, today), '')),
      (l10n.freeSpace, free == null ? ('—', '') : _split(localBytes(l10n, free))),
    ];
    return StudioPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = (constraints.maxWidth / 180).floor().clamp(1, 4);
          final width = constraints.maxWidth / perRow;
          return Wrap(
            children: [
              for (var i = 0; i < kpis.length; i++)
                Container(
                  width: width,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    border: i % perRow == 0
                        ? null
                        : BorderDirectional(
                            start: BorderSide(color: c.borderSubtle),
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StudioCap(kpis[i].$1),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          text: kpis[i].$2.$1,
                          style: studioMono(
                            c,
                            size: 28,
                            color: c.textPrimary,
                          ).copyWith(letterSpacing: -0.56, height: 1.2),
                          children: [
                            TextSpan(
                              text: kpis[i].$2.$2,
                              style: studioMono(c, size: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Chart extends ConsumerStatefulWidget {
  const _Chart();

  @override
  ConsumerState<_Chart> createState() => _ChartState();
}

class _ChartState extends ConsumerState<_Chart> {
  // The service keeps 30 days: no « 12 mois » period.
  int _days = 30;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final history = ref.watch(downloadStatsProvider.select((s) => s.dailyHistory));
    final byDay = {for (final d in history) d.date: d};
    final now = DateTime.now();
    final days = [
      for (var i = _days - 1; i >= 0; i--)
        byDay[_key(now.subtract(Duration(days: i)))] ??
            DailyStats(date: _key(now.subtract(Duration(days: i)))),
    ];
    final peak = days.fold<int>(0, (m, d) => d.downloads > m ? d.downloads : m);
    final none = ref.watch(
      downloadStatsProvider.select((s) => s.totalDownloads == 0),
    );
    return StudioPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _days == 7 ? l10n.studioChartTitle7 : l10n.studioChartTitle30,
                  style: studioTitle(c, 17).copyWith(letterSpacing: -0.34),
                ),
              ),
              const SizedBox(width: 12),
              _Segmented(
                label: l10n.studioPeriod,
                options: [(7, l10n.studioDays7), (30, l10n.studioDays30)],
                value: _days,
                onChanged: (v) => setState(() => _days = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _GridPainter(c.borderSubtle),
              // Nothing downloaded yet: say so on the empty grid.
              child: peak == 0 && none
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        color: c.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.studioNoStatsTitle,
                              textAlign: TextAlign.center,
                              style: studioTitle(
                                c,
                                17,
                              ).copyWith(letterSpacing: -0.34),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.studioNoStatsBody,
                              textAlign: TextAlign.center,
                              style: studioText(c, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: _Bar(
                          day: days[i],
                          fraction: peak == 0 ? 0 : days[i].downloads / peak,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.studioDaysAgo(_days),
                style: studioMono(c, size: 11, color: c.textDisabled),
              ),
              Text(
                l10n.studioToday,
                style: studioMono(c, size: 11, color: c.textDisabled),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal hairlines every 40px from the bottom, like the mockup's
/// repeating gradient.
class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = size.height - 1; y >= 0; y -= 40) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _Bar extends StatefulWidget {
  const _Bar({required this.day, required this.fraction});

  final DailyStats day;
  final double fraction;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.chartDownloadsTooltip(
        widget.day.downloads,
        localBytes(l10n, widget.day.bytes),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 56),
            child: FractionallySizedBox(
              heightFactor: widget.fraction,
              child: AnimatedContainer(
                duration: studioMotion(context, 160),
                decoration: BoxDecoration(
                  color: _hover ? c.textSecondary : c.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.seg`: a grey track holding small pills; the chosen one is white.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<(int, String)> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.borderSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, text) in options) ...[
              if (v != options.first.$1) const SizedBox(width: 2),
              Semantics(
                selected: v == value,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(v),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: studioMotion(context, 160),
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: v == value ? c.border : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      text,
                      style: studioText(
                        c,
                        size: 12,
                        color: v == value ? c.textPrimary : c.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w500),
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

/// A `label ─── value` row with a thin ink bar.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.fraction,
    required this.value,
    this.first = false,
  });

  final String label;
  final double fraction;
  final String value;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: studioText(c),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: StudioLine(value: fraction)),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: studioMono(c, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BySource extends ConsumerWidget {
  const _BySource();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final sources = ref.watch(
      downloadStatsProvider.select((s) => s.downloadsBySource),
    );
    final top = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peak = top.isEmpty ? 1 : top.first.value;
    return StudioPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioCap(l10n.studioBySource),
          const SizedBox(height: 6),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l10n.noSourceData,
                style: studioText(c, color: c.textSecondary),
              ),
            ),
          for (var i = 0; i < top.length && i < 5; i++)
            _BarRow(
              first: i == 0,
              // Stored by host ("youtube.com"): shown by name like the
              // library's Source column.
              label:
                  MediaSourceResolver.fromUrlString('https://${top[i].key}') ??
                  top[i].key,
              fraction: top[i].value / peak,
              value: _count(l10n, top[i].value),
            ),
        ],
      ),
    );
  }
}

class _ByFormat extends ConsumerWidget {
  const _ByFormat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    // Finished files only: stable across progress ticks.
    final (video, audio, image) = ref.watch(
      downloadListProvider.select((v) {
        var a = 0, b = 0, d = 0;
        for (final i in v.valueOrNull ?? const <DownloadItem>[]) {
          if (i.status != DownloadStatus.completed) continue;
          switch (mediaKindOf(i)) {
            case MediaKind.video:
              a++;
            case MediaKind.audio:
              b++;
            case MediaKind.image:
              d++;
          }
        }
        return (a, b, d);
      }),
    );
    final total = video + audio + image;
    const imageShade = Color(0xFFCFCCC5);
    final parts = [
      (l10n.designFilterVideo, video, c.primary),
      (l10n.designFilterAudio, audio, c.textDisabled),
      (l10n.designFilterImages, image, imageShade),
    ];
    int pct(int n) => total == 0 ? 0 : (n * 100 / total).round();
    final shown = [for (final p in parts) if (p.$2 > 0) p];
    return StudioPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioCap(l10n.studioByFormat),
          const SizedBox(height: 14),
          SizedBox(
            height: 10,
            child: shown.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: c.borderSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                : Row(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Expanded(
                          flex: shown[i].$2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: shown[i].$3,
                              borderRadius: BorderRadius.horizontal(
                                left: i == 0
                                    ? const Radius.circular(3)
                                    : Radius.zero,
                                right: i == shown.length - 1
                                    ? const Radius.circular(3)
                                    : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < parts.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: c.borderSubtle)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: parts[i].$3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: Text(parts[i].$1, style: studioText(c))),
                  Text(
                    '${pct(parts[i].$2)} %',
                    style: studioMono(c, color: c.textPrimary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopCreators extends ConsumerWidget {
  const _TopCreators();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The whole library grouped by creator; a record list compares by value.
    final top = ref.watch(
      downloadListProvider.select((v) {
        final folders = CreatorFolderGrouper.fromItems(
          v.valueOrNull ?? const <DownloadItem>[],
          order: CreatorFolderOrder.countDesc,
        );
        return _Top([
          for (final f in folders)
            if (!f.isUnknown) (f.handle!, f.count),
        ].take(5).toList());
      }),
    ).list;
    if (top.isEmpty) return const SizedBox.shrink();
    final peak = top.first.$2;
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(child: StudioCap(l10n.studioTopCreators)),
                StudioCap(l10n.downloads),
              ],
            ),
          ),
          for (var i = 0; i < top.length; i++)
            _CreatorRow(
              rank: i + 1,
              name: top[i].$1,
              count: top[i].$2,
              fraction: top[i].$2 / peak,
            ),
        ],
      ),
    );
  }
}

class _Top {
  const _Top(this.list);

  final List<(String, int)> list;

  @override
  bool operator ==(Object other) =>
      other is _Top &&
      other.list.length == list.length &&
      Iterable.generate(list.length).every((i) => other.list[i] == list[i]);

  @override
  int get hashCode => Object.hashAll(list);
}

class _CreatorRow extends StatefulWidget {
  const _CreatorRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.fraction,
  });

  final int rank;
  final String name;
  final int count;
  final double fraction;

  @override
  State<_CreatorRow> createState() => _CreatorRowState();
}

class _CreatorRowState extends State<_CreatorRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: studioMotion(context, 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _hover ? studioHover(c) : null,
          border: Border(top: BorderSide(color: c.borderSubtle)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                widget.rank.toString().padLeft(2, '0'),
                style: studioMono(c, color: c.textDisabled),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StudioUnderline(
                  text: widget.name,
                  hover: _hover,
                  style: studioText(c).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 16),
              SizedBox(width: 200, child: StudioLine(value: widget.fraction)),
            ],
            const SizedBox(width: 16),
            SizedBox(
              width: 40,
              child: Text(
                '${widget.count}',
                textAlign: TextAlign.end,
                style: studioMono(c, color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's keyboard shortcuts reference, as mono key chips.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final shortcuts = [
      ('Ctrl+N', l10n.newDownloadShortcut),
      ('Ctrl+,', l10n.settingsShortcut),
      ('Ctrl+D', l10n.dashboardShortcut),
      ('Esc', l10n.minimizeShortcut),
    ];
    return StudioPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioCap(l10n.keyboardShortcuts),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              for (final (keys, label) in shortcuts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.borderSubtle),
                      ),
                      child: Text(
                        keys,
                        style: studioMono(c, size: 12, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: studioText(c, color: c.textSecondary),
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
