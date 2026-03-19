import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../services/download_stats_service.dart';
import '../../services/disk_space_service.dart';
import '../../utils/format_utils.dart';

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
    final space = await DiskSpaceService.getFreeDiskSpace();
    if (mounted) {
      setState(() => _freeSpace = space);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(downloadStatsProvider);

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Statistics',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05),
            const Gap(AppSpacing.xxs),
            Text(
              'Track your download activity and storage usage',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const Gap(AppSpacing.xl),

            // Top stat cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.download_rounded,
                    label: 'Total Downloads',
                    value: stats.totalDownloads.toString(),
                    color: AppColors.primary,
                    delay: 0,
                  ),
                ),
                const Gap(AppSpacing.m),
                Expanded(
                  child: _StatCard(
                    icon: Icons.today_rounded,
                    label: 'Today',
                    value: stats.downloadsToday.toString(),
                    color: AppColors.info,
                    delay: 100,
                  ),
                ),
                const Gap(AppSpacing.m),
                Expanded(
                  child: _StatCard(
                    icon: Icons.data_usage_rounded,
                    label: 'Total Data',
                    value: FormatUtils.formatBytes(stats.totalBytesDownloaded),
                    color: AppColors.success,
                    delay: 200,
                  ),
                ),
                const Gap(AppSpacing.m),
                Expanded(
                  child: _StatCard(
                    icon: Icons.storage_rounded,
                    label: 'Free Space',
                    value: _freeSpace != null
                        ? FormatUtils.formatBytes(_freeSpace!)
                        : '...',
                    color:
                        _freeSpace != null &&
                            _freeSpace! < DiskSpaceService.minRequiredBytes
                        ? AppColors.error
                        : AppColors.warning,
                    delay: 300,
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.xl),

            // Charts row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity chart (last 7 days)
                Expanded(
                  flex: 2,
                  child: _GlassPanel(
                    title: 'Download Activity',
                    subtitle: 'Last 7 days',
                    delay: 400,
                    child: SizedBox(
                      height: 200,
                      child: _buildActivityChart(stats),
                    ),
                  ),
                ),
                const Gap(AppSpacing.m),
                // Source distribution
                Expanded(
                  flex: 1,
                  child: _GlassPanel(
                    title: 'Sources',
                    subtitle: 'By platform',
                    delay: 500,
                    child: SizedBox(
                      height: 200,
                      child: _buildSourceChart(stats),
                    ),
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.xl),

            // Keyboard shortcuts reference
            _GlassPanel(
              title: 'Keyboard Shortcuts',
              subtitle: 'Quick actions',
              delay: 600,
              child: Wrap(
                spacing: AppSpacing.m,
                runSpacing: AppSpacing.s,
                children: [
                  _ShortcutChip(keys: 'Ctrl+N', label: 'New Download'),
                  _ShortcutChip(keys: 'Ctrl+,', label: 'Settings'),
                  _ShortcutChip(keys: 'Ctrl+D', label: 'Dashboard'),
                  _ShortcutChip(keys: 'Esc', label: 'Minimize'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart(DownloadStats stats) {
    final history = stats.dailyHistory;

    if (history.isEmpty) {
      return Center(
        child: Text(
          'No download history yet',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textDisabled,
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
        maxY:
            (last7.map((d) => d.downloads).reduce((a, b) => a > b ? a : b) *
                    1.3)
                .toDouble(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = last7[group.x.toInt()];
              return BarTooltipItem(
                '${day.downloads} downloads\n${FormatUtils.formatBytes(day.bytes)}',
                AppTypography.caption.copyWith(color: AppColors.textPrimary),
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
                      color: AppColors.textDisabled,
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
                  colors: [AppColors.primary, AppColors.info],
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
    final sources = stats.downloadsBySource;

    if (sources.isEmpty) {
      return Center(
        child: Text(
          'No source data yet',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      );
    }

    // Sort sources by count and take top 5
    final sorted = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
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
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${top[i].value}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
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
    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
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
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const Gap(AppSpacing.m),
                  child,
                ],
              ),
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
        color: AppColors.surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              keys,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
