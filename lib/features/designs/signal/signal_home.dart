import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/components/design_progress_bar.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/disk_space_service.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'signal_inspector.dart';
import 'signal_library_row.dart';
import 'signal_library_tools.dart';
import 'signal_states.dart';
import 'signal_theme.dart';
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
              child: SignalInspector(downloadId: selected),
            ),
        ],
      ),
    );
  }
}

class _HomeScroll extends ConsumerStatefulWidget {
  const _HomeScroll();

  @override
  ConsumerState<_HomeScroll> createState() => _HomeScrollState();
}

class _HomeScrollState extends ConsumerState<_HomeScroll> {
  // The hero's field, shared with the empty state's « Coller un lien ».
  final _paste = TextEditingController();
  final _pasteFocus = FocusNode();

  @override
  void dispose() {
    _paste.dispose();
    _pasteFocus.dispose();
    super.dispose();
  }

  Future<void> _pasteLink() async {
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      final url = text?.trim() ?? '';
      if (ClipboardService.isSupportedUrl(url)) _paste.text = url;
    } catch (_) {}
    if (mounted) _pasteFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final folders =
        ref.watch(downloadViewModeProvider) == DownloadViewMode.folders;
    final (empty, error) = ref.watch(
      downloadListProvider.select(
        (v) => (v.hasValue && v.value!.isEmpty, v.hasError && !v.hasValue),
      ),
    );
    final notice = error
        ? SignalStateCard(
            eyebrow: context.l10n.librarySection,
            eyebrowColor: AppColors.of(context).error,
            title: context.l10n.signalLoadErrorTitle,
            body: context.l10n.signalLoadErrorBody,
            actions: [
              SignalButton(
                label: context.l10n.retry,
                icon: Icons.refresh_rounded,
                onTap: ref.read(downloadListProvider.notifier).refreshList,
              ),
            ],
          )
        : empty
        // The onboarding's library step points here on a first launch.
        ? KeyedSubtree(
            key: OnboardingTargets.library,
            child: SignalStateCard(
              eyebrow: context.l10n.librarySection,
              title: context.l10n.signalEmptyTitle,
              body: context.l10n.signalEmptyBody,
              art: const SignalEmptyArt(),
              actions: [
                SignalButton(
                  label: context.l10n.signalEmptyAction,
                  icon: Icons.content_paste_rounded,
                  onTap: _pasteLink,
                ),
              ],
            ),
          )
        : null;
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
              padding: pad(32, notice == null ? 0 : 48),
              sliver: SliverToBoxAdapter(
                child: _Bento(
                  wide: wide,
                  paste: _paste,
                  pasteFocus: _pasteFocus,
                  notice: notice,
                ),
              ),
            ),
            // Nothing to list or filter: the notice above says why.
            if (notice == null) ...[
              SliverPadding(
                padding: pad(40, 18),
                sliver: const SliverToBoxAdapter(child: _LibraryHeader()),
              ),
              if (folders)
                SliverPadding(
                  padding: pad(0, 0),
                  sliver: const SliverFillRemaining(
                    hasScrollBody: true,
                    child: SignalFolders(empty: _NoResults()),
                  ),
                )
              else
                SliverPadding(
                  padding: pad(0, 48),
                  sliver: _LibraryGrid(columns: wide ? 2 : 1),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Bento extends StatelessWidget {
  const _Bento({
    required this.wide,
    required this.paste,
    required this.pasteFocus,
    this.notice,
  });

  final bool wide;
  final TextEditingController paste;
  final FocusNode pasteFocus;

  /// Shown instead of the in-progress / queue / storage cards (empty
  /// library, library that failed to load).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final hero = _HeroCard(controller: paste, focus: pasteFocus);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          const SizedBox(height: 16),
          // The card spaces its figure with a Spacer: give it a height.
          const SizedBox(height: 260, child: _TodayCard()),
          const SizedBox(height: 16),
          if (notice != null)
            notice!
          else ...const [
            _ActiveCard(),
            SizedBox(height: 16),
            _QueueCard(),
            SizedBox(height: 16),
            _StorageCard(),
          ],
        ],
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 8, child: hero),
              const SizedBox(width: 16),
              const Expanded(flex: 4, child: _TodayCard()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        notice ??
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _ActiveCard()),
                SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _QueueCard(),
                      SizedBox(height: 16),
                      _StorageCard(),
                    ],
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
  const _HeroCard({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard>
    with WidgetsBindingObserver {
  TextEditingController get _controller => widget.controller;
  FocusNode get _focus => widget.focus;
  String? _clipboardUrl;
  bool _clipboardAdded = false;

  void _onFocus() => setState(() {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_onFocus);
    _readClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_onFocus);
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

class _ActiveCard extends ConsumerStatefulWidget {
  const _ActiveCard();

  @override
  ConsumerState<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends ConsumerState<_ActiveCard>
    with SingleTickerProviderStateMixin {
  /// The download that just finished: kept on screen for the finish moment.
  DownloadItem? _done;
  double _doneFrom = 0;
  final _lastProgress = <String, double>{};
  late final AnimationController _finish;

  @override
  void initState() {
    super.initState();
    _finish =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) {
            setState(() => _done = null);
          }
        });
  }

  @override
  void dispose() {
    _finish.dispose();
    super.dispose();
  }

  /// An item that was active in [prev] and is completed in [next] plays the
  /// finish moment.
  void _onList(
    AsyncValue<List<DownloadItem>>? prev,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final before = prev?.valueOrNull;
    final after = next.valueOrNull;
    if (before == null || after == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final wasActive = {
      for (final i in before)
        if (isActiveDownload(i)) i.id,
    };
    for (final item in after) {
      if (item.status == DownloadStatus.completed &&
          wasActive.contains(item.id)) {
        setState(() {
          _done = item;
          _doneFrom = _lastProgress[item.id] ?? 0.9;
        });
        _finish.forward(from: 0);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(downloadListProvider, _onList);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final loading = ref.watch(
      downloadListProvider.select((v) => v.isLoading && !v.hasValue),
    );
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    _lastProgress
      ..clear()
      ..addAll({for (final a in active) a.id: a.progress});
    final paused = [
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final failed = [
      for (final i in items)
        if (i.status == DownloadStatus.failed) i,
    ];
    final notifier = ref.read(downloadListProvider.notifier);
    final rows = [...active, ...paused];
    final done = _done;
    final count = rows.length;
    final showFailed = !loading && failed.length >= 2;
    final card = SignalCard(
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
              if (!loading)
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
          if (loading)
            const _ProgressBones()
          else if (done == null && rows.isEmpty)
            showFailed
                ? _FailedPanel(failed: failed)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      l10n.designNothingActive,
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
          else ...[
            if (done != null)
              _FinishedProgress(item: done, from: _doneFrom, t: _finish)
            else
              _MainProgress(item: rows.first),
            for (final item in rows.skip(done == null ? 1 : 0).take(2)) ...[
              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: colors.textPrimary.withValues(alpha: 0.07),
              ),
              const SizedBox(height: 22),
              _MiniProgress(item: item),
            ],
            if (showFailed) ...[
              const SizedBox(height: 22),
              _FailedPanel(failed: failed),
            ],
          ],
        ],
      ),
    );
    if (done == null) return card;
    // The card flashes chartreuse once the percent has reached 100.
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _finish,
                builder: (context, _) {
                  final f = ((_finish.value - 0.3) / 0.7).clamp(0.0, 1.0);
                  final a = f < 0.2 ? f / 0.2 : 1 - (f - 0.2) / 0.8;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: colors.primary.withValues(alpha: 0.12 * a),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.9 * a),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thumbnail size of the in-progress rows: smaller when the card is narrow.
Size _mainThumb(double width) =>
    width < 480 ? const Size(96, 54) : const Size(168, 95);

/// The finished download for [t]'s 900 ms: the percent climbs to 100, then a
/// chartreuse check pops in.
class _FinishedProgress extends StatelessWidget {
  const _FinishedProgress({
    required this.item,
    required this.from,
    required this.t,
  });

  final DownloadItem item;
  final double from;
  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final climb = CurveTween(
      curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
    );
    final pop = CurveTween(
      curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final thumb = _mainThumb(c.maxWidth);
        return AnimatedBuilder(
          animation: t,
          builder: (context, _) {
            final p = from + (1 - from) * climb.transform(t.value);
            final s = pop.transform(t.value);
            return Column(
              key: const ValueKey('signal-finish'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SignalThumb(
                      url: item.thumbnailUrl,
                      filePath: item.filePath,
                      width: thumb.width,
                      height: thumb.height,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        titleOf(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (s > 0) ...[
                      Transform.scale(
                        scale: s,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 24,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text.rich(
                      TextSpan(
                        text: '${(p * 100).round()}',
                        style: AppTypography.display(56).copyWith(
                          color: s > 0 ? colors.primary : colors.textPrimary,
                          height: 0.9,
                        ),
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
                SignalMeter(value: p, color: colors.primary),
                const SizedBox(height: 10),
                Text(l10n.statusCompleted, style: _MainProgress._mono(colors)),
              ],
            );
          },
        );
      },
    );
  }
}

/// « n téléchargements ont échoué », the latest reason and « Relancer les
/// échecs (n) ».
class _FailedPanel extends ConsumerWidget {
  const _FailedPanel({required this.failed});

  final List<DownloadItem> failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final reason = downloadErrorReason(failed.first.error);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.signalFailedCount(failed.length),
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
    final button = SignalButton(
      label: l10n.signalRetryFailed(failed.length),
      icon: Icons.refresh_rounded,
      height: 38,
      fontSize: 13,
      onTap: ref.read(downloadListProvider.notifier).retryAllFailed,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.28)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final icon = Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colors.error,
          );
          if (c.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 12),
                button,
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: text),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// The in-progress row while the library loads.
class _ProgressBones extends StatelessWidget {
  const _ProgressBones();

  @override
  Widget build(BuildContext context) {
    return SignalShimmer(
      child: LayoutBuilder(
        builder: (context, c) {
          final thumb = _mainThumb(c.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SignalBone(
                    width: thumb.width,
                    height: thumb.height,
                    radius: 10,
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.8,
                          child: SignalBone(height: 14),
                        ),
                        SizedBox(height: 10),
                        FractionallySizedBox(
                          widthFactor: 0.45,
                          child: SignalBone(height: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SignalBone(width: 88, height: 46, radius: 12),
                ],
              ),
              const SizedBox(height: 22),
              const SignalBone(height: 6),
              const SizedBox(height: 12),
              const Row(
                children: [
                  SignalBone(width: 110, height: 9),
                  Spacer(),
                  SignalBone(width: 64, height: 9),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainProgress extends StatelessWidget {
  const _MainProgress({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double width) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    final label = formatSpeed(l10n, speed);
    final percent = (item.progress * 100).clamp(0, 100).round();
    final running = item.status == DownloadStatus.downloading;
    final downloaded = _size(l10n, item.downloadedSize);
    final total = _size(l10n, item.totalSize);
    final thumb = _mainThumb(width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SignalThumb(
              url: item.thumbnailUrl,
              filePath: item.filePath,
              width: thumb.width,
              height: thumb.height,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleOf(item),
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
                  thumb.width < 168 ? 40 : 56,
                ).copyWith(color: colors.textPrimary, height: 0.9),
                children: [
                  TextSpan(
                    text: '%',
                    style: AppTypography.display(
                      thumb.width < 168 ? 20 : 28,
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
    return Row(
      children: [
        SignalThumb(
          url: item.thumbnailUrl,
          filePath: item.filePath,
          width: 56,
          height: 56,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleOf(item),
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
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

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
    final loading = ref.watch(
      downloadListProvider.select((v) => v.isLoading && !v.hasValue),
    );
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
          if (loading)
            SignalShimmer(
              child: Column(
                children: [
                  for (final f in const [0.8, 0.6, 0.7])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          const SignalBone(width: 18, height: 9),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: f,
                              child: const SignalBone(height: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else if (queued.isEmpty)
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
                      titleOf(queued[i]),
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

/// True while a search or a filter narrows the library.
final _signalFilteringProvider = Provider<bool>(
  (ref) =>
      ref.watch(downloadSearchQueryProvider).trim().isNotEmpty ||
      ref.watch(downloadStatusFilterProvider) != DownloadStatusFilter.all ||
      ref.watch(downloadSourceFilterProvider) != null ||
      ref.watch(signalKindFilterProvider) != null,
);

void _clearSignalFilters(WidgetRef ref) {
  ref.read(downloadSearchQueryProvider.notifier).state = '';
  ref.read(downloadStatusFilterProvider.notifier).state =
      DownloadStatusFilter.all;
  ref.read(downloadSourceFilterProvider.notifier).state = null;
  ref.read(signalKindFilterProvider.notifier).state = null;
}

class _LibraryHeader extends ConsumerStatefulWidget {
  const _LibraryHeader();

  @override
  ConsumerState<_LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends ConsumerState<_LibraryHeader> {
  @override
  void initState() {
    super.initState();
    // Back on the home with a search or a filter on: show its results.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(_signalFilteringProvider)) _reveal();
    });
  }

  /// Scrolls the library to the top so a search's results are in view.
  void _reveal() => Scrollable.ensureVisible(
    context,
    duration: signalMotion(context, 360),
    curve: signalEase,
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final kind = ref.watch(signalKindFilterProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final counts = ref.watch(downloadLibraryCountsProvider);
    final loading = ref.watch(
      downloadListProvider.select((v) => v.isLoading && !v.hasValue),
    );
    final shown = ref.watch(
      filteredDownloadsProvider.select((v) => v.valueOrNull?.length ?? 0),
    );
    void setKind(MediaKind? k) =>
        ref.read(signalKindFilterProvider.notifier).state = k;
    final kinds = [
      for (final (k, label) in [
        (null, l10n.designFilterAll),
        (MediaKind.video, l10n.designFilterVideo),
        (MediaKind.audio, l10n.designFilterAudio),
        (MediaKind.image, l10n.designFilterImages),
      ]) ...[
        const SizedBox(width: 8),
        SignalChip(label: label, selected: kind == k, onTap: () => setKind(k)),
      ],
    ];
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (s, label, n) in [
            (DownloadStatusFilter.active, l10n.sidebarActive, counts.active),
            (
              DownloadStatusFilter.completed,
              l10n.sidebarCompleted,
              counts.completed,
            ),
            (DownloadStatusFilter.failed, l10n.sidebarFailed, counts.failed),
          ]) ...[
            SignalChip(
              label: label,
              count: loading ? null : n,
              selected: status == s,
              onTap: () {
                ref.read(downloadSourceFilterProvider.notifier).state = null;
                ref.read(downloadStatusFilterProvider.notifier).state =
                    status == s ? DownloadStatusFilter.all : s;
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
                  ref.read(downloadStatusFilterProvider.notifier).state =
                      DownloadStatusFilter.all;
                  ref.read(downloadSourceFilterProvider.notifier).state =
                      source == entry.key ? null : entry.key;
                },
              ),
              const SizedBox(width: 8),
            ],
        ],
      ),
    );
    const search = SignalSearchField();
    const tools = [
      SizedBox(width: 8),
      _SortMenu(),
      SizedBox(width: 4),
      SignalMoreActions(),
    ];
    final title = [
      Text(
        l10n.librarySection,
        style: AppTypography.display(
          28,
          weight: FontWeight.w600,
        ).copyWith(color: colors.textPrimary),
      ),
      const SizedBox(width: 14),
      if (!loading)
        Text(
          '$shown',
          style: AppTypography.mono.copyWith(
            fontSize: 14,
            color: colors.textDisabled,
          ),
        ),
    ];
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: LayoutBuilder(
        builder: (context, c) {
          // Narrow (inspector open, small window): one control group a line.
          if (c.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: title),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: kinds.skip(1).toList()),
                ),
                const SizedBox(height: 10),
                filters,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: SizedBox(height: 36, child: search)),
                    ...tools,
                  ],
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [...title, const Spacer(), ...kinds]),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: filters),
                  const SizedBox(width: 12),
                  SizedBox(width: 260, height: 36, child: search),
                  ...tools,
                ],
              ),
            ],
          );
        },
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
    return SignalMaterial(
      child: PopupMenuButton<Object>(
        tooltip: l10n.sortAndView,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
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
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            Icons.sort_rounded,
            size: 17,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LibraryGrid extends ConsumerStatefulWidget {
  const _LibraryGrid({required this.columns});

  final int columns;

  @override
  ConsumerState<_LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends ConsumerState<_LibraryGrid>
    with SingleTickerProviderStateMixin {
  // The first rows rise in once, when the library first shows.
  static const _staggered = 12;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  late final List<CurvedAnimation> _rows = [
    for (var i = 0; i < _staggered; i++)
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(i * 0.04, i * 0.04 + 0.52, curve: signalEase),
      ),
  ];
  bool _played = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _entrance.dispose();
    super.dispose();
  }

  void _play() {
    _played = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrance.forward();
      });
    }
  }

  Widget _enter(int index, Widget child) {
    if (index >= _staggered) return child;
    final a = _rows[index];
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      downloadListProvider.select((v) => v.isLoading && !v.hasValue),
    );
    final grid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: widget.columns,
      mainAxisExtent: 74,
      crossAxisSpacing: 24,
      mainAxisSpacing: 4,
    );
    if (loading) {
      return SliverGrid(
        gridDelegate: grid,
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _RowBones(),
          childCount: 6,
        ),
      );
    }
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
      return const SliverToBoxAdapter(child: _NoResults());
    }
    if (!_played) _play();
    return SliverGrid(
      gridDelegate: grid,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _enter(
          index,
          _LibraryRow(itemId: items[index].id, base: items[index]),
        ),
        childCount: items.length,
      ),
    );
  }
}

/// A library row while the library loads.
class _RowBones extends StatelessWidget {
  const _RowBones();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: SignalShimmer(
      child: Row(
        children: [
          SignalBone(width: 88, height: 50, radius: 10),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: SignalBone(height: 12),
                ),
                SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.4,
                  child: SignalBone(height: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The search or the filters match nothing: say so and offer to clear them.
class _NoResults extends ConsumerWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final query = ref.watch(downloadSearchQueryProvider).trim();
    final ring = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        shape: BoxShape.circle,
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Icon(Icons.search_off_rounded, size: 24, color: colors.primary),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.signalNoResultsTitle,
          style: AppTypography.display(
            22,
            weight: FontWeight.w600,
          ).copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          query.isEmpty
              ? l10n.signalNoResultsFilters
              : l10n.signalNoResultsQuery(query),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ],
    );
    final button = SignalButton(
      label: l10n.signalClearFilters,
      icon: Icons.close_rounded,
      accent: false,
      height: 40,
      fontSize: 13.5,
      onTap: () => _clearSignalFilters(ref),
    );
    return SignalCard(
      padding: const EdgeInsets.all(28),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 560
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ring,
                  const SizedBox(height: 16),
                  text,
                  const SizedBox(height: 16),
                  button,
                ],
              )
            : Row(
                children: [
                  ring,
                  const SizedBox(width: 20),
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  button,
                ],
              ),
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
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item =
        ref.watch(downloadRuntimeItemProvider(widget.itemId)) ?? widget.base;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final notifier = ref.read(downloadListProvider.notifier);
    return DownloadItemContextMenu(
      item: item,
      child: SignalLibraryRow(
        item: item,
        selected: selected,
        onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
            selected ? null : item.id,
        onRetry: () => notifier.retryDownload(item),
        // A finished file leaves the disk too: ask first.
        onDelete: () async {
          if (await confirmFileDeletion(
            context,
            item,
            actionLabel: l10n.delete,
          )) {
            await notifier.deleteDownload(item.id);
          }
        },
      ),
    );
  }
}

/// Size strings from yt-dlp ("54.1MiB") in the app's units; empty if none.
String _size(AppLocalizations l10n, String raw) {
  final bytes = raw.isEmpty ? 0 : FormatUtils.parseBytes(raw);
  return bytes > 0 ? localBytes(l10n, bytes) : '';
}
