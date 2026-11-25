import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/design_progress_bar.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/disk_space_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_more_actions_menu.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/failed_downloads_badge.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'signal_widgets.dart';

/// Signal's home (mockup Main.dc.html): paste hero, today, downloads in
/// progress, queue, storage, then the whole library.
class SignalHome extends ConsumerWidget {
  const SignalHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDownloadIdProvider);
    final colors = AppColors.of(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            DownloadSearchFocus.request,
      },
      child: Row(
        children: [
          const Expanded(child: _HomeScroll()),
          if (selected != null)
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(left: BorderSide(color: colors.borderSubtle)),
              ),
              child: DownloadInspector(downloadId: selected),
            ),
        ],
      ),
    );
  }
}

class _HomeScroll extends ConsumerWidget {
  const _HomeScroll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        ref.watch(downloadViewModeProvider) == DownloadViewMode.folders;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final side = constraints.maxWidth > 1304
            ? (constraints.maxWidth - 1240) / 2
            : 32.0;
        EdgeInsets pad(double top, double bottom) =>
            EdgeInsets.fromLTRB(side, top, side, bottom);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: pad(32, 0),
              sliver: SliverToBoxAdapter(child: _Bento(wide: wide)),
            ),
            SliverPadding(
              padding: pad(40, 18),
              sliver: const SliverToBoxAdapter(child: _LibraryHeader()),
            ),
            if (folders)
              const SliverFillRemaining(
                hasScrollBody: true,
                child: DownloadList(),
              )
            else
              SliverPadding(
                padding: pad(0, 48),
                sliver: _LibraryGrid(columns: wide ? 2 : 1),
              ),
          ],
        );
      },
    );
  }
}

class _Bento extends StatelessWidget {
  const _Bento({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(),
          SizedBox(height: 16),
          _TodayCard(),
          SizedBox(height: 16),
          _ActiveCard(),
          SizedBox(height: 16),
          _QueueCard(),
          SizedBox(height: 16),
          _StorageCard(),
        ],
      );
    }
    return const Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 8, child: _HeroCard()),
              SizedBox(width: 16),
              Expanded(flex: 4, child: _TodayCard()),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _ActiveCard()),
            SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Column(
                children: [_QueueCard(), SizedBox(height: 16), _StorageCard()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Hero: paste a link ──────────────────────────────────────────────────────

class _HeroCard extends ConsumerStatefulWidget {
  const _HeroCard();

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _clipboardUrl;
  bool _clipboardAdded = false;

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

  Future<void> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      final url = ClipboardService.isSupportedUrl(text) ? text : null;
      if (url != _clipboardUrl) {
        setState(() {
          _clipboardUrl = url;
          _clipboardAdded = false;
        });
      }
    } catch (_) {}
  }

  void _start(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    ref.read(downloadListProvider.notifier).startDownload(trimmed);
  }

  void _submitField() {
    _start(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final clip = _clipboardUrl;
    final showClip =
        clip != null &&
        (_clipboardAdded || !items.any((i) => i.request.url == clip));
    return SignalCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.designHeroTitle,
            style: AppTypography.display(
              40,
              weight: FontWeight.w600,
            ).copyWith(color: colors.textPrimary, height: 1.05),
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: OnboardingTargets.newDownload,
            child: AnimatedContainer(
              duration: signalMotion(context, 200),
              height: 60,
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              decoration: BoxDecoration(
                color: colors.inputBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _focus.hasFocus
                      ? colors.primary
                      : colors.textPrimary.withValues(alpha: 0.08),
                ),
                boxShadow: _focus.hasFocus
                    ? [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.22),
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: colors.textDisabled,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      onSubmitted: (_) => _submitField(),
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                      cursorColor: colors.primary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.designPasteHint,
                        hintStyle: AppTypography.body.copyWith(
                          fontSize: 15,
                          fontStyle: FontStyle.normal,
                          color: colors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SignalButton(label: l10n.designDownload, onTap: _submitField),
                ],
              ),
            ),
          ),
          if (showClip) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              decoration: BoxDecoration(
                color: colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.content_paste_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.designClipboardFound,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          clip.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.mono.copyWith(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SignalButton(
                    label: _clipboardAdded
                        ? '${l10n.downloadStarted} ✓'
                        : l10n.designDownload,
                    accent: !_clipboardAdded,
                    height: 38,
                    fontSize: 13,
                    onTap: _clipboardAdded
                        ? null
                        : () {
                            _start(clip);
                            setState(() => _clipboardAdded = true);
                          },
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

// ── Today ───────────────────────────────────────────────────────────────────

class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final stats = ref.watch(downloadStatsProvider);
    final byDay = {for (final d in stats.dailyHistory) d.date: d.downloads};
    final now = DateTime.now();
    final week = [
      for (var i = 6; i >= 0; i--)
        byDay[_dayKey(now.subtract(Duration(days: i)))] ?? 0,
    ];
    week[6] = stats.downloadsToday;
    final peak = week.fold<int>(1, (a, b) => b > a ? b : a);
    return SignalCard(
      lift: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignalEyebrow(l10n.downloadsToday),
          const Spacer(),
          Text(
            '${stats.downloadsToday}',
            style: AppTypography.display(
              56,
            ).copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.designTodayCaption(localBytes(l10n, stats.bytesToday)),
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.1, end: 1),
                      duration: signalMotion(context, 700 + i * 40),
                      curve: signalEase,
                      builder: (context, t, _) => FractionallySizedBox(
                        heightFactor: (0.12 + 0.88 * week[i] / peak) * t,
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == 6
                                ? colors.primary
                                : colors.textPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── In progress ─────────────────────────────────────────────────────────────

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final paused = [
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final notifier = ref.read(downloadListProvider.notifier);
    final count = active.length + paused.length;
    return SignalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _LiveDot(live: active.isNotEmpty),
              const SizedBox(width: 10),
              Text(
                l10n.designInProgress,
                style: AppTypography.display(
                  22,
                  weight: FontWeight.w600,
                ).copyWith(color: colors.textPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                '$count',
                style: AppTypography.mono.copyWith(
                  fontSize: 13,
                  color: colors.textDisabled,
                ),
              ),
              const Spacer(),
              if (active.isNotEmpty)
                SignalButton(
                  label: l10n.designPauseAll,
                  accent: false,
                  height: 36,
                  fontSize: 13,
                  onTap: notifier.pauseAllActive,
                )
              else if (paused.isNotEmpty)
                SignalButton(
                  label: l10n.designResumeAll,
                  accent: false,
                  height: 36,
                  fontSize: 13,
                  onTap: () {
                    for (final p in paused) {
                      notifier.resumeDownload(p.id);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (active.isEmpty && paused.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                l10n.designNothingActive,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            )
          else ...[
            _MainProgress(
              item: active.isNotEmpty ? active.first : paused.first,
            ),
            for (final item in [...active.skip(1), ...paused].take(2)) ...[
              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: colors.textPrimary.withValues(alpha: 0.07),
              ),
              const SizedBox(height: 22),
              _MiniProgress(item: item),
            ],
          ],
        ],
      ),
    );
  }
}

class _MainProgress extends StatelessWidget {
  const _MainProgress({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final label = formatSpeed(l10n, speed);
    final percent = (item.progress * 100).clamp(0, 100).round();
    final running = item.status == DownloadStatus.downloading;
    final downloaded = _size(l10n, item.downloadedSize);
    final total = _size(l10n, item.totalSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SignalThumb(url: item.thumbnailUrl, width: 168, height: 95),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TitleCleanerService.clean(item.title ?? l10n.unknown),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      item.source,
                      formatLabelOf(item),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                text: '$percent',
                style: AppTypography.display(
                  56,
                ).copyWith(color: colors.textPrimary, height: 0.9),
                children: [
                  TextSpan(
                    text: '%',
                    style: AppTypography.display(
                      28,
                    ).copyWith(color: colors.textDisabled),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        DesignProgressBar(value: item.progress, height: 6, live: running),
        const SizedBox(height: 10),
        Row(
          children: [
            if (total.isNotEmpty)
              Text(
                downloaded.isEmpty ? total : '$downloaded / $total',
                style: _mono(colors),
              ),
            if (total.isNotEmpty) const SizedBox(width: 18),
            Text(
              phase != null
                  ? livePhaseLabel(l10n, phase)
                  : (item.status == DownloadStatus.paused
                        ? l10n.statusPaused
                        : '${label.value} ${label.unit}'),
              style: _mono(colors),
            ),
            const Spacer(),
            if (item.eta.isNotEmpty && running)
              Text(
                l10n.designRemaining(etaLabel(l10n, item.eta)),
                style: _mono(colors),
              ),
          ],
        ),
      ],
    );
  }

  static TextStyle _mono(AppColors colors) =>
      AppTypography.mono.copyWith(fontSize: 12.5, color: colors.textSecondary);
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        SignalThumb(url: item.thumbnailUrl, width: 56, height: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TitleCleanerService.clean(item.title ?? l10n.unknown),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DesignProgressBar(
                value: item.progress,
                height: 4,
                live: item.status == DownloadStatus.downloading,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '${(item.progress * 100).round()} %',
          style: AppTypography.mono.copyWith(
            fontSize: 12.5,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.live});

  final bool live;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
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
  void didUpdateWidget(_LiveDot old) {
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
    final color = widget.live ? colors.primary : colors.textDisabled;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.isAnimating ? _c.value : 1.0;
          return Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45 * (1 - t)),
                  spreadRadius: 8 * t,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Queue ───────────────────────────────────────────────────────────────────

class _QueueCard extends ConsumerWidget {
  const _QueueCard();

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
    return SignalCard(
      lift: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SignalEyebrow(l10n.designQueue),
              const Spacer(),
              if (queued.isNotEmpty)
                _TextLink(
                  label: l10n.designSeeAll,
                  onTap: () {
                    ref.read(downloadSourceFilterProvider.notifier).state =
                        null;
                    ref.read(downloadStatusFilterProvider.notifier).state =
                        DownloadStatusFilter.active;
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (queued.isEmpty)
            Text(
              l10n.designQueueEmpty,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          for (var i = 0; i < queued.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: AppTypography.mono.copyWith(
                        fontSize: 12,
                        color: colors.textDisabled,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      TitleCleanerService.clean(
                        queued[i].title ?? queued[i].request.url,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    queued[i].source,
                    style: AppTypography.mono.copyWith(
                      fontSize: 12,
                      color: colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: AppTypography.body.copyWith(
            fontSize: 13,
            color: _hover ? colors.textPrimary : colors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: _hover ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Storage ─────────────────────────────────────────────────────────────────

class _StorageCard extends ConsumerStatefulWidget {
  const _StorageCard();

  @override
  ConsumerState<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends ConsumerState<_StorageCard> {
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
    final folder = ref.watch(settingsProvider.select((s) => s.outputFolder));
    final freeBytes = ref.watch(designFreeSpaceProvider).valueOrNull;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final byKind = {for (final k in MediaKind.values) k: 0};
    for (final item in items) {
      if (item.status != DownloadStatus.completed) continue;
      byKind[mediaKindOf(item)] = byKind[mediaKindOf(item)]! + bytesOf(item);
    }
    final free = freeBytes ?? 0;
    final used = byKind.values.fold<int>(0, (a, b) => a + b);
    final total = (used + free) <= 0 ? 1 : used + free;
    final drive = driveOf(folder);
    final shades = [
      colors.textPrimary,
      colors.textDisabled,
      colors.textPrimary.withValues(alpha: 0.28),
    ];
    final labels = [
      l10n.designFilterVideo,
      l10n.designFilterAudio,
      l10n.designFilterImages,
    ];
    return SignalCard(
      lift: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SignalEyebrow(
                  drive == null
                      ? l10n.storageUsage
                      : l10n.designStorageDrive(drive),
                ),
              ),
              if (freeBytes != null)
                Text(
                  l10n.designFree(localBytes(l10n, free)),
                  style: AppTypography.mono.copyWith(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  if (byKind[MediaKind.values[i]]! > 0) ...[
                    Expanded(
                      flex: (byKind[MediaKind.values[i]]! * 1000 ~/ total)
                          .clamp(1, 1000),
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
                  flex: (free * 1000 ~/ total).clamp(1, 1000),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 3; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: shades[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${labels[i]} ${localBytes(l10n, byKind[MediaKind.values[i]]!)}',
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
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

// ── Library ─────────────────────────────────────────────────────────────────

/// Free bytes on the output folder's drive, null when unknown.
final designFreeSpaceProvider = FutureProvider<int?>((ref) {
  final folder = ref.watch(settingsProvider.select((s) => s.outputFolder));
  return DiskSpaceService.getFreeDiskSpace(folder.isEmpty ? null : folder);
});

/// Media type shown by the library chips (Tout / Vidéo / Audio / Images).
final signalKindFilterProvider = StateProvider<MediaKind?>((ref) => null);

class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final kind = ref.watch(signalKindFilterProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final counts = ref.watch(downloadLibraryCountsProvider);
    final shown = ref.watch(
      filteredDownloadsProvider.select((v) => v.valueOrNull?.length ?? 0),
    );
    void setKind(MediaKind? k) =>
        ref.read(signalKindFilterProvider.notifier).state = k;
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.librarySection,
                style: AppTypography.display(
                  28,
                  weight: FontWeight.w600,
                ).copyWith(color: colors.textPrimary),
              ),
              const SizedBox(width: 14),
              Text(
                '$shown',
                style: AppTypography.mono.copyWith(
                  fontSize: 14,
                  color: colors.textDisabled,
                ),
              ),
              const Spacer(),
              for (final (k, label) in [
                (null, l10n.designFilterAll),
                (MediaKind.video, l10n.designFilterVideo),
                (MediaKind.audio, l10n.designFilterAudio),
                (MediaKind.image, l10n.designFilterImages),
              ]) ...[
                const SizedBox(width: 8),
                SignalChip(
                  label: label,
                  selected: kind == k,
                  onTap: () => setKind(k),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (s, label, n) in [
                        (
                          DownloadStatusFilter.active,
                          l10n.sidebarActive,
                          counts.active,
                        ),
                        (
                          DownloadStatusFilter.completed,
                          l10n.sidebarCompleted,
                          counts.completed,
                        ),
                        (
                          DownloadStatusFilter.failed,
                          l10n.sidebarFailed,
                          counts.failed,
                        ),
                      ]) ...[
                        SignalChip(
                          label: label,
                          count: n,
                          selected: status == s,
                          onTap: () {
                            ref
                                    .read(downloadSourceFilterProvider.notifier)
                                    .state =
                                null;
                            ref
                                .read(downloadStatusFilterProvider.notifier)
                                .state = status == s
                                ? DownloadStatusFilter.all
                                : s;
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      for (final entry in counts.sourceCounts.entries)
                        if (entry.value > 0 && entry.key != 'Other') ...[
                          SignalChip(
                            label: entry.key,
                            count: entry.value,
                            selected: source == entry.key,
                            onTap: () {
                              ref
                                  .read(downloadStatusFilterProvider.notifier)
                                  .state = DownloadStatusFilter
                                  .all;
                              ref
                                  .read(downloadSourceFilterProvider.notifier)
                                  .state = source == entry.key
                                  ? null
                                  : entry.key;
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                height: 36,
                child: DownloadSearchField(
                  onChanged: (v) =>
                      ref.read(downloadSearchQueryProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              const FailedDownloadsBadge(compact: true),
              const _SortMenu(),
              const SizedBox(width: 4),
              const DownloadMoreActionsMenu(
                showQueueActions: true,
                showRetryFailed: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final sort = ref.watch(downloadSortProvider);
    final mode = ref.watch(downloadViewModeProvider);
    final options = [
      (DownloadSort.dateDesc, l10n.sortFieldDate),
      (DownloadSort.nameAsc, l10n.sortFieldName),
      (DownloadSort.sizeDesc, l10n.sortFieldSize),
    ];
    return PopupMenuButton<Object>(
      tooltip: l10n.sortAndView,
      color: colors.surfaceHighlight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value is DownloadSort) {
          ref.read(downloadSortProvider.notifier).state = value;
        } else if (value is DownloadViewMode) {
          ref.read(downloadViewModeProvider.notifier).state = value;
        }
      },
      itemBuilder: (context) => [
        for (final (s, label) in options)
          CheckedPopupMenuItem<Object>(
            value: s,
            checked: sort == s,
            child: Text(label),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
          value: DownloadViewMode.list,
          checked: mode != DownloadViewMode.folders,
          child: Text(l10n.viewList),
        ),
        CheckedPopupMenuItem<Object>(
          value: DownloadViewMode.folders,
          checked: mode == DownloadViewMode.folders,
          child: Text(l10n.viewFolders),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
        ),
        child: Icon(Icons.sort_rounded, size: 17, color: colors.textSecondary),
      ),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final kind = ref.watch(signalKindFilterProvider);
    final all =
        ref.watch(filteredDownloadsProvider).valueOrNull ??
        const <DownloadItem>[];
    final items = kind == null
        ? all
        : [
            for (final i in all)
              if (mediaKindOf(i) == kind) i,
          ];
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            l10n.designLibraryEmpty,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 74,
        crossAxisSpacing: 24,
        mainAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) =>
            _LibraryRow(itemId: items[index].id, base: items[index]),
        childCount: items.length,
      ),
    );
  }
}

class _LibraryRow extends ConsumerStatefulWidget {
  const _LibraryRow({required this.itemId, required this.base});

  final String itemId;
  final DownloadItem base;

  @override
  ConsumerState<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends ConsumerState<_LibraryRow> {
  bool _hover = false;

  void _play(DownloadItem item) {
    final path = item.filePath;
    if (path != null && File(path).existsSync()) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    }
  }

  void _reveal(DownloadItem item) {
    final path = item.filePath;
    if (path != null && File(path).existsSync() && Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item =
        ref.watch(downloadRuntimeItemProvider(widget.itemId)) ?? widget.base;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final busy = isActiveDownload(item) || item.status == DownloadStatus.queued;
    final size = bytesOf(item);
    final meta = failed
        ? '${l10n.designFailed} · ${(item.error ?? '').split('\n').first}'
        : busy
        ? '${item.source} · ${(item.progress * 100).round()} %'
        : [
            item.source,
            formatLabelOf(item),
            if (size > 0) localBytes(l10n, size),
          ].where((s) => s.isNotEmpty).join(' · ');
    return DownloadItemContextMenu(
      item: item,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
              selected ? null : item.id,
          onDoubleTap: () => _play(item),
          child: AnimatedContainer(
            duration: signalMotion(context, 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected || _hover ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? colors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SignalThumb(url: item.thumbnailUrl, width: 88, height: 50),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TitleCleanerService.clean(
                          item.title ?? item.request.url,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 12.5,
                          color: failed ? colors.error : colors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: signalMotion(context, 180),
                  child: Row(
                    children: [
                      if (failed)
                        _RowAction(
                          icon: Icons.refresh_rounded,
                          tooltip: l10n.retry,
                          onTap: () => ref
                              .read(downloadListProvider.notifier)
                              .retryDownload(item),
                        )
                      else if (item.status == DownloadStatus.completed) ...[
                        _RowAction(
                          icon: Icons.play_arrow_rounded,
                          tooltip: l10n.detailsPlayVideo,
                          onTap: () => _play(item),
                        ),
                        _RowAction(
                          icon: Icons.folder_open_rounded,
                          tooltip: l10n.openFolder,
                          onTap: () => _reveal(item),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 17, color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// Size strings from yt-dlp ("54.1MiB") in the app's units; empty if none.
String _size(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}
