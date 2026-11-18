import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import '../widgets/tiktok_filter_pane.dart';
import '../widgets/tiktok_video_card.dart';
import '../modes/tiktok_collections_view.dart';
import '../archive_hub_view.dart';

class TikTokArchiveDesktopView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokArchiveDesktopView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokArchiveDesktopView> createState() =>
      _TikTokArchiveDesktopViewState();
}

class _TikTokArchiveDesktopViewState
    extends ConsumerState<TikTokArchiveDesktopView> {
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
    final viewMode = state.viewMode;

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          // Filters stay beside the full video list on wide screens.
          if (viewMode == TikTokViewMode.list) const TikTokFilterPane(),

          // Right Pane: Main View Area
          Expanded(
            child: Column(
              children: [
                // Top Global Mode Selector & Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.6),
                    border: Border(
                      bottom: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        SegmentedButton<TikTokViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: TikTokViewMode.collections,
                              label: Text('Collections'),
                              icon: Icon(Icons.folder_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: TikTokViewMode.list,
                              label: Text('Vidéos'),
                              icon: Icon(Icons.list_alt_rounded, size: 16),
                            ),
                          ],
                          selected: {viewMode},
                          onSelectionChanged: (set) =>
                              notifier.setViewMode(set.first),
                        ),
                        const Spacer(),
                        if (constraints.maxWidth >= 640)
                          OutlinedButton.icon(
                            onPressed: () =>
                                notifier.setViewMode(TikTokViewMode.hub),
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 18,
                            ),
                            label: const Text('Importer / synchroniser'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Importer ou synchroniser',
                            onPressed: () =>
                                notifier.setViewMode(TikTokViewMode.hub),
                            icon: const Icon(Icons.file_upload_outlined),
                          ),
                      ],
                    ),
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
    return Column(
      children: [
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
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une vidéo ou une collection...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: colors.textDisabled,
                        ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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

              Row(
                children: [
                  Text(
                    '${filteredVideos.length} vidéos',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (state.selectedIds.isEmpty)
                    TextButton.icon(
                      onPressed: filteredVideos.isEmpty
                          ? null
                          : () => notifier.selectAll(filteredVideos),
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text('Tout sélectionner'),
                    )
                  else ...[
                    TextButton(
                      onPressed: notifier.clearSelection,
                      child: Text(
                        '${state.selectedIds.length} sélectionnées · Effacer',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.isBatchDownloading
                          ? null
                          : () async {
                              await notifier.downloadSelected();
                              _showNotice(
                                'Vidéos ajoutées à la file de téléchargement.',
                              );
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        state.isBatchDownloading
                            ? (state.batchSkippedCount > 0
                                ? 'En cours (${state.batchCompletedCount}/${state.batchTotalCount}) · ${state.batchSkippedCount} ignorées'
                                : 'En cours (${state.batchCompletedCount}/${state.batchTotalCount})')
                            : 'Télécharger la sélection',
                      ),
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
                      state.batchSkippedCount > 0
                          ? '${state.batchCompletedCount} / ${state.batchTotalCount} (${state.batchSkippedCount} ignorées)'
                          : '${state.batchCompletedCount} / ${state.batchTotalCount}',
                      style: AppTypography.mono.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: _buildVideosList(colors, filteredVideos, state, notifier),
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
            Icon(
              Icons.filter_alt_off_rounded,
              size: 48,
              color: colors.textDisabled,
            ),
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
              if (ref.read(showcaseModeProvider)) {
                _showNotice('Mode démo : téléchargement simulé.');
                return;
              }
              _showNotice('Téléchargement lancé : ${video.id}');
              await notifier.downloadBatch([video], limit: 1);
            },
          ),
        );
      },
    );
  }
}
