import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/logger/logger_service.dart';
import '../../../../core/services/binary/binary_locator.dart';
import '../../domain/entities/tiktok_archive_catalog.dart';

enum TikTokVideoStatus { idle, downloading, ready, unavailable }

typedef TikTokOutputDownloader =
    Future<String?> Function(
      String videoId,
      String url,
      void Function(double progress) onProgress,
    );

const _unavailableMarkerPrefix = 'confirmed_tiktok_unavailable_v1:';

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
  final TikTokOutputDownloader? _outputDownloader;
  Directory? _cacheDir;

  final Map<String, TikTokVideoState> _states = {};
  final Set<String> _activeDownloadIds = {};
  final List<String> _queuedIds = [];
  final Map<String, Process> _runningProcesses = {};
  final Set<String> _unavailableIds = {};
  final Map<String, String> _urlsById = {};

  final _stateController = StreamController<TikTokVideoState>.broadcast();
  Stream<TikTokVideoState> get stateStream => _stateController.stream;

  final _unavailableIdsController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get unavailableIdsStream =>
      _unavailableIdsController.stream;
  Set<String> get unavailableIds => Set.unmodifiable(_unavailableIds);

  static const int maxConcurrentDownloads = 2;

  TikTokVideoCacheService({
    BinaryLocator? binaryLocator,
    TikTokOutputDownloader? outputDownloader,
    Directory? cacheDirectory,
  }) : _binaryLocator = binaryLocator ?? BinaryLocator(),
       _outputDownloader = outputDownloader,
       _cacheDir = cacheDirectory;

  void _notifyUnavailable() {
    if (!_unavailableIdsController.isClosed) {
      _unavailableIdsController.add(Set.unmodifiable(_unavailableIds));
    }
  }

  bool isUnavailable(String videoId) => _unavailableIds.contains(videoId);

  Future<void> ensureLoaded() async => getCacheDirectory();

  void _loadExistingUnavailableFiles(Directory dir) {
    try {
      if (!dir.existsSync()) return;

      final indexFile = File(p.join(dir.path, 'unavailable_index.json'));
      if (indexFile.existsSync()) {
        try {
          final content = indexFile.readAsStringSync();
          final dynamic list = jsonDecode(content);
          if (list is List) {
            bool added = false;
            for (final id in list) {
              if (id is String && _unavailableIds.add(id)) {
                added = true;
              }
            }
            if (added) _notifyUnavailable();
            return;
          }
        } catch (_) {
          // If index is corrupt, fall back to directory scan below
        }
      }

      final entries = dir.listSync();
      bool added = false;
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.unavailable')) {
          final contents = entry.readAsStringSync();
          if (contents.startsWith(_unavailableMarkerPrefix) &&
              _isConfirmedUnavailable(
                contents.substring(_unavailableMarkerPrefix.length),
              )) {
            final id = p.basenameWithoutExtension(entry.path);
            if (_unavailableIds.add(id)) added = true;
          } else {
            // Older versions persisted every yt-dlp failure, including
            // timeouts and temporary HTTP errors. Those IDs need a retry.
            entry.deleteSync();
          }
        }
      }
      if (added) {
        _notifyUnavailable();
        _persistUnavailableIndex(dir);
      }
    } catch (_) {}
  }

  void _persistUnavailableIndex(Directory dir) {
    try {
      final indexFile = File(p.join(dir.path, 'unavailable_index.json'));
      indexFile.writeAsStringSync(
        jsonEncode(_unavailableIds.toList(growable: false)),
      );
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
      _updateState(
        TikTokVideoState(
          videoId: videoId,
          status: TikTokVideoStatus.unavailable,
          errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
        ),
      );
      return null;
    }

    final dir = await getCacheDirectory();
    if (_outputDownloader != null) {
      final path = _states[videoId]?.localPath;
      if (path != null && await File(path).exists()) return path;
      if (_states[videoId]?.isReady == true) {
        _states.remove(videoId);
      }
    }
    if (_outputDownloader == null) {
      final file = File(p.join(dir.path, '$videoId.mp4'));
      if (await file.exists() && (await file.length()) > 1000) {
        final path = file.path;
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.ready,
            localPath: path,
            progress: 1.0,
          ),
        );
        return path;
      }
    }

    final unavailFile = File(p.join(dir.path, '$videoId.unavailable'));
    if (await unavailFile.exists()) {
      final marker = await unavailFile.readAsString();
      if (marker.startsWith(_unavailableMarkerPrefix) &&
          _isConfirmedUnavailable(
            marker.substring(_unavailableMarkerPrefix.length),
          )) {
        _unavailableIds.add(videoId);
        _notifyUnavailable();
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.unavailable,
            errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
          ),
        );
      } else {
        await unavailFile.delete();
      }
    }
    return null;
  }

  void _updateState(TikTokVideoState state) {
    _states[state.videoId] = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Request a download for playback. In the application, [url] is passed to
  /// the regular downloader, which writes into the configured output folder.
  Future<String?> requestVideo(
    String videoId, {
    bool highPriority = true,
    String? url,
  }) async {
    if (url != null && url.trim().isNotEmpty) _urlsById[videoId] = url.trim();
    final cached = await getCachedVideoPath(videoId);
    if (cached != null) return cached;

    final currentState = getVideoState(videoId);
    if (currentState.isUnavailable) return null;
    if (currentState.isReady) return currentState.localPath;

    if (highPriority) {
      _queuedIds.remove(videoId);
      _queuedIds.insert(0, videoId);
    } else if (!_queuedIds.contains(videoId) &&
        !_activeDownloadIds.contains(videoId)) {
      _queuedIds.add(videoId);
    }

    unawaited(_processQueue());
    return null;
  }

  /// Preload videos in a sliding window around the currently focused index.
  void preloadAround(
    List<TikTokArchiveItem> items,
    int currentIndex, {
    int lookAhead = 1,
  }) {
    if (items.isEmpty || currentIndex < 0 || currentIndex >= items.length) {
      return;
    }

    // High priority: active item
    final currentItem = items[currentIndex];
    unawaited(
      requestVideo(currentItem.id, highPriority: true, url: currentItem.url),
    );

    // Medium priority: lookAhead items
    for (int i = 1; i <= lookAhead; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < items.length) {
        unawaited(
          requestVideo(
            items[nextIndex].id,
            highPriority: false,
            url: items[nextIndex].url,
          ),
        );
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
    while (_activeDownloadIds.length < maxConcurrentDownloads &&
        _queuedIds.isNotEmpty) {
      final videoId = _queuedIds.removeAt(0);
      if (_activeDownloadIds.contains(videoId)) continue;

      final cached = await getCachedVideoPath(videoId);
      if (cached != null) continue;

      _activeDownloadIds.add(videoId);
      unawaited(
        _downloadWorker(videoId).then((_) {
          _activeDownloadIds.remove(videoId);
          _processQueue();
        }),
      );
    }
  }

  Future<void> _downloadWorker(String videoId) async {
    _updateState(
      TikTokVideoState(
        videoId: videoId,
        status: TikTokVideoStatus.downloading,
        progress: 0.05,
      ),
    );

    try {
      final dir = await getCacheDirectory();
      final targetFile = File(p.join(dir.path, '$videoId.mp4'));

      if (_outputDownloader != null) {
        final url = _urlsById[videoId];
        if (url == null || url.isEmpty) {
          throw StateError('Lien TikTok manquant pour cette vidéo.');
        }
        final outputPath = await _outputDownloader(videoId, url, (progress) {
          _updateState(
            TikTokVideoState(
              videoId: videoId,
              status: TikTokVideoStatus.downloading,
              progress: progress.clamp(0.05, 0.99).toDouble(),
            ),
          );
        });
        if (outputPath == null ||
            !await File(outputPath).exists() ||
            await File(outputPath).length() <= 1000) {
          throw StateError(
            'Le fichier TikTok n’a pas été créé dans le dossier de sortie.',
          );
        }
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.ready,
            localPath: outputPath,
            progress: 1.0,
          ),
        );
        return;
      }

      if (await targetFile.exists() && (await targetFile.length()) > 1000) {
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.ready,
            localPath: targetFile.path,
            progress: 1.0,
          ),
        );
        return;
      }

      final ytDlp = await _binaryLocator.findYtDlp();
      if (ytDlp == null) {
        throw StateError(
          'Exécutable yt-dlp introuvable pour le téléchargement.',
        );
      }

      final partFilePath = '${targetFile.path}.part';
      final tempPartFile = File(partFilePath);
      if (await tempPartFile.exists()) {
        try {
          await tempPartFile.delete();
        } catch (_) {}
      }

      final process = await Process.start(ytDlp, [
        '-f',
        'best[ext=mp4]/best',
        '--no-playlist',
        '--no-warnings',
        '--socket-timeout',
        '15',
        '--retries',
        '2',
        '-o',
        targetFile.path,
        'https://www.tiktokv.com/share/video/$videoId/',
      ], runInShell: false);

      _runningProcesses[videoId] = process;

      final progressRegex = RegExp(r'(\d+(?:\.\d+)?)%');
      final output = StringBuffer();

      final outSub = process.stdout.transform(utf8.decoder).listen((data) {
        final match = progressRegex.firstMatch(data);
        if (match != null) {
          final pct = double.tryParse(match.group(1)!);
          if (pct != null) {
            _updateState(
              TikTokVideoState(
                videoId: videoId,
                status: TikTokVideoStatus.downloading,
                progress: (pct / 100.0).clamp(0.05, 0.99),
              ),
            );
          }
        }
        output.write(data);
      });

      final errSub = process.stderr.transform(utf8.decoder).listen((data) {
        output.write(data);
      });

      final exitCode = await process.exitCode;
      await outSub.cancel();
      await errSub.cancel();
      _runningProcesses.remove(videoId);

      if (exitCode == 0 &&
          await targetFile.exists() &&
          (await targetFile.length()) > 1000) {
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.ready,
            localPath: targetFile.path,
            progress: 1.0,
          ),
        );
      } else {
        final errorText = output.toString();
        if (_isConfirmedUnavailable(errorText)) {
          await _recordUnavailable(videoId, errorText);
          _updateState(
            TikTokVideoState(
              videoId: videoId,
              status: TikTokVideoStatus.unavailable,
              errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
            ),
          );
        } else {
          _updateState(
            TikTokVideoState(
              videoId: videoId,
              status: TikTokVideoStatus.idle,
              errorMessage: _friendlyDownloadError(
                errorText,
                exitCode: exitCode,
              ),
            ),
          );
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Erreur lors du préchargement de la vidéo $videoId: $e',
        e,
        st,
      );
      _runningProcesses.remove(videoId);
      final message = e.toString();
      if (_isConfirmedUnavailable(message)) {
        await _recordUnavailable(videoId, message);
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.unavailable,
            errorMessage: 'Vidéo indisponible ou supprimée sur TikTok',
          ),
        );
      } else {
        _updateState(
          TikTokVideoState(
            videoId: videoId,
            status: TikTokVideoStatus.idle,
            errorMessage: _friendlyDownloadError(message),
          ),
        );
      }
    }
  }

  bool _isConfirmedUnavailable(String message) {
    final value = message.toLowerCase();
    return value.contains("item doesn't exist") ||
        value.contains('item does not exist') ||
        value.contains('video has been removed') ||
        value.contains('video not found') ||
        value.contains('post has been removed') ||
        value.contains('post not found') ||
        value.contains('your ip address is blocked from accessing this post') ||
        value.contains('status_self_see') ||
        value.contains('item_privacy_authorization') ||
        value.contains('item_privacy_auth') ||
        value.contains('10204') ||
        RegExp(r'\b404\b').hasMatch(value);
  }

  String _friendlyDownloadError(String message, {int? exitCode}) {
    final value = message.toLowerCase();
    if (value.contains('comfortable for some audiences') ||
        value.contains('log in for access') ||
        value.contains('login required') ||
        value.contains('cookies-from-browser') ||
        value.contains('sign in to confirm') ||
        value.contains('age-restricted')) {
      return 'TikTok exige une session connectée ou une autorisation d’âge pour cette vidéo. '
          'Dans Paramètres > Avancé, choisis le navigateur où ta session TikTok est ouverte '
          '(Chrome si tu utilises Chrome), puis réessaie.';
    }
    if (value.contains('connection timed out') ||
        value.contains('socketexception') ||
        value.contains('network is unreachable') ||
        value.contains('connection reset') ||
        value.contains('failed to connect')) {
      return 'Connexion à TikTok impossible pour le moment. Vérifie ta connexion internet et réessaie.';
    }
    if (message.trim().isEmpty && exitCode != null) {
      return 'Téléchargement TikTok impossible (code $exitCode). Vérifie la connexion puis réessaie.';
    }
    return 'TikTok n’a pas fourni cette vidéo. Vérifie la session du navigateur choisie dans Paramètres > Avancé, puis réessaie.';
  }

  static final RegExp _rehydrationRegex = RegExp(
    r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
  );

  /// Fast-checks whether a TikTok video is available before handing it off to yt-dlp.
  ///
  /// Returns `false` ONLY when TikTok explicitly confirms the video is deleted or private:
  /// - HTTP 404
  /// - Rehydration payload with statusCode == 10204 and no itemStruct
  /// - statusMsg contains "item doesn't exist", "status_self_see", or "item_privacy" and no itemStruct
  ///
  /// In all other cases (including network errors, timeouts, or ambiguous HTML), returns `true`
  /// so working videos are NEVER mistakenly skipped.
  Future<bool> checkAvailability(
    String videoId, {
    String? url,
    HttpClient? client,
  }) async {
    // 1. Fast in-memory check
    if (_unavailableIds.contains(videoId)) {
      return false;
    }

    // 2. Check if already downloaded locally
    final cached = await getCachedVideoPath(videoId);
    if (cached != null) {
      return true;
    }

    // 3. Fast lightweight HTTP probe
    final ownsClient = client == null;
    final httpClient = client ??
        (HttpClient()..connectionTimeout = const Duration(seconds: 4));

    try {
      final probeUri = Uri.parse(
        url != null && url.trim().isNotEmpty
            ? url.trim()
            : 'https://www.tiktokv.com/share/video/$videoId/',
      );

      final request = await httpClient
          .getUrl(probeUri)
          .timeout(const Duration(seconds: 5));
      request.followRedirects = true;
      request.maxRedirects = 3;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.5');

      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 404) {
        await _recordUnavailable(
          videoId,
          'Vidéo introuvable (HTTP 404)',
        );
        return false;
      }

      if (response.statusCode != 200) {
        // Any rate-limit (429), protection (503), etc. - do not skip!
        return true;
      }

      final body = await response.transform(utf8.decoder).join();
      final match = _rehydrationRegex.firstMatch(body);
      if (match == null) {
        return true;
      }

      final jsonStr = match.group(1);
      if (jsonStr == null || jsonStr.isEmpty) return true;

      final dynamic data = jsonDecode(jsonStr);
      if (data is! Map) return true;

      final defaultScope = data['__DEFAULT_SCOPE__'];
      if (defaultScope is! Map) return true;

      final detail = defaultScope['webapp.video-detail'];
      if (detail is! Map) return true;

      final statusCode = detail['statusCode'];
      final statusMsg = (detail['statusMsg'] ?? '').toString().toLowerCase();
      final itemInfo = detail['itemInfo'];
      final hasItemStruct = itemInfo is Map && itemInfo['itemStruct'] != null;

      if ((statusCode == 10204 ||
              statusMsg.contains("item doesn't exist") ||
              statusMsg.contains('status_self_see') ||
              statusMsg.contains('item_privacy')) &&
          !hasItemStruct) {
        final reason = statusMsg.isNotEmpty
            ? statusMsg
            : 'Vidéo privée ou supprimée (code 10204)';
        await _recordUnavailable(videoId, reason);
        return false;
      }

      if (statusCode == 0 && hasItemStruct) {
        return true;
      }

      return true;
    } catch (e) {
      LoggerService.debug('TikTok availability probe error for $videoId: $e');
      return true;
    } finally {
      if (ownsClient) {
        httpClient.close(force: true);
      }
    }
  }

  /// Records a video as confirmed unavailable and persists the marker to disk.
  Future<void> recordUnavailable(String videoId, String reason) =>
      _recordUnavailable(videoId, reason);

  Future<void> _recordUnavailable(String videoId, String reason) async {
    _unavailableIds.add(videoId);
    _notifyUnavailable();
    try {
      final dir = await getCacheDirectory();
      final marker = File(p.join(dir.path, '$videoId.unavailable'));
      await marker.writeAsString(
        '$_unavailableMarkerPrefix${reason.trim().replaceAll('\n', ' ')}',
      );
      _persistUnavailableIndex(dir);
    } catch (_) {}
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
        if (file is File &&
            (file.path.endsWith('.mp4') ||
                file.path.endsWith('.part') ||
                file.path.endsWith('.unavailable'))) {
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
        if (file is File &&
            (file.path.endsWith('.mp4') ||
                file.path.endsWith('.part') ||
                file.path.endsWith('.unavailable'))) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    _states.clear();
    _unavailableIds.clear();
    _notifyUnavailable();
  }

  void dispose() {
    cancelAll();
    _stateController.close();
    _unavailableIdsController.close();
  }
}
