import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';

/// Import and browser-sync entry point for the local TikTok library.
class ArchiveHubView extends ConsumerWidget {
  const ArchiveHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final isShowcase = ref.watch(showcaseModeProvider);
    final isConnected =
        !isShowcase && ref.watch(extensionConnectedClientsProvider) > 0;
    final catalog = state.catalog;
    final hasCatalog = state.hasCatalog;
    final isSyncing = state.syncStatus == TikTokSyncStatus.waiting;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archive TikTok',
                    style: AppTypography.h2.copyWith(color: colors.textPrimary),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    'Importe la liste de tes favoris TikTok, retrouve une vidéo par collection ou recherche, puis '
                    'lance son téléchargement quand tu en as besoin. Cette page ne télécharge rien toute seule.',
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (hasCatalog) ...[
                    const Gap(AppSpacing.l),
                    _LibrarySummary(
                      colors: colors,
                      videoCount: catalog!.videos.length,
                      collectionCount: catalog.collections.length,
                      onOpen: () =>
                          notifier.setViewMode(TikTokViewMode.collections),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const Gap(AppSpacing.m),
                    _InlineNotice(
                      colors: colors,
                      message: state.errorMessage!,
                      isError: true,
                    ),
                  ],
                  const Gap(AppSpacing.l),
                  _ActionSection(
                    colors: colors,
                    icon: Icons.folder_open_outlined,
                    title: 'Importer un export TikTok',
                    description:
                        'Choisis le fichier JSON exporté depuis TikTok pour charger tes favoris et tes mentions J’aime.',
                    child: FilledButton.icon(
                      onPressed: isShowcase
                          ? null
                          : () => notifier.pickAndImportFile(),
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Choisir un fichier JSON'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.m),
                  _ActionSection(
                    colors: colors,
                    icon: Icons.sync_rounded,
                    title: 'Synchroniser les collections',
                    description: isConnected
                        ? 'L’extension récupère les vidéos associées à tes collections depuis une page TikTok ouverte.'
                        : 'Ouvre TikTok dans un navigateur où l’extension Modern Downloader est installée, puis reviens ici.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: !isShowcase && isConnected && !isSyncing
                              ? notifier.triggerExtensionSync
                              : null,
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(
                            isSyncing
                                ? 'Synchronisation en cours…'
                                : 'Synchroniser mes collections',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                        if (state.syncStatus == TikTokSyncStatus.waiting) ...[
                          const Gap(AppSpacing.s),
                          LinearProgressIndicator(
                            color: colors.primary,
                            backgroundColor: colors.surfaceHighlight,
                          ),
                          const Gap(AppSpacing.xs),
                          Text(
                            'En attente de la réponse du navigateur. Garde une page TikTok ouverte.',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ] else if (state.syncMessage != null) ...[
                          const Gap(AppSpacing.s),
                          _InlineNotice(
                            colors: colors,
                            message: state.syncMessage!,
                            isError:
                                state.syncStatus == TikTokSyncStatus.failed,
                            isWarning:
                                state.syncStatus == TikTokSyncStatus.partial,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.m),
                  Text(
                    'La synchronisation est manuelle. Pour actualiser tes collections, garde TikTok ouvert dans le navigateur et relance-la ici.',
                    style: AppTypography.caption.copyWith(
                      color: colors.textDisabled,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.colors,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final AppColors colors;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const Gap(AppSpacing.s),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h3.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const Gap(AppSpacing.m),
          child,
        ],
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.colors,
    required this.videoCount,
    required this.collectionCount,
    required this.onOpen,
  });

  final AppColors colors;
  final int videoCount;
  final int collectionCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: colors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$videoCount vidéos · $collectionCount collections',
              style: AppTypography.body.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('Ouvrir')),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.colors,
    required this.message,
    required this.isError,
    this.isWarning = false,
  });

  final AppColors colors;
  final String message;
  final bool isError;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? colors.error
        : isWarning
        ? const Color(0xFFF59E0B)
        : colors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}
