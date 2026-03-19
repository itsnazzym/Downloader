import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';

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
                    color: AppColors.background.withValues(alpha: 0.8),
                    alignment: Alignment.center,
                    child:
                        Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 80,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Drop links or files here",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "They will be added to your download queue",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
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

  Future<void> _handleDrop(DropDoneDetails details) async {
    final urls = <String>{};

    for (final file in details.files) {
      final path = file.path.trim();
      if (_isHttpUrl(path)) {
        urls.add(path);
        continue;
      }

      if (path.toLowerCase().endsWith('.url')) {
        final extracted = await _extractUrlFromInternetShortcut(path);
        if (extracted != null) {
          urls.add(extracted);
        }
        continue;
      }

      if (path.toLowerCase().endsWith('.txt')) {
        urls.addAll(await _extractUrlsFromTextFile(path));
      }
    }

    for (final url in urls) {
      ref.read(downloadListProvider.notifier).startDownload(url);
    }
  }

  bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<String?> _extractUrlFromInternetShortcut(String path) async {
    try {
      final lines = await File(path).readAsLines();
      for (final line in lines) {
        if (line.startsWith('URL=')) {
          final url = line.substring(4).trim();
          if (_isHttpUrl(url)) {
            return url;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Set<String>> _extractUrlsFromTextFile(String path) async {
    final urls = <String>{};
    try {
      final lines = await File(path).readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (_isHttpUrl(trimmed)) {
          urls.add(trimmed);
        }
      }
    } catch (_) {}
    return urls;
  }
}
