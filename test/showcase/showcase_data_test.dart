import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/showcase/showcase_data.dart';

void main() {
  test('fixtures use distinct public videos and allow-listed thumbnails', () {
    final items = createShowcaseDownloads();
    expect(items.length, 7);
    expect(
      items.where((item) => item.status == DownloadStatus.completed),
      hasLength(5),
    );
    expect(items.map((item) => item.request.url).toSet(), hasLength(7));
    expect(items.map((item) => item.title).toSet(), hasLength(7));
    for (final item in items) {
      expect(item.filePath, isNull);
      expect(item.request.outputFolder, isNull);
      expect(item.request.url, startsWith('https://www.youtube.com/watch?v='));
      expect(item.thumbnailUrl, startsWith('https://i.ytimg.com/vi/'));
      expect(
        isAllowedShowcaseThumbnailUrl(Uri.parse(item.thumbnailUrl!)),
        isTrue,
      );
    }
    expect(
      items.any((item) => (item.title ?? '').contains('Squeezie')),
      isTrue,
    );
    expect(
      items.any((item) => (item.title ?? '').contains('Crunchyroll FR')),
      isTrue,
    );
    expect(
      isAllowedShowcaseThumbnailUrl(
        Uri.parse('https://i.ytimg.com/vi/not-in-the-catalog/hqdefault.jpg'),
      ),
      isFalse,
    );
    expect(
      isAllowedShowcaseThumbnailUrl(
        Uri.parse('https://youtube.com/watch?v=hYtteXlh3ZQ'),
      ),
      isFalse,
    );

    final archive = createShowcaseArchive();
    expect(archive.videos, hasLength(4));
    expect(archive.videos.map((video) => video.id).toSet(), hasLength(4));
    expect(
      archive.videos.every((video) => video.url.contains('.invalid/')),
      isTrue,
    );
  });

  test(
    'download actions only mutate the volatile showcase repository',
    () async {
      final repository = ShowcaseDownloaderRepository();
      final initialCount = repository.getCurrentDownloads().length;
      final id = await repository.startDownload(
        const DownloadRequest(url: 'https://example.org/private-input'),
      );
      expect(repository.getCurrentDownloads(), hasLength(initialCount + 1));
      expect(
        repository.getCurrentDownloads().first.request.url,
        isNot(contains('private-input')),
      );
      await repository.pauseDownload(id);
      expect(
        repository.getCurrentDownloads().first.status,
        DownloadStatus.paused,
      );
      await repository.resumeDownload(id);
      expect(
        repository.getCurrentDownloads().first.status,
        DownloadStatus.downloading,
      );
      await repository.cancelDownload(id);
      expect(
        repository.getCurrentDownloads().first.status,
        DownloadStatus.canceled,
      );
      await repository.deleteDownload(id);
      expect(repository.getCurrentDownloads(), hasLength(initialCount));
      expect(
        ShowcaseDownloaderRepository().getCurrentDownloads(),
        hasLength(initialCount),
      );
    },
  );

  test('showcase persistence never loads saved user data', () async {
    final persistence = ShowcasePersistenceService();
    expect(await persistence.loadDownloads(), isEmpty);
    expect(await persistence.loadQueue(), isEmpty);
    await persistence.saveDownloads(createShowcaseDownloads());
    await persistence.saveQueue([
      const DownloadRequest(url: 'https://example.org/private-input'),
    ]);
    expect(await persistence.loadDownloads(), isEmpty);
    expect(await persistence.loadQueue(), isEmpty);
  });
}
