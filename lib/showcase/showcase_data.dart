import 'dart:async';

import '../features/archive/domain/entities/tiktok_archive_catalog.dart';
import '../features/archive/domain/repositories/i_tiktok_archive_repository.dart';
import '../features/downloader/data/datasources/persistence_service.dart';
import '../features/downloader/domain/entities/download_item.dart';
import '../features/downloader/domain/entities/download_request.dart';
import '../features/downloader/domain/enums/download_status.dart';
import '../features/downloader/domain/repositories/i_downloader_repository.dart';
import '../core/services/download_stats_service.dart';

/// Fixed, public videos used by the Windows showcase. The repository below
/// only displays their metadata; it never downloads the videos.
const showcaseVideos = <ShowcaseVideo>[
  ShowcaseVideo(
    id: 'squeezie-imposteur',
    channel: 'Squeezie',
    title: "QUI EST L'IMPOSTEUR ? (ft Alexandre Astier & Kyan Khojandi)",
    videoId: 'hYtteXlh3ZQ',
    size: '1.4 GB',
  ),
  ShowcaseVideo(
    id: 'inoxtag-kaizen',
    channel: 'Inoxtag',
    title: '[Trailer] KAIZEN - Everest',
    videoId: '6VgKYd0JWq4',
    size: '92 MB',
    status: DownloadStatus.downloading,
    progress: .68,
  ),
  ShowcaseVideo(
    id: 'mcfly-thomas-pesquet',
    channel: 'McFly et Carlito',
    title: 'CONCOURS D’ANECDOTES vs THOMAS PESQUET LA LÉGENDE',
    videoId: 'PRp3AclnHsc',
    size: '1.1 GB',
  ),
  ShowcaseVideo(
    id: 'michou-m2lt',
    channel: 'Michou',
    title: 'M2LT (Clip officiel)',
    videoId: 'wKQiJDWc2EE',
    size: '86 MB',
    status: DownloadStatus.paused,
    progress: .42,
  ),
  ShowcaseVideo(
    id: 'jujutsu-kaisen-trailer',
    channel: 'Crunchyroll FR',
    title: 'JUJUTSU KAISEN | TRAILER OFFICIEL',
    videoId: 'Xz5bOFNbjnI',
    size: '78 MB',
  ),
  ShowcaseVideo(
    id: 'demon-slayer-trailer',
    channel: 'Crunchyroll FR',
    title: 'Demon Slayer: Kimetsu no Yaiba | TRAILER OFFICIEL',
    videoId: 'Ogr9pOY8Wew',
    size: '82 MB',
  ),
  ShowcaseVideo(
    id: 'one-piece-trailer',
    channel: 'Crunchyroll FR',
    title: 'One Piece | Nous ne faisons que commencer - Trailer',
    videoId: '5FOSlStFPE0',
    size: '75 MB',
  ),
];

class ShowcaseVideo {
  const ShowcaseVideo({
    required this.id,
    required this.channel,
    required this.title,
    required this.videoId,
    required this.size,
    this.status = DownloadStatus.completed,
    this.progress = 1,
  });

  final String id;
  final String channel;
  final String title;
  final String videoId;
  final String size;
  final DownloadStatus status;
  final double progress;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  String get displayTitle => '$channel · $title';
}

/// Only the seven fixed thumbnail URLs above are permitted to leave the demo
/// process. No YouTube page, player, profile, or download endpoint is allowed.
bool isAllowedShowcaseThumbnailUrl(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'i.ytimg.com' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    uri.query.isEmpty &&
    uri.fragment.isEmpty &&
    showcaseVideos.any(
      (video) => uri.path == '/vi/${video.videoId}/hqdefault.jpg',
    );

/// The demo catalog is synthetic state around real, recognizable public
/// videos. Its only network images are fixed official YouTube thumbnails.
List<DownloadItem> createShowcaseDownloads() => [
  for (final video in showcaseVideos)
    DownloadItem(
      id: 'showcase-${video.id}',
      request: DownloadRequest(url: video.watchUrl),
      title: video.displayTitle,
      status: video.status,
      progress: video.progress,
      totalSize: video.size,
      downloadedSize: video.status == DownloadStatus.completed
          ? video.size
          : '${(video.progress * 100).round()} %',
      speed: video.status == DownloadStatus.downloading ? '4.8 MB/s' : '',
      eta: video.status == DownloadStatus.downloading ? '00:28' : '',
      thumbnailUrl: video.thumbnailUrl,
    ),
];

TikTokArchiveCatalog createShowcaseArchive() {
  final videos = [
    for (var i = 0; i < 4; i++)
      TikTokArchiveItem(
        id: 'demo-${i + 1}',
        url: 'https://showcase.invalid/archive/${i + 1}',
        date: DateTime(2026, 9, 20 - i),
        collectionId: i < 2 ? 'cinema' : 'animation',
        collectionName: i < 2 ? 'Cinéma ouvert' : 'Animation',
        isFavorite: i.isEven,
        isLiked: true,
        isDownloaded: i < 2,
      ),
  ];
  return TikTokArchiveCatalog(
    videos: videos,
    collections: [
      const TikTokCollectionItem(
        id: 'cinema',
        name: 'Cinéma ouvert',
        videoCount: 2,
      ),
      const TikTokCollectionItem(
        id: 'animation',
        name: 'Animation',
        videoCount: 2,
      ),
    ],
    sounds: [],
    totalFavorites: 2,
    totalLikes: 4,
    totalOverlap: 2,
    yearCounts: const {2026: 4},
  );
}

class ShowcasePersistenceService extends PersistenceService {
  @override
  Future<List<DownloadRequest>> loadQueue() async => [];

  @override
  Future<void> saveQueue(List<DownloadRequest> queue) async {}

  @override
  Future<List<DownloadItem>> loadDownloads() async => [];

  @override
  Future<void> saveDownloads(List<DownloadItem> downloads) async {}
}

/// In-memory implementation of the production repository contract. Every
/// mutation stays in this instance, and metadata requests never leave it.
class ShowcaseDownloaderRepository implements IDownloaderRepository {
  ShowcaseDownloaderRepository() : _items = createShowcaseDownloads();

  final List<DownloadItem> _items;
  final StreamController<DownloadItem> _updates = StreamController.broadcast();

  @override
  Future<void> get initialized async {}

  @override
  List<DownloadItem> getCurrentDownloads() => List.unmodifiable(_items);

  @override
  Stream<DownloadItem> get downloadUpdateStream => _updates.stream;

  void _replace(DownloadItem item) {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      _items.insert(0, item);
    } else {
      _items[index] = item;
    }
    _updates.add(item);
  }

  @override
  Future<String> startDownload(DownloadRequest request) async {
    final id = 'showcase-added-${_items.length + 1}';
    _replace(
      DownloadItem(
        id: id,
        request: DownloadRequest(url: 'https://showcase.invalid/media/$id'),
        title: 'Nouveau média de démonstration',
        status: DownloadStatus.downloading,
        progress: .15,
        totalSize: '120 MB',
        thumbnailUrl: showcaseVideos.first.thumbnailUrl,
      ),
    );
    return id;
  }

  @override
  Future<void> cancelDownload(String id) async {
    final item = _items.where((entry) => entry.id == id).firstOrNull;
    if (item != null) _replace(item.copyWith(status: DownloadStatus.canceled));
  }

  @override
  Future<void> pauseDownload(String id) async {
    final item = _items.where((entry) => entry.id == id).firstOrNull;
    if (item != null) _replace(item.copyWith(status: DownloadStatus.paused));
  }

  @override
  Future<void> resumeDownload(String id) async {
    final item = _items.where((entry) => entry.id == id).firstOrNull;
    if (item != null) {
      _replace(item.copyWith(status: DownloadStatus.downloading));
    }
  }

  @override
  Future<void> deleteDownload(String id) async {
    _items.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> reorderDownloads(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex < 0 ||
        newIndex >= _items.length) {
      return;
    }
    _items.insert(newIndex, _items.removeAt(oldIndex));
  }

  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    bool? useTorProxy,
  }) async => {
    'title': 'Média de démonstration',
    'thumbnail': showcaseVideos.first.thumbnailUrl,
  };

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(
    String url, {
    bool? useTorProxy,
  }) async => [];

  @override
  Future<void> clearHistory() async => _items.clear();

  @override
  Future<void> exportHistory(String path) async {}

  @override
  Future<void> importHistory(String path) async {}

  @override
  Future<void> refreshLibrary() async {}
}

class ShowcaseArchiveRepository implements ITikTokArchiveRepository {
  TikTokArchiveCatalog? _catalog = createShowcaseArchive();

  @override
  Future<TikTokArchiveCatalog?> getCachedCatalog() async => _catalog;

  @override
  Future<TikTokArchiveCatalog> importFromFile(String filePath) async =>
      _catalog ?? createShowcaseArchive();

  @override
  Future<void> saveCatalog(TikTokArchiveCatalog catalog) async {
    _catalog = catalog;
  }

  @override
  Future<void> clearCatalog() async {
    _catalog = null;
  }
}

class ShowcaseStatsNotifier extends DownloadStatsNotifier {
  ShowcaseStatsNotifier() {
    final today = DateTime.now();
    state = DownloadStats(
      totalDownloads: 5,
      downloadsToday: 2,
      totalBytesDownloaded: 2735000000,
      bytesToday: 165000000,
      downloadsBySource: const {'YouTube': 5},
      dailyHistory: [
        for (var daysAgo = 6; daysAgo >= 0; daysAgo--)
          DailyStats(
            date: today
                .subtract(Duration(days: daysAgo))
                .toIso8601String()
                .substring(0, 10),
            downloads: [0, 1, 0, 1, 1, 0, 2][6 - daysAgo],
            bytes: [0, 78, 0, 80, 85, 0, 165][6 - daysAgo] * 1000000,
          ),
      ],
      lastUpdated: today,
    );
  }

  @override
  void rebuildFromLibrary(List<DownloadItem> items) {}
}
