import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

Future<void> _settle(int ticks) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDownloaderRepository repo;
  late ProviderContainer container;

  Future<void> boot(List<DownloadItem> items) async {
    SharedPreferences.setMockInitialValues({});
    initPrefs(await SharedPreferences.getInstance());
    repo = FakeDownloaderRepository(items);
    container = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(repo),
        persistenceServiceProvider.overrideWithValue(FakePersistence()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(downloadListProvider, (_, _) {});
    await _settle(10);
  }

  test('removing a duplicate row by hand keeps the original file', () async {
    await boot(const [
      DownloadItem(
        id: 'dup',
        request: DownloadRequest(url: 'https://example.com/a'),
        title: 'Already here',
        status: DownloadStatus.duplicate,
        progress: 1,
        filePath: r'C:\Videos\a.mp4',
      ),
    ]);

    await container.read(downloadListProvider.notifier).deleteDownload('dup');

    expect(repo.deleteFilesCalls, [false]);
  });

  test(
    'an "already downloaded" row goes away without deleting the file',
    () async {
      const item = DownloadItem(
        id: 'dup',
        request: DownloadRequest(url: 'https://example.com/v'),
        title: 'Video',
        status: DownloadStatus.downloading,
        filePath: r'C:\Videos\video.mp4',
      );
      await boot(const [item]);

      // yt-dlp reports the existing file; its path is the user's real video.
      repo.emit(item.copyWith(status: DownloadStatus.duplicate, progress: 1));
      // Real 5 s delay in the provider: wait on the outcome, not a fixed time.
      for (var i = 0; i < 100 && repo.deleteFilesCalls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(repo.deleteFilesCalls, [false]);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
