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

  @override
  Future<List<DownloadItem>> loadDownloads() async =>
      List<DownloadItem>.from(stored);

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

class _FakeYtDlp extends YtDlpSource {
  _FakeYtDlp({this.downloadError, this.metadataError, this.metadataHold})
    : super(BinaryLocator(), ProcessRunner());

  final Object? downloadError;
  final Object? metadataError;
  final Completer<Map<String, dynamic>>? metadataHold;
  int metadataCalls = 0;
  int downloadCalls = 0;

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

  @override
  Future<void> cancel(String id) async {}
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

  DownloaderRepositoryImpl buildRepo(_FakeYtDlp source) {
    return DownloaderRepositoryImpl(
      source,
      gallery,
      persistence,
      _NoopScanner(),
      PluginManager(),
      () => tmp.path,
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

  Future<DownloadItem> _waitFailed(DownloaderRepositoryImpl repo) {
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

      final failed = _waitFailed(repo);
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

    final failed = _waitFailed(repo);
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
}
