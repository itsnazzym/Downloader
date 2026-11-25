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

  test(
    'a changing size estimate while downloading stays off the catalog',
    () async {
      SharedPreferences.setMockInitialValues({});
      initPrefs(await SharedPreferences.getInstance());
      const item = DownloadItem(
        id: 'live',
        request: DownloadRequest(url: 'https://example.com/a.m3u8'),
        title: 'Stream',
        status: DownloadStatus.downloading,
        progress: 0.1,
        totalSize: '~10.00MiB',
      );
      final repo = FakeDownloaderRepository([item]);
      final container = ProviderContainer(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(repo),
          persistenceServiceProvider.overrideWithValue(FakePersistence()),
        ],
      );
      addTearDown(container.dispose);

      var catalogEmits = 0;
      container.listen(downloadListProvider, (_, _) => catalogEmits++);
      await _settle(10);
      catalogEmits = 0;

      // yt-dlp's "~" estimate for fragmented streams moves on every line.
      repo.emit(item.copyWith(progress: 0.2, totalSize: '~11.00MiB'));
      await _settle(12);
      repo.emit(item.copyWith(progress: 0.3, totalSize: '~12.50MiB'));
      await _settle(12);

      expect(catalogEmits, 0);
      expect(
        container.read(downloadItemByIdProvider('live'))?.totalSize,
        '~12.50MiB',
      );

      // The final size still reaches the catalog when the download ends.
      repo.emit(
        item.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          totalSize: '13.00MiB',
        ),
      );
      await _settle(12);
      expect(
        container.read(downloadListProvider).valueOrNull!.single.totalSize,
        '13.00MiB',
      );
    },
  );
}
