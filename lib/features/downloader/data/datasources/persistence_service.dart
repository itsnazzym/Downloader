import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:tapload/core/logger/logger_service.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:path_provider/path_provider.dart';
import 'download_queue_codec.dart';

/// JSON encoding a multi-thousand-item library is CPU intensive. Keep it off
/// the Flutter UI isolate so download progress never stalls input or frames.
Future<String> encodeDownloadsInBackground(List<DownloadItem> downloads) {
  return Isolate.run(() => _encodeDownloads(downloads));
}

String _encodeDownloads(List<DownloadItem> downloads) {
  return jsonEncode([for (final download in downloads) download.toJson()]);
}

Future<List<DownloadItem>> _decodeDownloadsInBackground(String source) {
  return Isolate.run(() {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((entry) => DownloadItem.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  });
}

class PersistenceService {
  static const String _fileName = 'downloads_v1.json';
  static const String _mediaFingerprintFileName = 'media_fingerprints_v1.json';

  Future<void> saveDownloads(List<DownloadItem> downloads) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final jsonString = await encodeDownloadsInBackground(downloads);
      await _atomicWrite(file, jsonString);
      LoggerService.debug('Saved ${downloads.length} downloads to disk.');
    } catch (e) {
      LoggerService.e('Failed to save downloads', e);
    }
  }

  Future<List<DownloadItem>> loadDownloads() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final bakFile = File('${dir.path}/$_fileName.bak');

      File effectiveFile = file;
      if (!await file.exists()) {
        if (await bakFile.exists()) {
          LoggerService.w(
            'Primary downloads file missing, recovering from backup: ${bakFile.path}',
          );
          effectiveFile = bakFile;
        } else {
          LoggerService.i('No saved downloads found.');
          return [];
        }
      }

      String jsonString;
      try {
        jsonString = await effectiveFile.readAsString();
      } catch (e) {
        if (effectiveFile != bakFile && await bakFile.exists()) {
          LoggerService.w(
            'Failed reading primary file, falling back to backup: $e',
          );
          jsonString = await bakFile.readAsString();
        } else {
          rethrow;
        }
      }

      final downloads = await _decodeDownloadsInBackground(jsonString);

      LoggerService.i('Loaded ${downloads.length} downloads from disk.');
      return downloads;
    } catch (e) {
      LoggerService.e('Failed to load downloads', e);
      return [];
    }
  }

  Future<void> saveQueue(List<DownloadRequest> queue) async {
    try {
      final file = await _queueFile();
      final jsonString = DownloadQueueCodec.encode(queue);
      await _atomicWrite(file, jsonString);
      LoggerService.debug('Saved ${queue.length} queued downloads to disk.');
    } catch (e) {
      LoggerService.e('Failed to save download queue', e);
    }
  }

  Future<List<DownloadRequest>> loadQueue() async {
    try {
      final file = await _queueFile();
      if (!await file.exists()) {
        return const [];
      }
      final jsonString = await file.readAsString();
      final queue = DownloadQueueCodec.decode(jsonString);
      LoggerService.i('Loaded ${queue.length} queued downloads from disk.');
      return queue;
    } catch (e) {
      LoggerService.e('Failed to load download queue', e);
      return const [];
    }
  }

  Future<void> saveMediaFingerprintIndex(Map<String, dynamic> index) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_mediaFingerprintFileName');
      await _atomicWrite(file, jsonEncode(index));
    } catch (e) {
      LoggerService.e('Failed to save media fingerprint index', e);
    }
  }

  Future<Map<String, dynamic>?> loadMediaFingerprintIndex() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_mediaFingerprintFileName');
      if (!await file.exists()) {
        return null;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        LoggerService.w('Ignoring invalid media fingerprint index.');
        return null;
      }
      return decoded;
    } catch (e) {
      LoggerService.e('Failed to load media fingerprint index', e);
      return null;
    }
  }

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/queue_v1.json');
  }

  Future<void> _atomicWrite(File targetFile, String content) async {
    final tmp = File('${targetFile.path}.tmp');
    final bak = File('${targetFile.path}.bak');
    await tmp.writeAsString(content, flush: true);

    if (await targetFile.exists()) {
      try {
        if (await bak.exists()) {
          await bak.delete();
        }
        await targetFile.copy(bak.path);
      } catch (e) {
        LoggerService.debug('Persistence backup copy non-fatal error: $e');
      }

      try {
        await targetFile.delete();
      } catch (e) {
        // Direct copy over targetFile if delete fails on Windows locks
        await tmp.copy(targetFile.path);
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
    }

    try {
      await tmp.rename(targetFile.path);
    } catch (e) {
      // Fallback copy if rename fails across partitions or due to Windows flags
      await tmp.copy(targetFile.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}
