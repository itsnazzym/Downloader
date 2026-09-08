import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/app_typography.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/widgets/mesh_gradient_background.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class MobileAppShell extends ConsumerWidget {
  final Widget child;

  const MobileAppShell({super.key, required this.child});

  int _indexFor(String location) {
    if (location.startsWith('/browse')) return 1;
    if (location.startsWith('/transfer')) return 2;
    if (location.startsWith('/settings') || location.startsWith('/stats')) {
      return 3;
    }
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 1:
        context.go('/browse');
        break;
      case 2:
        context.go('/transfer');
        break;
      case 3:
        context.go('/settings');
        break;
      default:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final location = GoRouterState.of(context).uri.path;
    final mesh = colors.useMeshBackground;
    final isLibraryRoot = location == '/';

    Widget chrome = Scaffold(
      backgroundColor: mesh ? Colors.transparent : colors.background,
      appBar: isLibraryRoot
          ? AppBar(
              backgroundColor: colors.surface.withValues(alpha: 0.86),
              elevation: 0,
              scrolledUnderElevation: 2,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.accent,
                          colors.accent.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      if (counts.total > 0)
                        Text(
                          '${counts.total} ${counts.total == 1 ? "élément" : "éléments"}${counts.active > 0 ? " • ${counts.active} en cours" : ""}',
                          style: AppTypography.mono.copyWith(
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.newDownload,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showDialog(
                      context: context,
                      builder: (context) => const AddDownloadDialog(),
                    );
                  },
                  icon: const Icon(Icons.add_link_rounded),
                ),
              ],
            )
          : null,
      body: child,
      floatingActionButton: isLibraryRoot
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                showDialog(
                  context: context,
                  builder: (context) => const AddDownloadDialog(),
                );
              },
              backgroundColor: colors.accent,
              foregroundColor: colors.onPrimary,
              elevation: 3,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                l10n.newDownload,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Studio Capsule when active downloads exist
          if (counts.active > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(downloadStatusFilterProvider.notifier).state =
                        DownloadStatusFilter.active;
                    if (!isLibraryRoot) {
                      context.go('/');
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${counts.active} ${counts.active == 1 ? "téléchargement actif" : "téléchargements actifs"}',
                          style: AppTypography.mono.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Afficher',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          NavigationBar(
            selectedIndex: _indexFor(location),
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              _go(context, index);
            },
            destinations: [
              NavigationDestination(
                icon: counts.active > 0
                    ? Badge.count(
                        count: counts.active,
                        backgroundColor: colors.primary,
                        textColor: colors.onPrimary,
                        child: const Icon(Icons.video_library_outlined),
                      )
                    : const Icon(Icons.video_library_outlined),
                selectedIcon: counts.active > 0
                    ? Badge.count(
                        count: counts.active,
                        backgroundColor: colors.primary,
                        textColor: colors.onPrimary,
                        child: const Icon(Icons.video_library),
                      )
                    : const Icon(Icons.video_library),
                label: l10n.mobileLibrary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.travel_explore_outlined),
                selectedIcon: const Icon(Icons.travel_explore),
                label: l10n.browseX,
              ),
              NavigationDestination(
                icon: const Icon(Icons.ios_share_outlined),
                selectedIcon: const Icon(Icons.ios_share),
                label: l10n.transferTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.settings,
              ),
            ],
          ),
        ],
      ),
    );

    if (mesh) {
      chrome = MeshGradientBackground(child: chrome);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(mediaPlayerProvider).isOpen) {
          ref.read(mediaPlayerProvider.notifier).close();
          return;
        }
        if (!isLibraryRoot) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/');
          }
          return;
        }
        SystemNavigator.pop();
      },
      child: Stack(
        children: [
          chrome,
          if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen)))
            const Positioned.fill(child: MediaPlayerView()),
        ],
      ),
    );
  }
}
