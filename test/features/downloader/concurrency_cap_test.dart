import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the concurrency cap counts downloads the list has not shown yet',
    () async {
      SharedPreferences.setMockInitialValues({});
      initPrefs(await SharedPreferences.getInstance());
      final items = <DownloadItem>[];
      final repo = FakeDownloaderRepository(items);
      final container = ProviderContainer(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(repo),
          persistenceServiceProvider.overrideWithValue(FakePersistence()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(downloadListProvider, (_, _) {});
      container.read(settingsProvider.notifier).setMaxConcurrent(1);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // The repository already runs one; its first update is still inside the
      // 250 ms progress throttle, so the visible list does not show it yet.
      items.add(
        const DownloadItem(
          id: 'running',
          request: DownloadRequest(url: 'https://example.com/1'),
          title: 'Running',
          status: DownloadStatus.extracting,
        ),
      );

      await container
          .read(downloadListProvider.notifier)
          .startDownload('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(repo.startCalls, 0);
    },
  );
}
