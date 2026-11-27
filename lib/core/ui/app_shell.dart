import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/core/providers/launch_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/core/services/hotkey_service.dart';
import 'package:tapload/core/ui/media_player/media_player_view.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/widgets/drag_drop_overlay.dart';
import 'package:tapload/core/ui/widgets/floating_nav_dock.dart';
import 'package:tapload/core/ui/widgets/mesh_gradient_background.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/ui/layout/pane_layout_provider.dart';
import 'package:tapload/core/ui/widgets/resizable_width_pane.dart';
import 'package:tapload/core/ui/mobile/mobile_app_shell.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'shell/designed_chrome.dart';
import 'sidebar/sidebar.dart';
import 'window_chrome.dart';
import '../../features/onboarding/presentation/onboarding_overlay.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(pluginInstallRequestProvider, (previous, next) {
      if (next != null) _openPluginRequest(context, ref, next);
    });

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
      final pendingPlugin = ref.read(pluginInstallRequestProvider);
      if (pendingPlugin != null) {
        _openPluginRequest(context, ref, pendingPlugin);
      }
      if (ref.read(dependencyBootstrapProvider).blocksUi) return;
      final initialData = ref.read(launchDataProvider);
      if (initialData != null) {
        _handleLaunchData(context, ref, initialData);
      }
    });

    final colors = AppColors.of(context);
    final location = GoRouterState.of(context).uri.path;
    final showDock = colors.useFloatingDock && PlatformInfo.isDesktop;
    final mesh = colors.useMeshBackground;
    // Only the sidebar width: dragging the inspector must not rebuild the shell.
    final sidebarWidth = ref.watch(
      paneLayoutProvider.select((l) => l.visibleSidebarWidth),
    );
    final resizing = ref.watch(paneResizeActiveProvider);

    if (PlatformInfo.isMobile) {
      return MobileAppShell(child: child);
    }

    final design = DesignSpec.of(context);
    Widget chrome = design.nav != DesignNav.sidebar
        ? Scaffold(
            backgroundColor: colors.background,
            body: Column(
              children: [
                if (PlatformInfo.isDesktop) const AppTitleBar(),
                Expanded(child: designedChrome(design.nav, location, child)),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: mesh ? Colors.transparent : colors.background,
            body: MouseRegion(
              cursor: resizing
                  ? SystemMouseCursors.resizeColumn
                  : MouseCursor.defer,
              child: Column(
                children: [
                  if (PlatformInfo.isDesktop) const AppTitleBar(),
                  Expanded(
                    child: Row(
                      children: [
                        ResizableWidthPane(
                          width: sidebarWidth,
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
                            ref.read(paneResizeActiveProvider.notifier).state =
                                false;
                            ref
                                .read(paneLayoutProvider.notifier)
                                .commitSidebarDrag();
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

    if (mesh && design.nav == DesignNav.sidebar) {
      chrome = MeshGradientBackground(child: chrome);
    }

    return HotkeyHandler(
      child: DragDropOverlay(
        child: Stack(
          children: [
            chrome,
            if (showDock && design.nav == DesignNav.sidebar)
              FloatingNavDock(currentLocation: location),
            const OnboardingOverlay(),
            if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen)))
              const Positioned.fill(child: MediaPlayerView()),
          ],
        ),
      ),
    );
  }

  void _openPluginRequest(
    BuildContext context,
    WidgetRef ref,
    String pluginId,
  ) {
    ref.read(pluginInstallRequestProvider.notifier).state = null;
    context.go(
      '/settings/plugins?plugin=${Uri.encodeQueryComponent(pluginId)}',
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

    // One add dialog at a time: each copied link used to stack another one,
    // even while the window was hidden in the tray. A link that arrives
    // meanwhile is kept and offered once the open dialog closes.
    if (_addDialogOpen) {
      _pendingLaunch = data;
      return;
    }
    _addDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => AddDownloadDialog(
        initialUrl: data.url,
        initialCookies: data.cookies,
        userAgent: data.userAgent,
      ),
    ).whenComplete(() {
      _addDialogOpen = false;
      final next = _pendingLaunch;
      _pendingLaunch = null;
      // Re-publishing it runs the launchDataProvider listener again.
      if (next != null) ref.read(launchDataProvider.notifier).state = next;
    });
  }

  static bool _addDialogOpen = false;
  static LaunchData? _pendingLaunch;
}

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  static const double height = WindowChrome.titleBarHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // No BackdropFilter: the bar sits above the content in a Column, so a blur
    // only re-sampled the solid window colour each frame (GPU cost, no effect).
    return Container(
      height: WindowChrome.titleBarHeight,
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
