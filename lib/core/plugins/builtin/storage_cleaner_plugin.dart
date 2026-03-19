import 'dart:io';

import 'package:path/path.dart' as p;

import '../../logger/logger_service.dart';
import '../plugin_interface.dart';

class StorageCleanerPlugin extends DownloaderPlugin {
  static const _maxAge = Duration(hours: 24);

  @override
  String get id => 'builtin_storage_cleaner';

  @override
  String get name => 'Storage Cleaner';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Removes stale temp files, leftover cookies, and download artifacts after jobs finish.';

  @override
  String get iconName => 'cleaning_services';

  @override
  Future<void> onInit() async {
    await _cleanupSystemTemp();
  }

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    await _cleanupForEvent(event);
    return null;
  }

  @override
  Future<void> onDownloadFailed(PluginDownloadEvent event) async {
    await _cleanupForEvent(event);
  }

  Future<void> _cleanupForEvent(PluginDownloadEvent event) async {
    final directories = <String>{
      if (event.outputDirectory != null && event.outputDirectory!.isNotEmpty)
        event.outputDirectory!,
      if (event.filePath != null && event.filePath!.isNotEmpty)
        p.dirname(event.filePath!),
    };

    final baseName = event.filePath == null || event.filePath!.isEmpty
        ? null
        : p.basenameWithoutExtension(event.filePath!);

    for (final directoryPath in directories) {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        continue;
      }

      await for (final entity in directory.list(recursive: false)) {
        if (entity is! File) {
          continue;
        }

        final name = p.basename(entity.path);
        final lower = name.toLowerCase();
        final matchesBase = baseName == null
            ? false
            : p.basenameWithoutExtension(name).contains(baseName);

        final isTemp =
            lower.endsWith('.part') ||
            lower.endsWith('.ytdl') ||
            lower.endsWith('.aria2') ||
            lower.endsWith('.temp') ||
            lower.endsWith('.tmp') ||
            lower.contains('.f');

        final isStale = await _isOlderThan(entity, _maxAge);
        if ((matchesBase && isTemp) || (isTemp && isStale)) {
          try {
            await entity.delete();
          } catch (e) {
            LoggerService.w(
              '[StorageCleaner] Failed to delete ${entity.path}: $e',
            );
          }
        }
      }
    }
  }

  Future<void> _cleanupSystemTemp() async {
    final tempDir = Directory.systemTemp;
    if (!await tempDir.exists()) {
      return;
    }

    await for (final entity in tempDir.list(recursive: false)) {
      if (entity is! File) {
        continue;
      }

      final name = p.basename(entity.path).toLowerCase();
      if (!name.startsWith('md_cookies_') || !name.endsWith('.txt')) {
        continue;
      }

      if (!await _isOlderThan(entity, _maxAge)) {
        continue;
      }

      try {
        await entity.delete();
      } catch (e) {
        LoggerService.w(
          '[StorageCleaner] Failed to delete stale cookie file: $e',
        );
      }
    }
  }

  Future<bool> _isOlderThan(File file, Duration maxAge) async {
    try {
      final stat = await file.stat();
      return DateTime.now().difference(stat.modified) > maxAge;
    } catch (_) {
      return false;
    }
  }
}
