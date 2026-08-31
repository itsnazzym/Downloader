import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../../../design_system/foundation/colors.dart';
import '../../../design_system/foundation/spacing.dart';
import '../../../design_system/foundation/typography.dart';
import '../../../services/folder_size_service.dart';
import '../../../utils/format_utils.dart';

class DiskChartData {
  const DiskChartData({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;
}

class StorageChart extends StatefulWidget {
  StorageChart({
    super.key,
    required this.path,
    FolderSizeService? folderSizeService,
    this.loadDisk,
  }) : folderSizeService = folderSizeService ?? FolderSizeService();

  final String path;
  final FolderSizeService folderSizeService;
  final Future<DiskChartData> Function(String path)? loadDisk;

  @override
  State<StorageChart> createState() => _StorageChartState();
}

class _StorageChartState extends State<StorageChart> {
  int _touchedIndex = -1;
  int? _totalSpace;
  int? _freeSpace;
  bool _diskLoading = true;
  FolderSizeSnapshot? _folderSnapshot;
  bool _folderError = false;
  bool _folderScanInFlight = false;

  Future<DiskChartData> _defaultLoadDisk(String path) async {
    final diskSpace = DiskSpace();
    await diskSpace.scan();
    final disks = diskSpace.disks;
    final normalizedPath = path.replaceAll('/', '\\');
    Disk? targetDisk;
    for (final disk in disks) {
      if (normalizedPath.toUpperCase().startsWith(
        disk.devicePath.toUpperCase(),
      )) {
        targetDisk = disk;
        break;
      }
    }
    targetDisk ??= disks.isNotEmpty ? disks.first : null;
    if (targetDisk == null) {
      throw StateError('No volume');
    }
    return DiskChartData(
      totalBytes: targetDisk.totalSize,
      freeBytes: targetDisk.availableSpace,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll(resetFolder: true);
  }

  @override
  void didUpdateWidget(covariant StorageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadAll(resetFolder: true);
    }
  }

  Future<void> _loadAll({
    required bool resetFolder,
    bool forceFolder = false,
  }) async {
    if (resetFolder) {
      _folderSnapshot = null;
      _folderError = false;
    }
    await Future.wait<void>([
      _loadDisk(showFullSpinner: _totalSpace == null),
      _loadFolder(force: forceFolder),
    ]);
  }

  Future<void> _loadDisk({required bool showFullSpinner}) async {
    if (showFullSpinner) {
      setState(() => _diskLoading = true);
    }
    try {
      final loader = widget.loadDisk ?? _defaultLoadDisk;
      final data = await loader(widget.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _totalSpace = data.totalBytes;
        _freeSpace = data.freeBytes;
        _diskLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading disk space: $e');
      if (!mounted) {
        return;
      }
      setState(() => _diskLoading = false);
    }
  }

  Future<void> _loadFolder({required bool force}) async {
    final path = widget.path;
    if (!force) {
      final peeked = widget.folderSizeService.peek(path);
      if (peeked != null) {
        setState(() {
          _folderSnapshot = peeked;
          _folderError = false;
        });
        if (widget.folderSizeService.isFresh(peeked)) {
          return;
        }
      }
    }
    setState(() => _folderScanInFlight = true);
    try {
      final result = await widget.folderSizeService.getSize(path, force: force);
      if (!mounted || widget.path != path) {
        return;
      }
      switch (result) {
        case FolderSizeOk(:final snapshot):
          setState(() {
            _folderSnapshot = snapshot;
            _folderError = false;
            _folderScanInFlight = false;
          });
        case FolderSizeError():
          setState(() {
            _folderError = true;
            _folderScanInFlight = false;
          });
      }
    } catch (e) {
      debugPrint('Error loading folder size: $e');
      if (!mounted || widget.path != path) {
        return;
      }
      setState(() {
        if (_folderSnapshot == null) {
          _folderError = true;
        }
        _folderScanInFlight = false;
      });
    }
  }

  String _percent(num part, int total) {
    if (total <= 0) {
      return '0.0';
    }
    return (part / total * 100).toStringAsFixed(1);
  }

  String _hhmm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? _scanCaption(BuildContext context) {
    final l10n = context.l10n;
    if (_folderError) {
      return l10n.storageScanError;
    }
    if (_folderSnapshot == null && _folderScanInFlight) {
      return l10n.storageScanInProgress;
    }
    if (_folderSnapshot != null && _folderScanInFlight) {
      return l10n.storageScanCached;
    }
    if (_folderSnapshot != null) {
      return l10n.storageLastScanned(_hhmm(_folderSnapshot!.scannedAt));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_diskLoading && _totalSpace == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_totalSpace == null || _freeSpace == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          context.l10n.storageInfoUnavailable,
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
      );
    }

    final colors = AppColors.of(context);
    final total = _totalSpace!;
    final free = _freeSpace!;
    final used = max(0, total - free);
    final snapshot = _folderSnapshot;
    final folderBytes = snapshot?.totalBytes ?? 0;
    final folderSlice = snapshot == null ? 0 : min(folderBytes, used);
    final otherUsed = snapshot == null ? used : max(0, used - folderSlice);
    final showFolderLegend = snapshot != null;

    final sections = <PieChartSectionData>[];
    void addSection({
      required Color color,
      required int value,
      required String percent,
    }) {
      if (value <= 0) {
        return;
      }
      final index = sections.length;
      final thin = (value / total * 100) < 5.0;
      sections.add(
        PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '$percent%',
          radius: _touchedIndex == index ? 60 : 50,
          titlePositionPercentageOffset: thin ? 1.4 : 0.5,
          titleStyle: TextStyle(
            fontSize: _touchedIndex == index ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: thin ? colors.textPrimary : Colors.white,
          ),
        ),
      );
    }

    if (snapshot == null) {
      addSection(
        color: colors.primary,
        value: used,
        percent: _percent(used, total),
      );
      addSection(
        color: colors.success,
        value: free,
        percent: _percent(free, total),
      );
    } else {
      addSection(
        color: colors.warning,
        value: folderSlice,
        percent: _percent(folderSlice, total),
      );
      addSection(
        color: colors.primary,
        value: otherUsed,
        percent: _percent(otherUsed, total),
      );
      addSection(
        color: colors.success,
        value: free,
        percent: _percent(free, total),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
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
            children: [
              Text(
                context.l10n.storageUsage,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_scanCaption(context) != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _scanCaption(context)!,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              IconButton(
                onPressed: _folderScanInFlight && _folderSnapshot == null
                    ? null
                    : () => _loadAll(resetFolder: false, forceFolder: true),
                icon: _folderScanInFlight && _folderSnapshot != null
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textSecondary,
                        ),
                      )
                    : Icon(Icons.refresh, color: colors.textSecondary),
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
                      centerSpaceRadius: 40,
                      sections: sections,
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
                    if (showFolderLegend) ...[
                      _Indicator(
                        color: colors.warning,
                        text: context.l10n.storageFolder,
                        size: FormatUtils.formatBytes(folderBytes),
                        percent: '${_percent(folderSlice, total)}%',
                        isSquare: false,
                      ),
                      const Gap(AppSpacing.s),
                      _Indicator(
                        color: colors.primary,
                        text: context.l10n.storageOtherUsed,
                        size: FormatUtils.formatBytes(otherUsed),
                        percent: '${_percent(otherUsed, total)}%',
                        isSquare: false,
                      ),
                    ] else ...[
                      _Indicator(
                        color: colors.primary,
                        text: context.l10n.storageUsed,
                        size: FormatUtils.formatBytes(used),
                        percent: '${_percent(used, total)}%',
                        isSquare: false,
                      ),
                    ],
                    const Gap(AppSpacing.s),
                    _Indicator(
                      color: colors.success,
                      text: context.l10n.storageFree,
                      size: FormatUtils.formatBytes(free),
                      percent: '${_percent(free, total)}%',
                      isSquare: false,
                    ),
                    const Gap(AppSpacing.m),
                    Divider(color: colors.border.withValues(alpha: 0.3)),
                    const Gap(AppSpacing.s),
                    Text(
                      context.l10n.storageTotalLabel(
                        FormatUtils.formatBytes(total),
                      ),
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.m),
          if (_folderError && _folderSnapshot == null)
            KeyedSubtree(
              key: const Key('storage-folder-error'),
              child: Text(
                context.l10n.storageScanError,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else if (_folderSnapshot == null)
            KeyedSubtree(
              key: const Key('storage-folder-skeleton'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 180, color: colors.border),
                  const Gap(AppSpacing.s),
                  Container(
                    height: 8,
                    width: double.infinity,
                    color: colors.border,
                  ),
                  const Gap(AppSpacing.s),
                  Container(height: 14, width: 220, color: colors.border),
                  const Gap(4),
                  Container(height: 14, width: 200, color: colors.border),
                  const Gap(4),
                  Container(height: 14, width: 210, color: colors.border),
                ],
              ),
            )
          else
            _FolderDetails(snapshot: _folderSnapshot!, usedBytes: used),
        ],
      ),
    );
  }
}

class _FolderDetails extends StatelessWidget {
  const _FolderDetails({required this.snapshot, required this.usedBytes});

  final FolderSizeSnapshot snapshot;
  final int usedBytes;

  /// Keep flex in a small int range. Raw byte counts (tens of GB) make
  /// [Expanded] children lay out at 0 width.
  static int _typeBarFlex(
    int bytes,
    List<({Color color, int bytes, String label})> positive,
  ) {
    final typeTotal = positive.fold<int>(0, (sum, t) => sum + t.bytes);
    if (typeTotal <= 0) {
      return 1;
    }
    return max(1, (bytes * 1000) ~/ typeTotal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final ofUsed = usedBytes <= 0
        ? '0.0'
        : (snapshot.totalBytes / usedBytes * 100).toStringAsFixed(1);
    final types = <({Color color, int bytes, String label})>[
      (
        color: colors.info,
        bytes: snapshot.videoBytes,
        label: l10n.storageTypeVideo,
      ),
      (
        color: colors.accent,
        bytes: snapshot.audioBytes,
        label: l10n.storageTypeAudio,
      ),
      (
        color: colors.textDisabled,
        bytes: snapshot.otherBytes,
        label: l10n.storageTypeOther,
      ),
    ];
    final positive = types.where((t) => t.bytes > 0).toList();

    return KeyedSubtree(
      key: const Key('storage-folder-details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${FormatUtils.formatBytes(snapshot.totalBytes)} · ${l10n.storageFolderOfUsed(ofUsed)}',
            style: AppTypography.caption.copyWith(color: colors.textPrimary),
          ),
          const Gap(4),
          Text(
            l10n.storageFileCount(snapshot.fileCount),
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const Gap(AppSpacing.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: positive.isEmpty
                  ? ColoredBox(color: colors.border)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final t in positive)
                          Expanded(
                            flex: _typeBarFlex(t.bytes, positive),
                            child: ColoredBox(color: t.color),
                          ),
                      ],
                    ),
            ),
          ),
          if (snapshot.topSubfolders.isNotEmpty) ...[
            const Gap(AppSpacing.s),
            Text(
              l10n.storageTopSubfolders,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            for (final entry in snapshot.topSubfolders)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      FormatUtils.formatBytes(entry.bytes),
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
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

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.size,
    required this.percent,
    required this.isSquare,
  });

  final Color color;
  final String text;
  final String size;
  final String percent;
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
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
              Text(
                size,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
