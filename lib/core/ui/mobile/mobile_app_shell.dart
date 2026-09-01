import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/sidebar/sidebar.dart';
import 'package:modern_downloader/core/ui/widgets/mesh_gradient_background.dart';
import 'package:modern_downloader/core/ui/widgets/toast/custom_toast.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class MobileAppShell extends ConsumerWidget {
  final Widget child;

  const MobileAppShell({super.key, required this.child});

  int _indexFor(String location) {
    if (location.startsWith('/browse')) return 1;
    if (location.startsWith('/stats')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 1:
        context.go('/browse');
        break;
      case 2:
        context.go('/stats');
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
    final location = GoRouterState.of(context).uri.path;
    final mesh = colors.useMeshBackground;

    Widget chrome = Scaffold(
      backgroundColor: mesh ? Colors.transparent : colors.background,
      drawer: const Drawer(child: SafeArea(child: AppSidebar())),
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.86),
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.newDownload,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddDownloadDialog(),
              );
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (index) => _go(context, index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: l10n.mobileLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.travel_explore_outlined),
            selectedIcon: const Icon(Icons.travel_explore),
            label: l10n.browseX,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.statistics,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );

    if (mesh) {
      chrome = MeshGradientBackground(child: chrome);
    }

    return Stack(
      children: [
        chrome,
        if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen)))
          const Positioned.fill(child: MediaPlayerView()),
        const ToastOverlay(),
      ],
    );
  }
}
