import 'dart:convert';
import 'dart:io';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:path_provider/path_provider.dart';
import 'download_queue_codec.dart';

class PersistenceService {
  static const String _fileName = 'downloads_v1.json';
  static const String _mediaFingerprintFileName = 'media_fingerprints_v1.json';

  Future<void> saveDownloads(List<DownloadItem> downloads) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');

      final data = downloads.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(data);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
      LoggerService.debug('Saved ${downloads.length} downloads to disk.');
    } catch (e) {
      LoggerService.e('Failed to save downloads', e);
    }
  }

  Future<List<DownloadItem>> loadDownloads() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');

      if (!await file.exists()) {
        LoggerService.i('No saved downloads found.');
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final downloads = jsonList
          .map((e) => DownloadItem.fromJson(e as Map<String, dynamic>))
          .toList();

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
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
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
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(index), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
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
}
