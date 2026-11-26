import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'porcelaine_widgets.dart';

/// Porcelaine's TikTok archive (Porcelaine-Archives.dc.html): the archive
/// card with its figures and actions, Vidéos / Collections / Favoris tabs,
/// then today's archive view ([current]: filters, search, video list,
/// collection cards, selection and purge, import hub) on a Porcelaine sheet.
class PorcelaineArchive extends ConsumerWidget {
  const PorcelaineArchive({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final title =
        ref
            .watch(featureCatalogProvider)
            .byId['tiktok_archives']
            ?.nameFor(locale) ??
        l10n.archiveMobileTitle;
    final browsing = ref.watch(
      tikTokArchiveProvider.select(
        (s) => !s.isLoading && s.hasCatalog && s.viewMode != TikTokViewMode.hub,
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 1284 ? (box.maxWidth - 1220) / 2 : 32.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PPageTitle(title: title),
              const SizedBox(height: 26),
              if (browsing) ...[
                const _ArchiveCard(),
                const SizedBox(height: 20),
                const _Tabs(),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pCardFill(colors),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: pCardShadow(colors),
                  ),
                  child: current,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArchiveCard extends ConsumerWidget {
  const _ArchiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          videos: s.catalog?.totalUniqueVideos ?? 0,
          collections: s.catalog?.collections.length ?? 0,
          favorites: s.catalog?.totalFavorites ?? 0,
          selected: s.selectedIds.length,
          batch: s.isBatchDownloading,
          done: s.batchCompletedCount,
          total: s.batchTotalCount,
          sync: s.syncMessage,
        ),
      ),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    Widget figure(int n, String label) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: pDisp(30, color: colors.textPrimary).copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: pBody(colors, size: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
    final identity = Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFD8CFBD),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 24,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.archiveMobileTitle,
                    style: pDisp(26, color: colors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.porcelaineLocalArchive,
                      style: pBody(
                        colors,
                        size: 12,
                        weight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (s.sync != null && s.sync!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.sync!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(
                          colors,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final figures = [
      figure(s.videos, l10n.porcelaineArchiveVideos),
      figure(s.collections, l10n.porcelaineArchiveCollections),
      figure(s.favorites, l10n.porcelaineArchiveFavorites),
    ];
    final actions = [
      PBtn(
        label: l10n.porcelaineSync,
        icon: Icons.sync_rounded,
        onTap: () => notifier.setViewMode(TikTokViewMode.hub),
      ),
      if (s.batch)
        PBtn(
          label: '${l10n.archiveMobileStopBatch} · ${s.done}/${s.total}',
          icon: Icons.stop_rounded,
          kind: PBtnKind.dark,
          onTap: notifier.stopBatch,
        )
      else
        PBtn(
          label: s.selected > 0
              ? l10n.porcelaineDownloadSelection(s.selected)
              : l10n.porcelaineDownloadSelectionNone,
          icon: Icons.download_rounded,
          kind: PBtnKind.accent,
          tooltip: s.selected > 0 ? null : l10n.porcelaineSelectFirst,
          onTap: s.selected > 0 ? notifier.downloadSelected : null,
        ),
    ];
    return PCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 1000) {
            return Row(
              children: [
                Expanded(child: identity),
                ...figures,
                const SizedBox(width: 28),
                actions.first,
                const SizedBox(width: 8),
                actions.last,
              ],
            );
          }
          // Narrow: the identity, then the figures and actions wrap.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [...figures, const SizedBox(width: 20), ...actions],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (mode, favorites, videos, collections, favs) = ref.watch(
      tikTokArchiveProvider.select(
        (s) => (
          s.viewMode,
          s.filter.statusFilter == TikTokStatusFilter.favoritesOnly,
          s.catalog?.totalUniqueVideos ?? 0,
          s.catalog?.collections.length ?? 0,
          s.catalog?.totalFavorites ?? 0,
        ),
      ),
    );
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final tab = mode == TikTokViewMode.collections ? 1 : (favorites ? 2 : 0);
    void pick(int t) {
      if (t == 1) {
        notifier.setViewMode(TikTokViewMode.collections);
        return;
      }
      notifier.setStatusFilter(
        t == 2 ? TikTokStatusFilter.favoritesOnly : TikTokStatusFilter.all,
      );
      notifier.setViewMode(TikTokViewMode.list);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.surface.withValues(alpha: 0.7),
              colors.background,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.07),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label, n) in [
                (0, l10n.porcelaineArchiveVideosTab, videos),
                (1, l10n.porcelaineArchiveCollectionsTab, collections),
                (2, l10n.porcelaineArchiveFavoritesTab, favs),
              ]) ...[
                if (i > 0) const SizedBox(width: 4),
                PPill(
                  label: label,
                  trailing: '$n',
                  selected: tab == i,
                  transparent: true,
                  onTap: () => pick(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (tab == 1)
          Expanded(
            child: Text(
              l10n.porcelaineArchiveKeptHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pBody(colors, size: 13, color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}
