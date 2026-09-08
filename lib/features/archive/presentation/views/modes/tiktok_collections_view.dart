import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import '../widgets/tiktok_video_card.dart';

class TikTokCollectionsView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokCollectionsView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokCollectionsView> createState() => _TikTokCollectionsViewState();
}

class _TikTokCollectionsViewState extends ConsumerState<TikTokCollectionsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _confirmResetCollection(String collectionName, int count) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Réinitialiser la collection', style: AppTypography.h3),
        content: Text(
          'Voulez-vous dissocier les $count vidéos du dossier "$collectionName" et les renvoyer dans "Favoris non classés" ?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tikTokArchiveProvider.notifier).resetCollectionToUnclassified(collectionName);
      _showNotice('Vidéos de "$collectionName" réinitialisées vers les Favoris non classés.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final filteredVideos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final selectedCollection = state.filter.selectedCollection;

    // If a collection is selected, show the videos inside that collection!
    if (selectedCollection != null) {
      return _buildCollectionVideosView(
        colors: colors,
        collectionName: selectedCollection,
        videos: filteredVideos,
        state: state,
        notifier: notifier,
      );
    }

    // Otherwise, show the grid of all collections
    final collections = widget.catalog.collections.where((c) {
      if (_search.isEmpty) return true;
      return c.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Header & Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.6),
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _search = val.trim()),
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Rechercher parmi les ${widget.catalog.collections.length} collections...',
                    hintStyle: AppTypography.bodySmall.copyWith(color: colors.textDisabled),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${collections.length} dossiers',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Grid of collection folders
        Expanded(
          child: collections.isEmpty
              ? Center(
                  child: Text(
                    'Aucune collection trouvée',
                    style: AppTypography.body.copyWith(color: colors.textSecondary),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 700;
                    final crossAxisCount = isDesktop ? (constraints.maxWidth / 280).floor().clamp(2, 6) : 1;

                    return GridView.builder(
                      padding: const EdgeInsets.all(18),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: 110,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final coll = collections[index];
                        final canReset = coll.videoCount > 0 &&
                            coll.name != 'Favoris non classés' &&
                            coll.name != 'Vidéos Likées';

                        return _CollectionFolderCard(
                          collection: coll,
                          onOpen: () => notifier.selectCollection(coll.name),
                          onReset: canReset
                              ? () => _confirmResetCollection(coll.name, coll.videoCount)
                              : null,
                          onDownloadAll: coll.videoCount > 0
                              ? () async {
                                  // Filter videos of this collection and download
                                  final collVideos = widget.catalog.videos
                                      .where((v) => v.collectionName == coll.name)
                                      .toList();
                                  _showNotice('Téléchargement du dossier "${coll.name}" (${collVideos.length} vidéos)...');
                                  await notifier.downloadBatch(collVideos, limit: collVideos.length);
                                }
                              : null,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCollectionVideosView({
    required AppColors colors,
    required String collectionName,
    required List<TikTokArchiveItem> videos,
    required TikTokArchiveState state,
    required TikTokArchiveNotifier notifier,
  }) {
    final canReset = videos.isNotEmpty &&
        collectionName != 'Favoris non classés' &&
        collectionName != 'Vidéos Likées';

    return Column(
      children: [
        // Collection Banner / Breadcrumb
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.7),
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.selectCollection(null),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Toutes les collections'),
              ),
              const SizedBox(width: 14),
              Icon(Icons.folder_open_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  collectionName,
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${videos.length} vidéos',
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canReset) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _confirmResetCollection(collectionName, videos.length),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Dissocier'),
                ),
              ],
              const SizedBox(width: 12),
              if (videos.isNotEmpty)
                FilledButton.icon(
                  onPressed: state.isBatchDownloading
                      ? null
                      : () async {
                          _showNotice('Téléchargement des ${videos.length} vidéos du dossier...');
                          await notifier.downloadBatch(videos, limit: videos.length);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text('Tout télécharger (${videos.length})'),
                ),
            ],
          ),
        ),

        // Videos inside collection
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text(
                    'Aucune vidéo dans cette collection',
                    style: AppTypography.body.copyWith(color: colors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isSelected = state.selectedIds.contains(video.id);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TikTokVideoCard(
                        item: video,
                        isSelected: isSelected,
                        onToggleSelect: () => notifier.toggleSelection(video.id),
                        onDownload: () async {
                          _showNotice('Téléchargement lancé : ${video.id}');
                          await notifier.downloadBatch([video], limit: 1);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CollectionFolderCard extends StatefulWidget {
  final TikTokCollectionItem collection;
  final VoidCallback onOpen;
  final VoidCallback? onDownloadAll;
  final VoidCallback? onReset;

  const _CollectionFolderCard({
    required this.collection,
    required this.onOpen,
    this.onDownloadAll,
    this.onReset,
  });

  @override
  State<_CollectionFolderCard> createState() => _CollectionFolderCardState();
}

class _CollectionFolderCardState extends State<_CollectionFolderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final coll = widget.collection;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(12),
          hoverColor: colors.surfaceHighlight.withValues(alpha: 0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colors.surfaceHighlight.withValues(alpha: 0.7)
                  : colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? colors.primary.withValues(alpha: 0.5) : colors.borderSubtle,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    if (coll.heuristicCount != null && coll.heuristicCount! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, size: 11, color: Color(0xFF10B981)),
                            const SizedBox(width: 2),
                            Text(
                              '+${coll.heuristicCount}',
                              style: AppTypography.mono.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_isHovered && widget.onReset != null)
                      IconButton(
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        tooltip: 'Renvoyer dans "Favoris non classés"',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: widget.onReset,
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: coll.videoCount > 0
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        coll.declaredTotal != null && coll.declaredTotal! > coll.videoCount
                            ? '${coll.videoCount}/${coll.declaredTotal}'
                            : '${coll.videoCount} vids',
                        style: AppTypography.mono.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: coll.videoCount > 0 ? colors.primary : colors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  coll.name,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (coll.date != null)
                      Text(
                        '${coll.date!.year}-${coll.date!.month.toString().padLeft(2, '0')}',
                        style: AppTypography.caption.copyWith(color: colors.textSecondary),
                      ),
                    const Spacer(),
                    if (coll.videoCount > 0)
                      Text(
                        'Ouvrir →',
                        style: AppTypography.caption.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
