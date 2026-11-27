import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/utils/browser_launch.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'signal_controls.dart';
import 'signal_states.dart';
import 'signal_widgets.dart';

// ── Video row ───────────────────────────────────────────────────────────────

/// One archived TikTok video in Signal: check box, preview tile, date title
/// and id, favourite / like / collection pills, and on hover copy link,
/// open in the browser and Télécharger. Clicking the row selects it.
class SignalVideoRow extends StatefulWidget {
  const SignalVideoRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggleSelect,
    required this.onDownload,
  });

  final TikTokArchiveItem item;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDownload;

  @override
  State<SignalVideoRow> createState() => _SignalVideoRowState();
}

class _SignalVideoRowState extends State<SignalVideoRow> {
  bool _hover = false;
  bool _focus = false;

  // The demo shows bundled, licensed stills instead of a user's thumbnails.
  static const _demoFilms = [
    'Sintel',
    'Tears of Steel',
    'Elephants Dream',
    'Big Buck Bunny',
  ];
  static const _demoArt = [
    'sintel.jpg',
    'tears-of-steel.jpg',
    'elephants-dream.jpg',
    'big-buck-bunny.png',
  ];

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _open(String url) async {
    if (Uri.tryParse(url)?.host.endsWith('.invalid') == true) return;
    await openInBrowser(url);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = widget.item;
    final on = widget.selected;
    final demo = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demoIndex = demo == null ? null : (demo - 1) % 4;
    final actions = _hover || _focus;
    return Semantics(
      selected: on,
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggleSelect();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onToggleSelect,
          child: AnimatedContainer(
            duration: signalMotion(context, 180),
            curve: signalEase,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: on
                  ? Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.06),
                      colors.surface,
                    )
                  : (_hover ? colors.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: on || _focus
                    ? colors.primary.withValues(alpha: _focus ? 1 : 0.6)
                    : colors.textPrimary.withValues(
                        alpha: _hover ? 0.12 : 0.07,
                      ),
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SignalCheck(value: on),
                const SizedBox(width: 14),
                if (demoIndex != null)
                  SignalThumb(
                    url: 'assets/showcase/${_demoArt[demoIndex]}',
                    width: 48,
                    height: 48,
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              demoIndex == null
                                  ? l10n.archiveVideoTitle(_date(item.date))
                                  : '${_demoFilms[demoIndex]} · '
                                        '${(demo! - 1) ~/ 4 + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.id,
                            style: AppTypography.mono.copyWith(
                              fontSize: 11.5,
                              color: colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.isFavorite)
                            _Pill(
                              icon: Icons.bookmark_rounded,
                              label: l10n.signalArchiveFavorite,
                              tone: colors.primary,
                            ),
                          if (item.isLiked)
                            _Pill(
                              icon: Icons.favorite_rounded,
                              label: l10n.signalArchiveLiked,
                              tone: colors.error,
                            ),
                          if (item.collectionName != null)
                            _Pill(
                              icon: Icons.folder_outlined,
                              label: item.collectionName!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: actions ? 1 : 0,
                  duration: signalMotion(context, 160),
                  child: IgnorePointer(
                    ignoring: !actions,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SignalIconButton(
                          icon: Icons.link_rounded,
                          tooltip: l10n.detailsCopyLink,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.url));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(l10n.urlCopied),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                          },
                        ),
                        SignalIconButton(
                          icon: Icons.open_in_new_rounded,
                          tooltip: l10n.signalArchiveOpenInBrowser,
                          onTap: () => _open(item.url),
                        ),
                        const SizedBox(width: 6),
                        SignalButton(
                          label: l10n.archiveMobileDownload,
                          icon: Icons.download_rounded,
                          height: 34,
                          fontSize: 12.5,
                          onTap: widget.onDownload,
                        ),
                      ],
                    ),
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

/// Hairline pill with a small icon (favourite, like, collection).
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tone ?? colors.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                fontSize: 11.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter pane ─────────────────────────────────────────────────────────────

/// The archive's filters as a Signal card: type (all, favourites, likes),
/// year with counts, then the collections with a search; Réinitialiser
/// clears the type, year, collection and selection, as today's pane does.
class SignalFilterPane extends ConsumerStatefulWidget {
  const SignalFilterPane({super.key});

  @override
  ConsumerState<SignalFilterPane> createState() => _SignalFilterPaneState();
}

class _SignalFilterPaneState extends ConsumerState<SignalFilterPane> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    if (catalog == null) return const SizedBox.shrink();
    final filter = state.filter;
    final n = ref.read(tikTokArchiveProvider.notifier);
    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final query = _search.text.toLowerCase();
    final collections = [
      for (final c in catalog.collections)
        if (c.name.toLowerCase().contains(query)) c,
    ];
    Widget label(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: SignalEyebrow(text)),
          ?trailing,
        ],
      ),
    );
    return SizedBox(
      width: 272,
      child: SignalCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.archiveMobileFilters,
                    style: AppTypography.display(
                      20,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary),
                  ),
                ),
                _Link(
                  label: l10n.archiveMobileReset,
                  onTap: () {
                    n.selectYear(null);
                    n.selectCollection(null);
                    n.setStatusFilter(TikTokStatusFilter.all);
                    n.clearSelection();
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            label(l10n.archiveMobileType),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (f, text) in [
                  (TikTokStatusFilter.all, l10n.archiveMobileFilterAll),
                  (
                    TikTokStatusFilter.favoritesOnly,
                    l10n.archiveMobileFilterFavorites,
                  ),
                  (TikTokStatusFilter.likesOnly, l10n.archiveMobileFilterLikes),
                ])
                  SignalChip(
                    label: text,
                    selected: filter.statusFilter == f,
                    onTap: () => n.setStatusFilter(f),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            label(l10n.archiveMobileYear),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SignalChip(
                  label: l10n.archiveMobileAllYears,
                  selected: filter.selectedYear == null,
                  onTap: () => n.selectYear(null),
                ),
                for (final y in years)
                  SignalChip(
                    label: '$y',
                    count: catalog.yearCounts[y],
                    selected: filter.selectedYear == y,
                    onTap: () =>
                        n.selectYear(filter.selectedYear == y ? null : y),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            label(
              '${l10n.signalArchiveCollectionsTab} (${catalog.collections.length})',
              trailing: filter.selectedCollection == null
                  ? null
                  : _Link(
                      label: l10n.archiveMobileReset,
                      onTap: () => n.selectCollection(null),
                    ),
            ),
            SignalInset(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              height: 38,
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 15,
                    color: colors.textDisabled,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      cursorColor: colors.primary,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                      decoration: signalBareInput(
                        context,
                        l10n.signalArchiveSearchCollection,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: collections.length,
                itemBuilder: (context, i) {
                  final c = collections[i];
                  final on = filter.selectedCollection == c.name;
                  return _CollectionLine(
                    name: c.name,
                    count: c.videoCount,
                    selected: on,
                    onTap: () => n.selectCollection(on ? null : c.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionLine extends StatefulWidget {
  const _CollectionLine({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CollectionLine> createState() => _CollectionLineState();
}

class _CollectionLineState extends State<_CollectionLine> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final fg = on ? colors.background : colors.textPrimary;
    return Semantics(
      selected: on,
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: signalMotion(context, 160),
            height: 38,
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on
                  ? colors.textPrimary
                  : (_hover ? colors.surfaceHighlight : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              border: _focus
                  ? Border.all(color: colors.primary, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 15,
                  color: on ? colors.background : colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(fontSize: 13, color: fg),
                  ),
                ),
                Text(
                  '${widget.count}',
                  style: AppTypography.mono.copyWith(
                    fontSize: 11.5,
                    color: fg.withValues(alpha: 0.6),
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

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: colors.primary.withValues(alpha: 0.25),
        hoverColor: colors.surfaceHighlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              fontSize: 12.5,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hub (import and sync) ───────────────────────────────────────────────────

/// While the archive loads: the archive card and rows as bones.
class SignalArchiveLoading extends StatelessWidget {
  const SignalArchiveLoading({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Padding(
      padding: signalPagePadding(c.maxWidth),
      child: const SignalShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SignalBone(height: 140, radius: 20),
            SizedBox(height: 24),
            SignalBone(height: 72, radius: 16),
            SizedBox(height: 8),
            SignalBone(height: 72, radius: 16),
            SizedBox(height: 8),
            SignalBone(height: 72, radius: 16),
          ],
        ),
      ),
    ),
  );
}

/// Import the TikTok export or sync through the browser extension, with
/// the sync's progress and result; « Ouvrir » goes back to the archive.
class SignalArchiveHub extends ConsumerWidget {
  const SignalArchiveHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final n = ref.read(tikTokArchiveProvider.notifier);
    final showcase = ref.watch(showcaseModeProvider);
    final connected =
        !showcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final syncing = state.syncStatus == TikTokSyncStatus.waiting;
    final catalog = state.catalog;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: signalPagePadding(c.maxWidth),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.archiveMobileTitle,
                  style: AppTypography.display(
                    32,
                    weight: FontWeight.w600,
                  ).copyWith(color: colors.textPrimary, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.archiveDeskIntro,
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (state.hasCatalog && catalog != null) ...[
                  const SizedBox(height: 20),
                  SignalCard(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.archiveMobileVideoCount(catalog.videos.length)}'
                            ' · '
                            '${l10n.archiveHubCollections(catalog.collections.length)}',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SignalButton(
                          label: l10n.archiveHubOpen,
                          icon: Icons.arrow_forward_rounded,
                          height: 38,
                          fontSize: 13,
                          onTap: () =>
                              n.setViewMode(TikTokViewMode.collections),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _Notice(message: state.errorMessage!, tone: colors.error),
                ],
                const SizedBox(height: 20),
                _HubSection(
                  icon: Icons.folder_open_outlined,
                  title: l10n.archiveDeskImportTitle,
                  body: l10n.archiveDeskImportBody,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SignalButton(
                      label: l10n.archiveDeskPickJson,
                      icon: Icons.file_open_outlined,
                      onTap: showcase ? null : n.pickAndImportFile,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _HubSection(
                  icon: Icons.sync_rounded,
                  title: l10n.archiveDeskSyncTitle,
                  body: connected
                      ? l10n.archiveDeskSyncConnected
                      : l10n.archiveDeskSyncDisconnected,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SignalButton(
                          label: syncing
                              ? l10n.archiveDeskSyncing
                              : l10n.archiveDeskSyncAction,
                          icon: Icons.sync_rounded,
                          accent: false,
                          onTap: !showcase && connected && !syncing
                              ? n.triggerExtensionSync
                              : null,
                        ),
                      ),
                      if (syncing) ...[
                        const SizedBox(height: 14),
                        const SignalPulseBar(),
                        const SizedBox(height: 8),
                        Text(
                          l10n.archiveMobileSyncWaiting,
                          style: AppTypography.body.copyWith(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ] else if (state.syncMessage != null) ...[
                        const SizedBox(height: 14),
                        _Notice(
                          message: state.syncMessage!,
                          tone: switch (state.syncStatus) {
                            TikTokSyncStatus.failed => colors.error,
                            TikTokSyncStatus.partial => colors.warning,
                            _ => colors.primary,
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.archiveDeskSyncManual,
                  style: AppTypography.body.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                    color: colors.textDisabled,
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

class _HubSection extends StatelessWidget {
  const _HubSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SignalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(icon, size: 16, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.display(
                    20,
                    weight: FontWeight.w600,
                  ).copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppTypography.body.copyWith(
              fontSize: 13.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tone.withValues(alpha: 0.3)),
    ),
    child: Text(
      message,
      style: AppTypography.body.copyWith(fontSize: 13, color: tone),
    ),
  );
}

/// An indeterminate 6px Signal meter (sync waiting for the browser).
class SignalPulseBar extends StatefulWidget {
  const SignalPulseBar({super.key});

  @override
  State<SignalPulseBar> createState() => _SignalPulseBarState();
}

class _SignalPulseBarState extends State<SignalPulseBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => FractionallySizedBox(
          alignment: Alignment(-1 + 2 * _c.value, 0),
          widthFactor: 0.3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
