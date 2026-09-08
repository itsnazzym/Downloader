import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/binary/binary_locator.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';

enum TikTokVideoStatus {
  idle,
  downloading,
  ready,
  unavailable,
}

class TikTokVideoState {
  final String videoId;
  final TikTokVideoStatus status;
  final String? localPath;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;

  const TikTokVideoState({
    required this.videoId,
    this.status = TikTokVideoStatus.idle,
    this.localPath,
    this.progress = 0.0,
    this.errorMessage,
  });

  bool get isReady => status == TikTokVideoStatus.ready && localPath != null;
  bool get isDownloading => status == TikTokVideoStatus.downloading;
  bool get isUnavailable => status == TikTokVideoStatus.unavailable;

  TikTokVideoState copyWith({
    TikTokVideoStatus? status,
    String? localPath,
    double? progress,
    String? errorMessage,
  }) {
    return TikTokVideoState(
      videoId: videoId,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Service managing on-disk caching, background downloading, and intelligent preloading
/// for TikTok videos to enable instant zero-latency playback in the app.
class TikTokVideoCacheService {
  final BinaryLocator _binaryLocator;
  Directory? _cacheDir;
  
  final Map<String, TikTokVideoState> _states = {};
  final Set<String> _activeDownloadIds = {};
  final List<String> _queuedIds = [];
  final Map<String, Process> _runningProcesses = {};
  final Set<String> _unavailableIds = {};

  final _stateController = StreamController<TikTokVideoState>.broadcast();
  Stream<TikTokVideoState> get stateStream => _stateController.stream;

  final _unavailableIdsController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get unavailableIdsStream => _unavailableIdsController.stream;
  Set<String> get unavailableIds => Set.unmodifiable(_unavailableIds);

  static const int maxConcurrentDownloads = 2;

  TikTokVideoCacheService({BinaryLocator? binaryLocator})
      : _binaryLocator = binaryLocator ?? BinaryLocator();

  void _notifyUnavailable() {
    if (!_unavailableIdsController.isClosed) {
      _unavailableIdsController.add(Set.unmodifiable(_unavailableIds));
    }
  }

  void _loadExistingUnavailableFiles(Directory dir) {
    try {
      if (dir.existsSync()) {
        final entries = dir.listSync();
        bool added = false;
        for (final entry in entries) {
          if (entry is File && entry.path.endsWith('.unavailable')) {
            final id = p.basenameWithoutExtension(entry.path);
            if (_unavailableIds.add(id)) {
              added = true;
            }
          }
        }
        if (added) _notifyUnavailable();
      }
    } catch (_) {}
  }

  Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dir = Directory(p.join(supportDir.path, 'tiktok_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      _loadExistingUnavailableFiles(dir);
      return dir;
    } catch (_) {
      // Fallback for isolated tests or sandbox
      final temp = Directory(p.join(Directory.systemTemp.path, 'tiktok_cache'));
      if (!temp.existsSync()) temp.createSync(recursive: true);
      _cacheDir = temp;
      _loadExistingUnavailableFiles(temp);
      return temp;
    }
  }

  TikTokVideoState getVideoState(String videoId) {
    if (_states.containsKey(videoId)) {
      return _states[videoId]!;
    }
    if (_unavailableIds.contains(videoId)) {
      return TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.unavailable,
        errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
      );
    }
    return TikTokVideoState(videoId: videoId, status: TikTokVideoStatus.idle);
  }

  Future<String?> getCachedVideoPath(String videoId) async {
    if (_unavailableIds.contains(videoId)) {
      _updateState(TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.unavailable,
        errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
      ));
      return null;
    }

    final dir = await getCacheDirectory();
    final file = File(p.join(dir.path, '$videoId.mp4'));
    if (await file.exists() && (await file.length()) > 1000) {
      final path = file.path;
      _updateState(TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.ready,
        localPath: path,
        progress: 1.0,
      ));
      return path;
    }

    final unavailFile = File(p.join(dir.path, '$videoId.unavailable'));
    if (await unavailFile.exists()) {
      _unavailableIds.add(videoId);
      _notifyUnavailable();
      _updateState(TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.unavailable,
        errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
      ));
    }
    return null;
  }

  void _updateState(TikTokVideoState state) {
    _states[state.videoId] = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Request immediate or queued download of a TikTok video into cache.
  Future<String?> requestVideo(String videoId, {bool highPriority = true}) async {
    final cached = await getCachedVideoPath(videoId);
    if (cached != null) return cached;

    final currentState = getVideoState(videoId);
    if (currentState.isUnavailable) return null;
    if (currentState.isReady) return currentState.localPath;

    if (highPriority) {
      _queuedIds.remove(videoId);
      _queuedIds.insert(0, videoId);
    } else if (!_queuedIds.contains(videoId) && !_activeDownloadIds.contains(videoId)) {
      _queuedIds.add(videoId);
    }

    unawaited(_processQueue());
    return null;
  }

  /// Preload videos in a sliding window around the currently focused index.
  void preloadAround(List<TikTokArchiveItem> items, int currentIndex, {int lookAhead = 3}) {
    if (items.isEmpty || currentIndex < 0 || currentIndex >= items.length) return;

    // High priority: active item
    final currentItem = items[currentIndex];
    unawaited(requestVideo(currentItem.id, highPriority: true));

    // Medium priority: lookAhead items
    for (int i = 1; i <= lookAhead; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < items.length) {
        unawaited(requestVideo(items[nextIndex].id, highPriority: false));
      }
    }

    // Cancel / dequeue items that are completely out of the active window
    final allowedWindowIds = <String>{};
    final minIndex = (currentIndex - 1).clamp(0, items.length - 1);
    final maxIndex = (currentIndex + lookAhead + 1).clamp(0, items.length - 1);
    for (int i = minIndex; i <= maxIndex; i++) {
      allowedWindowIds.add(items[i].id);
    }

    _queuedIds.removeWhere((id) => !allowedWindowIds.contains(id));
  }

  Future<void> _processQueue() async {
    while (_activeDownloadIds.length < maxConcurrentDownloads && _queuedIds.isNotEmpty) {
      final videoId = _queuedIds.removeAt(0);
      if (_activeDownloadIds.contains(videoId)) continue;

      final cached = await getCachedVideoPath(videoId);
      if (cached != null) continue;

      _activeDownloadIds.add(videoId);
      unawaited(_downloadWorker(videoId).then((_) {
        _activeDownloadIds.remove(videoId);
        _processQueue();
      }));
    }
  }

  Future<void> _downloadWorker(String videoId) async {
    _updateState(TikTokVideoState(
      videoId: videoId,
      status: TikTokVideoStatus.downloading,
      progress: 0.05,
    ));

    try {
      final dir = await getCacheDirectory();
      final targetFile = File(p.join(dir.path, '$videoId.mp4'));
      final unavailFile = File(p.join(dir.path, '$videoId.unavailable'));

      if (await targetFile.exists() && (await targetFile.length()) > 1000) {
        _updateState(TikTokVideoState(
          videoId: videoId,
          status: TikTokVideoStatus.ready,
          localPath: targetFile.path,
          progress: 1.0,
        ));
        return;
      }

      final ytDlp = await _binaryLocator.findYtDlp();
      if (ytDlp == null) {
        throw StateError('Exécutable yt-dlp introuvable pour le téléchargement.');
      }

      final partFilePath = '${targetFile.path}.part';
      final tempPartFile = File(partFilePath);
      if (await tempPartFile.exists()) {
        try {
          await tempPartFile.delete();
        } catch (_) {}
      }

      final process = await Process.start(
        ytDlp,
        [
          '-f', 'best[ext=mp4]/best',
          '--no-playlist',
          '--no-warnings',
          '--socket-timeout', '15',
          '--retries', '2',
          '-o', targetFile.path,
          'https://www.tiktokv.com/share/video/$videoId/',
        ],
        runInShell: false,
      );

      _runningProcesses[videoId] = process;

      final progressRegex = RegExp(r'(\d+(?:\.\d+)?)%');
      bool isUnavailableDetected = false;

      final outSub = process.stdout.transform(utf8.decoder).listen((data) {
        final match = progressRegex.firstMatch(data);
        if (match != null) {
          final pct = double.tryParse(match.group(1)!);
          if (pct != null) {
            _updateState(TikTokVideoState(
              videoId: videoId,
              status: TikTokVideoStatus.downloading,
              progress: (pct / 100.0).clamp(0.05, 0.99),
            ));
          }
        }
        if (data.contains("item doesn't exist") ||
            data.contains('blocked from accessing this post') ||
            data.contains('Video unavailable')) {
          isUnavailableDetected = true;
        }
      });

      final errSub = process.stderr.transform(utf8.decoder).listen((data) {
        if (data.contains("item doesn't exist") ||
            data.contains('blocked from accessing this post') ||
            data.contains('Video unavailable')) {
          isUnavailableDetected = true;
        }
      });

      final exitCode = await process.exitCode;
      await outSub.cancel();
      await errSub.cancel();
      _runningProcesses.remove(videoId);

      if (exitCode == 0 && await targetFile.exists() && (await targetFile.length()) > 1000) {
        _updateState(TikTokVideoState(
          videoId: videoId,
          status: TikTokVideoStatus.ready,
          localPath: targetFile.path,
          progress: 1.0,
        ));
      } else {
        if (isUnavailableDetected || exitCode != 0) {
          _unavailableIds.add(videoId);
          _notifyUnavailable();
          try {
            await unavailFile.writeAsString('unavailable');
          } catch (_) {}
          _updateState(TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.unavailable,
            errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
          ));
        } else {
          _updateState(TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.idle,
            errorMessage: 'Erreur de chargement (code: $exitCode)',
          ));
        }
      }
    } catch (e, st) {
      LoggerService.e('Erreur lors du préchargement de la vidéo $videoId: $e', e, st);
      _runningProcesses.remove(videoId);
      _updateState(TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.idle,
        errorMessage: e.toString(),
      ));
    }
  }

  void cancelAll() {
    for (final proc in _runningProcesses.values) {
      try {
        proc.kill();
      } catch (_) {}
    }
    _runningProcesses.clear();
    _activeDownloadIds.clear();
    _queuedIds.clear();
  }

  Future<int> getCacheSizeBytes() async {
    final dir = await getCacheDirectory();
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      for (final file in dir.listSync(followLinks: false)) {
        if (file is File && (file.path.endsWith('.mp4') || file.path.endsWith('.part'))) {
          total += file.lengthSync();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<int> getCachedVideosCount() async {
    final dir = await getCacheDirectory();
    if (!dir.existsSync()) return 0;
    int count = 0;
    try {
      for (final file in dir.listSync(followLinks: false)) {
        if (file is File && file.path.endsWith('.mp4')) {
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  Future<void> clearCache() async {
    cancelAll();
    final dir = await getCacheDirectory();
    if (!dir.existsSync()) return;
    try {
      for (final file in dir.listSync(followLinks: false)) {
        if (file is File && (file.path.endsWith('.mp4') || file.path.endsWith('.part'))) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    _states.clear();
  }

  void dispose() {
    cancelAll();
    _stateController.close();
    _unavailableIdsController.close();
  }
}

