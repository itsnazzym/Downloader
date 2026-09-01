import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../download/download_file_resolver.dart';
import '../download/yt_dlp_progress_parser.dart';
import '../logger/logger_service.dart';
import '../../features/downloader/data/sources/download_progress_event.dart';
import '../../features/downloader/domain/exceptions/yt_dlp_exception.dart';

class AndroidYtDlpClient {
  AndroidYtDlpClient({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method = methodChannel ?? const MethodChannel(_methodName),
      _events = eventChannel ?? const EventChannel(_eventName);

  static const _methodName = 'modern_downloader/native';
  static const _eventName = 'modern_downloader/ytdlp_events';

  static final AndroidYtDlpClient instance = AndroidYtDlpClient();

  final MethodChannel _method;
  final EventChannel _events;
  Stream<Map<String, dynamic>>? _eventStream;

  Stream<Map<String, dynamic>> get events {
    return _eventStream ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  Future<void> initEngine() async {
    try {
      await _method.invokeMethod<void>('initEngine');
    } on PlatformException catch (error) {
      throw StateError('Android yt-dlp init failed: ${error.message}');
    }
  }

  Future<void> updateYtDlp() async {
    try {
      await _method.invokeMethod<void>('updateYtDlp');
    } on PlatformException catch (error) {
      LoggerService.w('Android yt-dlp update skipped: ${error.message}');
    }
  }

  Future<String?> defaultOutputFolder() async {
    try {
      return await _method.invokeMethod<String>('defaultOutputFolder');
    } on PlatformException catch (error) {
      LoggerService.w('Android output folder lookup failed: ${error.message}');
      return null;
    }
  }

  Future<String?> takeInitialShare() async {
    try {
      return await _method.invokeMethod<String>('getInitialShare');
    } on PlatformException catch (error) {
      LoggerService.w('Android share lookup failed: ${error.message}');
      return null;
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _method.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException catch (error) {
      LoggerService.w('Android cancel failed for $id: ${error.message}');
    }
  }

  Future<void> openPath(String path, {bool reveal = false}) async {
    try {
      await _method.invokeMethod<void>('openPath', {
        'path': path,
        'reveal': reveal,
      });
    } on PlatformException catch (error) {
      LoggerService.w('Android openPath failed: ${error.message}');
    }
  }

  Future<String> probe(List<String> args) async {
    try {
      final output = await _method.invokeMethod<String>('probe', {
        'args': args,
      });
      return output ?? '';
    } on PlatformException catch (error) {
      throw YtDlpException(error.message ?? 'yt-dlp probe failed');
    }
  }

  Future<Map<String, dynamic>> probeJson(List<String> args) async {
    final output = (await probe(args)).trim();
    if (output.isEmpty) {
      throw YtDlpException('Empty yt-dlp metadata');
    }
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Multi-object dumps are handled below.
    }
    for (final line in const LineSplitter().convert(output)) {
      final candidate = line.trim();
      if (candidate.isEmpty) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    throw YtDlpException('Could not parse yt-dlp metadata');
  }

  Future<List<Map<String, dynamic>>> probePlaylist(List<String> args) async {
    final output = (await probe(args)).trim();
    if (output.isEmpty) return [];
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map && decoded.containsKey('entries')) {
        final entries = decoded['entries'];
        if (entries is List) {
          return [
            for (final entry in entries)
              if (entry is Map) Map<String, dynamic>.from(entry),
          ];
        }
      }
      if (decoded is Map) {
        return [Map<String, dynamic>.from(decoded)];
      }
    } catch (error) {
      LoggerService.w('Failed to parse Android playlist JSON: $error');
    }
    return [];
  }

  Stream<DownloadProgressEvent> download({
    required String id,
    required List<String> args,
    required String outputFolder,
    String? videoId,
    required String preferredExt,
  }) async* {
    final parser = YtDlpProgressParser(
      baseFolder: outputFolder,
      preferredExt: preferredExt,
    );
    final incoming = StreamController<DownloadProgressEvent>();

    final subscription = events
        .where((event) => event['id'] == id)
        .listen(
          (event) {
            final type = event['type'];
            if (type == 'line') {
              final line = event['line'] as String? ?? '';
              for (final update in parser.onLine(line)) {
                if (!incoming.isClosed) {
                  incoming.add(
                    DownloadProgressEvent(
                      progress: update.progress,
                      totalSize: update.totalSize,
                      downloadedSize: update.downloadedSize,
                      speed: update.speed,
                      eta: update.eta,
                      title: update.title,
                      step: update.step,
                      filePath: update.filePath,
                      isDuplicate: update.isDuplicate,
                    ),
                  );
                }
              }
              return;
            }
            if (type == 'error') {
              if (!incoming.isClosed) {
                incoming.addError(
                  YtDlpException(
                    event['message'] as String? ?? 'download failed',
                  ),
                );
                unawaited(incoming.close());
              }
              return;
            }
            if (type == 'done' && !incoming.isClosed) {
              var currentFilePath =
                  parser.afterMovePath ?? parser.currentFilePath;
              final resolvedPath = DownloadFileResolver.resolve(
                candidatePath: currentFilePath,
                outputFolder: outputFolder,
                videoId: videoId,
                preferredExtension: preferredExt,
              );
              if (resolvedPath != null) {
                currentFilePath = resolvedPath;
              }
              final diskSize = DownloadFileResolver.formattedFileSize(
                currentFilePath,
              );
              incoming.add(
                DownloadProgressEvent(
                  progress: 1.0,
                  totalSize: diskSize ?? '',
                  downloadedSize: diskSize ?? '',
                  speed: 'Terminé',
                  eta: '',
                  title: parser.extractedTitle,
                  step: 'Fini',
                  filePath: currentFilePath,
                ),
              );
              unawaited(incoming.close());
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!incoming.isClosed) {
              incoming.addError(error, stackTrace);
              unawaited(incoming.close());
            }
          },
        );

    final invoke = _method.invokeMethod<void>('download', {
      'id': id,
      'args': args,
    });

    try {
      await for (final event in incoming.stream) {
        yield event;
      }
      await invoke;
    } on PlatformException catch (error) {
      throw YtDlpException(error.message ?? 'download failed');
    } finally {
      await subscription.cancel();
      if (!incoming.isClosed) {
        await incoming.close();
      }
    }
  }
}
