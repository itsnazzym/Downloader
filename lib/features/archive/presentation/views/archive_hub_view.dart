import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_video_cache_provider.dart';

/// Central Hub for Archives & Imports management.
/// Provides real-time synchronization with browser extension, catalog stats,
/// and quick launch cards for all browsing modes (Folders, Feed, Tinder, Grid).
class ArchiveHubView extends ConsumerStatefulWidget {
  const ArchiveHubView({super.key});

  @override
  ConsumerState<ArchiveHubView> createState() => _ArchiveHubViewState();
}

class _ArchiveHubViewState extends ConsumerState<ArchiveHubView> {
  int _cachedFilesCount = 0;
  int _cacheSizeBytes = 0;
  bool _isLoadingCache = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheStats();
  }

  Future<void> _refreshCacheStats() async {
    if (!mounted) return;
    setState(() => _isLoadingCache = true);
    try {
      final controller = ref.read(tiktokPreloadControllerProvider);
      final count = await controller.getCachedVideosCount();
      final size = await controller.getCacheSizeBytes();
      if (mounted) {
        setState(() {
          _cachedFilesCount = count;
          _cacheSizeBytes = size;
          _isLoadingCache = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCache = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _triggerSync() {
    final clientCount = ref.read(extensionConnectedClientsProvider);
    if (clientCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Extension non détectée. Veuillez vous assurer que votre navigateur est ouvert avec l\'extension connectée.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    ref.read(tikTokArchiveProvider.notifier).triggerExtensionSync();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demande de synchronisation envoyée à l\'extension ! Ouvrez TikTok Web si nécessaire pour finaliser.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    });
  }

  Future<void> _confirmClearCache() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Vider le cache vidéo', style: AppTypography.h3),
        content: Text(
          'Voulez-vous supprimer les $_cachedFilesCount vidéos en cache (${_formatBytes(_cacheSizeBytes)}) ? Les métadonnées de vos collections seront conservées.',
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
            child: const Text('Vider le cache'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tikTokArchiveProvider.notifier).clearVideoCache();
      await _refreshCacheStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache vidéo vidé avec succès.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final connectedClients = ref.watch(extensionConnectedClientsProvider);
    final isConnected = connectedClients > 0;
    final catalog = state.catalog;
    final hasCatalog = catalog != null && catalog.videos.isNotEmpty;

    const defaultPath = r'C:\Users\entre\Downloads\tiktok_data\user_data_tiktok.json';
    final defaultExists = File(defaultPath).existsSync();

    // Stats calculations
    final totalVideos = catalog?.videos.length ?? 0;
    int classifiedCount = 0;
    int unclassifiedCount = 0;
    if (catalog != null) {
      for (final v in catalog.videos) {
        if (v.collectionName != null) {
          classifiedCount++;
        } else if (v.isFavorite) {
          unclassifiedCount++;
        }
      }
    }
    final collectionsCount = catalog?.collections
            .where((c) => c.name != 'Favoris non classés' && c.name != 'Vidéos Likées')
            .length ??
        0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header & Hero Bar
                _buildHeader(
                  colors: colors,
                  isConnected: isConnected,
                  onSync: _triggerSync,
                  isSyncing: _isSyncing,
                ),

                const Gap(AppSpacing.l),

                // Error Message if any
                if (state.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
                        const Gap(AppSpacing.s),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: AppTypography.body.copyWith(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.m),
                ],

                // 2. Navigation Modes Cards (4 Modes)
                Text(
                  'Modes de Visionnage & Tri',
                  style: AppTypography.h3.copyWith(color: colors.textPrimary),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  'Choisissez votre façon préférée de parcourir et trier vos favoris',
                  style: AppTypography.caption.copyWith(color: colors.textSecondary),
                ),
                const Gap(AppSpacing.m),

                _buildModesGrid(
                  colors: colors,
                  hasCatalog: hasCatalog,
                  onSelectMode: (mode) => notifier.setViewMode(mode),
                  collectionsCount: collectionsCount,
                  totalVideos: totalVideos,
                ),

                const Gap(AppSpacing.xl),

                // 3. Central Data Hub (Import & Extension Sync)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: TikTok Source & Sync Manager
                    Expanded(
                      flex: 3,
                      child: _buildTikTokSourceCard(
                        colors: colors,
                        hasCatalog: hasCatalog,
                        defaultExists: defaultExists,
                        defaultPath: defaultPath,
                        totalVideos: totalVideos,
                        classifiedCount: classifiedCount,
                        unclassifiedCount: unclassifiedCount,
                        collectionsCount: collectionsCount,
                        totalHeuristicVideos: catalog?.collections.fold<int>(
                              0,
                              (sum, c) => sum + (c.heuristicCount ?? 0),
                            ) ??
                            0,
                        heuristicCollectionsCount: catalog?.collections
                                .where((c) => (c.heuristicCount ?? 0) > 0)
                                .length ??
                            0,
                        isConnected: isConnected,
                        onFastLoad: () => notifier.importFromPath(defaultPath),
                        onPickFile: () => notifier.pickAndImportFile(),
                        onImportMapping: () => notifier.importCollectionsMappingFromFile(),
                        onSyncExtension: _triggerSync,
                      ),
                    ),

                    const Gap(AppSpacing.l),

                    // Right Column: Cache & Metrics + Upcoming Platforms
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildCacheMetricsCard(
                            colors: colors,
                            cachedFilesCount: _cachedFilesCount,
                            cacheSizeBytes: _cacheSizeBytes,
                            isLoading: _isLoadingCache,
                            onRefresh: _refreshCacheStats,
                            onClearCache: _confirmClearCache,
                            onDownloadAll: hasCatalog
                                ? () => notifier.downloadBatch(catalog.videos, limit: 100)
                                : null,
                          ),
                          const Gap(AppSpacing.m),
                          _buildUpcomingPlatformsCard(colors: colors),
                        ],
                      ),
                    ),
                  ],
                ),

                const Gap(AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required AppColors colors,
    required bool isConnected,
    required VoidCallback onSync,
    required bool isSyncing,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surface,
            colors.surface.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5DD3), Color(0xFFFE2C55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Gap(AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Archives & Imports',
                      style: AppTypography.h2.copyWith(color: colors.textPrimary),
                    ),
                    const Gap(AppSpacing.s),
                    _buildExtensionBadge(colors, isConnected),
                  ],
                ),
                const Gap(AppSpacing.xs),
                Text(
                  'Gérez vos exports de réseaux sociaux, synchronisez vos playlists exactes et explorez hors-ligne.',
                  style: AppTypography.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.m),
          FilledButton.icon(
            onPressed: isSyncing ? null : onSync,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE2C55),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
              isSyncing ? 'Synchronisation...' : 'Synchroniser avec TikTok Web',
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionBadge(AppColors colors, bool isConnected) {
    final statusColor = isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(6),
          Text(
            isConnected ? 'Extension active' : 'Extension en attente',
            style: AppTypography.caption.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModesGrid({
    required AppColors colors,
    required bool hasCatalog,
    required void Function(TikTokViewMode) onSelectMode,
    required int collectionsCount,
    required int totalVideos,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth > 800 ? 1.25 : 1.15,
          children: [
            _buildModeCard(
              colors: colors,
              title: 'Dossiers & Collections',
              description: 'Navigation par répertoires de vos vraies playlists TikTok.',
              badge: hasCatalog ? '$collectionsCount dossiers' : null,
              icon: Icons.folder_special_rounded,
              gradientColors: [const Color(0xFF6C5DD3), const Color(0xFF8B5CF6)],
              isEnabled: hasCatalog,
              onTap: () => onSelectMode(TikTokViewMode.collections),
            ),
            _buildModeCard(
              colors: colors,
              title: 'Feed Vidéo TikTok',
              description: 'Scroll vertical infini plein écran avec préchargement vidéo.',
              badge: hasCatalog ? '$totalVideos vidéos' : null,
              icon: Icons.view_carousel_rounded,
              gradientColors: [const Color(0xFFFE2C55), const Color(0xFFFF5277)],
              isEnabled: hasCatalog,
              onTap: () => onSelectMode(TikTokViewMode.feed),
            ),
            _buildModeCard(
              colors: colors,
              title: 'Mode Tinder (Swipe)',
              description: 'Swipez à gauche ou à droite pour trier vos vidéos préférées.',
              badge: 'Interactif',
              icon: Icons.swipe_rounded,
              gradientColors: [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
              isEnabled: hasCatalog,
              onTap: () => onSelectMode(TikTokViewMode.tinder),
            ),
            _buildModeCard(
              colors: colors,
              title: 'Grille & Filtres',
              description: 'Vue catalogue complète avec filtres par année et recherche.',
              badge: 'Avancé',
              icon: Icons.grid_view_rounded,
              gradientColors: [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
              isEnabled: hasCatalog,
              onTap: () => onSelectMode(TikTokViewMode.list),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeCard({
    required AppColors colors,
    required String title,
    required String description,
    required String? badge,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradientColors[0].withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: AppTypography.caption.copyWith(
                            color: gradientColors[0],
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: isEnabled ? colors.textPrimary : colors.textDisabled,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(4),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: isEnabled ? colors.textSecondary : colors.textDisabled,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(8),
                Row(
                  children: [
                    Text(
                      isEnabled ? 'Ouvrir ce mode' : 'Importez un catalogue',
                      style: AppTypography.caption.copyWith(
                        color: isEnabled ? gradientColors[0] : colors.textDisabled,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: isEnabled ? gradientColors[0] : colors.textDisabled,
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

  Widget _buildTikTokSourceCard({
    required AppColors colors,
    required bool hasCatalog,
    required bool defaultExists,
    required String defaultPath,
    required int totalVideos,
    required int classifiedCount,
    required int unclassifiedCount,
    required int collectionsCount,
    required int totalHeuristicVideos,
    required int heuristicCollectionsCount,
    required bool isConnected,
    required VoidCallback onFastLoad,
    required VoidCallback onPickFile,
    required VoidCallback onImportMapping,
    required VoidCallback onSyncExtension,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE2C55).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_video_rounded, color: Color(0xFFFE2C55), size: 20),
              ),
              const Gap(AppSpacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archive TikTok (Export RGPD + Extension)',
                    style: AppTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hasCatalog
                        ? 'Catalogue actif ($totalVideos vidéos indexées)'
                        : 'Aucune archive importée actuellement',
                    style: AppTypography.caption.copyWith(
                      color: hasCatalog ? const Color(0xFF10B981) : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Gap(AppSpacing.m),

          // Explanatory Note on Exact Sync
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: colors.primary, size: 18),
                const Gap(AppSpacing.s),
                Expanded(
                  child: Text(
                    'L\'export officiel TikTok ne contenant pas l\'association directe vidéo ↔ collection, l\'extension Modern Downloader synchronise automatiquement vos collections exactes depuis TikTok Web en temps réel.',
                    style: AppTypography.caption.copyWith(color: colors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.m),

          // Stats Counters if catalog loaded
          if (hasCatalog) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Vidéos totales', '$totalVideos', colors.textPrimary),
                  _buildStatDivider(colors),
                  _buildStatItem('Dans collections', '$classifiedCount', const Color(0xFF10B981)),
                  _buildStatDivider(colors),
                  _buildStatItem('Favoris non classés', '$unclassifiedCount', const Color(0xFFF59E0B)),
                  _buildStatDivider(colors),
                  _buildStatItem('Collections réelles', '$collectionsCount', const Color(0xFF6C5DD3)),
                ],
              ),
            ),
            if (totalHeuristicVideos > 0) ...[
              const Gap(AppSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF10B981), size: 18),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        '$totalHeuristicVideos vidéos complétées par ancrage chronologique strict dans $heuristicCollectionsCount collections.',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap(AppSpacing.m),
          ],

          // Actions Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (defaultExists)
                FilledButton.icon(
                  onPressed: onFastLoad,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Charger C:\\Users\\...\\tiktok_data'),
                ),
              OutlinedButton.icon(
                onPressed: onPickFile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Sélectionner user_data_tiktok.json'),
              ),
              OutlinedButton.icon(
                onPressed: onImportMapping,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Importer mapping JSON'),
              ),
              FilledButton.tonalIcon(
                onPressed: onSyncExtension,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                label: const Text('Synchroniser via Extension'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h3.copyWith(color: valueColor, fontWeight: FontWeight.bold),
        ),
        const Gap(2),
        Text(
          label,
          style: AppTypography.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStatDivider(AppColors colors) {
    return Container(
      width: 1,
      height: 28,
      color: colors.borderSubtle,
    );
  }

  Widget _buildCacheMetricsCard({
    required AppColors colors,
    required int cachedFilesCount,
    required int cacheSizeBytes,
    required bool isLoading,
    required VoidCallback onRefresh,
    required VoidCallback onClearCache,
    required VoidCallback? onDownloadAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stockage & Cache Vidéo',
                style: AppTypography.body.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Actualiser les métriques',
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
          const Gap(AppSpacing.s),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? 'Calcul...' : _formatBytes(cacheSizeBytes),
                      style: AppTypography.h3.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      '$cachedFilesCount vidéos préchargées hors-ligne',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
                Icon(
                  Icons.save_outlined,
                  color: colors.primary.withValues(alpha: 0.6),
                  size: 28,
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cachedFilesCount > 0 ? onClearCache : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Vider le cache'),
                ),
              ),
              if (onDownloadAll != null) ...[
                const Gap(AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDownloadAll,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Télécharger (100)'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPlatformsCard({required AppColors colors}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Autres Plateformes Prévues',
            style: AppTypography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(AppSpacing.s),
          _buildPlatformItem(
            name: 'Instagram',
            detail: 'Favoris & Collections enregistrées',
            icon: Icons.camera_alt_outlined,
            colors: colors,
          ),
          const Gap(AppSpacing.xs),
          _buildPlatformItem(
            name: 'YouTube',
            detail: 'Playlists & À regarder plus tard',
            icon: Icons.play_circle_outline_rounded,
            colors: colors,
          ),
          const Gap(AppSpacing.xs),
          _buildPlatformItem(
            name: 'X / Twitter',
            detail: 'Signets (Bookmarks) & Likes',
            icon: Icons.alternate_email_rounded,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformItem({
    required String name,
    required String detail,
    required IconData icon,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const Gap(AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: AppTypography.caption.copyWith(
                    color: colors.textDisabled,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Text(
              'Bientôt',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
