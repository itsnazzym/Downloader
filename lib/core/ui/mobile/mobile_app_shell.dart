import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/app_typography.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/widgets/mesh_gradient_background.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/mobile_add_download_sheet.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class MobileAppShell extends ConsumerWidget {
  final Widget child;

  const MobileAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final hasSelection = ref.watch(selectedDownloadIdProvider) != null;
    final location = GoRouterState.of(context).uri.path;
    final features = ref.watch(featureActivationProvider);
    final featureCatalog = ref.watch(featureCatalogProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isFr = locale == 'fr';
    final destinations = <_MobileNavigationDestination>[
      _MobileNavigationDestination(
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        label: isFr ? 'Vidéos' : 'Library',
        route: '/',
      ),
      if (features.isEnabledById('x_browser'))
        _MobileNavigationDestination(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore,
          label: isFr ? 'Navigateur' : 'Browse',
          route: '/browse',
        ),
      if (features.isEnabledById('statistics'))
        _MobileNavigationDestination(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart_rounded,
          label: 'Stats',
          route: '/stats',
        ),
      if (features.isEnabledById('device_transfer'))
        _MobileNavigationDestination(
          icon: Icons.ios_share_outlined,
          selectedIcon: Icons.ios_share,
          label: isFr ? 'Transfert' : 'Transfer',
          route: '/transfer',
        ),
      if (features.isEnabledById('tiktok_archives'))
        _MobileNavigationDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: 'TikTok',
          route: '/archive',
        ),
      _MobileNavigationDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: isFr ? 'Réglages' : 'Settings',
        route: '/settings',
      ),
    ];
    final matchedDestination = destinations.indexWhere(
      (destination) => destination.matches(location),
    );
    final selectedDestination = matchedDestination >= 0
        ? matchedDestination
        : destinations.length - 1;
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
                    MobileAddDownloadSheet.show(context);
                  },
                  icon: const Icon(Icons.add_link_rounded),
                ),
              ],
            )
          : null,
      body: child,
      floatingActionButton: (isLibraryRoot && !hasSelection)
          ? FloatingActionButton(
              heroTag: 'mobile_add_download_fab',
              onPressed: () {
                HapticFeedback.mediumImpact();
                MobileAddDownloadSheet.show(context);
              },
              backgroundColor: colors.accent,
              foregroundColor: colors.onPrimary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, size: 28),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
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
          NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 62,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.2,
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: selectedDestination,
              onDestinationSelected: (index) {
                HapticFeedback.selectionClick();
                context.go(destinations[index].route);
              },
              destinations: destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: destination.route == '/' && counts.active > 0
                          ? Badge.count(
                              count: counts.active,
                              backgroundColor: colors.primary,
                              textColor: colors.onPrimary,
                              child: Icon(destination.icon, size: 22),
                            )
                          : Icon(destination.icon, size: 22),
                      selectedIcon: destination.route == '/' && counts.active > 0
                          ? Badge.count(
                              count: counts.active,
                              backgroundColor: colors.primary,
                              textColor: colors.onPrimary,
                              child: Icon(destination.selectedIcon, size: 22),
                            )
                          : Icon(destination.selectedIcon, size: 22),
                      label: destination.label,
                    ),
                  )
                  .toList(),
            ),
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

class _MobileNavigationDestination {
  const _MobileNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  bool matches(String location) => route == '/'
      ? location == '/'
      : location == route || location.startsWith('$route/');
}
