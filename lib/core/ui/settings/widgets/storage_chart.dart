import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:universal_disk_space/universal_disk_space.dart';
import '../../../design_system/foundation/colors.dart';
import '../../../design_system/foundation/spacing.dart';
import '../../../design_system/foundation/typography.dart';
import 'dart:math';

class StorageChart extends StatefulWidget {
  final String path;

  const StorageChart({super.key, required this.path});

  @override
  State<StorageChart> createState() => _StorageChartState();
}

class _StorageChartState extends State<StorageChart> {
  int _touchedIndex = -1;
  double? _totalSpace;
  double? _freeSpace;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  @override
  void didUpdateWidget(covariant StorageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadStorageInfo();
    }
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    try {
      final diskSpace = DiskSpace();
      await diskSpace.scan();
      var disks = diskSpace.disks;

      // Find the disk that contains the path
      // This is a bit tricky, simple heuristic: find the disk with the matching root
      // Or just assume the path starts with the drive letter on Windows
      Disk? targetDisk;

      // Normalize path specifically for Windows drive letter matching
      String normalizedPath = widget.path.replaceAll('/', '\\');

      for (var disk in disks) {
        // e.g., "C:\"
        if (normalizedPath.toUpperCase().startsWith(
          disk.devicePath.toUpperCase(),
        )) {
          targetDisk = disk;
          break;
        }
      }

      // Fallback: If no match (maybe network drive?), just pick the first one or simulate for UI
      targetDisk ??= disks.isNotEmpty ? disks.first : null;

      if (targetDisk != null) {
        setState(() {
          _totalSpace = targetDisk!.totalSize.toDouble();
          _freeSpace = targetDisk.availableSpace.toDouble();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading disk space: $e");
      setState(() => _isLoading = false);
    }
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }

    if (_totalSpace == null || _freeSpace == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "Storage info unavailable",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final usedSpace = _totalSpace! - _freeSpace!;
    final usedPercentage = (usedSpace / _totalSpace! * 100).toStringAsFixed(1);
    final freePercentage = (_freeSpace! / _totalSpace! * 100).toStringAsFixed(
      1,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Storage Usage",
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _loadStorageInfo,
                icon: Icon(Icons.refresh, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Gap(AppSpacing.m),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40, // Donut style
                      sections: [
                        PieChartSectionData(
                          color: AppColors.primary,
                          value: usedSpace,
                          title: '$usedPercentage%',
                          radius: _touchedIndex == 0 ? 60 : 50,
                          titleStyle: TextStyle(
                            fontSize: _touchedIndex == 0 ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: AppColors.success.withValues(
                            alpha: 0.8,
                          ), // Using green/success flavor for Free space to look positive
                          value: _freeSpace!,
                          title: '$freePercentage%',
                          radius: _touchedIndex == 1 ? 60 : 50,
                          titleStyle: TextStyle(
                            fontSize: _touchedIndex == 1 ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(AppSpacing.l),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Indicator(
                      color: AppColors.primary,
                      text: 'Used',
                      size: _formatBytes(usedSpace),
                      isSquare: false,
                    ),
                    const Gap(AppSpacing.s),
                    _Indicator(
                      color: AppColors.success.withValues(alpha: 0.8),
                      text: 'Free',
                      size: _formatBytes(_freeSpace!),
                      isSquare: false,
                    ),
                    const Gap(AppSpacing.m),
                    Divider(color: AppColors.border.withValues(alpha: 0.3)),
                    const Gap(AppSpacing.s),
                    Text(
                      "Total: ${_formatBytes(_totalSpace!)}",
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.size,
    required this.isSquare,
  });
  final Color color;
  final String text;
  final String size;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                size,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
