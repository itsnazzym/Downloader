import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/core/ui/shell/shell_strips.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_home.dart' show designFreeSpaceProvider;
import 'pastille_kit.dart';
import 'pastille_states.dart';

/// Pastille's `/` route: the bento home (mockup Pastille.dc.html), or the
/// whole library at `/?view=library` (the dock's Bibliothèque stop and
/// "Toute la bibliothèque"): today's library view — filters, search, sort,
/// view mode, list, inspector, context menu — under a Pastille header.
class PastilleHome extends StatelessWidget {
  const PastilleHome({super.key, required this.library});

  final Widget library;

  @override
  Widget build(BuildContext context) {
    final view = GoRouterState.of(context).uri.queryParameters['view'];
    return view == 'library' ? _LibraryView(library: library) : const _Home();
  }
}

void _openLibrary(BuildContext context) => context.go('/?view=library');

void _play(WidgetRef ref, DownloadItem item) {
  final path = item.filePath;
  if (path != null && File(path).existsSync()) {
    ref.read(mediaPlayerProvider.notifier).openFile(path);
  }
}

String _title(AppLocalizations l10n, DownloadItem item) =>
    titleOf(item);

/// "54,1 Mo" from yt-dlp's "54.1MiB"; empty if none.
String _size(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}

enum _Phase { loading, error, empty, ready }

/// A refresh keeps the last list on screen; only a first load or a load
/// that never produced a list shows the skeleton or the error.
_Phase _phaseOf(AsyncValue<List<DownloadItem>> v) => v.hasValue
    ? (v.requireValue.isEmpty ? _Phase.empty : _Phase.ready)
    : (v.hasError ? _Phase.error : _Phase.loading);

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final busy = ref.watch(
      downloadListProvider.select(
        (v) => v.valueOrNull?.any(isActiveDownload) ?? false,
      ),
    );
    final phase = ref.watch(downloadListProvider.select(_phaseOf));
    final noMatch =
        phase == _Phase.ready &&
        pFiltered(ref) &&
        ref.watch(
          filteredDownloadListPhaseProvider.select((v) => v.valueOrNull == 0),
        );
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final greeting = now.hour >= 5 && now.hour < 18
        ? l10n.pastilleGreetingMorning
        : l10n.pastilleGreetingEvening;
    void search() {
      _openLibrary(context);
      // The library's search field exists once the next page is built.
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        DownloadSearchFocus.request,
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): search,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): search,
      },
      child: Focus(
        autofocus: true,
        child: PastillePage(
          children: [
            PastilleHeader(
              eyebrow: DateFormat.MMMMEEEEd(locale).format(now),
              title: busy
                  ? l10n.pastilleHomeBusy(greeting)
                  : l10n.pastilleHomeIdle(greeting),
              actions: [
                if (pFailedCount(ref) > 1) const PRetryFailedButton(),
                KeyedSubtree(
                  key: OnboardingTargets.newDownload,
                  child: PButton(
                    label: l10n.newDownload,
                    icon: Icons.download_rounded,
                    iconSize: 17,
                    kind: PButtonKind.butter,
                    height: 46,
                    padH: 22,
                    fontSize: 14,
                    onTap: () => openNewDownload(context),
                  ),
                ),
              ],
            ),
            if (noMatch) const PastilleNoResults(),
            AnimatedSwitcher(
              duration: pMotion(context, 250),
              child: switch (phase) {
                _Phase.loading => const PastilleHomeSkeleton(
                  key: ValueKey(_Phase.loading),
                ),
                _Phase.error => const SizedBox(
                  key: ValueKey(_Phase.error),
                  height: 360,
                  child: PastilleLoadError(),
                ),
                _Phase.empty || _Phase.ready => Column(
                  key: const ValueKey(_Phase.ready),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PGrid(
                      cells: [
                        phase == _Phase.empty
                            ? PCell(
                                PastilleEmpty(
                                  onNew: () => openNewDownload(context),
                                ),
                                w: 2,
                                h: 2,
                              )
                            : const PCell(_ActiveTile(), w: 2, h: 2),
                        const PCell(_QuickLinkTile(), w: 2),
                        const PCell(_SpeedTile()),
                        const PCell(_StorageTile()),
                        const PCell(_ActivityTile(), w: 2),
                        const PCell(_QueueTile()),
                        const PCell(_LastTile()),
                      ],
                    ),
                    if (phase == _Phase.ready) ...[
                      const SizedBox(height: 26),
                      const _Recents(),
                    ],
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── In progress ─────────────────────────────────────────────────────────────

/// The finish moment's squish: squash down, spring up, settle (0 = rest).
final _squish = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
    weight: 14,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 1.0,
      end: -0.7,
    ).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 18,
  ),
  TweenSequenceItem(
    tween: Tween(begin: -0.7, end: 0.0).chain(CurveTween(curve: pEase)),
    weight: 26,
  ),
  TweenSequenceItem(tween: ConstantTween(0.0), weight: 42),
]);

class _ActiveTile extends ConsumerStatefulWidget {
  const _ActiveTile();

  @override
  ConsumerState<_ActiveTile> createState() => _ActiveTileState();
}

class _ActiveTileState extends ConsumerState<_ActiveTile>
    with SingleTickerProviderStateMixin {
  /// The moment runs in its first ~800 ms, then holds « Terminé » a beat.
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The download that just finished, shown at 100 % during the moment.
  DownloadItem? _finished;

  @override
  void initState() {
    super.initState();
    ref.listenManual(downloadListProvider, _onList);
  }

  void _onList(
    AsyncValue<List<DownloadItem>>? previous,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final before = previous?.valueOrNull;
    final after = next.valueOrNull;
    if (before == null || after == null || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final wasActive = {
      for (final i in before)
        if (isActiveDownload(i)) i.id,
    };
    for (final i in after) {
      if (i.status != DownloadStatus.completed || !wasActive.contains(i.id)) {
        continue;
      }
      setState(() => _finished = i);
      _finish.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _finished = null);
      });
      return;
    }
  }

  @override
  void dispose() {
    _finish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final all = [
      ...active,
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final finished = _finished;
    final item = finished ?? (all.isEmpty ? null : all.first);
    final failedItems = [
      for (final i in items)
        if (i.status == DownloadStatus.failed) i,
    ];
    if (failedItems.length > 1) {
      // Newest failure first (the progress ticks rebuild this: no full sort).
      final newest = failedItems.reduce(
        (a, b) => b.sortOrder > a.sortOrder ? b : a,
      );
      failedItems
        ..remove(newest)
        ..insert(0, newest);
    }
    final percent = finished != null
        ? 100
        : (item == null ? 0 : (item.progress * 100).clamp(0, 100).floor());
    final running = item != null && isActiveDownload(item);
    final speed = item == null ? null : parseSpeed(item.speed);
    final phase = item == null ? null : livePhase(item, speed);
    final speedLabel = formatSpeed(l10n, speed);
    final done = item == null ? '' : _size(l10n, item.downloadedSize);
    final total = item == null ? '' : _size(l10n, item.totalSize);
    final notifier = ref.read(downloadListProvider.notifier);
    final tile = PTile(
      color: tones.lav,
      semanticLabel: l10n.designInProgress,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.download_rounded,
              text: l10n.designInProgress,
              trailing: all.isEmpty
                  ? null
                  : Text(l10n.pastilleOneOf(1, all.length)),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    text: '$percent',
                    style: pNum(112, color: pInk),
                    children: [
                      TextSpan(
                        text: '%',
                        style: pNum(48, color: pInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item == null
                              ? l10n.designNothingActive
                              : _title(l10n, item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: pBody(
                            size: 15,
                            weight: FontWeight.w700,
                            color: pInk,
                            height: 1.3,
                          ),
                        ),
                        if (item != null)
                          Text(
                            [
                              item.source,
                              formatLabelOf(item),
                              if (total.isNotEmpty)
                                done.isEmpty
                                    ? total
                                    : l10n.transferMobileBytesOf(done, total),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pSub(context),
                          ),
                        if (item == null && failedItems.isNotEmpty)
                          Text(
                            [
                              l10n.pastilleFailedIdle(failedItems.length),
                              downloadErrorReason(failedItems.first.error),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pSub(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            PDots(
              // A new key replays the cascade: the matrix fills at the finish.
              key: ValueKey(finished?.id),
              count: 100,
              maxWidth: 560,
              columns: 25,
              on: percent,
              step: finished == null ? 12 : 4,
              live: item != null && finished == null,
              paused: !running,
              semanticLabel: '$percent %',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  if (finished != null) ...[
                    const Icon(Icons.check_circle_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.pastilleFinished,
                      style: pBody(
                        size: 14,
                        weight: FontWeight.w700,
                        color: pInk,
                      ),
                    ),
                    const Spacer(),
                  ] else if (item != null) ...[
                    Text(
                      phase != null
                          ? livePhaseLabel(l10n, phase)
                          : (running
                                ? '${speedLabel.value} ${speedLabel.unit}'
                                : l10n.statusPaused),
                      style: pMono(
                        size: 13,
                        weight: FontWeight.w500,
                        color: pInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (running && item.eta.isNotEmpty)
                      Expanded(
                        child: Text(
                          l10n.designRemaining(etaLabel(l10n, item.eta)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pSub(context),
                        ),
                      ),
                  ],
                  if (finished == null &&
                      (item == null || !running || item.eta.isEmpty))
                    const Spacer(),
                  if (item != null && finished == null)
                    PButton(
                      label: running ? l10n.pause : l10n.resume,
                      height: 38,
                      onTap: running
                          ? () => notifier.pauseDownload(item.id)
                          : () => notifier.resumeDownload(item.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _finish,
      child: tile,
      builder: (context, child) {
        final s = _finished == null ? 0.0 : _squish.evaluate(_finish);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1 + 0.025 * s, 1 - 0.045 * s, 1),
          child: child,
        );
      },
    );
  }
}

// ── Quick link ──────────────────────────────────────────────────────────────

class _QuickLinkTile extends ConsumerStatefulWidget {
  const _QuickLinkTile();

  @override
  ConsumerState<_QuickLinkTile> createState() => _QuickLinkTileState();
}

class _QuickLinkTileState extends ConsumerState<_QuickLinkTile>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _clip;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(() => setState(() {}));
    _controller.addListener(() {
      if (_added) setState(() => _added = false);
    });
    _readClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      final url = ClipboardService.isSupportedUrl(text) ? text : null;
      if (url != _clip) setState(() => _clip = url);
    } catch (_) {}
  }

  /// The clipboard link, unless it is already in the library.
  String? _freshClip() {
    final clip = _clip;
    if (clip == null) return null;
    final items =
        ref.read(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    return items.any((i) => i.request.url == clip) ? null : clip;
  }

  void _submit() {
    final typed = _controller.text.trim();
    final url = typed.isNotEmpty ? typed : (_freshClip() ?? '');
    if (url.isEmpty) return;
    ref.read(downloadListProvider.notifier).startDownload(url);
    _controller.clear();
    setState(() => _added = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    ref.watch(downloadListProvider.select((v) => v.valueOrNull?.length));
    final clip = _freshClip();
    return PTile(
      color: pInkDeep,
      delay: 60,
      semanticLabel: l10n.pastilleQuickLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PLabel(
            icon: Icons.link_rounded,
            iconColor: tones.butter,
            text: l10n.pastilleQuickLink,
          ),
          const Spacer(),
          AnimatedContainer(
            duration: pMotion(context, 200),
            height: 46,
            padding: const EdgeInsets.fromLTRB(16, 0, 5, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C1A),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _focus.hasFocus
                      ? tones.butter
                      : pCream.withValues(alpha: 0.1),
                  spreadRadius: _focus.hasFocus ? 2 : 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onSubmitted: (_) => _submit(),
                    style: pBody(color: pCream),
                    cursorColor: tones.butter,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: l10n.designPasteHint,
                      hintStyle: pBody(color: pFaint),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PButton(
                  label: _added ? l10n.pastilleAdded : l10n.designDownload,
                  kind: _added ? PButtonKind.cream : PButtonKind.butter,
                  height: 36,
                  padH: 16,
                  onTap: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 18,
            child: clip == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      l10n.pastilleClipboard(
                        clip.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(
                        size: 12.5,
                        weight: FontWeight.w500,
                        color: pMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Speed ───────────────────────────────────────────────────────────────────

class _SpeedTile extends ConsumerStatefulWidget {
  const _SpeedTile();

  @override
  ConsumerState<_SpeedTile> createState() => _SpeedTileState();
}

class _SpeedTileState extends ConsumerState<_SpeedTile> {
  /// The last four seconds of total speed, oldest first.
  final _samples = <double>[0, 0, 0, 0];
  double _now = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _samples
          ..removeAt(0)
          ..add(_now);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    _now = aggregateSpeed(active) ?? 0;
    _samples[3] = _now;
    final peak = _samples.fold<double>(0, math.max);
    final label = formatSpeed(l10n, _now > 0 ? _now : null);
    return PTile(
      color: PTones.of(context).sage,
      delay: 120,
      semanticLabel: l10n.pastilleSpeed,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.speed_rounded, text: l10n.pastilleSpeed),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _now > 0 ? label.value : '0',
                        style: pNum(46, color: pInk),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _now > 0 ? label.unit : l10n.libraryHeaderUnitMBps,
                        style: pSub(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: PBars(
                    values: [for (final s in _samples) peak > 0 ? s / peak : 0],
                    hi: 3,
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

// ── Storage ─────────────────────────────────────────────────────────────────

class _StorageTile extends ConsumerStatefulWidget {
  const _StorageTile();

  @override
  ConsumerState<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends ConsumerState<_StorageTile> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // DiskSpaceService caches for 30 s; a minute is plenty for a summary.
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.invalidate(designFreeSpaceProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final used = ref.watch(
      downloadListProvider.select(
        (v) => (v.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.completed)
            .fold<int>(0, (a, i) => a + bytesOf(i)),
      ),
    );
    final (value, unit) = pSplitUnit(localBytes(l10n, free ?? 0));
    // A fuel gauge: the ink is the room left next to what TapLoad stored.
    final fraction = free == null || free + used <= 0
        ? 0.0
        : free / (free + used);
    return PTile(
      color: PTones.of(context).sky,
      delay: 180,
      semanticLabel: l10n.pastilleStorage,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.storage_rounded, text: l10n.pastilleStorage),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        free == null ? '—' : value,
                        style: pNum(40, color: pInk),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.designFree(unit), style: pSub(context)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 46,
                    child: Semantics(
                      label: l10n.designFree(localBytes(l10n, free ?? 0)),
                      child: PLiquid(fraction: fraction),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity calendar ───────────────────────────────────────────────────────

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 0–4 intensity of [n] against the busiest day [peak].
int _level(int n, int peak) =>
    n <= 0 || peak <= 0 ? 0 : (4 * n / peak).ceil().clamp(1, 4);

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final byDay = {for (final d in stats.dailyHistory) d.date: d.downloads};
    final days = DateUtils.getDaysInMonth(now.year, now.month);
    final counts = [
      for (var d = 1; d <= days; d++)
        d == now.day
            ? stats.downloadsToday
            : (d > now.day
                  ? 0
                  : byDay[_dayKey(DateTime(now.year, now.month, d))] ?? 0),
    ];
    final peak = counts.fold<int>(0, math.max);
    final month = counts.fold<int>(0, (a, b) => a + b);
    return PTile(
      color: PTones.of(context).rose,
      delay: 240,
      semanticLabel: l10n.pastilleActivity(DateFormat.MMMM(locale).format(now)),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.calendar_month_rounded,
              text: l10n.pastilleActivity(DateFormat.MMMM(locale).format(now)),
              trailing: Text(l10n.pastilleTodayCount(stats.downloadsToday)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$month', style: pNum(52, color: pInk)),
                      const SizedBox(height: 6),
                      Text(l10n.pastilleThisMonth, style: pSub(context)),
                    ],
                  ),
                  const SizedBox(width: 22),
                  Flexible(
                    child: PDots(
                      count: days,
                      columns: (days / 3).ceil(),
                      on: 0,
                      square: true,
                      gap: 5,
                      maxWidth: 300,
                      levels: [for (final n in counts) _level(n, peak)],
                      semanticLabel: l10n.pastilleActivity(
                        DateFormat.MMMM(locale).format(now),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Queue ───────────────────────────────────────────────────────────────────

class _QueueTile extends ConsumerWidget {
  const _QueueTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queued = [
      for (final i
          in ref.watch(downloadListProvider).valueOrNull ??
              const <DownloadItem>[])
        if (i.status == DownloadStatus.queued) i,
    ];
    return PTile(
      color: PTones.of(context).butter,
      delay: 300,
      semanticLabel: l10n.designQueue,
      onTap: () {
        ref.read(downloadSourceFilterProvider.notifier).state = null;
        ref.read(downloadStatusFilterProvider.notifier).state =
            DownloadStatusFilter.active;
        _openLibrary(context);
      },
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.format_list_bulleted_rounded,
              text: l10n.designQueue,
            ),
            const Spacer(),
            Text('${queued.length}', style: pNum(56, color: pInk)),
            const SizedBox(height: 6),
            Text(
              queued.isEmpty
                  ? l10n.designQueueEmpty
                  : l10n.pastilleNext(_title(l10n, queued.first)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pSub(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Last downloaded ─────────────────────────────────────────────────────────

class _LastTile extends ConsumerWidget {
  const _LastTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    DownloadItem? item;
    for (final i in pNewestFirst(
      ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[],
    )) {
      if (i.status == DownloadStatus.completed) {
        item = i;
        break;
      }
    }
    final last = item;
    final size = last == null ? 0 : bytesOf(last);
    return PTile(
      color: tones.cream,
      delay: 360,
      padding: const EdgeInsets.all(12),
      semanticLabel: last == null ? null : _title(l10n, last),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PThumb(
                    url: last?.thumbnailUrl,
                    filePath: last?.filePath,
                    tone: const Color(0xFFC7D0CA),
                  ),
                  if (last != null)
                    PButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: l10n.detailsPlayVideo,
                      height: 46,
                      onTap: () => _play(ref, last),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    last == null ? l10n.pastilleNothingYet : _title(l10n, last),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      size: 13,
                      weight: FontWeight.w700,
                      color: pInk,
                    ),
                  ),
                  Text(
                    last == null
                        ? ''
                        : [
                            last.source,
                            if (size > 0) localBytes(l10n, size),
                          ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pSub(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recents ─────────────────────────────────────────────────────────────────

class _Recents extends ConsumerWidget {
  const _Recents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final recent = pNewestFirst(items)
        .where(
          (i) =>
              !isActiveDownload(i) &&
              i.status != DownloadStatus.queued &&
              i.status != DownloadStatus.paused,
        )
        .take(4)
        .toList();
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.pastilleRecent,
                  style: pNum(
                    24,
                    weight: FontWeight.w700,
                    color: pCream,
                  ).copyWith(letterSpacing: -0.03 * 24),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.pastilleTotal(items.length),
                style: pMono(size: 12, color: pFaint),
              ),
              const Spacer(),
              _Link(
                label: l10n.pastilleAllLibrary,
                onTap: () => _openLibrary(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Text(l10n.designLibraryEmpty, style: pBody(color: pMuted))
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = math.max(1, ((c.maxWidth + 14) / 234).floor());
                final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < recent.length; i++)
                      SizedBox(
                        width: w,
                        child: _RecentCard(
                          item: recent[i],
                          delay: 400 + i * 60,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Link extends StatefulWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? PTones.of(context).butter : pCream;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        link: true,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(
              widget.label,
              style: pBody(size: 13, weight: FontWeight.w600, color: color)
                  .copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: color,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends ConsumerStatefulWidget {
  const _RecentCard({required this.item, required this.delay});

  final DownloadItem item;
  final int delay;

  @override
  ConsumerState<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends ConsumerState<_RecentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final item = widget.item;
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final size = bytesOf(item);
    final tone = failed
        ? const Color(0xFFCFCFD1)
        : switch (mediaKindOf(item)) {
            MediaKind.video => const Color(0xFFD8CFBD),
            MediaKind.audio => const Color(0xFFCDCAD8),
            MediaKind.image => const Color(0xFFD5CEC4),
          };
    final total = widget.delay + 500;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: pMotion(context, total),
      builder: (context, v, child) {
        final start = widget.delay / total;
        final t = v <= start ? 0.0 : pPop.transform((v - start) / (1 - start));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: DownloadItemContextMenu(
        item: item,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: pMotion(context, 250),
            curve: pEase,
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: _hover ? const Color(0xFF2A2723) : pCard,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: pCream.withValues(alpha: 0.07),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                hoverColor: Colors.transparent,
                focusColor: tones.butter.withValues(alpha: 0.2),
                onTap: () {
                  ref.read(selectedDownloadIdProvider.notifier).state = item.id;
                  _openLibrary(context);
                },
                onDoubleTap: () => _play(ref, item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 96,
                        child: PThumb(
                          url: item.thumbnailUrl,
                          filePath: item.filePath,
                          tone: tone,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(l10n, item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: pBody(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: pCream,
                              ),
                            ),
                            if (failed)
                              Row(
                                children: [
                                  Expanded(
                                    child: Tooltip(
                                      message: item.error ?? l10n.designFailed,
                                      child: Text(
                                        downloadErrorReason(item.error).isEmpty
                                            ? l10n.designFailed
                                            : downloadErrorReason(item.error),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: pBody(
                                          size: 12,
                                          color: tones.rose,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => ref
                                        .read(downloadListProvider.notifier)
                                        .retryDownload(item),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Text(
                                      l10n.retry,
                                      style: pBody(
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: tones.rose,
                                      ).copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: tones.rose,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                [
                                  item.source,
                                  if (size > 0) localBytes(l10n, size),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: pBody(size: 12, color: pMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
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

// ── Library view ────────────────────────────────────────────────────────────

/// Height of today's library top bar and its hairline; Pastille's no-results
/// capsule covers the list under it.
// shortcut: mirrors DownloadTopBar (64) + hairline (1); a DownloadView slot for
// the empty list would remove it.
const double _libraryTopBar = 65;

class _LibraryView extends ConsumerWidget {
  const _LibraryView({required this.library});

  final Widget library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final phase = ref.watch(downloadListProvider.select(_phaseOf));
    final noMatch =
        phase == _Phase.ready &&
        pFiltered(ref) &&
        ref.watch(
          filteredDownloadListPhaseProvider.select((v) => v.valueOrNull == 0),
        );
    final Widget body = switch (phase) {
      _Phase.loading => const PastilleListSkeleton(),
      _Phase.error => const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(height: 340, child: PastilleLoadError()),
        ),
      ),
      _Phase.empty => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            height: 340,
            child: PastilleEmpty(onNew: () => openNewDownload(context)),
          ),
        ),
      ),
      _Phase.ready => Stack(
        children: [
          Positioned.fill(child: library),
          if (noMatch)
            Positioned.fill(
              top: _libraryTopBar,
              child: ColoredBox(
                color: pBackground,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: const PastilleNoResults(),
                  ),
                ),
              ),
            ),
        ],
      ),
    };
    return ColoredBox(
      color: pBackground,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth > 1264 ? (c.maxWidth - 1200) / 2 : 32.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(side, 30, side, 0),
                child: PastilleHeader(
                  eyebrow: l10n.librarySection.toLowerCase(),
                  title: l10n.pastilleLibraryTitle,
                  actions: [
                    if (pFailedCount(ref) > 1) const PRetryFailedButton(),
                    KeyedSubtree(
                      key: OnboardingTargets.newDownload,
                      child: PButton(
                        label: l10n.newDownload,
                        icon: Icons.download_rounded,
                        iconSize: 17,
                        kind: PButtonKind.butter,
                        height: 46,
                        padH: 22,
                        fontSize: 14,
                        onTap: () => openNewDownload(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(side, 20, side, 12),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: LibraryFilterStrip(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    math.max(0, side - 32),
                    0,
                    math.max(0, side - 32),
                    92,
                  ),
                  child: AnimatedSwitcher(
                    duration: pMotion(context, 250),
                    child: KeyedSubtree(key: ValueKey(phase), child: body),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
