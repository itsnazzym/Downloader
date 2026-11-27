import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_row_host.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_top_bar.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../nocturne/nocturne_library.dart' show sizeLabel;
import '../shared/design_data.dart';
import 'oled_states.dart';
import 'oled_theme.dart';
import 'oled_widgets.dart';

/// Media type shown by the library tabs (Tout / Vidéo / Audio / Images).
final oledKindFilterProvider = StateProvider<MediaKind?>((ref) => null);

void _clearFilters(WidgetRef ref) {
  ref.read(downloadSearchQueryProvider.notifier).state = '';
  ref.read(downloadStatusFilterProvider.notifier).state =
      DownloadStatusFilter.all;
  ref.read(downloadSourceFilterProvider.notifier).state = null;
  ref.read(oledKindFilterProvider.notifier).state = null;
}

/// What the library is: still loading, unreadable, empty or filled.
enum _Phase { loading, error, empty, ready }

_Phase _phaseOf(AsyncValue<List<DownloadItem>> s) {
  if (s.hasValue) return s.requireValue.isEmpty ? _Phase.empty : _Phase.ready;
  return s.hasError ? _Phase.error : _Phase.loading;
}

/// OLED's home (mockup Main.dc.html): the link field, the download in
/// progress as a lit Doto figure over 40 dots, then the library (tabs,
/// today's search / sort / view bar, OLED rows). A selected row opens
/// today's inspector beside it, or in a sheet on narrow windows.
class OledHome extends ConsumerWidget {
  const OledHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDownloadIdProvider);
    final narrow = MediaQuery.sizeOf(context).width < 1000;
    ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
      if (!narrow || next == null || next == previous) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => OledTheme(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: DownloadInspector(downloadId: next),
          ),
        ),
      ).whenComplete(() {
        if (ref.read(selectedDownloadIdProvider) == next) {
          ref.read(selectedDownloadIdProvider.notifier).state = null;
        }
      });
    });
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              DownloadSearchFocus.request,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              DownloadSearchFocus.request,
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _Body()),
            if (selected != null && !narrow)
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: OledInk.line)),
                ),
                child: DownloadInspector(downloadId: selected),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase changes only: progress ticks never rebuild the page.
    final phase = ref.watch(downloadListProvider.select(_phaseOf));
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final side = wide ? 40.0 : 20.0;
        final link = Padding(
          padding: EdgeInsets.fromLTRB(side, 28, side, 28),
          child: const _LinkBar(),
        );
        if (phase == _Phase.empty || phase == _Phase.error) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              link,
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: KeyedSubtree(
                      key: OnboardingTargets.creatorList,
                      child: phase == _Phase.empty
                          ? const OledEmptyLibrary()
                          : OledLoadError(
                              error: ref.read(downloadListProvider).error ?? '',
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final loading = phase == _Phase.loading;
        if (!wide) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: link),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverToBoxAdapter(
                  child: loading ? const _HeroSkeleton() : const _Hero(),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 36, side, 0),
                sliver: const SliverToBoxAdapter(child: _LibraryHeader()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 32),
                sliver: _LibraryRows(loading: loading),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            link,
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsetsDirectional.only(end: 40),
                        decoration: const BoxDecoration(
                          border: BorderDirectional(
                            end: BorderSide(color: OledInk.line),
                          ),
                        ),
                        // The actions sit at the bottom of the column.
                        child: LayoutBuilder(
                          builder: (context, column) => SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (column.maxHeight - 32).clamp(
                                  0,
                                  double.infinity,
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: loading
                                    ? const _HeroSkeleton()
                                    : const _Hero(fill: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 7,
                      child: CustomScrollView(
                        slivers: [
                          const SliverToBoxAdapter(child: _LibraryHeader()),
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 32),
                            sliver: _LibraryRows(loading: loading),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── The link field ──────────────────────────────────────────────────────────

/// « Colle un lien… » and « Télécharger »: opens the new-download dialog
/// with the link in it (empty: the dialog alone).
class _LinkBar extends StatefulWidget {
  const _LinkBar();

  @override
  State<_LinkBar> createState() => _LinkBarState();
}

class _LinkBarState extends State<_LinkBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      openNewDownload(context);
      return;
    }
    _controller.clear();
    showDialog<void>(
      context: context,
      builder: (_) => AddDownloadDialog(initialUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: OledInk.edge),
    );
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              style: oledText(size: 15),
              cursorColor: OledInk.ion,
              decoration: InputDecoration(
                hintText: l10n.oledPasteHint,
                isDense: false,
                hintStyle: oledText(size: 15, color: OledInk.mute),
                filled: true,
                fillColor: OledInk.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                border: pill,
                enabledBorder: pill,
                focusedBorder: pill.copyWith(
                  borderSide: const BorderSide(color: OledInk.ink),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        KeyedSubtree(
          key: OnboardingTargets.newDownload,
          child: OledPill(
            label: l10n.designDownload,
            kind: OledPillKind.outline,
            height: 48,
            padding: 24,
            onTap: _submit,
          ),
        ),
      ],
    );
  }
}

// ── Hero: the download in progress ──────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero({this.fill = false});

  /// Beside the library: the actions sit at the bottom of the column.
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    // Live copies: this column is the only part that follows progress ticks.
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    final paused = [
      for (final i in items)
        if (i.status == DownloadStatus.paused) i,
    ];
    final queued = [
      for (final i in items)
        if (i.status == DownloadStatus.queued) i,
    ];
    final failed = items.where((i) => i.status == DownloadStatus.failed).length;
    final main = active.firstOrNull ?? paused.firstOrNull;
    final next = [
      ...active.skip(1),
      ...paused.where((p) => p != main),
      ...queued,
    ].firstOrNull;
    final notifier = ref.read(downloadListProvider.notifier);
    final progress = main?.progress.clamp(0.0, 1.0) ?? 0.0;
    final isPaused = main?.status == DownloadStatus.paused;

    final String eyebrow;
    if (main == null) {
      eyebrow = l10n.designInProgress;
    } else if (isPaused) {
      eyebrow = l10n.statusPaused;
    } else {
      eyebrow = l10n.oledActiveOf(1, active.length);
    }
    String meta() {
      if (main == null) {
        return failed > 0 ? '${l10n.sidebarFailed} · $failed' : '';
      }
      final speed = parseSpeed(main.speed);
      final phase = livePhase(main, speed);
      final done = sizeLabel(l10n, main.downloadedSize);
      final total = sizeLabel(l10n, main.totalSize);
      return [
        main.source,
        formatLabelOf(main),
        if (total.isNotEmpty) done.isEmpty ? total : '$done / $total',
        if (phase != null)
          livePhaseLabel(l10n, phase)
        else if (!isPaused && main.eta.isNotEmpty)
          l10n.oledEtaLeft(etaLabel(l10n, main.eta)),
      ].where((s) => s.isNotEmpty).join(' · ');
    }

    final lit = main != null && !isPaused;
    final percent = (progress * 100).floor();
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: oledEyebrow()),
        const SizedBox(height: 22),
        // The 168px figure shrinks with the column rather than overflow.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              text: '$percent',
              children: [
                TextSpan(
                  text: '%',
                  style: oledDoto(64, color: lit ? OledInk.ion : OledInk.ghost),
                ),
              ],
            ),
            style: oledDoto(
              168,
              color: lit ? OledInk.ion : OledInk.ghost,
              height: 0.85,
              glow: lit ? oledGlow(28) : null,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          main == null ? l10n.designNothingActive : titleOf(main),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: oledText(
            size: 24,
            weight: FontWeight.w600,
            height: 1.2,
            spacing: -0.24,
          ),
        ),
        if (meta().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: oledMono(color: main == null ? OledInk.err : OledInk.mute),
          ),
        ],
        const SizedBox(height: 22),
        OledDots(value: lit || isPaused ? progress : 0),
      ],
    );
    final bottom = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: main == null
              ? [
                  OledPill(
                    label: l10n.newDownload,
                    onTap: () => openNewDownload(context),
                  ),
                ]
              : [
                  OledPill(
                    label: isPaused ? l10n.resume : l10n.pause,
                    onTap: () => isPaused
                        ? notifier.resumeDownload(main.id)
                        : notifier.pauseDownload(main.id),
                  ),
                  OledPill(
                    label: l10n.cancel,
                    onTap: () => notifier.cancelDownload(main.id),
                  ),
                ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: OledInk.line)),
          ),
          child: Row(
            children: [
              Text(
                l10n.oledNext,
                style: oledText(size: 13, color: OledInk.mute),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  next == null ? l10n.designQueueEmpty : titleOf(next),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: oledText(
                    size: 13,
                    color: next == null ? OledInk.mute : OledInk.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        if (fill) const Spacer(),
        const SizedBox(height: 40),
        bottom,
      ],
    );
  }
}

/// The hero while the library loads: an unlit figure and unlit dots.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.designInProgress.toUpperCase(), style: oledEyebrow()),
        const SizedBox(height: 22),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('00', style: oledDoto(168, color: OledInk.unlit)),
        ),
        const SizedBox(height: 26),
        Container(
          width: 260,
          height: 14,
          decoration: BoxDecoration(
            color: OledInk.track,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 22),
        const OledDots(value: 0),
      ],
    );
  }
}

// ── Library ─────────────────────────────────────────────────────────────────

/// « Bibliothèque 8 070 », the kind / failed tabs, then today's search,
/// queue, sort-and-view and more-actions bar.
class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final list = ref.watch(downloadViewModeProvider) == DownloadViewMode.list;
    // Kinds narrow the list view only: elsewhere no kind is applied.
    final kind = list ? ref.watch(oledKindFilterProvider) : null;
    final failedOnly = status == DownloadStatusFilter.failed;
    void pick(MediaKind? k, {bool failed = false}) {
      ref.read(downloadSourceFilterProvider.notifier).state = null;
      ref.read(oledKindFilterProvider.notifier).state = k;
      ref.read(downloadStatusFilterProvider.notifier).state = failed
          ? DownloadStatusFilter.failed
          : DownloadStatusFilter.all;
    }

    final tabs = <Widget>[
      OledTextLink(
        label: l10n.designFilterAll,
        size: 13,
        selected: kind == null && status == DownloadStatusFilter.all,
        onTap: () => pick(null),
      ),
      // Kinds narrow the list view only (folders and cards are today's).
      if (list)
        for (final (k, label) in [
          (MediaKind.video, l10n.designFilterVideo),
          (MediaKind.audio, l10n.designFilterAudio),
          (MediaKind.image, l10n.designFilterImages),
        ])
          OledTextLink(
            label: label,
            size: 13,
            selected: kind == k && !failedOnly,
            onTap: () => pick(kind == k ? null : k),
          ),
      OledTextLink(
        label: l10n.sidebarFailed,
        size: 13,
        selected: failedOnly,
        trailing: TextSpan(
          text: '${counts.failed}',
          style: oledText(size: 13, color: OledInk.err),
        ),
        onTap: () => pick(null, failed: !failedOnly),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: OnboardingTargets.library,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [
              Text.rich(
                TextSpan(
                  text: l10n.librarySection,
                  children: [
                    TextSpan(text: '  ${counts.total}', style: oledMono()),
                  ],
                ),
                style: oledText(size: 15, weight: FontWeight.w600),
              ),
              Wrap(spacing: 18, runSpacing: 4, children: tabs),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Search (Ctrl+F), failed badge, queue, sort and view, more actions.
        DownloadTopBar(key: OnboardingTargets.topBar),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// The rows (list view, narrowed by the kind tab) as a sliver; folders and
/// detailed cards stay today's [DownloadList], drawn by OLED's skin.
class _LibraryRows extends ConsumerWidget {
  const _LibraryRows({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const SliverToBoxAdapter(child: OledRowsSkeleton());
    }
    final mode = ref.watch(downloadViewModeProvider);
    if (mode != DownloadViewMode.list) {
      final empty = ref.watch(
        filteredDownloadIdListProvider.select((l) => l.ids.isEmpty),
      );
      if (empty) return _noResults(ref);
      // Today's list scrolls itself inside a fixed window of the page.
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 640,
          child: DownloadList(key: OnboardingTargets.creatorList),
        ),
      );
    }
    final kind = ref.watch(oledKindFilterProvider);
    // Ids only: a row follows its own progress ticks.
    final ids = ref.watch(
      filteredDownloadsProvider.select(
        (v) => [
          for (final i in v.valueOrNull ?? const <DownloadItem>[])
            if (kind == null || mediaKindOf(i) == kind) i.id,
        ].join('\n'),
      ),
    );
    if (ids.isEmpty) return _noResults(ref);
    final list = ids.split('\n');
    return SliverList.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final row = DownloadRowHost(key: ValueKey(list[i]), id: list[i]);
        // The onboarding points at the list through its first row.
        return i == 0
            ? KeyedSubtree(key: OnboardingTargets.creatorList, child: row)
            : row;
      },
    );
  }

  Widget _noResults(WidgetRef ref) => SliverToBoxAdapter(
    child: KeyedSubtree(
      key: OnboardingTargets.creatorList,
      child: OledNoResults(onClear: () => _clearFilters(ref)),
    ),
  );
}
