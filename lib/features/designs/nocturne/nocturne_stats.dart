import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/services/disk_space_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'nocturne_widgets.dart';

/// Nocturne's statistics (mockup Nocturne-Stats.dc.html): key figures, the
/// daily bars, sources, formats and the keyboard shortcuts.
class NocturneStats extends ConsumerStatefulWidget {
  const NocturneStats({super.key});

  @override
  ConsumerState<NocturneStats> createState() => _NocturneStatsState();
}

class _NocturneStatsState extends ConsumerState<NocturneStats> {
  int? _days;

  /// The desktop library rebuild keeps 7 days of history: 30 only when the
  /// history holds an older day.
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
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    (String, String) split(String s) {
      final i = s.lastIndexOf(' ');
      return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 1));
    }

    final volume = split(localBytes(l10n, stats.totalBytesDownloaded));
    final freeLabel = free == null ? ('—', '') : split(localBytes(l10n, free));
    return SingleChildScrollView(
      padding: nocturnePagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneHeader(
            eyebrow: l10n.statistics,
            title: l10n.nocturneStatsTitle,
          ),
          const SizedBox(height: 22),
          KeyedSubtree(
            key: OnboardingTargets.stats,
            child: NocturneAutoGrid(
              minWidth: 200,
              children: [
                _Kpi(
                  icon: Icons.file_download_outlined,
                  label: l10n.nocturneStatDownloads,
                  value: (_group(stats.totalDownloads), ''),
                ),
                _Kpi(
                  icon: Icons.storage_rounded,
                  label: l10n.nocturneStatVolume,
                  value: volume,
                ),
                _Kpi(
                  icon: Icons.schedule_rounded,
                  label: l10n.statsToday,
                  value: (_group(stats.downloadsToday), ''),
                ),
                // The mockup's average speed is not recorded: free space.
                _Kpi(
                  icon: Icons.speed_rounded,
                  label: l10n.freeSpace,
                  value: freeLabel,
                  warn:
                      free != null && free < DiskSpaceService.minRequiredBytes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          NocturneCard(
            lift: false,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: _Activity(
              stats: stats,
              periods: _covers30(stats) ? const [7, 30] : const [7],
              days: _covers30(stats) ? (_days ?? 30) : 7,
              onDays: (d) => setState(() => _days = d),
            ),
          ),
          const SizedBox(height: 22),
          NocturneAutoGrid(
            minWidth: 270,
            children: [
              _BySource(stats: stats),
              const _ByFormat(),
              const _Shortcuts(),
            ],
          ),
        ],
      ),
    );
  }

  /// "1 284": thin-space thousands like the mockup.
  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final (String, String) value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NocturneCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: warn ? c.error : c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nocturneText(c, size: 12.5, color: c.textDisabled),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: value.$1,
              style: nocturneMono(
                c,
                size: 28,
                color: warn ? c.error : c.textPrimary,
              ).copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.56),
              children: [
                if (value.$2.isNotEmpty)
                  TextSpan(
                    text: ' ${value.$2}',
                    style: nocturneMono(c, size: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({
    required this.stats,
    required this.periods,
    required this.days,
    required this.onDays,
  });

  final DownloadStats stats;
  final List<int> periods;
  final int days;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final byDay = {for (final d in stats.dailyHistory) d.date: d};
    final today = DateTime.now();
    final series = [
      for (var i = days - 1; i >= 0; i--)
        byDay[_key(today.subtract(Duration(days: i)))],
    ];
    final max = series.fold<int>(1, (m, d) => d == null || d.downloads < m ? m : d.downloads);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NocturneTitle(l10n.nocturneLastDays(days)),
                  const SizedBox(height: 3),
                  Text(
                    l10n.nocturnePerDay,
                    style: nocturneText(c, size: 12.5, color: c.textDisabled),
                  ),
                ],
              ),
            ),
            NocturneSegmented<int>(
              height: 32,
              padding: 13,
              value: days,
              onChanged: onDays,
              segments: [
                for (final p in periods)
                  NocturneSegment(p, l10n.nocturneDaysShort(p)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 176,
          child: CustomPaint(
            painter: _GridPainter(c.primary.withValues(alpha: 0.07)),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++) ...[
                    if (i > 0) SizedBox(width: days > 7 ? 6 : 18),
                    Expanded(
                      child: _Bar(
                        day: series[i],
                        ratio: (series[i]?.downloads ?? 0) / max,
                        now: i == series.length - 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.nocturneDaysAgo(days),
              style: nocturneText(c, size: 12, color: c.textDisabled),
            ),
            Text(
              l10n.nocturneToday,
              style: nocturneText(c, size: 12, color: c.textDisabled),
            ),
          ],
        ),
      ],
    );
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.ratio, required this.now});

  final DailyStats? day;
  final double ratio;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final count = day?.downloads ?? 0;
    return Tooltip(
      message: l10n.chartDownloadsTooltip(
        count,
        localBytes(l10n, day?.bytes ?? 0),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Container(
          // Empty days keep a 3px stub so the rhythm of the days stays.
          height: count == 0 ? 3 : (box.maxHeight * ratio).clamp(6, box.maxHeight),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(3),
            ),
            color: now ? c.primary : null,
            gradient: now
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.primary.withValues(alpha: 0.55),
                      c.primary.withValues(alpha: 0.16),
                    ],
                  ),
            boxShadow: now
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Hairlines every 44px from the bottom (the mockup's background grid).
class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = size.height - 1; y >= 0; y -= 44) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _BySource extends StatelessWidget {
  const _BySource({required this.stats});

  final DownloadStats stats;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final entries = stats.downloadsBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return NocturneCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneTitle(l10n.nocturneBySource),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              l10n.noSourceData,
              style: nocturneText(c, color: c.textSecondary),
            ),
          for (final e in entries.take(5)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sourceName(e.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c),
                  ),
                ),
                Text('${e.value}', style: nocturneMono(c, size: 13.5)),
              ],
            ),
            const SizedBox(height: 6),
            NocturneBar(value: total == 0 ? 0 : e.value / total),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  /// "youtube.com" -> "YouTube"-ish: the domain without its suffix.
  static String _sourceName(String raw) {
    const known = {
      'youtube': 'YouTube',
      'youtu': 'YouTube',
      'tiktok': 'TikTok',
      'instagram': 'Instagram',
      'x': 'X',
      'twitter': 'X',
      'vimeo': 'Vimeo',
      'twitch': 'Twitch',
      'facebook': 'Facebook',
    };
    final host = raw.replaceFirst(RegExp(r'^www\.'), '').split('.').first;
    return known[host.toLowerCase()] ??
        (host.isEmpty ? raw : host[0].toUpperCase() + host.substring(1));
  }
}

class _ByFormat extends ConsumerWidget {
  const _ByFormat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    // Kinds change with the catalogue, not with progress ticks.
    final kinds = ref.watch(
      downloadListProvider.select((s) {
        final counts = <MediaKind, int>{};
        for (final DownloadItem i in s.valueOrNull ?? const []) {
          if (i.status != DownloadStatus.completed) continue;
          counts[mediaKindOf(i)] = (counts[mediaKindOf(i)] ?? 0) + 1;
        }
        return (
          counts[MediaKind.video] ?? 0,
          counts[MediaKind.audio] ?? 0,
          counts[MediaKind.image] ?? 0,
        );
      }),
    );
    final total = kinds.$1 + kinds.$2 + kinds.$3;
    double share(int n) => total == 0 ? 0 : n / total;
    Widget ring(int n, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NocturneRing(
          value: share(n),
          size: 76,
          stroke: 7,
          radius: 30,
          child: Text(
            '${(share(n) * 100).round()} %',
            style: nocturneMono(
              c,
              size: 15,
              color: c.textPrimary,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: nocturneText(c, color: c.textSecondary)),
      ],
    );
    return NocturneCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneTitle(l10n.nocturneByFormat),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              ring(kinds.$1, l10n.designFilterVideo),
              ring(kinds.$2, l10n.designFilterAudio),
              ring(kinds.$3, l10n.designFilterImages),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today's stats page lists the keyboard shortcuts: kept here, in the slot
/// of the mockup's "Top créateurs" (no creator data is recorded).
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final rows = [
      ('Ctrl+N', l10n.newDownloadShortcut),
      ('Ctrl+,', l10n.settingsShortcut),
      ('Ctrl+D', l10n.dashboardShortcut),
      ('Esc', l10n.minimizeShortcut),
    ];
    return NocturneCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneTitle(l10n.keyboardShortcuts),
          const SizedBox(height: 12),
          for (final (keys, label) in rows) ...[
            Row(
              children: [
                Container(
                  height: 34,
                  constraints: const BoxConstraints(minWidth: 54),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: nocturneTint(keys.hashCode),
                  ),
                  child: Text(
                    keys,
                    style: nocturneMono(c, size: 12, color: c.textPrimary)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
