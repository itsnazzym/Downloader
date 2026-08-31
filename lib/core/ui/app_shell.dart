import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/providers/launch_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/services/hotkey_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/widgets/toast/custom_toast.dart';
import 'package:modern_downloader/core/ui/widgets/drag_drop_overlay.dart';
import 'package:modern_downloader/core/ui/widgets/floating_nav_dock.dart';
import 'package:modern_downloader/core/ui/widgets/mesh_gradient_background.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';
import 'package:modern_downloader/core/ui/widgets/resizable_width_pane.dart';
import 'sidebar/sidebar.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LaunchData?>(launchDataProvider, (previous, next) {
      if (next != null && !ref.read(dependencyBootstrapProvider).blocksUi) {
        _handleLaunchData(context, ref, next);
      }
    });

    ref.listen<DependencyBootstrapState>(dependencyBootstrapProvider, (
      previous,
      next,
    ) {
      if (previous?.isReady != true && next.isReady) {
        final pending = ref.read(launchDataProvider);
        if (pending != null) {
          _handleLaunchData(context, ref, pending);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (ref.read(dependencyBootstrapProvider).blocksUi) return;
      final initialData = ref.read(launchDataProvider);
      if (initialData != null) {
        _handleLaunchData(context, ref, initialData);
      }
    });

    final colors = AppColors.of(context);
    final location = GoRouterState.of(context).uri.path;
    final showDock = colors.useFloatingDock;
    final mesh = colors.useMeshBackground;
    final layout = ref.watch(paneLayoutProvider);
    final resizing = ref.watch(paneResizeActiveProvider);

    Widget chrome = Scaffold(
      backgroundColor: mesh ? Colors.transparent : colors.background,
      body: MouseRegion(
        cursor: resizing ? SystemMouseCursors.resizeColumn : MouseCursor.defer,
        child: Column(
          children: [
            const AppTitleBar(),
            Expanded(
              child: Row(
                children: [
                  ResizableWidthPane(
                    width: layout.visibleSidebarWidth,
                    minWidth: PaneLayout.sidebarRail,
                    maxWidth: PaneLayout.sidebarMax,
                    resizeFrom: PaneResizeFrom.trailing,
                    onWidthChanged: (width) {
                      ref
                          .read(paneLayoutProvider.notifier)
                          .setSidebarWidth(width);
                    },
                    onDragActive: (active) {
                      ref.read(paneResizeActiveProvider.notifier).state =
                          active;
                    },
                    onResizeEnd: () {
                      ref.read(paneResizeActiveProvider.notifier).state = false;
                      ref.read(paneLayoutProvider.notifier).commitSidebarDrag();
                      ref.read(paneLayoutProvider.notifier).persist();
                    },
                    onToggleCollapse: () {
                      ref
                          .read(paneLayoutProvider.notifier)
                          .toggleSidebarCollapsed();
                      ref.read(paneLayoutProvider.notifier).persist();
                    },
                    child: const AppSidebar(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: showDock ? 72 : 0),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (mesh) {
      chrome = MeshGradientBackground(child: chrome);
    }

    return HotkeyHandler(
      child: DragDropOverlay(
        child: Stack(
          children: [
            chrome,
            if (showDock) FloatingNavDock(currentLocation: location),
            if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen)))
              const Positioned.fill(child: MediaPlayerView()),
            const ToastOverlay(),
          ],
        ),
      ),
    );
  }

  void _handleLaunchData(BuildContext context, WidgetRef ref, LaunchData data) {
    // Clear the provider to prevent re-triggering
    ref.read(launchDataProvider.notifier).state = null;

    if (data.shouldAutoStart) {
      // Direct start for extensions
      ref
          .read(downloadListProvider.notifier)
          .startDownload(
            data.url,
            rawCookies: data.cookies,
            userAgent: data.userAgent,
            cookieBrowser: data.cookieBrowser,
            audioOnly: data.isAudioOnly ? true : null,
            preferredQuality: data.preferredQuality,
          );
      return;
    }

    // Show the dialog with the URL and cookies (Deep link fallback)
    showDialog(
      context: context,
      builder: (context) => AddDownloadDialog(
        initialUrl: data.url,
        initialCookies: data.cookies,
        userAgent: data.userAgent,
      ),
    );
  }
}

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // iOS chrome already blurs the sidebar; keep a single live BackdropFilter.
    final useTitleBlur = !colors.isIosChrome;
    Widget bar = Container(
      height: 32,
      color: colors.background.withValues(alpha: 0.78),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  '',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _WindowButton(
                  color: const Color(0xFFFFBD2E),
                  onTap: () async {
                    await windowManager.minimize();
                  },
                  icon: Icons.minimize,
                ),
                const SizedBox(width: 8),
                _WindowButton(
                  color: const Color(0xFF28C940),
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  icon: Icons.crop_square,
                ),
                const SizedBox(width: 8),
                _WindowButton(
                  color: const Color(0xFFFF5F57),
                  onTap: () async {
                    await windowManager.close();
                  },
                  icon: Icons.close,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!useTitleBlur) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: bar,
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  final IconData icon;

  const _WindowButton({
    required this.color,
    required this.onTap,
    required this.icon,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
          child: _isHovering
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 10,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
