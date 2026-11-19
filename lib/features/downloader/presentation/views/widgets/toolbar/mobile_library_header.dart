import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

bool _isActiveItem(DownloadItem item) =>
    item.status == DownloadStatus.downloading ||
    item.status == DownloadStatus.extracting ||
    item.status == DownloadStatus.processing;

/// Parses a yt-dlp style speed such as "6.2MiB/s" into bytes per second.
/// Returns null when the text is not a recognisable speed.
double? _parseSpeed(String raw) {
  final match = RegExp(
    r'([0-9]+(?:[.,][0-9]+)?)\s*([KMGT]?)i?B\s*/\s*s',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (number == null) return null;
  const exponents = <String, int>{'': 0, 'K': 1, 'M': 2, 'G': 3, 'T': 4};
  final exponent = exponents[match.group(2)!.toUpperCase()] ?? 0;
  return number * math.pow(1024, exponent);
}

/// Sum of the parseable speeds, or null when none of the items has one.
double? _aggregateSpeed(List<DownloadItem> items) {
  var total = 0.0;
  var found = false;
  for (final item in items) {
    final speed = _parseSpeed(item.speed);
    if (speed != null) {
      total += speed;
      found = true;
    }
  }
  return found ? total : null;
}

class _SpeedLabel {
  const _SpeedLabel(this.value, this.unit);

  final String value;
  final String unit;
}

_SpeedLabel _formatSpeed(AppLocalizations l10n, double? bytesPerSecond) {
  if (bytesPerSecond == null) return const _SpeedLabel('—', '');
  const k = 1024.0;
  final decimalSeparator = l10n.localeName.startsWith('en') ? '.' : ',';
  String fmt(double v) =>
      v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', decimalSeparator);
  if (bytesPerSecond >= k * k * k) {
    return _SpeedLabel(
      fmt(bytesPerSecond / (k * k * k)),
      l10n.libraryHeaderUnitGBps,
    );
  }
  if (bytesPerSecond >= k * k) {
    return _SpeedLabel(
      fmt(bytesPerSecond / (k * k)),
      l10n.libraryHeaderUnitMBps,
    );
  }
  if (bytesPerSecond >= k) {
    return _SpeedLabel(fmt(bytesPerSecond / k), l10n.libraryHeaderUnitKBps);
  }
  return _SpeedLabel(
    bytesPerSecond.round().toString(),
    l10n.libraryHeaderUnitBps,
  );
}

/// Library header of the Android OLED interface: title, shortcuts, filter
/// chips and, while something downloads, the live throughput panel.
class MobileLibraryHeader extends ConsumerWidget {
  const MobileLibraryHeader({super.key});

  void _setFilter(WidgetRef ref, DownloadStatusFilter filter, bool isFolders) {
    if (isFolders) {
      ref.read(downloadViewModeProvider.notifier).state = DownloadViewMode.list;
    }
    ref.read(downloadStatusFilterProvider.notifier).state = filter;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final features = ref.watch(featureActivationProvider);
    final statusFilter = ref.watch(downloadStatusFilterProvider);
    final viewMode = ref.watch(downloadViewModeProvider);
    final counts = ref.watch(downloadLibraryCountsProvider);
    final hasActive = ref.watch(
      downloadListProvider.select(
        (async) =>
            (async.valueOrNull ?? const <DownloadItem>[]).any(_isActiveItem),
      ),
    );

    final isFolders = viewMode == DownloadViewMode.folders;
    final showArchive = features.isEnabledById('tiktok_archives');
    final showStats = features.isEnabledById('statistics');

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mobileLibrary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.title(context),
                  ),
                ),
                if (showArchive)
                  OledIconButton(
                    icon: Icons.grid_view_rounded,
                    tooltip: l10n.libraryHeaderArchive,
                    onPressed: () => context.go('/archive'),
                  ),
                if (showArchive && showStats) const SizedBox(width: 6),
                if (showStats)
                  OledIconButton(
                    icon: Icons.bar_chart_rounded,
                    tooltip: l10n.statistics,
                    onPressed: () => context.go('/stats'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OledChip(
                  label: l10n.sidebarAll,
                  count: counts.total,
                  selected:
                      !isFolders && statusFilter == DownloadStatusFilter.all,
                  onTap: () =>
                      _setFilter(ref, DownloadStatusFilter.all, isFolders),
                ),
                const SizedBox(width: 8),
                OledChip(
                  label: l10n.sidebarActive,
                  count: counts.active > 0 ? counts.active : null,
                  selected:
                      !isFolders && statusFilter == DownloadStatusFilter.active,
                  onTap: () =>
                      _setFilter(ref, DownloadStatusFilter.active, isFolders),
                ),
                const SizedBox(width: 8),
                OledChip(
                  label: l10n.sidebarCompleted,
                  count: counts.completed,
                  selected:
                      !isFolders &&
                      statusFilter == DownloadStatusFilter.completed,
                  onTap: () => _setFilter(
                    ref,
                    DownloadStatusFilter.completed,
                    isFolders,
                  ),
                ),
                const SizedBox(width: 8),
                OledChip(
                  label: l10n.libraryHeaderFailed,
                  count: counts.failed > 0 ? counts.failed : null,
                  countColor: t.warn,
                  selected:
                      !isFolders && statusFilter == DownloadStatusFilter.failed,
                  onTap: () =>
                      _setFilter(ref, DownloadStatusFilter.failed, isFolders),
                ),
                const SizedBox(width: 8),
                OledChip(
                  label: l10n.libraryHeaderFolders,
                  selected: isFolders,
                  onTap: () {
                    ref
                        .read(downloadViewModeProvider.notifier)
                        .state = isFolders
                        ? DownloadViewMode.list
                        : DownloadViewMode.folders;
                  },
                ),
              ],
            ),
          ),
          if (hasActive)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _LiveScope(),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Live throughput panel. Owns its own rolling samples and 1s timer so only
/// this subtree rebuilds on a tick.
class _LiveScope extends ConsumerStatefulWidget {
  const _LiveScope();

  @override
  ConsumerState<_LiveScope> createState() => _LiveScopeState();
}

class _LiveScopeState extends ConsumerState<_LiveScope> {
  static const int _maxSamples = 14;

  final List<double> _samples = <double>[];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _record();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_record);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _record() {
    final items =
        ref.read(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = items.where(_isActiveItem).toList();
    _samples.add(_aggregateSpeed(active) ?? 0.0);
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = items.where(_isActiveItem).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final first = active.first;
    final speed = _formatSpeed(l10n, _aggregateSpeed(active));
    final title =
        first.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(first.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(first.title ?? l10n.unknown);
    final rightLabel = active.length > 1
        ? l10n.libraryHeaderMoreActive(active.length - 1)
        : first.source;
    final percent = (first.progress.clamp(0.0, 1.0) * 100).round();

    return OledCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const OledLiveDot(),
                        const SizedBox(width: 8),
                        Text(
                          l10n.libraryHeaderLiveSpeed,
                          style: OledText.ui(
                            context,
                            size: 13,
                            weight: FontWeight.w400,
                            color: t.ink2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            speed.value,
                            style: OledText.dot(context, size: 52),
                          ),
                          if (speed.unit.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              speed.unit,
                              style: OledText.ui(
                                context,
                                size: 15,
                                weight: FontWeight.w600,
                                color: t.ink2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OledSparkline(
                values: List<double>.of(_samples),
                width: 96,
                height: 56,
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            height: 1,
            color: t.line,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.ui(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (rightLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  rightLabel,
                  maxLines: 1,
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w400,
                    color: t.ink2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          OledFragmentMap(progress: first.progress),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$percent %',
                style: OledText.ui(context, size: 13, weight: FontWeight.w600),
              ),
              if (first.downloadedSize.isNotEmpty && first.totalSize.isNotEmpty)
                Text(
                  l10n.downloadCardSizeOf(
                    first.downloadedSize,
                    first.totalSize,
                  ),
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w400,
                    color: t.ink2,
                  ),
                ),
              if (first.eta.isNotEmpty)
                Text(
                  l10n.libraryHeaderRemaining(first.eta),
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w400,
                    color: t.ink2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
