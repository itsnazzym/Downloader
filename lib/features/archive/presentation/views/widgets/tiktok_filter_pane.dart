import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';

class TikTokFilterPane extends ConsumerStatefulWidget {
  const TikTokFilterPane({super.key});

  @override
  ConsumerState<TikTokFilterPane> createState() => _TikTokFilterPaneState();
}

class _TikTokFilterPaneState extends ConsumerState<TikTokFilterPane> {
  final TextEditingController _collectionSearchController =
      TextEditingController();
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

    final years = catalog.yearCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final collections = catalog.collections.where((collection) {
      return collection.name.toLowerCase().contains(
        _collectionSearch.toLowerCase(),
      );
    }).toList();

    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.4),
        border: Border(right: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Text(
                  'Filtres',
                  style: AppTypography.h3.copyWith(color: colors.textPrimary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.selectYear(null);
                    notifier.selectCollection(null);
                    notifier.setStatusFilter(TikTokStatusFilter.all);
                    notifier.clearSelection();
                  },
                  child: const Text('Effacer'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<TikTokStatusFilter>(
              initialValue: filter.statusFilter,
              decoration: const InputDecoration(
                labelText: 'Type de vidéos',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: TikTokStatusFilter.all,
                  child: Text('Toutes'),
                ),
                DropdownMenuItem(
                  value: TikTokStatusFilter.favoritesOnly,
                  child: Text('Favoris'),
                ),
                DropdownMenuItem(
                  value: TikTokStatusFilter.likesOnly,
                  child: Text('Mentions J’aime'),
                ),
              ],
              onChanged: (value) {
                if (value != null) notifier.setStatusFilter(value);
              },
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      for (final year in years) ...[
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: filter.selectedYear == year,
                          label: Text('$year (${catalog.yearCounts[year]})'),
                          onSelected: (_) => notifier.selectYear(
                            filter.selectedYear == year ? null : year,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                  TextButton(
                    onPressed: () => notifier.selectCollection(null),
                    child: const Text('Effacer'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _collectionSearchController,
              onChanged: (value) => setState(() => _collectionSearch = value),
              style: AppTypography.caption.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Rechercher une collection',
                hintStyle: AppTypography.caption.copyWith(
                  color: colors.textDisabled,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                filled: true,
                fillColor: colors.inputBackground,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                final selected = filter.selectedCollection == collection.name;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: colors.primary.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    Icons.folder_outlined,
                    color: selected ? colors.primary : colors.textSecondary,
                  ),
                  title: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('${collection.videoCount}'),
                  onTap: () => notifier.selectCollection(
                    selected ? null : collection.name,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
