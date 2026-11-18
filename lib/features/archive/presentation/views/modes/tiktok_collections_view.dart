import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_feed_view.dart';
import '../widgets/tiktok_video_card.dart';
import '../../../../../showcase/showcase_mode.dart';

class TikTokCollectionsView extends ConsumerStatefulWidget {
  final TikTokArchiveCatalog catalog;

  const TikTokCollectionsView({super.key, required this.catalog});

  @override
  ConsumerState<TikTokCollectionsView> createState() =>
      _TikTokCollectionsViewState();
}

class _TikTokCollectionsViewState extends ConsumerState<TikTokCollectionsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _isApplyingSuggestions = false;
  bool _posterView = false;

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

  Future<void> _confirmResetCollection(
    String collectionKey,
    String collectionName,
    int count,
  ) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Réinitialiser la collection', style: AppTypography.h3),
        content: Text(
          'Retirer les $count vidéos de "$collectionName" ? Les vidéos et leurs autres classements seront conservés.',
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
      await ref
          .read(tikTokArchiveProvider.notifier)
          .resetCollectionToUnclassified(collectionKey);
      _showNotice(
        'Classement retiré pour "$collectionName". Les vidéos sont conservées.',
      );
    }
  }

  Future<void> _confirmDeleteCollection(
    String collectionKey,
    String collectionName,
    int count,
  ) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Supprimer la collection', style: AppTypography.h3),
        content: Text(
          'Supprimer définitivement la collection "$collectionName" ?\n\n'
          'Les $count vidéos ne seront pas supprimées de votre disque, mais elles ne feront plus partie de ce dossier.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(tikTokArchiveProvider.notifier)
          .deleteCollection(collectionKey);
      _showNotice('Collection "$collectionName" supprimée.');
    }
  }

  Future<void> _confirmClearArchive() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Réinitialiser toute l’archive', style: AppTypography.h3),
        content: Text(
          'Supprimer toutes les collections, les classements et l’import TikTok local ? '
          'Les vidéos déjà téléchargées sur le disque seront conservées.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tikTokArchiveProvider.notifier).clearCatalog();
      _showNotice('Archive TikTok réinitialisée.');
    }
  }

  Future<void> _reviewSuggestions(
    List<TikTokCollectionSuggestion> suggestions,
  ) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _CollectionSuggestionsDialog(suggestions: suggestions),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() => _isApplyingSuggestions = true);
    try {
      await ref
          .read(tikTokArchiveProvider.notifier)
          .applyCollectionSuggestions(selected);
      if (mounted) {
        _showNotice(
          '${selected.length} propositions ajoutées aux collections.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showNotice('Impossible d’appliquer ces propositions : $error');
      }
    } finally {
      if (mounted) setState(() => _isApplyingSuggestions = false);
    }
  }

  int _visibleCollectionCount(
    TikTokArchiveCatalog catalog,
    TikTokCollectionItem collection,
    Set<String> unavailableIds,
  ) {
    return catalog.videos.where((video) {
      if (unavailableIds.contains(video.id)) return false;
      if (collection.name == 'Vidéos Likées') return video.isLiked;
      if (collection.name == 'Favoris non classés') {
        return video.isFavorite &&
            video.collectionIds.isEmpty &&
            (video.collectionName == null ||
                video.collectionName == 'Favoris non classés' ||
                video.collectionName == 'Vidéos Likées');
      }
      return (collection.id != null &&
              video.collectionIds.contains(collection.id)) ||
          (video.collectionName?.split(' · ').contains(collection.name) ??
              false);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final filteredVideos = ref.watch(filteredTikTokVideosProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final selectedCollection = state.filter.selectedCollection;
    final catalog = state.catalog ?? widget.catalog;
    final unavailableIds = ref.watch(showcaseModeProvider)
        ? <String>{}
        : ref.watch(tiktokUnavailableIdsProvider).valueOrNull ??
              ref.read(tiktokVideoCacheServiceProvider).unavailableIds;

    // If a collection is selected, show the videos inside that collection!
    if (selectedCollection != null) {
      return _buildCollectionVideosView(
        colors: colors,
        collectionKey: selectedCollection,
        collectionName:
            catalog.collections
                .where(
                  (collection) =>
                      collection.id == selectedCollection ||
                      (collection.id == null &&
                          collection.name == selectedCollection),
                )
                .firstOrNull
                ?.name ??
            selectedCollection,
        videos: filteredVideos,
        state: state,
        notifier: notifier,
      );
    }

    // Otherwise, show the grid of all collections
    final collections = catalog.collections
        .map((collection) {
          return collection.copyWith(
            videoCount: _visibleCollectionCount(
              catalog,
              collection,
              unavailableIds,
            ),
          );
        })
        .where((c) {
          if (_search.isEmpty) return true;
          return c.name.toLowerCase().contains(_search.toLowerCase());
        })
        .toList();

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
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher parmi les ${catalog.collections.length} collections...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: colors.textDisabled,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
              const SizedBox(width: 14),
              Text(
                '${collections.length} dossiers',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _posterView
                    ? 'Afficher les dossiers'
                    : 'Afficher les miniatures',
                onPressed: () => setState(() => _posterView = !_posterView),
                icon: Icon(
                  _posterView
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Supprimer toutes les collections et réinitialiser',
                onPressed: _confirmClearArchive,
                icon: Icon(Icons.delete_sweep_outlined, color: colors.error),
              ),
            ],
          ),
        ),

        if (catalog.suggestions.isNotEmpty)
          _CollectionSuggestionsBanner(
            count: catalog.suggestions.length,
            isApplying: _isApplyingSuggestions,
            onReview: _isApplyingSuggestions
                ? null
                : () => _reviewSuggestions(catalog.suggestions),
          ),

        // Grid of collection folders
        Expanded(
          child: collections.isEmpty
              ? Center(
                  child: Text(
                    'Aucune collection trouvée',
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 700;
                    final crossAxisCount = _posterView
                        ? (constraints.maxWidth / 190).floor().clamp(2, 8)
                        : isDesktop
                        ? (constraints.maxWidth / 280).floor().clamp(2, 6)
                        : 1;

                    return GridView.builder(
                      padding: const EdgeInsets.all(18),
                      gridDelegate: _posterView
                          ? SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            )
                          : SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 110,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final coll = collections[index];
                        final isSpecial =
                            coll.name == 'Favoris non classés' ||
                            coll.name == 'Vidéos Likées';

                        void onOpen() =>
                            notifier.selectCollection(coll.id ?? coll.name);
                        final onDelete = isSpecial
                            ? null
                            : () => _confirmDeleteCollection(
                                  coll.id ?? coll.name,
                                  coll.name,
                                  coll.videoCount,
                                );
                        return _posterView
                            ? _CollectionPosterCard(
                                collection: coll,
                                onOpen: onOpen,
                                onDelete: onDelete,
                              )
                            : _CollectionFolderCard(
                                collection: coll,
                                onOpen: onOpen,
                                onDelete: onDelete,
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
    required String collectionKey,
    required String collectionName,
    required List<TikTokArchiveItem> videos,
    required TikTokArchiveState state,
    required TikTokArchiveNotifier notifier,
  }) {
    final canReset =
        videos.isNotEmpty &&
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
              if (canReset)
                PopupMenuButton<String>(
                  tooltip: 'Autres actions',
                  onSelected: (value) {
                    if (value == 'reset') {
                      _confirmResetCollection(
                        collectionKey,
                        collectionName,
                        videos.length,
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteCollection(
                        collectionKey,
                        collectionName,
                        videos.length,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Retirer les vidéos de cette collection'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer définitivement',
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 12),
              if (videos.isNotEmpty && !ref.read(showcaseModeProvider))
                IconButton.filledTonal(
                  tooltip: 'Lire les vidéos en plein écran, verticalement',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog.fullscreen(
                        child: TikTokFeedView(
                          videos: videos,
                          onClose: () => Navigator.of(dialogContext).pop(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              if (videos.isNotEmpty)
                FilledButton.icon(
                  onPressed: state.isBatchDownloading
                      ? null
                      : () async {
                          _showNotice(
                            'Téléchargement des ${videos.length} vidéos du dossier...',
                          );
                          await notifier.downloadBatch(
                            videos,
                            limit: videos.length,
                          );
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
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isSelected = state.selectedIds.contains(video.id);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TikTokVideoCard(
                        item: video,
                        isSelected: isSelected,
                        onToggleSelect: () =>
                            notifier.toggleSelection(video.id),
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

class _CollectionSuggestionsBanner extends StatelessWidget {
  const _CollectionSuggestionsBanner({
    required this.count,
    required this.isApplying,
    required this.onReview,
  });

  final int count;
  final bool isApplying;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Text(
            '$count propositions de classement à vérifier',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          );
          final action = OutlinedButton.icon(
            onPressed: onReview,
            icon: isApplying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined, size: 17),
            label: Text(
              isApplying
                  ? 'Classement en cours…'
                  : 'Examiner les $count propositions',
            ),
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 8), action],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _CollectionSuggestionsDialog extends StatefulWidget {
  const _CollectionSuggestionsDialog({required this.suggestions});

  final List<TikTokCollectionSuggestion> suggestions;

  @override
  State<_CollectionSuggestionsDialog> createState() =>
      _CollectionSuggestionsDialogState();
}

class _CollectionSuggestionsDialogState
    extends State<_CollectionSuggestionsDialog> {
  late final List<_SuggestionReviewRow> _rows;
  late final Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    final grouped = <String, List<TikTokCollectionSuggestion>>{};
    for (final suggestion in widget.suggestions) {
      grouped.putIfAbsent(suggestion.collectionName, () => []).add(suggestion);
    }
    final names = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _rows = [];
    for (final name in names) {
      final suggestions = grouped[name]!
        ..sort((a, b) => a.videoId.compareTo(b.videoId));
      _rows.add(_SuggestionReviewRow.header(name, suggestions.length));
      _rows.addAll(suggestions.map(_SuggestionReviewRow.item));
    }
    _selectedKeys = widget.suggestions.map((item) => item.key).toSet();
  }

  String _reasonLabel(String reason) => switch (reason) {
    'partial_snapshot' => 'Résultat de synchronisation incomplet',
    'date_proximity' => 'Date proche des vidéos confirmées',
    'imported_mapping' => 'Ancien fichier de correspondance',
    _ => 'Ancien classement à vérifier',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final height = (MediaQuery.sizeOf(context).height * 0.65)
        .clamp(280.0, 620.0)
        .toDouble();
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Row(
        children: [
          const Expanded(child: Text('Vérifier les propositions')),
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: height,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Coche les vidéos à ranger. Rien ne change avant validation.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.borderSubtle),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  if (row.suggestion == null) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                      child: Text(
                        '${row.collectionName} · ${row.count}',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  final suggestion = row.suggestion!;
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selectedKeys.contains(suggestion.key),
                    title: Text('Vidéo ${suggestion.videoId}'),
                    subtitle: Text(_reasonLabel(suggestion.reason)),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedKeys.add(suggestion.key);
                      } else {
                        _selectedKeys.remove(suggestion.key);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        Text(
          '${_selectedKeys.length} sélectionnées',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
        FilledButton.icon(
          onPressed: _selectedKeys.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.of(_selectedKeys)),
          icon: const Icon(Icons.check_rounded, size: 17),
          label: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _SuggestionReviewRow {
  const _SuggestionReviewRow.header(this.collectionName, this.count)
    : suggestion = null;
  const _SuggestionReviewRow.item(this.suggestion)
    : collectionName = '',
      count = 0;

  final String collectionName;
  final int count;
  final TikTokCollectionSuggestion? suggestion;
}

class _CollectionFolderCard extends StatefulWidget {
  final TikTokCollectionItem collection;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  const _CollectionFolderCard({
    required this.collection,
    required this.onOpen,
    this.onDelete,
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
                color: _isHovered
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.borderSubtle,
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
                    if (coll.syncComplete == false &&
                        coll.syncError != 'count_mismatch') ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: coll.syncError == null
                            ? 'Synchronisation incomplète. Le dernier état fiable est conservé.'
                            : 'Synchronisation incomplète : ${coll.syncError}',
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Tooltip(
                      message:
                          coll.declaredTotal != null &&
                              coll.declaredTotal! > coll.videoCount
                          ? '${coll.videoCount} vidéos synchronisées sur ${coll.declaredTotal} déclarées (${coll.declaredTotal! - coll.videoCount} indisponibles ou supprimées sur TikTok)'
                          : '${coll.videoCount} vidéos',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: coll.videoCount > 0
                              ? colors.primary.withValues(alpha: 0.15)
                              : colors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          coll.syncComplete == false &&
                                  coll.syncError != 'count_mismatch' &&
                                  coll.declaredTotal != null &&
                                  coll.declaredTotal! > coll.videoCount
                              ? '${coll.videoCount}/${coll.declaredTotal}'
                              : '${coll.videoCount} vids',
                          style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: coll.videoCount > 0
                                ? colors.primary
                                : colors.textDisabled,
                          ),
                        ),
                      ),
                    ),
                    if (widget.onDelete != null)
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          child: _isHovered
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Tooltip(
                                    message:
                                        'Supprimer définitivement la collection',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: widget.onDelete,
                                        borderRadius: BorderRadius.circular(6),
                                        hoverColor: colors.error.withValues(
                                          alpha: 0.18,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: colors.error.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16,
                                            color: colors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
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

class _CollectionPosterCard extends StatefulWidget {
  const _CollectionPosterCard({
    required this.collection,
    required this.onOpen,
    this.onDelete,
  });

  final TikTokCollectionItem collection;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  State<_CollectionPosterCard> createState() => _CollectionPosterCardState();
}

class _CollectionPosterCardState extends State<_CollectionPosterCard> {
  bool _isHovered = false;

  bool _isTrustedCover(String? value) {
    if (value == null) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return false;
    const trustedDomains = [
      'tiktokcdn.com',
      'tiktokv.com',
      'byteoversea.com',
      'ibytedtos.com',
      'byteimg.com',
    ];
    return trustedDomains.any(
      (domain) =>
          uri.host.toLowerCase() == domain ||
          uri.host.toLowerCase().endsWith('.$domain'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final coverUrl = _isTrustedCover(widget.collection.coverUrl)
        ? widget.collection.coverUrl
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null)
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPosterFallback(colors),
                )
              else
                _buildPosterFallback(colors),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.collection.videoCount.toString(),
                        style: AppTypography.mono.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.onDelete != null)
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          child: _isHovered
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Tooltip(
                                    message:
                                        'Supprimer définitivement la collection',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: widget.onDelete,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        hoverColor: colors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.75,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: colors.error.withValues(
                                                alpha: 0.6,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 15,
                                            color: colors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.collection.syncComplete == false &&
                  widget.collection.syncError != 'count_mismatch')
                Positioned(
                  top: 9,
                  left: 9,
                  child: Tooltip(
                    message: widget.collection.syncError == null
                        ? 'Synchronisation incomplète'
                        : 'Synchronisation incomplète : ${widget.collection.syncError!}',
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.collection.name,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.collection.videoCount} vidéos',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white70,
                      ),
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

  Widget _buildPosterFallback(AppColors colors) => ColoredBox(
    color: colors.surfaceHighlight,
    child: Center(
      child: Icon(
        Icons.folder_open_rounded,
        size: 42,
        color: colors.textDisabled,
      ),
    ),
  );
}
