import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'tiktok_stat_card.dart';

class TikTokFilterPane extends ConsumerStatefulWidget {
  const TikTokFilterPane({super.key});

  @override
  ConsumerState<TikTokFilterPane> createState() => _TikTokFilterPaneState();
}

class _TikTokFilterPaneState extends ConsumerState<TikTokFilterPane> {
  final TextEditingController _collectionSearchController = TextEditingController();
  String _collectionSearch = '';

  @override
  void dispose() {
    _collectionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog;
    final filter = state.filter;
    final notifier = ref.read(tikTokArchiveProvider.notifier);

    if (catalog == null) return const SizedBox.shrink();

    final years = catalog.yearCounts.keys.toList()..sort((a, b) => b.compareTo(a));

    final filteredCollections = catalog.collections.where((c) {
      if (_collectionSearch.isEmpty) return true;
      return c.name.toLowerCase().contains(_collectionSearch.toLowerCase());
    }).toList();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.4),
        border: Border(
          right: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Stats Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.library_music_rounded,
                        size: 18,
                        color: Color(0xFFFE2C55),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Archive TikTok',
                      style: AppTypography.h3.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      tooltip: 'Recharger / Réimporter',
                      onPressed: () => notifier.pickAndImportFile(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2x2 Grid of Quick Stats
                Row(
                  children: [
                    Expanded(
                      child: TikTokStatCard(
                        label: 'Vidéos',
                        value: '${catalog.totalUniqueVideos}',
                        icon: Icons.video_collection_rounded,
                        accentColor: colors.primary,
                        onTap: () {
                          notifier.setShowSounds(false);
                          notifier.setStatusFilter(TikTokStatusFilter.all);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TikTokStatCard(
                        label: 'Sons MP3',
                        value: '${catalog.sounds.length}',
                        icon: Icons.music_note_rounded,
                        accentColor: Colors.amber,
                        onTap: () => notifier.setShowSounds(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TikTokStatCard(
                        label: 'Favoris',
                        value: '${catalog.totalFavorites}',
                        icon: Icons.bookmark_rounded,
                        accentColor: const Color(0xFFFE2C55),
                        onTap: () {
                          notifier.setShowSounds(false);
                          notifier.setStatusFilter(TikTokStatusFilter.favoritesOnly);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TikTokStatCard(
                        label: 'Likes',
                        value: '${catalog.totalLikes}',
                        icon: Icons.favorite_rounded,
                        accentColor: const Color(0xFFE91E63),
                        onTap: () {
                          notifier.setShowSounds(false);
                          notifier.setStatusFilter(TikTokStatusFilter.likesOnly);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Year Filter Horizontal Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANNÉE',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: filter.selectedYear == null,
                        label: const Text('Toutes'),
                        onSelected: (_) => notifier.selectYear(null),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      for (final year in years) ...[
                        FilterChip(
                          selected: filter.selectedYear == year,
                          label: Text('$year (${catalog.yearCounts[year]})'),
                          onSelected: (_) => notifier.selectYear(filter.selectedYear == year ? null : year),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Collections Section Header + Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'COLLECTIONS (${catalog.collections.length})',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (filter.selectedCollection != null)
                  InkWell(
                    onTap: () => notifier.selectCollection(null),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Effacer',
                        style: AppTypography.caption.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _collectionSearchController,
              onChanged: (val) => setState(() => _collectionSearch = val),
              style: AppTypography.caption.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Filtrer les collections...',
                hintStyle: AppTypography.caption.copyWith(color: colors.textDisabled),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: colors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
              ),
            ),
          ),

          // Collections List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: filteredCollections.length,
              itemBuilder: (context, index) {
                final coll = filteredCollections[index];
                final isSelected = filter.selectedCollection == coll.name;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => notifier.selectCollection(isSelected ? null : coll.name),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: colors.primary.withValues(alpha: 0.4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 16,
                              color: isSelected ? colors.primary : colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                coll.name,
                                style: AppTypography.caption.copyWith(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? colors.primary : colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (coll.videoCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colors.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${coll.videoCount}',
                                  style: AppTypography.mono.copyWith(fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Browser Sync Action at bottom
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.8),
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                // Navigate to in-app browser for TikTok
                context.go('/browse');
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text(
                'Sync via Navigateur',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
