import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/plugins/feature_activation.dart';
import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/l10n/l10n_ext.dart';

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
          const _LiveScope(),
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

  /// When each download was first seen active / first received bytes.
  final Map<String, DateTime> _seenActiveAt = {};
  final Map<String, DateTime> _firstBytesAt = {};

  /// Shown for a few seconds once a download is done, so a fast one is not
  /// gone before it can be read.
  CompletionSummary? _summary;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(downloadListProvider, _onListChanged);
    _record();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_record);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onListChanged(
    AsyncValue<List<DownloadItem>>? previous,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final before = previous?.valueOrNull;
    final after = next.valueOrNull;
    if (before == null || after == null) return;
    final wasActive = {
      for (final item in before)
        if (isActiveDownload(item)) item.id,
    };
    for (final item in after) {
      if (item.status != DownloadStatus.completed ||
          !wasActive.contains(item.id)) {
        continue;
      }
      final started =
          _firstBytesAt.remove(item.id) ?? _seenActiveAt.remove(item.id);
      _seenActiveAt.remove(item.id);
      if (started == null) continue;
      HapticFeedback.mediumImpact();
      setState(() {
        _summary = summarizeCompletion(
          item,
          firstBytesAt: started,
          now: DateTime.now(),
          title: item.title ?? '',
        );
      });
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _summary = null);
      });
    }
  }

  void _record() {
    final items =
        ref.read(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.read(downloadRuntimeItemProvider(id)),
    );
    _samples.add(aggregateSpeed(active) ?? 0.0);
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
    // Progress ticks only reach the per-download runtime item.
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final now = DateTime.now();
    for (final item in active) {
      _seenActiveAt.putIfAbsent(item.id, () => now);
      if (item.progress > 0) _firstBytesAt.putIfAbsent(item.id, () => now);
    }
    if (active.isEmpty) {
      final summary = _summary;
      if (summary == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: _CompletionCard(summary: summary),
      );
    }

    final first = active.first;
    final bytesPerSecond = aggregateSpeed(active);
    final speed = formatSpeed(l10n, bytesPerSecond);
    final phase = livePhase(first, bytesPerSecond);
    final title =
        first.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(first.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(first.title ?? l10n.unknown);
    final rightLabel = active.length > 1
        ? l10n.libraryHeaderMoreActive(active.length - 1)
        : first.source;
    final percent = (first.progress.clamp(0.0, 1.0) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: OledCard(
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
                      if (phase != null)
                        SizedBox(
                          height: 52,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                livePhaseLabel(l10n, phase),
                                key: ValueKey(phase),
                                style: OledText.ui(
                                  context,
                                  size: 20,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
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
            OledFragmentMap(
              progress: first.progress,
              waiting:
                  phase == LivePhase.analyzing || phase == LivePhase.connecting,
            ),
            const SizedBox(height: 12),
            if (phase != LivePhase.analyzing && phase != LivePhase.connecting)
              Wrap(
                spacing: 12,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$percent %',
                    style: OledText.ui(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (first.downloadedSize.isNotEmpty &&
                      first.totalSize.isNotEmpty)
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
                      l10n.libraryHeaderRemaining(etaLabel(l10n, first.eta)),
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
      ),
    );
  }
}

/// The panel once a download has finished: how fast it went on average, what
/// it was, how big and how long. Replaces the live view for a few seconds.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.summary});

  final CompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final average = summary.bytesPerSecond;
    final speed = formatSpeed(l10n, average);
    final title = TitleCleanerService.clean(
      summary.title.isEmpty ? l10n.unknown : summary.title,
    );
    return OledCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.ink),
                child: Icon(Icons.check_rounded, size: 14, color: t.onInk),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.libraryDoneTitle,
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
          SizedBox(
            height: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    average != null ? speed.value : summary.sizeText,
                    style: OledText.dot(context, size: 52),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    average != null
                        ? '${speed.unit} ${l10n.libraryDoneAverage}'
                        : '',
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
            ),
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
              const SizedBox(width: 12),
              Text(
                l10n.libraryDoneSummary(
                  summary.sizeText,
                  durationLabel(l10n, summary.duration),
                ),
                style: OledText.ui(
                  context,
                  size: 13,
                  weight: FontWeight.w400,
                  color: t.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const OledFragmentMap(progress: 1, active: 0),
        ],
      ),
    );
  }
}
