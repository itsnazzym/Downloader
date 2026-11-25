import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:modern_downloader/features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/transfer/data/localsend_api.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';

const String failedItemId = 'dl-failed';

/// Sample library matching the Main mockup.
List<DownloadItem> sampleDownloads() => const [
  DownloadItem(
    id: 'dl-active',
    request: DownloadRequest(
      url: 'https://www.youtube.com/watch?v=Zq8Jf2xLk9A',
    ),
    title: 'Documentaire, les derniers glaciers',
    status: DownloadStatus.downloading,
    progress: 0.62,
    speed: '6.2MiB/s',
    eta: '00:05',
    downloadedSize: '54.1MiB',
    totalSize: '87.3MiB',
    step: 'Téléchargement',
    usesAria2c: true,
  ),
  DownloadItem(
    id: 'dl-done-1',
    request: DownloadRequest(url: 'https://vimeo.com/76979871'),
    title: 'Concert acoustique, session live',
    status: DownloadStatus.completed,
    progress: 1,
    totalSize: '84.2MiB',
    downloadedSize: '84.2MiB',
  ),
  DownloadItem(
    id: 'dl-done-2',
    request: DownloadRequest(
      url: 'https://www.youtube.com/watch?v=Pc9Lw3mBd7Q',
    ),
    title: 'Monter un PC en 20 minutes',
    status: DownloadStatus.completed,
    progress: 1,
    totalSize: '212MiB',
    downloadedSize: '212MiB',
  ),
  DownloadItem(
    id: failedItemId,
    request: DownloadRequest(
      url: 'https://x.com/atelier_nord/status/1790234567890123456',
    ),
    title: 'Clip court',
    status: DownloadStatus.failed,
    error: 'ERROR: [twitter] No video could be found in this tweet',
  ),
  DownloadItem(
    id: 'dl-queued',
    request: DownloadRequest(
      url: 'https://www.youtube.com/playlist?list=PLmixdusoir',
    ),
    title: 'Playlist, mix du soir',
    status: DownloadStatus.queued,
  ),
];

class FakePersistence extends PersistenceService {
  @override
  Future<List<DownloadRequest>> loadQueue() async => [];

  @override
  Future<void> saveQueue(List<DownloadRequest> queue) async {}

  @override
  Future<List<DownloadItem>> loadDownloads() async => [];

  @override
  Future<void> saveDownloads(List<DownloadItem> downloads) async {}
}

/// Read-only in-memory repository: no processes, no network.
class FakeDownloaderRepository implements IDownloaderRepository {
  FakeDownloaderRepository(this._items);

  final List<DownloadItem> _items;
  final StreamController<DownloadItem> _updates = StreamController.broadcast();

  @override
  Future<void> get initialized async {}

  @override
  List<DownloadItem> getCurrentDownloads() => List.unmodifiable(_items);

  @override
  Stream<DownloadItem> get downloadUpdateStream => _updates.stream;

  @override
  Future<String> startDownload(DownloadRequest request) async {
    startCalls++;
    return 'new';
  }

  /// How many downloads the provider asked this repository to start.
  int startCalls = 0;

  @override
  Future<void> cancelDownload(String id) async {}

  @override
  Future<void> pauseDownload(String id) async {}

  @override
  Future<void> resumeDownload(String id) async {}

  /// Pushes an update as the real repository does.
  void emit(DownloadItem item) => _updates.add(item);

  /// Every `deleteFiles` flag passed to [deleteDownload], in call order.
  final List<bool> deleteFilesCalls = [];

  @override
  Future<void> deleteDownload(String id, {bool deleteFiles = true}) async {
    deleteFilesCalls.add(deleteFiles);
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0) return;
    // Like the real repository: a final `canceled` copy goes out on the stream.
    _updates.add(_items[index].copyWith(status: DownloadStatus.canceled));
  }

  @override
  Future<void> reorderDownloads(int oldIndex, int newIndex) async {}

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    bool? useTorProxy,
  }) async => {
    'title': 'Documentaire, les derniers glaciers',
    'uploader': 'Atelier Nord',
    'duration': 1425,
    'formats': [
      {'vcodec': 'none', 'acodec': 'mp4a', 'filesize': 22 * 1024 * 1024},
      {
        'vcodec': 'avc1',
        'acodec': 'none',
        'height': 480,
        'filesize': 61 * 1024 * 1024,
      },
      {
        'vcodec': 'avc1',
        'acodec': 'none',
        'height': 720,
        'filesize': 118 * 1024 * 1024,
      },
      {
        'vcodec': 'avc1',
        'acodec': 'none',
        'height': 1080,
        'filesize': 241 * 1024 * 1024,
      },
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(
    String url, {
    bool? useTorProxy,
  }) async => [];

  @override
  Future<void> clearHistory() async {}

  @override
  Future<void> exportHistory(String path) async {}

  @override
  Future<void> importHistory(String path) async {}

  @override
  Future<void> refreshLibrary() async {}
}

/// The real notifier auto-deletes failures it classifies as permanent
/// (including the mockup's "No video could be found" error) at startup. Pin the
/// sample list after that purge so the failed row can be rendered.
class PinnedDownloadList extends DownloadListNotifier {
  PinnedDownloadList(super.repository, super.ref, this._items) {
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (mounted) state = AsyncValue.data(_items);
    });
  }

  final List<DownloadItem> _items;
}

/// Stats matching the Stats mockup: 18.6 GB, 142 downloads, three sources.
class FakeStatsNotifier extends DownloadStatsNotifier {
  FakeStatsNotifier() {
    final now = DateTime.now();
    final history = <DailyStats>[];
    for (var daysAgo = 83; daysAgo >= 0; daysAgo--) {
      final date = now.subtract(Duration(days: daysAgo));
      // Deterministic pseudo-random activity, denser in recent weeks.
      final seed = (date.day * 7 + date.month * 13 + daysAgo * 3) % 11;
      final n = seed < 4 ? 0 : (seed < 7 ? 1 : (seed < 9 ? 2 : 4));
      if (n == 0) continue;
      history.add(
        DailyStats(
          date: date.toIso8601String().substring(0, 10),
          downloads: n,
          bytes: n * 120 * 1024 * 1024,
        ),
      );
    }
    state = DownloadStats(
      totalDownloads: 142,
      downloadsToday: 3,
      totalBytesDownloaded: (18.6 * 1024 * 1024 * 1024).round(),
      bytesToday: 420 * 1024 * 1024,
      downloadsBySource: const {
        'youtube.com': 87,
        'x.com': 33,
        'vimeo.com': 22,
      },
      dailyHistory: history,
      lastUpdated: now,
    );
  }

  @override
  void rebuildFromLibrary(List<DownloadItem> items) {}
}

/// Archive notifier seeded with a richer demo than the showcase one. The
/// showcase flag makes the base constructor fill state synchronously.
class DemoArchiveNotifier extends TikTokArchiveNotifier {
  DemoArchiveNotifier(super.repo, super.ref) {
    final base = DateTime(2026, 9, 20);
    final names = ['Cuisine', 'Voyages'];
    final videos = [
      for (var i = 0; i < 12; i++)
        TikTokArchiveItem(
          id: '73000000000000000${i + 10}',
          url:
              'https://www.tiktok.com/@atelier.cuisine/video/73000000000000000${i + 10}',
          date: base.subtract(Duration(days: i * 3)),
          collectionId: i.isEven ? 'cuisine' : 'voyages',
          collectionName: names[i % 2],
          isFavorite: i % 3 == 0,
          isLiked: true,
          isDownloaded: i < 4,
        ),
    ];
    final catalog = TikTokArchiveCatalog(
      videos: videos,
      collections: const [
        TikTokCollectionItem(id: 'cuisine', name: 'Cuisine', videoCount: 6),
        TikTokCollectionItem(id: 'voyages', name: 'Voyages', videoCount: 6),
      ],
      sounds: const [],
      totalFavorites: 4,
      totalLikes: 12,
      totalOverlap: 4,
      yearCounts: const {2026: 12},
    );
    state = state.copyWith(
      catalog: catalog,
      viewMode: TikTokViewMode.list,
      selectedIds: {videos[1].id, videos[2].id},
      isBatchDownloading: true,
      batchCompletedCount: 42,
      batchTotalCount: 86,
    );
  }
}

class FakeArchiveRepository implements ITikTokArchiveRepository {
  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async => null;

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async =>
      TikTokArchiveCatalog.empty;

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog catalog) async {}

  @override
  Future<void> clearCatalog() async {}
}

/// Transfer controller with two nearby peers and a transfer in flight.
class FakeTransferController extends TransferController {
  FakeTransferController(super.ref);

  @override
  Future<void> start() async {
    state = const TransferUiState(
      started: true,
      pin: '123456',
      port: LocalSendApi.defaultPort,
      lanIp: '192.168.1.42',
      alias: 'Pixel de Léa',
      fingerprint: 'DEMO-SELF',
      peers: [
        TransferPeer(
          alias: 'PC du bureau',
          fingerprint: 'DEMO-PC',
          ip: '192.168.1.24',
          port: LocalSendApi.defaultPort,
          deviceType: TransferDeviceType.desktop,
          deviceModel: 'Windows',
        ),
        TransferPeer(
          alias: 'Téléphone de Léa',
          fingerprint: 'DEMO-PHONE',
          ip: '192.168.1.31',
          port: LocalSendApi.defaultPort,
          deviceType: TransferDeviceType.mobile,
          deviceModel: 'Android',
        ),
      ],
      selectedFilesCount: 3,
      selectedTotalBytes: 208 * 1024 * 1024,
      activeTargetFingerprint: 'DEMO-PC',
      progress: TransferProgress(
        phase: TransferPhase.transferring,
        bytesDone: 142 * 1024 * 1024,
        bytesTotal: 208 * 1024 * 1024,
        currentName: 'Documentaire.mp4',
        bytesPerSecond: 18.3 * 1024 * 1024,
      ),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> scanSubnet() async {}

  @override
  Future<void> triggerDiscoveryPulse() async {}
}
