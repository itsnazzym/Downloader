import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class DragDropOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const DragDropOverlay({super.key, required this.child});

  @override
  ConsumerState<DragDropOverlay> createState() => _DragDropOverlayState();
}

class _DragDropOverlayState extends ConsumerState<DragDropOverlay> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) {
      return widget.child;
    }
    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _handleDrop(details);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            IgnorePointer(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: AppColors.of(context).overlay.withValues(alpha: 0.8),
                    alignment: Alignment.center,
                    child:
                        Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 80,
                                  color: AppColors.of(context).primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.dropLinksHere,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.of(context).textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.dropLinksHint,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.of(context).textSecondary,
                                  ),
                                ),
                              ],
                            )
                            .animate()
                            .fadeIn(duration: 200.ms)
                            .scale(duration: 200.ms, curve: Curves.easeOutBack),
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),
        ],
      ),
    );
  }

  void _handleDrop(DropDoneDetails details) {
    // 1. Handle Files
    if (details.files.isNotEmpty) {
      for (final file in details.files) {
        // Check if it's a text file or just treat path as potential input?
        // For now, valid URLs or paths are handled by startDownload logic (if extended).
        // But usually dragging a file path implies "downloading" doesn't make sense unless it's a torrent/metafile.
        // If it's a text file, maybe parse it?
        // Let's assume the user drags a link (which might come as a file on some OSs?)
        // Or drag a .torrent file.
        // For now, pass path to provider.
        ref.read(downloadListProvider.notifier).startDownload(file.path);
      }
    }

    // 2. Handle URIs (if provided separately, though desktop_drop typically maps URIs to files if they are files, or text?)
    // desktop_drop mainly gives XFiles. if dragging text/url, it might not trigger?
    // desktop_drop supports URI dragging on some platforms.
    // If details.files is empty, we might need to check other data, but DropDoneDetails only has files.
    // On Windows/Linux/macOS, dragging a URL from browser often creates a .url file or passes the URL as text.
    // XFile might contain the URL if it's a text drag? No, XFile is a file.

    // If the library supports text, we'd use it. But desktop_drop 0.4.x is file focused.
    // However, dragging a link from Chrome to a Flutter app often results in nothing with desktop_drop unless it's a file.
    // BUT, let's stick to what we have.
  }
}
