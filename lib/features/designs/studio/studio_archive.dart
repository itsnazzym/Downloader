import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/desktop/tiktok_archive_desktop_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'studio_widgets.dart';

/// Studio's TikTok archive (mockup Studio-Archives.dc.html): « Archive locale
/// · TikTok », the archive's counts, Synchroniser / Tout télécharger and the
/// Vidéos / Collections / Favoris tabs over today's archive views. Loading,
/// the import hub and an empty archive keep today's view.
class StudioArchive extends ConsumerWidget {
  const StudioArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (loading, hub, hasCatalog, mode, favorites) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.isLoading,
          s.viewMode == TikTokViewMode.hub,
          s.hasCatalog,
          s.viewMode,
          s.filter.statusFilter == TikTokStatusFilter.favoritesOnly,
        ),
      ),
    );
    if (loading || hub || !hasCatalog) return current;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 30, side, 14),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: _Header(mode: mode, favorites: favorites),
                ),
              ),
            ),
            Expanded(
              child: mode == TikTokViewMode.collections
                  ? TikTokCollectionsView(catalog: catalog)
                  : TikTokArchiveDesktopView(catalog: catalog),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.mode, required this.favorites});

  final TikTokViewMode mode;
  final bool favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final catalog = ref.watch(tikTokArchiveProvider.select((s) => s.catalog!));
    final batch = ref.watch(
      tikTokArchiveProvider.select((s) => s.isBatchDownloading),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final pending = [
      for (final v in catalog.videos)
        if (!v.isDownloaded) v,
    ];

    Future<void> downloadAll() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.studioDownloadAll),
          content: Text(l10n.studioDownloadAllConfirm(pending.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok == true) {
        await notifier.downloadBatch(pending, limit: pending.length);
      }
    }

    void listMode(TikTokStatusFilter filter) {
      notifier.setStatusFilter(filter);
      notifier.setViewMode(TikTokViewMode.list);
    }

    InlineSpan stat(int n, String unit) => TextSpan(
      children: [
        TextSpan(
          text: number.format(n),
          style: studioMono(c, color: c.textPrimary),
        ),
        TextSpan(text: ' $unit'),
      ],
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioCap(l10n.studioArchiveCap),
        const SizedBox(height: 6),
        Text(l10n.studioArchiveTitle, style: studioTitle(c)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: studioText(c, color: c.textSecondary),
            children: [
              stat(catalog.videos.length, l10n.studioVideosUnit),
              const TextSpan(text: '    '),
              stat(catalog.collections.length, l10n.studioCollectionsUnit),
              const TextSpan(text: '    '),
              stat(catalog.totalFavorites, l10n.studioFavoritesUnit),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Import and sync live in today's archive hub.
        StudioButton(
          label: l10n.studioSync,
          icon: Icons.sync_rounded,
          kind: StudioButtonKind.light,
          onTap: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        const SizedBox(width: 16),
        batch
            ? StudioButton(
                label: l10n.cancel,
                kind: StudioButtonKind.light,
                onTap: notifier.stopBatch,
              )
            : StudioButton(
                label: l10n.studioDownloadAll,
                onTap: pending.isEmpty ? null : downloadAll,
              ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 16,
          spacing: 16,
          children: [title, actions],
        ),
        const SizedBox(height: 22),
        StudioTabs(
          tabs: [
            StudioTab(
              label: l10n.studioVideos,
              count: number.format(catalog.videos.length),
              selected: mode == TikTokViewMode.list && !favorites,
              onTap: () => listMode(TikTokStatusFilter.all),
            ),
            StudioTab(
              label: l10n.studioCollections,
              count: number.format(catalog.collections.length),
              selected: mode == TikTokViewMode.collections,
              onTap: () => notifier.setViewMode(TikTokViewMode.collections),
            ),
            StudioTab(
              label: l10n.archiveMobileFilterFavorites,
              count: number.format(catalog.totalFavorites),
              selected: mode == TikTokViewMode.list && favorites,
              onTap: () => listMode(TikTokStatusFilter.favoritesOnly),
            ),
          ],
        ),
      ],
    );
  }
}
