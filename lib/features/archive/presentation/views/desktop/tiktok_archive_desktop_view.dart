import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import '../widgets/tiktok_filter_pane.dart';
import '../widgets/tiktok_video_card.dart';
import '../widgets/tiktok_sound_card.dart';
import '../modes/tiktok_collections_view.dart';
import '../modes/tiktok_tinder_view.dart';
import '../modes/tiktok_feed_view.dart';
import '../archive_hub_view.dart';

class TikTokArchiveDesktopView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokArchiveDesktopView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokArchiveDesktopView> createState() => _TikTokArchiveDesktopViewState();
}

class _TikTokArchiveDesktopViewState extends ConsumerState<TikTokArchiveDesktopView> {
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final filteredVideos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final filter = state.filter;
    final viewMode = state.viewMode;

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          // Left Pane: Filters, KPIs & Collections (only in list mode or when relevant)
          if (viewMode == TikTokViewMode.list)
            const TikTokFilterPane(),

          // Right Pane: Main View Area
          Expanded(
            child: Column(
              children: [
                // Top Global Mode Selector & Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.6),
                    border: Border(bottom: BorderSide(color: colors.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        tooltip: 'Retour au Hub Archives & Imports',
                        onPressed: () => notifier.setViewMode(TikTokViewMode.hub),
                      ),
                      const SizedBox(width: 8),
                      // View Mode Switcher
                      SegmentedButton<TikTokViewMode>(
                        segments: const [
                          ButtonSegment(
                            value: TikTokViewMode.hub,
                            label: Text('Hub'),
                            icon: Icon(Icons.inventory_2_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: TikTokViewMode.collections,
                            label: Text('Dossiers'),
                            icon: Icon(Icons.folder_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: TikTokViewMode.list,
                            label: Text('Liste'),
                            icon: Icon(Icons.list_alt_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: TikTokViewMode.feed,
                            label: Text('Feed'),
                            icon: Icon(Icons.view_carousel_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: TikTokViewMode.tinder,
                            label: Text('Tinder'),
                            icon: Icon(Icons.swipe_rounded, size: 16),
                          ),
                        ],
                        selected: {viewMode},
                        onSelectionChanged: (set) => notifier.setViewMode(set.first),
                      ),
                      const Spacer(),

                      // Audio vs Video quick filter
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Vidéos'),
                            icon: Icon(Icons.video_collection_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Musiques'),
                            icon: Icon(Icons.music_note_outlined, size: 16),
                          ),
                        ],
                        selected: {filter.showSounds},
                        onSelectionChanged: (set) => notifier.setShowSounds(set.first),
                      ),
                    ],
                  ),
                ),

                // Active View Mode Rendering
                Expanded(
                  child: _buildActiveMode(
                    viewMode: viewMode,
                    colors: colors,
                    state: state,
                    filteredVideos: filteredVideos,
                    notifier: notifier,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMode({
    required TikTokViewMode viewMode,
    required AppColors colors,
    required TikTokArchiveState state,
    required List<TikTokArchiveItem> filteredVideos,
    required TikTokArchiveNotifier notifier,
  }) {
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
        return _buildListView(colors, state, filteredVideos, notifier);
    }
  }

  Widget _buildListView(
    AppColors colors,
    TikTokArchiveState state,
    List<TikTokArchiveItem> filteredVideos,
    TikTokArchiveNotifier notifier,
  ) {
    final filter = state.filter;

    return Column(
      children: [
        // Search & Batch Controls Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.4),
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => notifier.setSearchQuery(val),
                      style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: filter.showSounds
                            ? 'Rechercher un son ou une musique...'
                            : 'Rechercher par ID TikTok ou collection...',
                        hintStyle: AppTypography.bodySmall.copyWith(color: colors.textDisabled),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                },
                              )
                            : null,
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
                ],
              ),
              const SizedBox(height: 10),

              // Batch Action Controls
              Row(
                children: [
                  if (!filter.showSounds) ...[
                    Text(
                      '${filteredVideos.length} éléments affichés',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (state.selectedIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.selectedIds.length} sélectionnés',
                          style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        if (state.selectedIds.length == filteredVideos.length) {
                          notifier.clearSelection();
                        } else {
                          notifier.selectAll(filteredVideos);
                        }
                      },
                      icon: Icon(
                        state.selectedIds.length == filteredVideos.length && filteredVideos.isNotEmpty
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 16,
                      ),
                      label: Text(
                        state.selectedIds.length == filteredVideos.length && filteredVideos.isNotEmpty
                            ? 'Tout désélectionner'
                            : 'Tout sélectionner',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (state.selectedIds.isNotEmpty)
                      FilledButton.icon(
                        onPressed: state.isBatchDownloading
                            ? null
                            : () async {
                                _showNotice('Téléchargement du lot démarré');
                                await notifier.downloadSelected();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text('Télécharger (${state.selectedIds.length})'),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: state.isBatchDownloading || filteredVideos.isEmpty
                          ? null
                          : () async {
                              _showNotice('Téléchargement des 50 premiers démarré');
                              await notifier.downloadBatch(filteredVideos, limit: 50);
                            },
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.playlist_play_rounded, size: 16),
                      label: const Text('Lot de 50'),
                    ),
                  ] else ...[
                    Text(
                      '${widget.catalog.sounds.length} sons favoris répertoriés',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: state.isBatchDownloading || widget.catalog.sounds.isEmpty
                          ? null
                          : () async {
                              _showNotice('Téléchargement des 50 sons MP3 démarré');
                              await notifier.downloadSounds(widget.catalog.sounds, limit: 50);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Télécharger lot de 50 MP3'),
                    ),
                  ],
                ],
              ),

              // Batch Downloading Progress Bar
              if (state.isBatchDownloading) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: state.batchTotalCount > 0
                            ? state.batchCompletedCount / state.batchTotalCount
                            : null,
                        backgroundColor: colors.surfaceHighlight,
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${state.batchCompletedCount} / ${state.batchTotalCount}',
                      style: AppTypography.mono.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // List Content
        Expanded(
          child: filter.showSounds
              ? _buildSoundsList(widget.catalog.sounds, colors, notifier)
              : _buildVideosList(colors, filteredVideos, state, notifier),
        ),
      ],
    );
  }

  Widget _buildVideosList(
    AppColors colors,
    List<TikTokArchiveItem> videos,
    TikTokArchiveState state,
    TikTokArchiveNotifier notifier,
  ) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'Aucune vidéo ne correspond aux filtres actifs',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => notifier.resetFilters(),
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildSoundsList(
    List<TikTokSoundItem> sounds,
    AppColors colors,
    TikTokArchiveNotifier notifier,
  ) {
    if (sounds.isEmpty) {
      return Center(
        child: Text(
          'Aucun son trouvé dans l\'archive',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TikTokSoundCard(
            sound: sound,
            onDownloadMp3: () async {
              _showNotice('Extraction audio lancée : ${sound.title}');
              await notifier.downloadSounds([sound], limit: 1);
            },
          ),
        );
      },
    );
  }
}
