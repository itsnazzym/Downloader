import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/design_system/foundation/colors.dart';
import 'package:tapload/core/design_system/foundation/spacing.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/services/disk_space_service.dart';
import 'package:tapload/core/utils/format_utils.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  int? _freeSpace;

  @override
  void initState() {
    super.initState();
    _loadDiskSpace();
  }

  Future<void> _loadDiskSpace() async {
    if (ref.read(showcaseModeProvider)) {
      _freeSpace = 512 * 1024 * 1024 * 1024;
      return;
    }
    final space = await DiskSpaceService.getFreeDiskSpace();
    if (mounted) {
      setState(() => _freeSpace = space);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(downloadStatsProvider);
    final l10n = context.l10n;

    final isMobile =
        PlatformInfo.isMobile || MediaQuery.sizeOf(context).width < 640;

    if (isMobile) return _buildMobile(context, stats);

    final statCards = [
      _StatCard(
        icon: Icons.download_rounded,
        label: l10n.totalDownloads,
        value: stats.totalDownloads.toString(),
        color: AppColors.of(context).primary,
        delay: 0,
      ),
      _StatCard(
        icon: Icons.today_rounded,
        label: l10n.statsToday,
        value: stats.downloadsToday.toString(),
        color: AppColors.of(context).info,
        delay: 100,
      ),
      _StatCard(
        icon: Icons.data_usage_rounded,
        label: l10n.totalData,
        value: FormatUtils.formatBytes(stats.totalBytesDownloaded),
        color: AppColors.of(context).success,
        delay: 200,
      ),
      _StatCard(
        icon: Icons.storage_rounded,
        label: l10n.freeSpace,
        value: _freeSpace != null
            ? FormatUtils.formatBytes(_freeSpace!)
            : '...',
        color:
            _freeSpace != null &&
                _freeSpace! < DiskSpaceService.minRequiredBytes
            ? AppColors.of(context).error
            : AppColors.of(context).success,
        delay: 300,
      ),
    ];

    final activityChartPanel = _GlassPanel(
      title: l10n.downloadActivity,
      subtitle: l10n.last7DaysShort,
      delay: 400,
      child: SizedBox(height: 200, child: _buildActivityChart(stats)),
    );

    final sourceChartPanel = _GlassPanel(
      title: l10n.sourcesChartTitle,
      subtitle: l10n.sourcesByPlatform,
      delay: 500,
      child: SizedBox(height: 200, child: _buildSourceChart(stats)),
    );

    return Container(
      color: AppColors.of(context).background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              l10n.statistics,
              style: (isMobile ? AppTypography.h3 : AppTypography.h2).copyWith(
                color: AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05),
            const Gap(AppSpacing.xxs),
            Text(
              l10n.statsSubtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const Gap(AppSpacing.l),

            // Top stat cards
            if (isMobile)
              GridView.count(
                key: OnboardingTargets.stats,
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.m,
                crossAxisSpacing: AppSpacing.m,
                childAspectRatio: 1.4,
                children: statCards,
              )
            else
              Row(
                key: OnboardingTargets.stats,
                children: [
                  for (int i = 0; i < statCards.length; i++) ...[
                    if (i > 0) const Gap(AppSpacing.m),
                    Expanded(child: statCards[i]),
                  ],
                ],
              ),

            const Gap(AppSpacing.xl),

            // Charts
            if (isMobile) ...[
              activityChartPanel,
              const Gap(AppSpacing.m),
              sourceChartPanel,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: activityChartPanel),
                  const Gap(AppSpacing.m),
                  Expanded(flex: 1, child: sourceChartPanel),
                ],
              ),

            if (!isMobile) ...[
              const Gap(AppSpacing.xl),
              // Keyboard shortcuts reference (desktop only)
              _GlassPanel(
                title: l10n.keyboardShortcuts,
                subtitle: l10n.shortcutsQuickActions,
                delay: 600,
                child: Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.s,
                  children: [
                    _ShortcutChip(
                      keys: 'Ctrl+N',
                      label: l10n.newDownloadShortcut,
                    ),
                    _ShortcutChip(keys: 'Ctrl+,', label: l10n.settingsShortcut),
                    _ShortcutChip(
                      keys: 'Ctrl+D',
                      label: l10n.dashboardShortcut,
                    ),
                    _ShortcutChip(keys: 'Esc', label: l10n.minimizeShortcut),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Mobile (Android OLED) layout ---

  Widget _buildMobile(BuildContext context, DownloadStats stats) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final total = _splitBytes(context, stats.totalBytesDownloaded);
    final lowSpace =
        _freeSpace != null && _freeSpace! < DiskSpaceService.minRequiredBytes;

    return SingleChildScrollView(
      key: OnboardingTargets.stats,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                OledIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: l10n.statsMobileBackToLibrary,
                  outlined: false,
                  onPressed: () => context.go('/'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.statistics,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(
                      context,
                      size: 20,
                      weight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statsMobileTotalSinceInstall,
                  style: OledText.ui(context, size: 13, color: t.ink2),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          total.$1,
                          style: OledText.dot(context, size: 100),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        total.$2,
                        style: OledText.ui(
                          context,
                          size: 22,
                          weight: FontWeight.w600,
                          color: t.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _downloadsSummary(l10n, stats),
                  style: OledText.ui(context, size: 14, color: t.ink2),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: OledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.statsMobileActivity,
                          style: OledText.ui(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l10n.statsMobileLast12Weeks,
                        style: OledText.ui(context, size: 12, color: t.ink2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildHeatmap(context, stats),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        l10n.statsMobileLess,
                        style: OledText.ui(context, size: 12, color: t.ink2),
                      ),
                      for (var level = 0; level < 4; level++) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _heatColor(t, level),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        l10n.statsMobileMore,
                        style: OledText.ui(context, size: 12, color: t.ink2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: OledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsMobileBySource,
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSourceBreakdown(context, stats),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: OledCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.freeSpace,
                      style: OledText.ui(context, size: 14),
                    ),
                  ),
                  Text(
                    _freeSpace != null
                        ? FormatUtils.formatBytes(_freeSpace!)
                        : '...',
                    style: OledText.ui(
                      context,
                      size: 14,
                      color: lowSpace ? t.warn : t.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _downloadsSummary(AppLocalizations l10n, DownloadStats stats) {
    return l10n.statsMobileDownloadsSummary(
      stats.totalDownloads,
      stats.downloadsToday,
    );
  }

  /// Splits a byte count into a localized figure and unit, e.g. ("18,6", "Go").
  (String, String) _splitBytes(BuildContext context, int bytes) {
    final l10n = context.l10n;
    final units = [
      l10n.statsMobileUnitB,
      l10n.statsMobileUnitKB,
      l10n.statsMobileUnitMB,
      l10n.statsMobileUnitGB,
      l10n.statsMobileUnitTB,
    ];
    if (bytes <= 0) return ('0', units[0]);
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    final text = i == 0
        ? value.toStringAsFixed(0)
        : (value >= 100
              ? value.toStringAsFixed(0)
              : NumberFormat(
                  '0.0',
                  l10n.localeName,
                ).format(double.parse(value.toStringAsFixed(1))));
    return (text, units[i]);
  }

  Color _heatColor(OledTokens t, int level) {
    const alphas = [0.10, 0.30, 0.60, 1.0];
    return t.ink.withValues(alpha: alphas[level.clamp(0, 3)]);
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 12 weeks x 7 days, one column per week (Monday on top, current week on
  /// the right). Days without recorded downloads stay at the lowest level.
  Widget _buildHeatmap(BuildContext context, DownloadStats stats) {
    final t = OledTokens.of(context);
    final byDay = <String, int>{
      for (final d in stats.dailyHistory) d.date: d.downloads,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) - 11 * 7,
    );

    // downloads per cell, null for days that have not happened yet
    final cells = <List<int?>>[];
    var peak = 0;
    for (var week = 0; week < 12; week++) {
      final column = <int?>[];
      for (var day = 0; day < 7; day++) {
        final date = DateTime(
          start.year,
          start.month,
          start.day + week * 7 + day,
        );
        if (date.isAfter(today)) {
          column.add(null);
        } else {
          final n = byDay[_dayKey(date)] ?? 0;
          if (n > peak) peak = n;
          column.add(n);
        }
      }
      cells.add(column);
    }

    int levelFor(int n) {
      if (n <= 0 || peak <= 0) return 0;
      final ratio = n / peak;
      if (ratio <= 1 / 3) return 1;
      if (ratio <= 2 / 3) return 2;
      return 3;
    }

    return Semantics(
      image: true,
      label: context.l10n.statsMobileHeatmapLabel,
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 4.0;
          final cell = (box.maxWidth - gap * 11) / 12;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final column in cells)
                Column(
                  children: [
                    for (var i = 0; i < column.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == 6 ? 0 : gap),
                        child: SizedBox(
                          width: cell,
                          height: cell,
                          child: column[i] == null
                              ? null
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _heatColor(t, levelFor(column[i]!)),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  /// Segmented share bar plus one legend row per source (by download count).
  Widget _buildSourceBreakdown(BuildContext context, DownloadStats stats) {
    final t = OledTokens.of(context);
    final sources = Map<String, int>.from(stats.downloadsBySource)
      ..removeWhere(
        (key, value) =>
            value <= 0 ||
            key.isEmpty ||
            key.toLowerCase() == 'local' ||
            key.toLowerCase() == 'other',
      );

    if (sources.isEmpty) {
      return Text(
        context.l10n.noSourceData,
        style: OledText.ui(context, size: 14, color: t.ink2),
      );
    }

    final sorted = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final grand = sorted.fold<int>(0, (sum, e) => sum + e.value);
    final rows = <MapEntry<String, int>>[
      if (sorted.length > 5) ...sorted.take(4) else ...sorted,
      if (sorted.length > 5)
        MapEntry(
          context.l10n.statsMobileOthers,
          sorted.skip(4).fold<int>(0, (sum, e) => sum + e.value),
        ),
    ];
    const alphas = [1.0, 0.7, 0.45, 0.28, 0.16];
    Color shade(int i) => t.ink.withValues(alpha: alphas[i % alphas.length]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++)
                Expanded(
                  flex: rows[i].value,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == rows.length - 1 ? 0 : 3,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: shade(i),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: shade(i),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(context, size: 14),
                  ),
                ),
                Text(
                  '${rows[i].value}',
                  style: OledText.ui(context, size: 14, color: t.ink2),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(rows[i].value * 100 / grand).round()} %',
                    textAlign: TextAlign.end,
                    style: OledText.ui(context, size: 14, color: t.ink3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityChart(DownloadStats stats) {
    final history = stats.dailyHistory;

    if (history.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noDownloadHistory,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
        ),
      );
    }

    // Get last 7 days of data
    final last7 = history.length > 7
        ? history.sublist(history.length - 7)
        : history;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (() {
          final peak = last7
              .map((d) => d.downloads)
              .fold<int>(0, (a, b) => a > b ? a : b);
          return (peak < 1 ? 1 : peak) * 1.3;
        })(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.of(context).surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = last7[group.x.toInt()];
              return BarTooltipItem(
                context.l10n.chartDownloadsTooltip(
                  day.downloads,
                  FormatUtils.formatBytes(day.bytes),
                ),
                AppTypography.caption.copyWith(
                  color: AppColors.of(context).textPrimary,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < last7.length) {
                  final date = last7[idx].date;
                  // Show day name from date string
                  final parts = date.split('-');
                  return Text(
                    '${parts[2]}/${parts[1]}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 9,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(last7.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: last7[i].downloads.toDouble(),
                gradient: LinearGradient(
                  colors: [
                    AppColors.of(context).primary,
                    AppColors.of(context).primaryVariant,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSourceChart(DownloadStats stats) {
    final sources = Map<String, int>.from(stats.downloadsBySource)
      ..removeWhere(
        (key, value) =>
            value <= 0 ||
            key.isEmpty ||
            key.toLowerCase() == 'local' ||
            key.toLowerCase() == 'other',
      );

    if (sources.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noSourceData,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
        ),
      );
    }

    // Sort sources by count and take top 5
    final sorted = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    final colors = [
      AppColors.of(context).primary,
      AppColors.of(context).info,
      AppColors.of(context).success,
      AppColors.of(context).warning,
      AppColors.of(context).error,
    ];

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 24,
              sections: List.generate(top.length, (i) {
                return PieChartSectionData(
                  value: top[i].value.toDouble(),
                  color: colors[i % colors.length],
                  radius: 36,
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const Gap(AppSpacing.s),
        // Legend
        ...List.generate(top.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(AppSpacing.xs),
                Expanded(
                  child: Text(
                    top[i].key,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.of(context).textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${top[i].value}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.of(context).textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// --- Components ---

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Cards sit on a solid background: a backdrop blur only cost GPU time on
    // every scroll frame.
    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const Spacer(),
                  ],
                ),
                const Gap(AppSpacing.m),
                Text(
                  value,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.of(context).textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: delay),
        )
        .slideY(begin: 0.1);
  }
}

class _GlassPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final int delay;

  const _GlassPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Cards sit on a solid background: a backdrop blur only cost GPU time on
    // every scroll frame.
    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.of(context).textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
                const Gap(AppSpacing.m),
                child,
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: delay),
        )
        .slideY(begin: 0.1);
  }
}

class _ShortcutChip extends StatelessWidget {
  final String keys;
  final String label;

  const _ShortcutChip({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.of(context).background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Text(
              keys,
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
