import 'dart:io';
import 'package:path/path.dart' as p;

import '../plugin_interface.dart';

class DuplicateGuardPlugin extends DownloaderPlugin {
  @override
  String get id => 'builtin_duplicate_guard';

  @override
  String get name => 'Duplicate Guard';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Blocks duplicate downloads by checking active jobs, history, and files already present on disk.';

  @override
  String get iconName => 'content_copy';

  @override
  Future<PluginPreDownloadResult?> onBeforeDownload(
    PluginDownloadEvent event,
  ) async {
    final normalizedUrl = _normalizeUrl(event.url);
    final metadataId = _extractMetadataId(event.sourceMetadata);

    for (final download in event.existingDownloads) {
      if (download.downloadId == event.downloadId) {
        continue;
      }

      if (_isTerminalFailure(download.status)) {
        continue;
      }

      if (_normalizeUrl(download.url) == normalizedUrl) {
        return PluginPreDownloadResult(
          shouldCancel: true,
          isDuplicate: true,
          message: 'Duplicate URL already present in the queue or history.',
          existingFilePath: download.filePath,
        );
      }

      if (metadataId != null &&
          (_pathContainsId(download.filePath, metadataId) ||
              _titleContainsId(download.title, metadataId))) {
        return PluginPreDownloadResult(
          shouldCancel: true,
          isDuplicate: true,
          message: 'A video with the same extractor ID already exists.',
          existingFilePath: download.filePath,
        );
      }
    }

    if (metadataId != null && event.outputDirectory != null) {
      final existing = await _findExistingFile(
        event.outputDirectory!,
        metadataId,
      );
      if (existing != null) {
        return PluginPreDownloadResult(
          shouldCancel: true,
          isDuplicate: true,
          message: 'A matching file already exists on disk.',
          existingFilePath: existing,
        );
      }
    }

    return null;
  }

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final sortedKeys = uri.queryParameters.keys.toList()..sort();
      final query = {
        for (final key in sortedKeys)
          if (!const {'feature', 'si'}.contains(key))
            key: uri.queryParameters[key]!,
      };
      return uri.replace(fragment: '', queryParameters: query).toString();
    } catch (_) {
      return url.trim();
    }
  }

  String? _extractMetadataId(Map<String, dynamic>? metadata) {
    final value = metadata?['id'];
    if (value == null) {
      return null;
    }
    final id = value.toString().trim();
    return id.isEmpty ? null : id;
  }

  bool _pathContainsId(String? filePath, String metadataId) {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }
    return p.basenameWithoutExtension(filePath).contains('[$metadataId]');
  }

  bool _titleContainsId(String? title, String metadataId) {
    if (title == null || title.isEmpty) {
      return false;
    }
    return title.contains(metadataId);
  }

  bool _isTerminalFailure(String status) {
    return status == 'failed' || status == 'canceled';
  }

  Future<String?> _findExistingFile(
    String outputDirectory,
    String metadataId,
  ) async {
    final directory = Directory(outputDirectory);
    if (!await directory.exists()) {
      return null;
    }

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final basename = p.basenameWithoutExtension(entity.path);
      if (basename.contains('[$metadataId]')) {
        return entity.path;
      }
    }

    return null;
  }
}
