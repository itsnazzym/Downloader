import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/plugins/plugin_manager.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:modern_downloader/core/services/media_fingerprint_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';
import 'package:modern_downloader/features/downloader/data/repositories/downloader_repository_impl.dart';
import 'package:modern_downloader/features/downloader/data/services/library_scanner_service.dart';
import 'package:modern_downloader/features/downloader/data/sources/fallback_media_resolver.dart';
import 'package:modern_downloader/features/downloader/data/sources/gallery_dl_source.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/core/download/metadata_probe_limiter.dart';
import 'package:modern_downloader/features/downloader/domain/exceptions/yt_dlp_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryPersistence extends PersistenceService {
  List<DownloadItem> stored = [];
  Map<String, dynamic>? fingerprintIndex;

  @override
  Future<void> saveDownloads(List<DownloadItem> downloads) async {
    stored = List<DownloadItem>.from(downloads);
  }

  /// When set, loading waits on it (a large library decoding slowly).
  Completer<void>? loadHold;

  @override
  Future<List<DownloadItem>> loadDownloads() async {
    await loadHold?.future;
    return List<DownloadItem>.from(stored);
  }

  @override
  Future<Map<String, dynamic>?> loadMediaFingerprintIndex() async =>
      fingerprintIndex;

  @override
  Future<void> saveMediaFingerprintIndex(Map<String, dynamic> value) async {
    fingerprintIndex = Map<String, dynamic>.from(value);
  }
}

class _NoopScanner extends LibraryScannerService {
  _NoopScanner() : super(BinaryLocator());

  @override
  Future<List<DownloadItem>> scanAndFix(
    List<DownloadItem> items,
    String basePath,
  ) async {
    return items;
  }

  @override
  Future<List<DownloadItem>> scanForNewFiles(
    List<DownloadItem> knownItems,
    String downloadPath,
  ) async {
    return [];
  }
}

/// Holds the scan open so the test can change the library meanwhile.
class _HeldScanner extends _NoopScanner {
  final release = Completer<void>();

  @override
  Future<LibraryScanResult> scanLibrary(
    List<DownloadItem> items,
    String basePath,
  ) async {
    final snapshot = List<DownloadItem>.from(items);
    await release.future;
    return LibraryScanResult(fixedItems: snapshot, newItems: const []);
  }
}

class _FakeYtDlp extends YtDlpSource {
  _FakeYtDlp({this.downloadError, this.metadataError, this.metadataHold})
    : super(BinaryLocator(), ProcessRunner());

  final Object? downloadError;
  final Object? metadataError;
  final Completer<Map<String, dynamic>>? metadataHold;
  int metadataCalls = 0;
  int downloadCalls = 0;
  DownloadRequest? lastRequest;

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    String? cookiesFilePath,
    String? cookieBrowser,
    bool useTorProxy = false,
    bool Function()? isCancelled,
  }) async {
    metadataCalls++;
    if (metadataHold != null) {
      final result = await metadataHold!.future;
      if (isCancelled != null && isCancelled()) {
        throw const MetadataProbeCancelledException();
      }
      return result;
    }
    if (metadataError != null) {
      throw metadataError!;
    }
    return {'id': 'vid1', 'title': 'Test Video', 'thumbnail': null};
  }

  @override
  Stream<DownloadProgressEvent> download(
    String id,
    DownloadRequest request,
  ) async* {
    downloadCalls++;
    lastRequest = request;
    if (downloadError != null) {
      throw downloadError!;
    }
    yield DownloadProgressEvent(
      progress: 1,
      totalSize: '1MiB',
      speed: '',
      eta: '',
      title: 'Test Video',
    );
  }

  final List<String> cancelled = [];

  @override
  Future<void> cancel(String id) async => cancelled.add(id);
}

/// Streams progress lines faster than the save debounce, like real yt-dlp.
class _SteadyYtDlp extends _FakeYtDlp {
  @override
  Stream<DownloadProgressEvent> download(
    String id,
    DownloadRequest request,
  ) async* {
    for (var i = 1; i <= 15; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      yield DownloadProgressEvent(
        progress: i / 16,
        totalSize: '10MiB',
        speed: '1MiB/s',
        eta: '00:05',
      );
    }
  }
}

class _FakeGalleryDl extends GalleryDlSource {
  _FakeGalleryDl() : super(BinaryLocator());

  int downloadCalls = 0;

  @override
  Stream<GalleryDlProgressEvent> download(
    String id,
    DownloadRequest request,
  ) async* {
    downloadCalls++;
  }

  @override
  Future<void> cancel(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _MemoryPersistence persistence;
  late Completer<void> loaded;
  late _FakeGalleryDl gallery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('downloader-repo-');
    persistence = _MemoryPersistence();
    loaded = Completer<void>();
    gallery = _FakeGalleryDl();
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  DownloaderRepositoryImpl buildRepo(
    _FakeYtDlp source, {
    Future<void> Function()? networkPreflight,
    FallbackMediaResolver? fallbackResolver,
    LibraryScannerService? scanner,
  }) {
    return DownloaderRepositoryImpl(
      source,
      gallery,
      persistence,
      scanner ?? _NoopScanner(),
      PluginManager(),
      () => tmp.path,
      networkPreflight: networkPreflight,
      fallbackResolver: fallbackResolver,
      mediaFingerprintService: MediaFingerprintService(persistence),
      waitForLibraryScan: () async {
        if (!loaded.isCompleted) loaded.complete();
      },
    );
  }

  test('enqueue adds an extracting item without waiting for yt-dlp', () async {
    final hold = Completer<Map<String, dynamic>>();
    final repo = buildRepo(_FakeYtDlp(metadataHold: hold));
    await loaded.future.timeout(const Duration(seconds: 3));

    final id = await repo.startDownload(
      const DownloadRequest(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );

    expect(id, isNotEmpty);
    final items = repo.getCurrentDownloads();
    expect(items, hasLength(1));
    expect(items.first.id, id);
    expect(items.first.status, DownloadStatus.extracting);
    expect(items.first.request.url, contains('youtube.com'));
  });

  test('download failure marks the item failed', () async {
    final repo = buildRepo(
      _FakeYtDlp(downloadError: Exception('Low Disk Space: 100MB free')),
    );
    await loaded.future.timeout(const Duration(seconds: 3));

    final failed = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.failed && !failed.isCompleted) {
        failed.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );

    final item = await failed.future.timeout(const Duration(seconds: 8));
    expect(item.status, DownloadStatus.failed);
    expect(item.error, isNotNull);
  });

  test('wifi-only preflight fails the item before any download', () async {
    final source = _FakeYtDlp();
    final repo = buildRepo(
      source,
      networkPreflight: () async => throw const WifiOnlyBlockedException(),
    );
    await loaded.future.timeout(const Duration(seconds: 3));

    final failed = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.failed && !failed.isCompleted) {
        failed.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );

    final item = await failed.future.timeout(const Duration(seconds: 8));
    expect(item.error, contains('Wi-Fi only'));
    expect(source.downloadCalls, 0);
  });

  test('wifi-only refusal never falls back to gallery-dl', () async {
    final source = _FakeYtDlp();
    final repo = buildRepo(
      source,
      networkPreflight: () async => throw const WifiOnlyBlockedException(),
    );
    await loaded.future.timeout(const Duration(seconds: 3));
    final failed = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.failed && !failed.isCompleted) {
        failed.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(url: 'https://x.com/someone/status/1234567890123'),
    );

    final item = await failed.future.timeout(const Duration(seconds: 8));
    expect(item.error, contains('Wi-Fi only'));
    expect(gallery.downloadCalls, 0);
    expect(source.downloadCalls, 0);
  });

  test('falls back to a direct stream when yt-dlp finds no video', () async {
    final source = _FakeYtDlp(
      metadataError: YtDlpException(
        'ERROR: [twitter] 1: No video could be found in this tweet',
      ),
    );
    final repo = buildRepo(
      source,
      fallbackResolver: FallbackMediaResolver(
        fetchText: (url) async => url.host == 'api.fxtwitter.com'
            ? '{"tweet":{"text":"hello https://t.co/x","author":{"screen_name":"abc"},'
                  '"media":{"videos":[{"thumbnail_url":"https://img/t.jpg",'
                  '"url":"https://video.twimg.com/v/avc1/720x1280/a.mp4",'
                  '"formats":[{"container":"m3u8","url":"https://video.twimg.com/p.m3u8"},'
                  '{"container":"mp4","url":"https://video.twimg.com/v/avc1/320x568/b.mp4"},'
                  '{"container":"mp4","url":"https://video.twimg.com/v/avc1/720x1280/a.mp4"}]}]}}}'
            : null,
      ),
    );
    await loaded.future.timeout(const Duration(seconds: 3));
    final done = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.completed && !done.isCompleted) {
        done.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(
        url: 'https://x.com/abc/status/2122798036061483429',
      ),
    );

    await done.future.timeout(const Duration(seconds: 8));
    expect(source.lastRequest?.forceStreamUrl, contains('720x1280/a.mp4'));
    expect(source.lastRequest?.customFilename, startsWith('hello ['));
  });

  test('no fallback result keeps the yt-dlp failure', () async {
    final source = _FakeYtDlp(
      metadataError: YtDlpException(
        'ERROR: [twitter] 1: No video could be found in this tweet',
      ),
    );
    final repo = buildRepo(
      source,
      fallbackResolver: FallbackMediaResolver(fetchText: (_) async => null),
    );
    await loaded.future.timeout(const Duration(seconds: 3));
    final failed = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.failed && !failed.isCompleted) {
        failed.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(
        url: 'https://x.com/abc/status/2122798036061483429',
      ),
    );

    final item = await failed.future.timeout(const Duration(seconds: 8));
    expect(item.error, contains('No video'));
    expect(source.downloadCalls, 0);
  });

  test('a stream picked in the browser skips the metadata lookup', () async {
    final source = _FakeYtDlp();
    final repo = buildRepo(source);
    await loaded.future.timeout(const Duration(seconds: 3));
    final done = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.completed && !done.isCompleted) {
        done.complete(item);
      }
    });

    await repo.startDownload(
      const DownloadRequest(
        url: 'https://example.com/watch/1',
        forceStreamUrl: 'https://cdn.example.com/v/master.m3u8',
        customFilename: 'My clip [ab12].%(ext)s',
      ),
    );

    await done.future.timeout(const Duration(seconds: 8));
    expect(source.metadataCalls, 0);
    expect(source.lastRequest?.forceStreamUrl, endsWith('master.m3u8'));
  });

  test('deleteDownload removes item and cleans media files', () async {
    final repo = buildRepo(_FakeYtDlp(metadataHold: Completer()));
    await loaded.future.timeout(const Duration(seconds: 3));

    final media = File('${tmp.path}/clip.mp4');
    final thumb = File('${tmp.path}/clip.webp');
    final part = File('${tmp.path}/clip.mp4.part');
    await media.writeAsBytes(const [1, 2, 3, 4]);
    await thumb.writeAsBytes(const [5, 6]);
    await part.writeAsBytes(const [7]);

    final history = File('${tmp.path}/history.json');
    await history.writeAsString(
      jsonEncode([
        DownloadItem(
          id: 'del-1',
          request: const DownloadRequest(url: 'https://example.com/v'),
          status: DownloadStatus.completed,
          title: 'Clip',
          filePath: media.path,
        ).toJson(),
      ]),
    );

    await repo.importHistory(history.path);
    expect(repo.getCurrentDownloads().map((e) => e.id), contains('del-1'));

    await repo.deleteDownload('del-1');

    expect(repo.getCurrentDownloads().where((e) => e.id == 'del-1'), isEmpty);
    expect(await media.exists(), isFalse);
    expect(await thumb.exists(), isFalse);
    expect(await part.exists(), isFalse);
  });

  Future<DownloadItem> waitFailed(DownloaderRepositoryImpl repo) {
    final failed = Completer<DownloadItem>();
    repo.downloadUpdateStream.listen((item) {
      if (item.status == DownloadStatus.failed && !failed.isCompleted) {
        failed.complete(item);
      }
    });
    return failed.future;
  }

  test(
    'suspended metadata fails once without download or gallery-dl',
    () async {
      final source = _FakeYtDlp(metadataError: SuspendedContentException());
      final repo = buildRepo(source);
      await loaded.future.timeout(const Duration(seconds: 3));

      final failed = waitFailed(repo);
      await repo.startDownload(
        const DownloadRequest(
          url: 'https://x.com/alice/status/2093058718350893415',
        ),
      );

      final item = await failed.timeout(const Duration(seconds: 8));
      expect(item.status, DownloadStatus.failed);
      expect(item.error, isNot(contains('Exception:')));
      expect(item.error, contains('suspendu'));
      expect(source.metadataCalls, 1);
      expect(source.downloadCalls, 0);
      expect(gallery.downloadCalls, 0);
    },
  );

  test('no-video metadata fails once without download or gallery-dl', () async {
    final source = _FakeYtDlp(metadataError: NoMediaFoundException());
    final repo = buildRepo(source);
    await loaded.future.timeout(const Duration(seconds: 3));

    final failed = waitFailed(repo);
    await repo.startDownload(
      const DownloadRequest(
        url: 'https://x.com/alice/status/2091798624661602420',
      ),
    );

    final item = await failed.timeout(const Duration(seconds: 8));
    expect(item.status, DownloadStatus.failed);
    expect(item.error, isNot(contains('Exception:')));
    expect(item.error, contains('Aucune vidéo'));
    expect(source.metadataCalls, 1);
    expect(source.downloadCalls, 0);
    expect(gallery.downloadCalls, 0);
  });

  test('cancel during metadata aborts without download or fail', () async {
    final hold = Completer<Map<String, dynamic>>();
    final source = _FakeYtDlp(metadataHold: hold);
    final repo = buildRepo(source);
    await loaded.future.timeout(const Duration(seconds: 3));

    final id = await repo.startDownload(
      const DownloadRequest(
        url: 'https://x.com/alice/status/2093058718350893415',
      ),
    );
    await repo.cancelDownload(id);
    hold.complete({'id': 'vid1', 'title': 'Late', 'thumbnail': null});

    await Future<void>.delayed(const Duration(milliseconds: 150));
    final item = repo.getCurrentDownloads().firstWhere((e) => e.id == id);
    expect(item.status, DownloadStatus.canceled);
    expect(source.downloadCalls, 0);
    expect(gallery.downloadCalls, 0);
    expect(item.error, isNull);
  });

  test(
    'the library is saved while a download keeps reporting progress',
    () async {
      final repo = buildRepo(_SteadyYtDlp());
      await loaded.future.timeout(const Duration(seconds: 3));

      await repo.startDownload(
        const DownloadRequest(
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Progress lines arrive every 200 ms; they must not postpone the save
      // until the download goes quiet (a crash would lose the queue).
      expect(persistence.stored, isNotEmpty);
    },
  );

  test(
    'a library refresh keeps downloads that changed during the scan',
    () async {
      final scanner = _HeldScanner();
      final repo = buildRepo(_FakeYtDlp(), scanner: scanner);
      await loaded.future.timeout(const Duration(seconds: 3));

      final refresh = repo.refreshLibrary();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Added while the (slow) scan still works on its snapshot.
      final id = await repo.startDownload(
        const DownloadRequest(
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final before = repo.getCurrentDownloads().single;

      scanner.release.complete();
      await refresh;

      final after = repo.getCurrentDownloads();
      expect(after.map((e) => e.id), [id]);
      expect(after.single.status, before.status);
    },
  );

  test('shutdown stops running downloads and saves them to resume', () async {
    final source = _SteadyYtDlp();
    final repo = buildRepo(source);
    await loaded.future.timeout(const Duration(seconds: 3));

    final id = await repo.startDownload(
      const DownloadRequest(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await repo.shutdown();

    expect(source.cancelled, contains(id));
    // Saved as still running, so crash recovery re-queues it on next launch.
    final saved = persistence.stored.singleWhere((e) => e.id == id);
    expect(saved.status, DownloadStatus.downloading);
  });

  test('closing the app while the library still loads keeps it', () async {
    const saved = DownloadItem(
      id: 'old',
      request: DownloadRequest(url: 'https://example.com/old'),
      title: 'Old',
      status: DownloadStatus.completed,
      progress: 1,
    );
    persistence.stored = [saved];
    persistence.loadHold = Completer<void>();
    final repo = buildRepo(_FakeYtDlp());

    final exiting = repo.shutdown();
    persistence.loadHold!.complete();
    await exiting;

    // An empty snapshot written here would wipe the library on next launch.
    expect(persistence.stored.map((e) => e.id), ['old']);
  });

  test('a second shutdown waits for the first one', () async {
    final repo = buildRepo(_FakeYtDlp());
    await loaded.future.timeout(const Duration(seconds: 3));
    final first = repo.shutdown();
    final second = repo.shutdown();
    expect(identical(first, second), isTrue);
    await first;
  });

  test('pause then resume during metadata runs yt-dlp once', () async {
    final hold = Completer<Map<String, dynamic>>();
    final source = _FakeYtDlp(metadataHold: hold);
    final repo = buildRepo(source);
    await loaded.future.timeout(const Duration(seconds: 3));

    final id = await repo.startDownload(
      const DownloadRequest(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.pauseDownload(id);
    await repo.resumeDownload(id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Both the paused run and the resumed run are now waiting on the probe.
    hold.complete({'id': 'vid1', 'title': 'Test Video', 'thumbnail': null});
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Two runs would mean two yt-dlp processes writing the same file.
    expect(source.downloadCalls, 1);
  });

  test('reorder moves the dragged row one place down', () async {
    DownloadItem row(String id, int order) => DownloadItem(
      id: id,
      request: DownloadRequest(url: 'https://example.com/$id'),
      title: id,
      status: DownloadStatus.completed,
      progress: 1,
      sortOrder: order,
    );
    persistence.stored = [row('a', 0), row('b', 1), row('c', 2)];
    final repo = buildRepo(_FakeYtDlp());
    await loaded.future.timeout(const Duration(seconds: 3));

    // onReorderItem: 'a' dropped after 'b' gives newIndex 1 (post-removal).
    await repo.reorderDownloads(0, 1);

    final order = repo.getCurrentDownloads().toList()
      ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
    expect(order.map((e) => e.id), ['b', 'a', 'c']);
  });
}
