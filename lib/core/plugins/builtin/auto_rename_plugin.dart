import 'dart:io';
import 'package:flutter/foundation.dart';
import '../plugin_interface.dart';

/// Built-in plugin: Auto-rename downloaded files by cleaning up filenames.
///
/// Removes common junk from filenames like resolution tags, IDs,
/// and excessive punctuation.
class AutoRenamePlugin extends DownloaderPlugin {
  @override
  String get id => 'builtin_auto_rename';

  @override
  String get name => 'Auto Rename';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Automatically clean up downloaded filenames by removing resolution tags, IDs, and excessive punctuation.';

  @override
  String get iconName => 'drive_file_rename_outline';

  @override
  bool get isBuiltIn => true;

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    if (event.filePath == null) return null;

    final file = File(event.filePath!);
    if (!await file.exists()) return null;

    final dir = file.parent.path;
    final ext = _getExtension(file.path);
    final baseName = _getBaseName(file.path);

    // Clean the filename
    String cleaned = baseName;

    // Remove resolution tags: [1080p], (720p), etc.
    cleaned = cleaned.replaceAll(RegExp(r'[\[\(]\d{3,4}p\d*[\]\)]'), '');

    // Remove common video IDs: [dQw4w9WgXcQ], (dQw4w9WgXcQ)
    cleaned = cleaned.replaceAll(RegExp(r'[\[\(][a-zA-Z0-9_-]{11}[\]\)]'), '');

    // Remove excessive hyphens/underscores at boundaries
    cleaned = cleaned.replaceAll(RegExp(r'[-_]{2,}'), ' ');

    // Remove leading/trailing whitespace and punctuation
    cleaned = cleaned.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[-_.\s]+|[-_.\s]+$'), '');

    if (cleaned.isEmpty || cleaned == baseName) return null;

    String finalPath = '$dir${Platform.pathSeparator}$cleaned$ext';
    if (await File(finalPath).exists() && finalPath != file.path) {
      int counter = 1;
      while (await File('$dir${Platform.pathSeparator}$cleaned ($counter)$ext').exists()) {
        counter++;
      }
      finalPath = '$dir${Platform.pathSeparator}$cleaned ($counter)$ext';
    }

    try {
      await file.rename(finalPath);
      debugPrint('[AutoRename] Renamed: $baseName → ${File(finalPath).uri.pathSegments.last}');

      // Rename matching sidecars if they exist
      final oldSidecars = [
        File('$dir${Platform.pathSeparator}$baseName.jpg'),
        File('$dir${Platform.pathSeparator}$baseName.webp'),
        File('$dir${Platform.pathSeparator}$baseName.en.vtt'),
        File('$dir${Platform.pathSeparator}$baseName.vtt'),
      ];
      final newBase = finalPath.substring(0, finalPath.length - ext.length);
      for (final sidecar in oldSidecars) {
        if (await sidecar.exists()) {
          final sidecarExt = _getExtension(sidecar.path);
          try {
            await sidecar.rename('$newBase$sidecarExt');
          } catch (_) {}
        }
      }

      return PluginModificationResult(newFilePath: finalPath);
    } catch (e) {
      debugPrint('[AutoRename] Failed to rename: $e');
      return null;
    }
  }

  String _getExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot);
  }

  String _getBaseName(String path) {
    final sep = path.lastIndexOf(Platform.pathSeparator);
    final dot = path.lastIndexOf('.');
    if (sep == -1 && dot == -1) return path;
    final start = sep == -1 ? 0 : sep + 1;
    final end = dot == -1 ? path.length : dot;
    return path.substring(start, end);
  }
}
