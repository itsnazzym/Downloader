import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_list.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_more_actions_menu.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_context_menu.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'studio_inspector.dart';
import 'studio_states.dart';
import 'studio_widgets.dart';

/// Studio's home (mockup Studio.dc.html): the library as an editorial table.
/// Title + summary, search and « Coller un lien », then one white panel with
/// Titre / Source / Taille / État / Format columns. Folders and grid views,
/// and the empty/loading/error states, use today's list under the same header.
class StudioHome extends ConsumerWidget {
  const StudioHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Like today's view: under 620px beside the 220px sidebar, the inspector
    // opens as a bottom sheet instead of a side pane.
    final narrow = MediaQuery.sizeOf(context).width - 220 < 620;
    if (narrow) {
      ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
        if (next == null || next == previous) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: AppColors.of(context).surface,
          builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: StudioInspector(downloadId: next),
          ),
        ).whenComplete(() {
          if (ref.read(selectedDownloadIdProvider) == next) {
            ref.read(selectedDownloadIdProvider.notifier).state = null;
          }
        });
      });
    }
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
          children: [
            const Expanded(child: _Library()),
            if (!narrow) const _InspectorPane(),
          ],
        ),
      ),
    );
  }
}

// ── Page ────────────────────────────────────────────────────────────────────

class _Library extends ConsumerStatefulWidget {
  const _Library();

  @override
  ConsumerState<_Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<_Library> {
  // The table's rows rise in once per page opening, not each time a filter
  // or a view switch brings the table back.
  bool _entrancePlayed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listMode =
        ref.watch(downloadViewModeProvider) == DownloadViewMode.list;
    final phase = ref.watch(filteredDownloadListPhaseProvider);
    final query = ref.watch(downloadSearchQueryProvider);
    final filtered =
        query.isNotEmpty ||
        ref.watch(downloadStatusFilterProvider) != DownloadStatusFilter.all ||
        ref.watch(downloadSourceFilterProvider) != null;
    final failed = ref.watch(
      downloadListProvider.select(
        (v) => (v.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.failed)
            .length,
      ),
    );
    // One child per situation, cross-faded when the situation changes.
    final (String kind, Widget body) = switch (phase) {
      AsyncValue(hasValue: true, :final value) when value! > 0 =>
        listMode
            ? (
                'table',
                _Table(
                  animate: !_entrancePlayed,
                  onPlayed: () => _entrancePlayed = true,
                ),
              )
            : ('list', const DownloadList()),
      AsyncValue(hasValue: true) when filtered => (
        'noresults',
        _NoResults(query: query),
      ),
      AsyncValue(hasValue: true) => (
        'empty',
        StudioSituation(
          title: l10n.studioEmptyTitle,
          body: l10n.studioEmptyBody,
          actions: [
            StudioButton(
              label: l10n.studioPasteLink,
              icon: Icons.content_paste_rounded,
              onTap: () => _pasteLink(context),
            ),
          ],
        ),
      ),
      AsyncError(:final error) => (
        'error',
        StudioSituation(
          broken: true,
          title: l10n.studioLoadErrorTitle,
          body: l10n.studioLoadErrorBody,
          detail: downloadErrorReason('$error'),
          actions: [
            StudioButton(
              label: l10n.retry,
              icon: Icons.refresh_rounded,
              onTap: () =>
                  ref.read(downloadListProvider.notifier).refreshList(),
            ),
          ],
        ),
      ),
      _ => ('loading', const _TableSkeleton()),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 30, side, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(stacked: constraints.maxWidth < 900),
              const SizedBox(height: 24),
              if (failed >= 2 && kind == 'table') ...[
                _FailedStrip(count: failed),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: kind == 'list' ? 0 : 30),
                  child: KeyedSubtree(
                    key: OnboardingTargets.creatorList,
                    child: AnimatedSwitcher(
                      duration: studioMotion(context, 180),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: KeyedSubtree(key: ValueKey(kind), child: body),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// « 5 téléchargements ont échoué » and « Relancer les échecs (5) », above
/// the table when more than one failed.
class _FailedStrip extends ConsumerWidget {
  const _FailedStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.studioFailedCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: studioText(c, color: c.error),
            ),
          ),
          const SizedBox(width: 12),
          StudioButton(
            label: l10n.studioRetryFailed(count),
            icon: Icons.refresh_rounded,
            kind: StudioButtonKind.light,
            height: 32,
            onTap: () =>
                ref.read(downloadListProvider.notifier).retryAllFailed(),
          ),
        ],
      ),
    );
  }
}

/// A search or filter that matches nothing: the table's frame, the query
/// quoted, and one way back.
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    void reset() {
      ref.read(downloadSearchQueryProvider.notifier).state = '';
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: StudioPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(compact: constraints.maxWidth < 620),
              const StudioRule(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudioCap(l10n.studioItems(0)),
                    const SizedBox(height: 10),
                    Text(
                      query.isEmpty
                          ? l10n.noResults
                          : l10n.studioNoResultsFor(query),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: studioTitle(c, 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.studioNoResultsHint,
                      style: studioText(c, color: c.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    StudioButton(
                      label: l10n.clearSearchAndFilters,
                      icon: Icons.close_rounded,
                      kind: StudioButtonKind.light,
                      onTap: reset,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The table while the library loads: its real header over six rows of
/// shimmering bars in the columns' places.
class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();

  static const _titles = [0.62, 0.44, 0.7, 0.36, 0.55, 0.48];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Align(
          alignment: Alignment.topCenter,
          child: StudioPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderRow(compact: compact),
                StudioShimmer(
                  child: Column(
                    children: [
                      for (final f in _titles)
                        Container(
                          height: _rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppColors.of(context).borderSubtle,
                              ),
                            ),
                          ),
                          child: _Columns(
                            compact: compact,
                            title: LayoutBuilder(
                              builder: (context, box) => Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StudioBone(width: box.maxWidth * f),
                              ),
                            ),
                            source: const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StudioBone(width: 56),
                            ),
                            size: const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StudioBone(width: 44),
                            ),
                            state: const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StudioBone(width: 64),
                            ),
                            format: const Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: StudioBone(width: 28),
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
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (total, active) = ref.watch(
      downloadLibraryCountsProvider.select((v) => (v.total, v.active)),
    );
    // Finished files only, so progress ticks never change it.
    final bytes = ref.watch(
      downloadListProvider.select((v) {
        var sum = 0;
        for (final i in v.valueOrNull ?? const <DownloadItem>[]) {
          if (i.status == DownloadStatus.completed) sum += bytesOf(i);
        }
        return sum;
      }),
    );
    final loaded = ref.watch(
      downloadListProvider.select((v) => v.hasValue || v.hasError),
    );
    // While the library loads, a bar instead of a false « 0 élément ».
    final summary = !loaded
        ? const SizedBox(
            height: 22,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StudioShimmer(child: StudioBone(width: 120)),
            ),
          )
        : Text.rich(
            TextSpan(
              style: studioText(c, color: c.textSecondary),
              children: [
                TextSpan(text: l10n.studioItems(total)),
                if (bytes > 0) TextSpan(text: ' · ${localBytes(l10n, bytes)}'),
                if (active > 0) ...[
                  const TextSpan(text: ' · '),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: StudioRecDot(),
                  ),
                  TextSpan(
                    text: '  ${l10n.studioLiveCount(active)}',
                    style: studioText(c, size: 12, color: c.textSecondary),
                  ),
                ],
              ],
            ),
          );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.librarySection, style: studioTitle(c)),
        const SizedBox(height: 6),
        summary,
      ],
    );
    final controls = KeyedSubtree(
      key: OnboardingTargets.topBar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SortViewMenu(),
          const SizedBox(width: 8),
          const StudioThemed(
            child: DownloadMoreActionsMenu(
              showQueueActions: true,
              showRetryFailed: true,
              child: _MenuGlyph(Icons.more_horiz_rounded),
            ),
          ),
          const SizedBox(width: 16),
          const Flexible(child: SizedBox(width: 280, child: _SearchField())),
          const SizedBox(width: 16),
          KeyedSubtree(
            key: OnboardingTargets.newDownload,
            child: StudioButton(
              label: l10n.studioPasteLink,
              onTap: () => _pasteLink(context),
            ),
          ),
        ],
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 16), controls],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        const SizedBox(width: 16),
        controls,
      ],
    );
  }
}

/// « Coller un lien »: opens the new-download dialog with the clipboard's
/// link already in it when there is one.
Future<void> _pasteLink(BuildContext context) async {
  String? url;
  try {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null && ClipboardService.isSupportedUrl(text)) url = text;
  } catch (_) {}
  if (!context.mounted) return;
  if (url == null) {
    openNewDownload(context);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => AddDownloadDialog(initialUrl: url),
  );
}

/// White search box with a magnifier (Ctrl+F focuses it, Esc clears it).
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(downloadSearchQueryProvider),
  );
  final FocusNode _focus = FocusNode(debugLabel: 'studio-search');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    DownloadSearchFocus.attach(_focus);
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    DownloadSearchFocus.detach(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _set(String value) =>
      ref.read(downloadSearchQueryProvider.notifier).state = value;

  void _clear() {
    _controller.clear();
    _set('');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(downloadSearchQueryProvider, (_, next) {
      if (_controller.text != next) _controller.text = next;
    });
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _controller.text.isEmpty ? _focus.unfocus() : _clear(),
      },
      child: AnimatedContainer(
        duration: studioMotion(context, 160),
        height: 36,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focused ? c.textPrimary : c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 15, color: c.textDisabled),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: (v) {
                  _set(v);
                  setState(() {});
                },
                cursorColor: c.textPrimary,
                cursorHeight: 16,
                style: studioText(c),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l10n.search,
                  hintStyle: studioText(c, color: c.textDisabled),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: l10n.searchClear,
                onPressed: _clear,
                iconSize: 15,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: c.textDisabled),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Sort (date / name / size, and video count in folders; picking the current
/// one flips its direction) and view (list / grid / folders), as one menu.
class _SortViewMenu extends ConsumerWidget {
  const _SortViewMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final sort = ref.watch(downloadSortProvider);
    final mode = ref.watch(downloadViewModeProvider);
    final opened = ref.watch(openedCreatorFolderKeyProvider);
    final contents = ref.watch(folderContentsViewModeProvider);
    final insideFolder = mode == DownloadViewMode.folders && opened != null;

    void setSort(DownloadSort desc, DownloadSort asc) =>
        ref.read(downloadSortProvider.notifier).state = sort == desc
        ? asc
        : desc;

    void setMode(DownloadViewMode next) {
      if (insideFolder && next != DownloadViewMode.folders) {
        ref.read(folderContentsViewModeProvider.notifier).state = next;
        return;
      }
      ref.read(downloadViewModeProvider.notifier).state = next;
      ref.read(openedCreatorFolderKeyProvider.notifier).state = null;
      if (next != DownloadViewMode.folders &&
          (sort == DownloadSort.countDesc || sort == DownloadSort.countAsc)) {
        ref.read(downloadSortProvider.notifier).state = DownloadSort.dateDesc;
      }
    }

    PopupMenuItem<VoidCallback> sortItem(
      String label,
      DownloadSort desc,
      DownloadSort asc,
    ) {
      final on = sort == desc || sort == asc;
      return PopupMenuItem(
        value: () => setSort(desc, asc),
        height: 36,
        child: Row(
          children: [
            Icon(
              Icons.check_rounded,
              size: 16,
              color: on ? c.textPrimary : Colors.transparent,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: studioText(c))),
            Icon(
              sort == asc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: on ? c.textPrimary : c.textDisabled,
            ),
          ],
        ),
      );
    }

    PopupMenuItem<VoidCallback> modeItem(String label, DownloadViewMode m) {
      final current = insideFolder && m != DownloadViewMode.folders
          ? contents
          : mode;
      return CheckedPopupMenuItem(
        value: () => setMode(m),
        checked: current == m,
        height: 36,
        child: Text(label, style: studioText(c)),
      );
    }

    PopupMenuItem<VoidCallback> caption(String label) =>
        PopupMenuItem(enabled: false, height: 30, child: StudioCap(label));

    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.sortAndView,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        caption(l10n.sortBy),
        sortItem(
          l10n.sortFieldDate,
          DownloadSort.dateDesc,
          DownloadSort.dateAsc,
        ),
        sortItem(
          l10n.sortFieldName,
          DownloadSort.nameAsc,
          DownloadSort.nameDesc,
        ),
        sortItem(
          l10n.sortFieldSize,
          DownloadSort.sizeDesc,
          DownloadSort.sizeAsc,
        ),
        if (mode == DownloadViewMode.folders)
          sortItem(
            l10n.sortVideoCount,
            DownloadSort.countDesc,
            DownloadSort.countAsc,
          ),
        const PopupMenuDivider(),
        caption(l10n.viewMode),
        modeItem(l10n.viewList, DownloadViewMode.list),
        modeItem(l10n.viewDetailed, DownloadViewMode.detailed),
        modeItem(l10n.viewFolders, DownloadViewMode.folders),
      ],
      child: const _MenuGlyph(Icons.sort_rounded),
    );
  }
}

/// The ringed 36px square a toolbar menu opens from.
class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, size: 16, color: c.textSecondary),
    );
  }
}

// ── Table ───────────────────────────────────────────────────────────────────

const double _headerHeight = 41;
const double _rowHeight = 42;
const double _lineRowHeight = 52;

/// A row draws its progress line while the bytes are (or were) flowing.
bool _hasLine(DownloadItem item) =>
    isActiveDownload(item) || item.status == DownloadStatus.paused;

class _Table extends ConsumerStatefulWidget {
  const _Table({required this.animate, required this.onPlayed});

  final bool animate;
  final VoidCallback onPlayed;

  @override
  ConsumerState<_Table> createState() => _TableState();
}

/// Rows that rise in when the table opens.
const int _entranceRows = 12;
const int _entranceStepMs = 30;
const int _entranceRowMs = 280;

class _TableState extends ConsumerState<_Table>
    with SingleTickerProviderStateMixin {
  // Played once per opening: rows scrolled in or refiltered later find it
  // finished.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: _entranceStepMs * (_entranceRows - 1) + _entranceRowMs,
      ),
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
      widget.onPlayed();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _rise(int i) {
    if (i >= _entranceRows) return kAlwaysCompleteAnimation;
    final total = _entrance.duration!.inMilliseconds;
    final start = i * _entranceStepMs / total;
    return _entrance.drive(
      CurveTween(
        curve: Interval(
          start,
          start + _entranceRowMs / total,
          curve: studioEase,
        ),
      ),
    );
  }

  Widget _entering(int i, Widget row) {
    final t = _rise(i);
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: row,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Ids and which rows carry a line: both change with status, not progress.
    final rows = ref.watch(
      filteredDownloadsProvider.select((v) {
        final items = v.valueOrNull ?? const <DownloadItem>[];
        return _Rows([for (final i in items) (i.id, _hasLine(i))]);
      }),
    );
    // Drag indices map onto the stored order only when the table shows the
    // whole library in that order (oldest first, no filter), like today's list.
    final reorder =
        ref.watch(downloadSearchQueryProvider).isEmpty &&
        ref.watch(downloadStatusFilterProvider) == DownloadStatusFilter.all &&
        ref.watch(downloadSourceFilterProvider) == null &&
        ref.watch(downloadSortProvider) == DownloadSort.dateAsc &&
        rows.list.length <= 50;
    double? extent(int i, _) => i < rows.list.length
        ? (rows.list[i].$2 ? _lineRowHeight : _rowHeight)
        : _rowHeight;
    final height =
        _headerHeight +
        rows.list.fold<double>(
          0,
          (sum, r) => sum + (r.$2 ? _lineRowHeight : _rowHeight),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: height.clamp(0, constraints.maxHeight),
            clipBehavior: Clip.antiAlias,
            decoration: studioPanelDecoration(c),
            child: Column(
              children: [
                _HeaderRow(compact: compact),
                Expanded(
                  child: reorder
                      // Long-press a row to move it, as today's list allows.
                      ? ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: rows.list.length,
                          itemExtentBuilder: extent,
                          onReorderItem: ref
                              .read(downloadListProvider.notifier)
                              .reorder,
                          itemBuilder: (context, i) =>
                              ReorderableDelayedDragStartListener(
                                key: ValueKey(rows.list[i].$1),
                                index: i,
                                child: _entering(
                                  i,
                                  _Row(id: rows.list[i].$1, compact: compact),
                                ),
                              ),
                        )
                      : ListView.builder(
                          itemCount: rows.list.length,
                          itemExtentBuilder: extent,
                          itemBuilder: (context, i) => KeyedSubtree(
                            key: ValueKey(rows.list[i].$1),
                            child: _entering(
                              i,
                              _Row(id: rows.list[i].$1, compact: compact),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Value-equal list of (id, hasLine) so the table only rebuilds on changes.
class _Rows {
  const _Rows(this.list);

  final List<(String, bool)> list;

  @override
  bool operator ==(Object other) {
    if (other is! _Rows || other.list.length != list.length) return false;
    for (var i = 0; i < list.length; i++) {
      if (other.list[i] != list[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(list);
}

/// The five columns: the title takes what is left.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.compact,
    required this.title,
    required this.source,
    required this.size,
    required this.state,
    required this.format,
  });

  final bool compact;
  final Widget title;
  final Widget source;
  final Widget size;
  final Widget state;
  final Widget format;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: title),
        if (!compact) ...[
          const SizedBox(width: 16),
          SizedBox(width: 110, child: source),
        ],
        const SizedBox(width: 16),
        SizedBox(width: 90, child: size),
        const SizedBox(width: 16),
        SizedBox(width: 130, child: state),
        if (!compact) ...[
          const SizedBox(width: 16),
          SizedBox(width: 70, child: format),
        ],
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: _Columns(
        compact: compact,
        title: StudioCap(l10n.title),
        source: StudioCap(l10n.detailsInfoSource),
        size: StudioCap(l10n.detailsInfoSize),
        state: StudioCap(l10n.studioColState),
        // No « Ajouté »: downloads carry no date, so the file format instead.
        format: StudioCap(l10n.formatLabel, textAlign: TextAlign.end),
      ),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({required this.id, required this.compact});

  final String id;
  final bool compact;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  /// The finish moment, created the first time this row completes.
  AnimationController? _done;

  void _celebrate() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    (_done ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )).forward(from: 0);
  }

  @override
  void dispose() {
    _done?.dispose();
    super.dispose();
  }

  void _play(DownloadItem item) {
    final path = item.filePath;
    if (path != null && File(path).existsSync()) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    }
  }

  Future<void> _retry(DownloadItem item) async {
    final notifier = ref.read(downloadListProvider.notifier);
    if (!await confirmFileDeletion(
      context,
      item,
      actionLabel: context.l10n.restartDownload,
    )) {
      return;
    }
    await notifier.retryDownload(item);
  }

  @override
  Widget build(BuildContext context) {
    // Live -> done on this row's own item: the recording dot becomes a check.
    ref.listen<DownloadItem?>(downloadItemByIdProvider(widget.id), (
      previous,
      next,
    ) {
      if (previous != null &&
          isActiveDownload(previous) &&
          next?.status == DownloadStatus.completed) {
        _celebrate();
      }
    });
    final item = ref.watch(downloadItemByIdProvider(widget.id));
    if (item == null) return const SizedBox.shrink();
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final reason = failed ? downloadErrorReason(item.error) : '';
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final selected = ref.watch(
      selectedDownloadIdProvider.select((id) => id == item.id),
    );
    final line = _hasLine(item);
    final secondary = studioText(c, color: c.textSecondary);
    return DownloadItemContextMenu(
      item: item,
      child: Material(
        color: selected
            ? Color.lerp(c.surface, c.surfaceHighlight, 0.6)
            : (_hover ? studioHover(c) : c.surface),
        child: InkWell(
          onTap: () => ref.read(selectedDownloadIdProvider.notifier).state =
              selected ? null : item.id,
          onDoubleTap: () => _play(item),
          onHover: (v) => setState(() => _hover = v),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: c.surfaceHighlight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.borderSubtle)),
            ),
            child: _Columns(
              compact: widget.compact,
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: StudioUnderline(
                          text: titleOf(item),
                          hover: _hover,
                          style: studioText(
                            c,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Why it failed, short, beside the title.
                      if (reason.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 2,
                          child: Text(
                            reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: studioText(c, size: 12, color: c.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (line) ...[
                    const SizedBox(height: 8),
                    StudioLine(value: item.progress),
                  ],
                ],
              ),
              source: Text(
                item.source.isEmpty ? '—' : item.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: secondary,
              ),
              size: _cell(Text(_sizeLabel(l10n, item), style: studioMono(c))),
              state: _State(
                item: item,
                reason: reason,
                done: _done,
                onRetry: () => _retry(item),
              ),
              format: Text(
                formatLabelOf(item),
                textAlign: TextAlign.end,
                maxLines: 1,
                style: studioMono(c, color: c.textDisabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _cell(Widget child) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}

/// État: a blinking red dot with percent and speed while live, plain words
/// otherwise, « Échec · Réessayer » in red when it failed.
class _State extends StatelessWidget {
  const _State({
    required this.item,
    required this.reason,
    required this.done,
    required this.onRetry,
  });

  final DownloadItem item;
  final String reason;
  final Animation<double>? done;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final pill = studioText(c, size: 12, color: c.textSecondary);
    switch (item.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.extracting:
      case DownloadStatus.processing:
        final speed = parseSpeed(item.speed);
        final phase = livePhase(item, speed);
        final percent = (item.progress * 100).clamp(0, 100).round();
        final rate = formatSpeed(l10n, speed);
        final text = phase != null
            ? livePhaseLabel(l10n, phase)
            : speed == null
            ? '$percent %'
            : '$percent % · ${rate.value} ${rate.unit}';
        return Row(
          children: [
            const StudioRecDot(),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(text, style: studioMono(c, size: 12)),
              ),
            ),
          ],
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        final red = pill.copyWith(color: c.error);
        return Row(
          children: [
            Text('${l10n.designFailed} · ', style: red),
            Flexible(
              child: Tooltip(
                message: reason,
                child: InkWell(
                  onTap: onRetry,
                  child: Text(
                    l10n.retry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: red.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: c.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case DownloadStatus.queued:
        return Text(l10n.statusQueued, style: pill);
      case DownloadStatus.paused:
        return Text(
          '${l10n.statusPaused} · ${(item.progress * 100).round()} %',
          style: pill,
        );
      case DownloadStatus.completed:
        final done = this.done;
        if (done != null) {
          return _DoneMark(animation: done, label: l10n.statusCompleted);
        }
        return Text(l10n.statusCompleted, style: pill);
      case DownloadStatus.duplicate:
        return Text(l10n.statusDuplicate, style: pill);
    }
  }
}

/// The finish moment (900 ms): the red recording dot shrinks away as an ink
/// check stamps in, an ink underline sweeps under « Terminé », then check
/// and underline fade and the cell settles to its plain resting look.
class _DoneMark extends StatelessWidget {
  const _DoneMark({required this.animation, required this.label});

  final Animation<double> animation;
  final String label;

  static double _at(double t, double a, double b, [Curve curve = studioEase]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final dotOut = _at(t, 0, 0.3);
          final checkIn = _at(t, 0.12, 0.42, Curves.easeOutBack);
          final sweep = _at(t, 0.35, 0.75);
          final settle = _at(t, 0.8, 1);
          return Row(
            children: [
              SizedBox(
                width: 19 * (1 - settle),
                height: 14,
                child: OverflowBox(
                  maxWidth: 19,
                  alignment: AlignmentDirectional.centerStart,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 1 - dotOut,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: (1 - settle) * checkIn.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: checkIn,
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: studioText(
                          c,
                          size: 12,
                          color: Color.lerp(
                            c.textPrimary,
                            c.textSecondary,
                            settle,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: sweep,
                          child: Container(
                            height: 1,
                            color: c.textPrimary.withValues(alpha: 1 - settle),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "3,8 / 6,1 Go" while live (the unit once when both share it), the file
/// size when done, "—" when unknown.
String _sizeLabel(AppLocalizations l10n, DownloadItem item) {
  if (_hasLine(item)) {
    final done = FormatUtils.parseBytes(item.downloadedSize);
    final total = FormatUtils.parseBytes(item.totalSize);
    if (total > 0) {
      final a = localBytes(l10n, done);
      final b = localBytes(l10n, total);
      final unitA = a.split(' ').last;
      final unitB = b.split(' ').last;
      final head = unitA == unitB ? a.substring(0, a.lastIndexOf(' ')) : a;
      return done > 0 ? '$head / $b' : b;
    }
  }
  final bytes = bytesOf(item);
  return bytes > 0 ? localBytes(l10n, bytes) : '—';
}

// ── Inspector ───────────────────────────────────────────────────────────────

/// Today's inspector pane: resizable from its leading edge, collapsible to a
/// rail, its width saved.
class _InspectorPane extends ConsumerWidget {
  const _InspectorPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedDownloadIdProvider);
    if (selectedId == null) return const SizedBox.shrink();
    final layout = ref.watch(paneLayoutProvider);
    final pane = ref.read(paneLayoutProvider.notifier);
    return ResizableWidthPane(
      width: layout.visibleInspectorWidth,
      minWidth: PaneLayout.inspectorRail,
      maxWidth: PaneLayout.inspectorMax,
      contentMinWidth: PaneLayout.inspectorMin,
      resizeFrom: PaneResizeFrom.leading,
      onWidthChanged: pane.setInspectorWidth,
      onDragActive: (active) =>
          ref.read(paneResizeActiveProvider.notifier).state = active,
      onResizeEnd: () {
        ref.read(paneResizeActiveProvider.notifier).state = false;
        pane.commitInspectorDrag();
        pane.persist();
      },
      onToggleCollapse: () {
        pane.toggleInspectorCollapsed();
        pane.persist();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: AppColors.of(context).border),
          ),
        ),
        child: layout.inspectorCollapsed
            ? StudioInspectorRail(
                onExpand: () {
                  pane.expandInspector();
                  pane.persist();
                },
              )
            : StudioInspector(downloadId: selectedId),
      ),
    );
  }
}

// ── Shared library rows (grid and folders), drawn by Studio ────────────────

/// [DesignSkin.row]: the detailed grid's cards and the folders' rows, in the
/// table's language (title with its growing underline, mono size, the same
/// État cell, the thin ink line), with retry / delete (they ask first) and
/// the age-check help where the shared row has them.
Widget studioRow(BuildContext context, DesignRow row) => _SkinRow(row: row);

class _SkinRow extends ConsumerStatefulWidget {
  const _SkinRow({required this.row});

  final DesignRow row;

  @override
  ConsumerState<_SkinRow> createState() => _SkinRowState();
}

class _SkinRowState extends ConsumerState<_SkinRow> {
  bool _hover = false;

  void _play(DownloadItem item) {
    final path = item.filePath;
    if (path != null && File(path).existsSync()) {
      ref.read(mediaPlayerProvider.notifier).openFile(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final item = row.item;
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final failed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.canceled;
    final reason = failed ? downloadErrorReason(item.error) : '';
    final age =
        item.status == DownloadStatus.failed &&
        DownloadStatusGuard.isAgeVerificationFailure(
          error: item.error,
          url: item.request.url,
        );
    final ended = failed || item.status == DownloadStatus.completed;
    final actions = AnimatedOpacity(
      duration: studioMotion(context, 160),
      opacity: _hover || row.isSelected ? 1 : 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (age) ...[
            StudioIconButton(
              icon: Icons.shield_outlined,
              tooltip: l10n.ageCheckSeeSolutions,
              onTap: () => AgeVerificationHelpDialog.show(context, item),
            ),
            const SizedBox(width: 6),
          ],
          if (ended) ...[
            StudioIconButton(
              icon: Icons.refresh_rounded,
              tooltip: l10n.retryDownload,
              onTap: row.onRetry,
            ),
            const SizedBox(width: 6),
            StudioIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.remove,
              onTap: row.onCancel,
            ),
          ],
        ],
      ),
    );
    final title = StudioUnderline(
      text: titleOf(item),
      hover: _hover,
      style: studioText(c).copyWith(fontWeight: FontWeight.w500),
    );
    // Why it failed, else where it comes from and its format.
    final note = Text(
      reason.isNotEmpty
          ? reason
          : '${item.source.isEmpty ? '—' : item.source} · ${formatLabelOf(item)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: studioText(
        c,
        size: 12,
        color: reason.isNotEmpty ? c.error : c.textSecondary,
      ),
    );
    final state = _State(
      item: item,
      reason: reason,
      done: null,
      onRetry: row.onRetry,
    );
    final size = Text(
      _sizeLabel(l10n, item),
      maxLines: 1,
      style: studioMono(c, size: 12),
    );
    final line = _hasLine(item) ? StudioLine(value: item.progress) : null;
    final Widget body;
    if (row.grid) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                StudioThumb(item: item, radius: 0),
                PositionedDirectional(top: 10, end: 10, child: actions),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 4),
                note,
                const SizedBox(height: 12),
                if (line != null) ...[line, const SizedBox(height: 10)],
                Row(
                  children: [
                    Expanded(flex: 3, child: state),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(fit: BoxFit.scaleDown, child: size),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 64, height: 36, child: StudioThumb(item: item)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 3),
                  note,
                  if (line != null) ...[const SizedBox(height: 7), line],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 90, child: size),
            const SizedBox(width: 16),
            SizedBox(width: 130, child: state),
            const SizedBox(width: 8),
            actions,
          ],
        ),
      );
    }
    final radius = BorderRadius.circular(row.grid ? 12 : 10);
    return AnimatedContainer(
      duration: studioMotion(context, 180),
      curve: studioEase,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: row.isSelected
            ? Color.lerp(c.surface, c.surfaceHighlight, 0.6)
            : (_hover ? studioHover(c) : c.surface),
        borderRadius: radius,
        border: Border.all(
          color: row.isSelected
              ? c.textPrimary
              : (_hover ? const Color(0xFFD6D3CD) : c.border),
          width: row.isSelected ? 1.5 : 1,
        ),
        boxShadow: _hover || row.isSelected
            ? [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.07),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: row.onTap,
          onDoubleTap: () => _play(item),
          onHover: (v) => setState(() => _hover = v),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: c.surfaceHighlight,
          child: body,
        ),
      ),
    );
  }
}
