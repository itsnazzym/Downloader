import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import '../widgets/tiktok_video_card.dart';
import '../modes/tiktok_collections_view.dart';
import '../modes/tiktok_tinder_view.dart';
import '../modes/tiktok_feed_view.dart';
import '../archive_hub_view.dart';

class TikTokArchiveMobileView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokArchiveMobileView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokArchiveMobileView> createState() => _TikTokArchiveMobileViewState();
}

class _TikTokArchiveMobileViewState extends ConsumerState<TikTokArchiveMobileView> {
  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final colors = AppColors.of(context);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final catalog = widget.catalog;
    final years = catalog.yearCounts.keys.toList()..sort((a, b) => b.compareTo(a));

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(tikTokArchiveProvider.select((s) => s.filter));

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filtres du catalogue',
                          style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            notifier.resetFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Status Segment
                    Text(
                      'TYPE',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<TikTokStatusFilter>(
                      segments: const [
                        ButtonSegment(value: TikTokStatusFilter.all, label: Text('Tous')),
                        ButtonSegment(value: TikTokStatusFilter.favoritesOnly, label: Text('Favoris')),
                        ButtonSegment(value: TikTokStatusFilter.likesOnly, label: Text('Likes')),
                      ],
                      selected: {filter.statusFilter},
                      onSelectionChanged: (set) => notifier.setStatusFilter(set.first),
                    ),
                    const SizedBox(height: 16),

                    // Year Filter
                    Text(
                      'ANNÉE',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Toutes'),
                          selected: filter.selectedYear == null,
                          onSelected: (_) => notifier.selectYear(null),
                        ),
                        for (final y in years)
                          ChoiceChip(
                            label: Text('$y (${catalog.yearCounts[y]})'),
                            selected: filter.selectedYear == y,
                            onSelected: (_) => notifier.selectYear(y),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Collections Dropdown
                    Text(
                      'COLLECTION (${catalog.collections.length})',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: filter.selectedCollection,
                      dropdownColor: colors.surface,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.borderSubtle),
                        ),
                      ),
                      hint: const Text('Toutes les collections'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Toutes les collections'),
                        ),
                        for (final coll in catalog.collections)
                          DropdownMenuItem(
                            value: coll.name,
                            child: Text(
                              '${coll.name} (${coll.videoCount})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) => notifier.selectCollection(val),
                    ),
                    const SizedBox(height: 20),

                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        minimumSize: const Size.fromHeight(48), // Touch target >= 48dp
                      ),
                      child: const Text('Appliquer les filtres'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final filteredVideos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final viewMode = state.viewMode;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour au Hub',
          onPressed: () => notifier.setViewMode(TikTokViewMode.hub),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archive TikTok',
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.catalog.totalUniqueVideos} vidéos • ${widget.catalog.collections.length} dossiers',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtres',
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Importer un fichier',
            onPressed: () => notifier.pickAndImportFile(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ModeChip(
                    icon: Icons.inventory_2_rounded,
                    label: 'Hub',
                    isSelected: viewMode == TikTokViewMode.hub,
                    onTap: () => notifier.setViewMode(TikTokViewMode.hub),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    icon: Icons.folder_rounded,
                    label: 'Dossiers',
                    isSelected: viewMode == TikTokViewMode.collections,
                    onTap: () => notifier.setViewMode(TikTokViewMode.collections),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    icon: Icons.list_alt_rounded,
                    label: 'Liste',
                    isSelected: viewMode == TikTokViewMode.list,
                    onTap: () => notifier.setViewMode(TikTokViewMode.list),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    icon: Icons.view_carousel_rounded,
                    label: 'Feed TikTok',
                    isSelected: viewMode == TikTokViewMode.feed,
                    onTap: () => notifier.setViewMode(TikTokViewMode.feed),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    icon: Icons.swipe_rounded,
                    label: 'Mode Tinder',
                    isSelected: viewMode == TikTokViewMode.tinder,
                    onTap: () => notifier.setViewMode(TikTokViewMode.tinder),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildActiveMode(viewMode, colors, state, filteredVideos, notifier),

      // Bottom Bar (Thumb Zone) for Batch Downloads when items selected in list mode
      bottomNavigationBar: (viewMode == TikTokViewMode.list && state.selectedIds.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Text(
                      '${state.selectedIds.length} sélectionnés',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => notifier.clearSelection(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: state.isBatchDownloading
                          ? null
                          : () async {
                              _showNotice('Téléchargement du lot démarré');
                              await notifier.downloadSelected();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        minimumSize: const Size(0, 48), // Touch target >= 48dp
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Télécharger'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildActiveMode(
    TikTokViewMode viewMode,
    AppColors colors,
    TikTokArchiveState state,
    List<TikTokArchiveItem> filteredVideos,
    TikTokArchiveNotifier notifier,
  ) {
    switch (viewMode) {
      case TikTokViewMode.hub:
        return const ArchiveHubView();

      case TikTokViewMode.collections:
        return TikTokCollectionsView(catalog: widget.catalog);

      case TikTokViewMode.feed:
        return TikTokFeedView(videos: filteredVideos);

      case TikTokViewMode.tinder:
        return TikTokTinderView(videos: filteredVideos);

      case TikTokViewMode.list:
        return filteredVideos.isEmpty
            ? Center(
                child: Text(
                  'Aucune vidéo trouvée',
                  style: AppTypography.body.copyWith(color: colors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: filteredVideos.length,
                itemBuilder: (context, index) {
                  final video = filteredVideos[index];
                  final isSelected = state.selectedIds.contains(video.id);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TikTokVideoCard(
                      item: video,
                      isSelected: isSelected,
                      onToggleSelect: () => notifier.toggleSelection(video.id),
                      onDownload: () async {
                        _showNotice('Téléchargement démarré');
                        await notifier.downloadBatch([video], limit: 1);
                      },
                    ),
                  );
                },
              );
    }
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? colors.onPrimary : colors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary,
      labelStyle: TextStyle(
        color: isSelected ? colors.onPrimary : colors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }
}
