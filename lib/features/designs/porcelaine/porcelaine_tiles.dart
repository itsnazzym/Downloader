import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/design_progress_bar.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import '../signal/signal_home.dart' show designFreeSpaceProvider;
import 'porcelaine_states.dart';
import 'porcelaine_widgets.dart';
import 'porcelaine_workspace_model.dart';

/// The Espace's six widgets, each drawn for its three sizes
/// (Espace.dc.html, `w.isS` / `w.isM` / `w.isL`).

String pWidgetName(AppLocalizations l10n, PWidgetType type) => switch (type) {
  PWidgetType.active => l10n.designInProgress,
  PWidgetType.paste => l10n.porcelaineQuickLink,
  PWidgetType.speed => l10n.porcelaineSpeed,
  PWidgetType.storage => l10n.porcelaineStorage,
  PWidgetType.recent => l10n.porcelaineRecent,
  PWidgetType.queue => l10n.designQueue,
};

String pWidgetDesc(AppLocalizations l10n, PWidgetType type) => switch (type) {
  PWidgetType.active => l10n.porcelaineDescActive,
  PWidgetType.paste => l10n.porcelaineDescPaste,
  PWidgetType.speed => l10n.porcelaineDescSpeed,
  PWidgetType.storage => l10n.porcelaineDescStorage,
  PWidgetType.recent => l10n.porcelaineDescRecent,
  PWidgetType.queue => l10n.porcelaineDescQueue,
};

String pSizeName(AppLocalizations l10n, PWidgetSize s) => switch (s) {
  PWidgetSize.small => l10n.porcelaineSizeSmall,
  PWidgetSize.medium => l10n.porcelaineSizeMedium,
  PWidgetSize.large => l10n.porcelaineSizeLarge,
};

String pSizeShort(AppLocalizations l10n, PWidgetSize s) => switch (s) {
  PWidgetSize.small => l10n.porcelaineSizeSmallShort,
  PWidgetSize.medium => l10n.porcelaineSizeMediumShort,
  PWidgetSize.large => l10n.porcelaineSizeLargeShort,
};

/// [keyed] false for copies (the drag feedback): onboarding keys are global
/// and may be in the tree once.
Widget pTileFor(PWidgetType type, PWidgetSize size, {bool keyed = true}) =>
    switch (type) {
      PWidgetType.active => PActiveTile(size: size),
      PWidgetType.paste => PPasteTile(size: size, keyed: keyed),
      PWidgetType.speed => PSpeedTile(size: size),
      PWidgetType.storage => PStorageTile(size: size),
      PWidgetType.recent => PRecentTile(size: size, keyed: keyed),
      PWidgetType.queue => PQueueTile(size: size),
    };

/// Room the head keeps for the « … » button.
const _headEnd = 30.0;

/// While the library loads or cannot be read: the widget's head over its
/// skeleton or error body. Null once the list is there.
Widget? _gate(WidgetRef ref, Widget head, PWidgetType type, PWidgetSize size) {
  final phase = ref.watch(
    downloadListProvider.select((v) => v.hasValue ? 0 : (v.hasError ? 2 : 1)),
  );
  if (phase == 0) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      head,
      Expanded(
        child: phase == 2
            ? const PTileError()
            : PTileSkeleton(type: type, size: size),
      ),
    ],
  );
}

String _title(AppLocalizations l10n, DownloadItem item) =>
    TitleCleanerService.clean(item.title ?? item.request.url);

/// yt-dlp sizes ("54.1MiB") in the app's units; empty when unknown.
String _size(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}

/// A speed as number and unit; no speed reads "0 Mo/s", not "0 o/s".
(String, String) pSpeedParts(AppLocalizations l10n, double bytesPerSecond) {
  if (bytesPerSecond <= 0) {
    return ('0', formatSpeed(l10n, 1024 * 1024).unit);
  }
  final s = formatSpeed(l10n, bytesPerSecond);
  return (s.value, s.unit);
}

/// "412 Go" → ("412", "Go").
(String, String) _split(String text) {
  final i = text.lastIndexOf(' ');
  return i < 0 ? (text, '') : (text.substring(0, i), text.substring(i + 1));
}

// ── Live speed, sampled while the Espace is open ───────────────────────────

class PSpeedHistory {
  const PSpeedHistory(this.samples);

  /// Bytes per second, oldest first; the last one is "now".
  final List<double> samples;

  double get now => samples.isEmpty ? 0 : samples.last;
  double get peak => samples.fold(0, (a, b) => b > a ? b : a);
  double get average {
    final live = samples.where((s) => s > 0);
    return live.isEmpty ? 0 : live.reduce((a, b) => a + b) / live.length;
  }
}

/// Aggregate speed of what is downloading, one sample every 2 s, the last
/// [length] kept in memory only. Disposed (timer stopped) with the page.
final porcelaineSpeedProvider =
    StateNotifierProvider.autoDispose<PSpeedNotifier, PSpeedHistory>(
      (ref) => PSpeedNotifier(ref),
    );

class PSpeedNotifier extends StateNotifier<PSpeedHistory> {
  PSpeedNotifier(this._ref) : super(const PSpeedHistory([])) {
    _sample();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _sample());
    // The list loads after the first sample: take it again once it is there.
    _ref.listen(downloadListProvider, (_, _) {
      if (state.now == 0) _sample(replace: true);
    });
  }

  static const length = 18;
  final Ref _ref;
  late final Timer _timer;

  void _sample({bool replace = false}) {
    final items =
        _ref.read(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => _ref.read(downloadRuntimeItemProvider(id)),
    );
    final speed = aggregateSpeed(active) ?? 0;
    if (state.samples.isNotEmpty && speed == 0 && state.now == 0) return;
    final next = [
      ...replace && state.samples.isNotEmpty
          ? state.samples.sublist(0, state.samples.length - 1)
          : state.samples,
      speed,
    ];
    state = PSpeedHistory(
      next.length > length ? next.sublist(next.length - length) : next,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

// ── En cours ───────────────────────────────────────────────────────────────

class PActiveTile extends ConsumerWidget {
  const PActiveTile({super.key, required this.size});

  final PWidgetSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final list = ref.watch(downloadListProvider);
    final items = list.valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final paused = [
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final shown = [...active, ...paused];
    final notifier = ref.read(downloadListProvider.notifier);
    final main = shown.isEmpty ? null : shown.first;
    final head = PHead(
      icon: Icons.download_rounded,
      label: l10n.designInProgress,
      tint: colors.primary,
      end: _headEnd,
      trailing: Expanded(
        child: Row(
          children: [
            const SizedBox(width: 8),
            PLiveDot(live: active.isNotEmpty),
            const Spacer(),
            // No count until the list is there (it is not « 0 » yet).
            if (list.hasValue)
              Text('${shown.length}', style: pMono(colors, size: 13)),
          ],
        ),
      ),
    );
    final gate = _gate(ref, head, PWidgetType.active, size);
    if (gate != null) return gate;
    final finished = ref.watch(porcelaineFinishProvider);
    if (finished != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(
            child: _ActiveDone(item: finished, size: size),
          ),
        ],
      );
    }
    if (main == null) {
      Widget ring(double d) => PDashedBox(
        width: d,
        height: d,
        circle: true,
        child: Icon(
          Icons.download_rounded,
          size: d * 0.36,
          color: colors.textDisabled,
        ),
      );
      final title = Text(
        l10n.porcelaineNothingActiveTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: pBody(colors, size: 15, weight: FontWeight.w600),
      );
      final hint = Text(
        l10n.designNothingActive,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: pBody(colors, size: 13, color: colors.textSecondary),
      );
      final empty = switch (size) {
        PWidgetSize.small => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ring(46), const SizedBox(height: 12), title],
        ),
        PWidgetSize.medium => Row(
          children: [
            ring(64),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 2), hint],
              ),
            ),
          ],
        ),
        PWidgetSize.large => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ring(96),
              const SizedBox(height: 18),
              Text(
                l10n.porcelaineNothingActiveTitle,
                style: pDisp(24, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  l10n.designNothingActive,
                  textAlign: TextAlign.center,
                  style: pBody(colors, size: 13.5, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(child: empty),
        ],
      );
    }
    final percent = (main.progress * 100).clamp(0, 100).round();
    final running = main.status == DownloadStatus.downloading;
    final speed = parseSpeed(main.speed);
    final phase = livePhase(main, speed);
    final sp = formatSpeed(l10n, speed);
    final speedText = phase != null
        ? livePhaseLabel(l10n, phase)
        : (main.status == DownloadStatus.paused
              ? l10n.statusPaused
              : '${sp.value} ${sp.unit}'.trim());
    final eta = main.eta.isNotEmpty && running
        ? l10n.designRemaining(etaLabel(l10n, main.eta))
        : '';
    Widget bigPercent(double s, double unit) => Text.rich(
      TextSpan(
        text: '$percent',
        style: pDisp(s, color: colors.textPrimary).copyWith(height: 0.85),
        children: [
          TextSpan(
            text: '%',
            style: pDisp(unit, color: colors.textDisabled).copyWith(height: 1),
          ),
        ],
      ),
    );
    final bar = DesignProgressBar(
      value: main.progress,
      height: 8,
      live: running,
    );
    final body = switch (size) {
      PWidgetSize.small => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [bigPercent(44, 22), const SizedBox(height: 10), bar],
      ),
      PWidgetSize.medium => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _title(l10n, main),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(colors, weight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                bar,
                const SizedBox(height: 10),
                Text(
                  [speedText, eta].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pMono(colors),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          bigPercent(48, 22),
        ],
      ),
      PWidgetSize.large => _ActiveLarge(
        main: main,
        next: shown.length > 1 ? shown[1] : null,
        percent: bigPercent(52, 24),
        bar: bar,
        speedText: speedText,
        eta: eta,
        canPause: active.isNotEmpty,
        onPauseAll: notifier.pauseAllActive,
        onResumeAll: () {
          for (final p in paused) {
            notifier.resumeDownload(p.id);
          }
        },
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: body),
      ],
    );
  }
}

/// The « finished » moment: the bar full, a cobalt check that pops in, the
/// title; the card around it glows (see the Espace's cell).
class _ActiveDone extends StatelessWidget {
  const _ActiveDone({required this.item, required this.size});

  final DownloadItem item;
  final PWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final check = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: pMotion(context, 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.check_rounded, size: 22, color: colors.onPrimary),
      ),
    );
    return Semantics(
      liveRegion: true,
      label: '${l10n.statusCompleted}: ${_title(l10n, item)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              check,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.statusCompleted,
                      style: pBody(colors, weight: FontWeight.w600),
                    ),
                    Text(
                      _title(l10n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(
                        colors,
                        size: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (size != PWidgetSize.small)
                Text.rich(
                  TextSpan(
                    text: '100',
                    style: pDisp(
                      48,
                      color: colors.textPrimary,
                    ).copyWith(height: 0.85),
                    children: [
                      TextSpan(
                        text: '%',
                        style: pDisp(
                          22,
                          color: colors.primary,
                        ).copyWith(height: 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const DesignProgressBar(value: 1, height: 8, live: false),
        ],
      ),
    );
  }
}

class _ActiveLarge extends StatelessWidget {
  const _ActiveLarge({
    required this.main,
    required this.next,
    required this.percent,
    required this.bar,
    required this.speedText,
    required this.eta,
    required this.canPause,
    required this.onPauseAll,
    required this.onResumeAll,
  });

  final DownloadItem main;
  final DownloadItem? next;
  final Widget percent;
  final Widget bar;
  final String speedText;
  final String eta;
  final bool canPause;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final done = _size(l10n, main.downloadedSize);
    final total = _size(l10n, main.totalSize);
    final n = next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PThumb(
              url: main.thumbnailUrl,
              seed: main.id,
              width: 120,
              height: 68,
              radius: 12,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(l10n, main),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      colors,
                      weight: FontWeight.w500,
                    ).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      main.source,
                      formatLabelOf(main),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pBody(
                      colors,
                      size: 12.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            percent,
          ],
        ),
        const SizedBox(height: 18),
        bar,
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                total.isEmpty ? '' : (done.isEmpty ? total : '$done / $total'),
                maxLines: 1,
                style: pMono(colors),
              ),
            ),
            Expanded(
              child: Text(
                speedText,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: pMono(colors),
              ),
            ),
            Expanded(
              child: Text(
                eta,
                maxLines: 1,
                textAlign: TextAlign.end,
                style: pMono(colors),
              ),
            ),
          ],
        ),
        if (n != null) ...[
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: colors.textPrimary.withValues(alpha: 0.07),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              PThumb(
                url: n.thumbnailUrl,
                seed: n.id,
                width: 44,
                height: 44,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title(l10n, n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(colors, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DesignProgressBar(
                      value: n.progress,
                      height: 4,
                      live: n.status == DownloadStatus.downloading,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${(n.progress * 100).round()} %', style: pMono(colors)),
            ],
          ),
        ],
        const Spacer(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PBtn(
            label: canPause ? l10n.designPauseAll : l10n.designResumeAll,
            height: 34,
            fontSize: 13,
            onTap: canPause ? onPauseAll : onResumeAll,
          ),
        ),
      ],
    );
  }
}

/// `.live`: the accent dot that pulses while something downloads.
class PLiveDot extends StatefulWidget {
  const PLiveDot({super.key, required this.live});

  final bool live;

  @override
  State<PLiveDot> createState() => _PLiveDotState();
}

class _PLiveDotState extends State<PLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  void _sync() {
    final run = widget.live && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PLiveDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = widget.live ? colors.primary : const Color(0xFFA9AAB0);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.isAnimating ? (_c.value / 0.7).clamp(0.0, 1.0) : 1.0;
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18 * (1 - t)),
                  spreadRadius: 7 * t,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Lien rapide ────────────────────────────────────────────────────────────

class PPasteTile extends ConsumerStatefulWidget {
  const PPasteTile({super.key, required this.size, this.keyed = true});

  final PWidgetSize size;
  final bool keyed;

  @override
  ConsumerState<PPasteTile> createState() => _PPasteTileState();
}

enum _Format { auto, hd1080, audio }

class _PPasteTileState extends ConsumerState<PPasteTile>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _clip;
  bool _added = false;
  _Format _format = _Format.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(() => setState(() {}));
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

  Future<String?> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final url = ClipboardService.isSupportedUrl(text) ? text : null;
      if (mounted && url != _clip) {
        setState(() {
          _clip = url;
          _added = false;
        });
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  void _start(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    ref
        .read(downloadListProvider.notifier)
        .startDownload(
          trimmed,
          audioOnly: _format == _Format.audio ? true : null,
          preferredQuality: _format == _Format.hd1080 ? '1080' : null,
        );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _start(text);
      _controller.clear();
      return;
    }
    _pasteNow();
  }

  Future<void> _pasteNow() async {
    final url = _clip ?? await _readClipboard();
    if (url == null) {
      _focus.requestFocus();
      return;
    }
    _start(url);
    if (mounted) setState(() => _added = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final clip = _clip;
    final shortClip = clip?.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    final head = PHead(
      icon: Icons.link_rounded,
      label: l10n.porcelaineQuickLink,
      end: _headEnd,
    );
    final acceptLabel = _added ? l10n.porcelaineAdded : l10n.designDownload;
    Widget field({required bool withButton, required String hint}) =>
        KeyedSubtree(
          key: widget.keyed ? OnboardingTargets.newDownload : null,
          child: AnimatedContainer(
            duration: pMotion(context, 200),
            height: 48,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 6, 0),
            decoration: BoxDecoration(
              color: _focus.hasFocus ? colors.surface : colors.inputBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: _focus.hasFocus ? 1.5 : 1,
                color: _focus.hasFocus
                    ? colors.primary
                    : colors.textPrimary.withValues(alpha: 0.08),
              ),
              boxShadow: _focus.hasFocus
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.18),
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onSubmitted: (_) => _submit(),
                    style: pBody(colors),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: hint,
                      hintStyle: pBody(colors, color: colors.textDisabled),
                    ),
                  ),
                ),
                if (withButton) ...[
                  const SizedBox(width: 8),
                  PBtn(
                    label: acceptLabel,
                    kind: _added ? PBtnKind.line : PBtnKind.accent,
                    height: 36,
                    padding: 14,
                    onTap: _submit,
                  ),
                ],
              ],
            ),
          ),
        );
    final body = switch (widget.size) {
      PWidgetSize.small => Center(
        child: KeyedSubtree(
          key: widget.keyed ? OnboardingTargets.newDownload : null,
          child: _BigPasteButton(
            label: _added ? l10n.porcelaineAddedShort : l10n.porcelainePaste,
            accent: !_added,
            tooltip: l10n.porcelainePasteAndDownload,
            onTap: _pasteNow,
          ),
        ),
      ),
      PWidgetSize.medium => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(withButton: true, hint: l10n.porcelainePasteHint),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(
              shortClip == null
                  ? l10n.porcelaineClipboardNone
                  : l10n.porcelaineClipboard(shortClip),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pBody(colors, size: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
      PWidgetSize.large => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.designHeroTitle,
            maxLines: 2,
            style: pDisp(26, color: colors.textPrimary).copyWith(height: 1.1),
          ),
          const SizedBox(height: 14),
          field(withButton: false, hint: l10n.designPasteHint),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (f, label) in [
                (_Format.auto, l10n.porcelaineFormatAuto),
                (_Format.hd1080, '1080p'),
                (_Format.audio, l10n.porcelaineFormatAudio),
              ])
                PPill(
                  label: label,
                  selected: _format == f,
                  onTap: () => setState(() => _format = f),
                ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.textPrimary.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortClip == null
                            ? l10n.porcelaineClipboardNone
                            : l10n.porcelaineClipboardTitle,
                        style: pBody(
                          colors,
                          size: 12.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                      if (shortClip != null)
                        Text(
                          shortClip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pMono(colors, size: 11.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PBtn(
                  label: acceptLabel,
                  kind: _added ? PBtnKind.line : PBtnKind.accent,
                  height: 34,
                  fontSize: 13,
                  padding: 14,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: body),
      ],
    );
  }
}

class _BigPasteButton extends StatefulWidget {
  const _BigPasteButton({
    required this.label,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final bool accent;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_BigPasteButton> createState() => _BigPasteButtonState();
}

class _BigPasteButtonState extends State<_BigPasteButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = widget.accent ? colors.onPrimary : colors.textPrimary;
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: pMotion(context, 160),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: widget.accent ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (widget.accent ? colors.primary : colors.textPrimary)
                    .withValues(alpha: widget.accent ? 0.18 : 0.1),
                blurRadius: widget.accent ? 20 : 0,
                spreadRadius: widget.accent ? 0 : 1,
                offset: Offset(0, widget.accent ? 8 : 0),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _down = true),
              onTapUp: (_) => setState(() => _down = false),
              onTapCancel: () => setState(() => _down = false),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 24, color: fg),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: pBody(
                      colors,
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Débit ──────────────────────────────────────────────────────────────────

class PSpeedTile extends ConsumerWidget {
  const PSpeedTile({super.key, required this.size});

  final PWidgetSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final history = ref.watch(porcelaineSpeedProvider);
    final (number, unit) = pSpeedParts(l10n, history.now);
    final head = PHead(
      icon: Icons.speed_rounded,
      label: l10n.porcelaineSpeed,
      tint: pGreen,
      end: _headEnd,
    );
    final gate = _gate(ref, head, PWidgetType.speed, size);
    if (gate != null) return gate;
    Widget big(double s) => Text(
      number,
      style: pDisp(s, color: colors.textPrimary).copyWith(height: 0.9),
    );
    final body = switch (size) {
      PWidgetSize.small => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          big(44),
          const SizedBox(height: 6),
          Text(
            l10n.porcelaineSpeedNow(unit),
            style: pBody(colors, size: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
      PWidgetSize.medium => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              big(44),
              const SizedBox(height: 6),
              Text(
                unit,
                style: pBody(colors, size: 12.5, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 64,
              child: PSpark(samples: history.samples, slots: 12),
            ),
          ),
        ],
      ),
      PWidgetSize.large => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              big(56),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: pBody(colors, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: PSpark(samples: history.samples, slots: 18)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (label, value) in [
                (l10n.porcelainePeak, _speedText(l10n, history.peak)),
                (l10n.porcelaineAverage, _speedText(l10n, history.average)),
                (
                  l10n.statsToday,
                  localBytes(
                    l10n,
                    ref.watch(
                      downloadStatsProvider.select((s) => s.bytesToday),
                    ),
                  ),
                ),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: pMono(colors, color: colors.textDisabled),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pMono(
                          colors,
                          size: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    };
    return Semantics(
      label: '${l10n.porcelaineSpeed}: $number $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(child: body),
        ],
      ),
    );
  }

  static String _speedText(AppLocalizations l10n, double v) {
    final (n, u) = pSpeedParts(l10n, v);
    return '$n $u';
  }
}

/// `.spark`: the last samples as bars, the newest in green; empty slots on
/// the left until the history fills.
class PSpark extends StatelessWidget {
  const PSpark({super.key, required this.samples, required this.slots});

  final List<double> samples;
  final int slots;

  @override
  Widget build(BuildContext context) {
    final shown = samples.length > slots
        ? samples.sublist(samples.length - slots)
        : samples;
    final peak = shown.fold<double>(0, (a, b) => b > a ? b : a);
    final pad = slots - shown.length;
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < slots; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: i < pad || peak <= 0
                    ? 0.06
                    : (0.08 + 0.92 * shown[i - pad] / peak).clamp(0.06, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i == slots - 1 && shown.isNotEmpty
                        ? pGreen
                        : const Color(0xFFDFE6DF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stockage ───────────────────────────────────────────────────────────────

class PStorageTile extends ConsumerStatefulWidget {
  const PStorageTile({super.key, required this.size});

  final PWidgetSize size;

  @override
  ConsumerState<PStorageTile> createState() => _PStorageTileState();
}

class _PStorageTileState extends ConsumerState<PStorageTile> {
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final done = [
      for (final i in items)
        if (i.status == DownloadStatus.completed) i,
    ];
    final byKind = {for (final k in MediaKind.values) k: 0};
    for (final item in done) {
      byKind[mediaKindOf(item)] = byKind[mediaKindOf(item)]! + bytesOf(item);
    }
    final used = byKind.values.fold<int>(0, (a, b) => a + b);
    final total = used + (free ?? 0) <= 0 ? 1 : used + (free ?? 0);
    final (number, unit) = free == null
        ? ('—', '')
        : _split(localBytes(l10n, free));
    final shades = [
      colors.textPrimary,
      const Color(0xFF8E9097),
      const Color(0xFFC4C5C9),
    ];
    final labels = [
      l10n.designFilterVideo,
      l10n.designFilterAudio,
      l10n.designFilterImages,
    ];
    final head = PHead(
      icon: Icons.storage_rounded,
      label: l10n.porcelaineStorage,
      tint: pPink,
      end: _headEnd,
    );
    final gate = _gate(ref, head, PWidgetType.storage, widget.size);
    if (gate != null) return gate;
    Widget composition(double h) => SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++)
            if (byKind[MediaKind.values[i]]! > 0) ...[
              Expanded(
                flex: (byKind[MediaKind.values[i]]! * 1000 ~/ total).clamp(
                  1,
                  1000,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shades[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 3),
            ],
          Expanded(
            flex: ((free ?? 0) * 1000 ~/ total).clamp(1, 1000),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pTrack(colors),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
    Widget amount(double s, String tail) => Text.rich(
      TextSpan(
        text: number,
        style: pDisp(s, color: colors.textPrimary).copyWith(height: 0.9),
        children: [
          TextSpan(
            text: ' $tail',
            style: pBody(
              colors,
              color: colors.textSecondary,
            ).copyWith(letterSpacing: 0),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final heaviest = [...done]
      ..sort((a, b) => bytesOf(b).compareTo(bytesOf(a)));
    final body = switch (widget.size) {
      PWidgetSize.small => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amount(40, l10n.porcelaineFreeUnit(unit).trim()),
          const SizedBox(height: 10),
          PBar(value: used / total, color: colors.textPrimary),
        ],
      ),
      PWidgetSize.medium => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amount(36, l10n.porcelaineFreeUnit(unit).trim()),
          const SizedBox(height: 12),
          composition(10),
          const SizedBox(height: 12),
          _Legend(labels: labels, byKind: byKind),
        ],
      ),
      PWidgetSize.large => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amount(44, l10n.porcelaineFreeUnit(unit).trim()),
          const SizedBox(height: 14),
          composition(12),
          const SizedBox(height: 12),
          _Legend(labels: labels, byKind: byKind),
          const SizedBox(height: 14),
          Text(
            l10n.porcelaineHeaviest,
            style: pBody(colors, size: 12, color: colors.textDisabled),
          ),
          const SizedBox(height: 8),
          for (final item in heaviest.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(l10n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(colors, size: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    localBytes(l10n, bytesOf(item)),
                    style: pMono(colors, size: 12.5),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PBtn(
              label: l10n.porcelaineFreeUp,
              height: 34,
              fontSize: 13,
              onTap: () {
                // The library sorted by size, where files can be removed.
                ref.read(downloadSortProvider.notifier).state =
                    DownloadSort.sizeDesc;
                ref.read(downloadStatusFilterProvider.notifier).state =
                    DownloadStatusFilter.completed;
                ref.read(downloadSourceFilterProvider.notifier).state = null;
                ref.read(porcelaineLibraryOpenProvider.notifier).state = true;
              },
            ),
          ),
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: body),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.labels, required this.byKind});

  final List<String> labels;
  final Map<MediaKind, int> byKind;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Text(
      [
        for (var i = 0; i < 3; i++)
          '${labels[i]} ${localBytes(l10n, byKind[MediaKind.values[i]]!)}',
      ].join('    '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: pBody(colors, size: 12, color: colors.textSecondary),
    );
  }
}

// ── Récents ────────────────────────────────────────────────────────────────

class PRecentTile extends ConsumerWidget {
  const PRecentTile({super.key, required this.size, this.keyed = true});

  final PWidgetSize size;
  final bool keyed;

  static void openLibrary(WidgetRef ref, {String? select}) {
    ref.read(porcelaineLibraryOpenProvider.notifier).state = true;
    if (select != null) {
      ref.read(selectedDownloadIdProvider.notifier).state = select;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final recent = [
      for (final i in items)
        if (i.status == DownloadStatus.completed ||
            i.status == DownloadStatus.failed ||
            i.status == DownloadStatus.canceled)
          i,
    ]..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    String meta(DownloadItem i) {
      if (i.status != DownloadStatus.completed) {
        final reason = pFailReason(i.error);
        return reason.isEmpty ? l10n.designFailed : reason;
      }
      final size = bytesOf(i);
      return [
        i.source,
        if (size > 0) localBytes(l10n, size),
      ].where((s) => s.isNotEmpty).join(' · ');
    }

    Color metaColor(DownloadItem i) => i.status == DownloadStatus.completed
        ? colors.textDisabled
        : colors.error;
    final head = PHead(
      icon: Icons.schedule_rounded,
      label: l10n.porcelaineRecent,
      tint: pSlate,
      end: _headEnd,
      // A small card has no room: the « … » menu carries the link there.
      trailing: size == PWidgetSize.small
          ? null
          : Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: KeyedSubtree(
                  key: keyed ? OnboardingTargets.creatorList : null,
                  child: _TextLink(
                    label: l10n.porcelaineWholeLibrary,
                    onTap: () => openLibrary(ref),
                  ),
                ),
              ),
            ),
    );
    final gate = _gate(ref, head, PWidgetType.recent, size);
    if (gate != null) return gate;
    if (recent.isEmpty) {
      // Empty slots where the thumbnails will land.
      final slots = switch (size) {
        PWidgetSize.small => const PDashedBox(height: 58),
        PWidgetSize.medium => Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              const Expanded(child: PDashedBox(height: 54)),
            ],
          ],
        ),
        PWidgetSize.large => Column(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  const PDashedBox(width: 52, height: 32, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: const [0.7, 0.5, 0.62, 0.42][i],
                      child: const PDashedBox(height: 10, radius: 5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(child: slots),
                const SizedBox(height: 10),
                Text(
                  l10n.designLibraryEmpty,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(colors, size: 13, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // A failed item's picture says how to get it back.
    Widget thumb(
      DownloadItem i, {
      double? width,
      required double height,
      double radius = 12,
    }) {
      final picture = PThumb(
        url: i.thumbnailUrl,
        seed: i.id,
        width: width,
        height: height,
        radius: radius,
      );
      if (i.status == DownloadStatus.completed) return picture;
      final compact = (width ?? 999) < 80;
      return Stack(
        alignment: Alignment.center,
        children: [
          picture,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Tooltip(
            message: l10n.retry,
            child: Container(
              height: 24,
              padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 9),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 14, color: colors.error),
                  if (!compact) ...[
                    const SizedBox(width: 4),
                    Text(
                      l10n.retry,
                      style: pBody(
                        colors,
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: colors.error,
                      ).copyWith(height: 1.1),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // InkWell: hover wash, press, keyboard focus and Enter, like a button.
    Widget tap(DownloadItem i, Widget child) => DownloadItemContextMenu(
      item: i,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: colors.textPrimary.withValues(alpha: 0.04),
          focusColor: colors.primary.withValues(alpha: 0.12),
          splashColor: Colors.transparent,
          onTap: () => i.status == DownloadStatus.completed
              ? openLibrary(ref, select: i.id)
              : ref.read(downloadListProvider.notifier).retryDownload(i),
          child: child,
        ),
      ),
    );
    final title = pBody(
      colors,
      size: 12.5,
      weight: FontWeight.w500,
    ).copyWith(height: 1.3);
    final Widget body = switch (size) {
      PWidgetSize.small => tap(
        recent.first,
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            thumb(recent.first, height: 58),
            const SizedBox(height: 10),
            Text(
              _title(l10n, recent.first),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: title.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
      PWidgetSize.medium => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: i >= recent.length
                  ? const SizedBox()
                  : tap(
                      recent[i],
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          thumb(recent[i], height: 54),
                          const SizedBox(height: 8),
                          Text(
                            _title(l10n, recent[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: title,
                          ),
                          Text(
                            meta(recent[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pBody(
                              colors,
                              size: 11.5,
                              color: metaColor(recent[i]),
                            ).copyWith(height: 1.3),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
      PWidgetSize.large => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in recent.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: tap(
                i,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      thumb(i, width: 52, height: 32, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(l10n, i),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: title.copyWith(fontSize: 13),
                            ),
                            Text(
                              i.status == DownloadStatus.completed
                                  ? meta(i)
                                  : '${meta(i)} · ${l10n.retry}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: pBody(
                                colors,
                                size: 11.5,
                                color: metaColor(i),
                              ).copyWith(height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    };
    return KeyedSubtree(
      key: keyed ? OnboardingTargets.library : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _TextLink extends StatefulWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<_TextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = _hover ? colors.textPrimary : colors.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              widget.label,
              maxLines: 1,
              style: pBody(
                colors,
                size: 12.5,
                weight: FontWeight.w500,
                color: c,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── File d'attente ─────────────────────────────────────────────────────────

class PQueueTile extends ConsumerWidget {
  const PQueueTile({super.key, required this.size});

  final PWidgetSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final queued = [
      for (final i
          in ref.watch(downloadListProvider).valueOrNull ??
              const <DownloadItem>[])
        if (i.status == DownloadStatus.queued) i,
    ];
    final head = PHead(
      icon: Icons.format_list_bulleted_rounded,
      label: l10n.designQueue,
      tint: colors.primary,
      end: _headEnd,
    );
    final gate = _gate(ref, head, PWidgetType.queue, size);
    if (gate != null) return gate;
    Widget row(int i, {bool line = false}) => DownloadItemContextMenu(
      item: queued[i],
      child: Container(
        padding: EdgeInsets.only(bottom: line ? 10 : 0),
        decoration: line
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.textPrimary.withValues(alpha: 0.06),
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Text(
              (i + 1).toString().padLeft(2, '0'),
              style: pMono(colors, size: 13, color: colors.textDisabled),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _title(l10n, queued[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pBody(colors, size: 13),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              queued[i].source,
              style: pMono(colors, color: colors.textDisabled),
            ),
          ],
        ),
      ),
    );
    final Widget body;
    if (size == PWidgetSize.small) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${queued.length}',
            style: pDisp(44, color: colors.textPrimary).copyWith(height: 0.9),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.porcelaineWaiting,
            style: pBody(colors, size: 12.5, color: colors.textSecondary),
          ),
        ],
      );
    } else if (queued.isEmpty) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Empty numbered slots where waiting links will line up.
          for (var i = 0; i < (size == PWidgetSize.large ? 4 : 2); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: pMono(
                        colors,
                        size: 13,
                        color: colors.textDisabled.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: PDashedBox(height: 14, radius: 7)),
                  ],
                ),
              ),
            ),
          Text(
            l10n.designQueueEmpty,
            style: pBody(colors, size: 13, color: colors.textSecondary),
          ),
        ],
      );
    } else if (size == PWidgetSize.medium) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < queued.length && i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            row(i),
          ],
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < queued.length && i < 6; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            row(i, line: true),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: body),
      ],
    );
  }
}

/// Live value shown on a catalog card's preview.
String pCatalogPreview(WidgetRef ref, AppLocalizations l10n, PWidgetType t) {
  final items =
      ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
  switch (t) {
    case PWidgetType.active:
      final active = liveActiveItems(
        items,
        (id) => ref.watch(downloadRuntimeItemProvider(id)),
      );
      return active.isEmpty ? '0' : '${(active.first.progress * 100).round()}%';
    case PWidgetType.paste:
      return '↓';
    case PWidgetType.speed:
      final s = ref.watch(porcelaineSpeedProvider).now;
      return s == 0 ? '0' : formatSpeed(l10n, s).value;
    case PWidgetType.storage:
      final free = ref.watch(designFreeSpaceProvider).valueOrNull;
      return free == null ? '—' : localBytes(l10n, free);
    case PWidgetType.recent:
      return '${items.where((i) => i.status == DownloadStatus.completed).length}';
    case PWidgetType.queue:
      return '${items.where((i) => i.status == DownloadStatus.queued).length}';
  }
}
