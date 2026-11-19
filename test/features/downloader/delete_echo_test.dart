import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleting a row does not bring it back as a ghost', () async {
    SharedPreferences.setMockInitialValues({});
    initPrefs(await SharedPreferences.getInstance());
    const item = DownloadItem(
      id: 'keep',
      request: DownloadRequest(url: 'https://example.com/a.mp4'),
      title: 'Kept',
      status: DownloadStatus.completed,
      progress: 1,
    );
    const failed = DownloadItem(
      id: 'gone',
      request: DownloadRequest(url: 'https://example.com/b.mp4'),
      title: 'Failed once',
      status: DownloadStatus.failed,
      error: 'Wi-Fi only is on and the device is using mobile data.',
    );
    final repo = FakeDownloaderRepository([item, failed]);
    final container = ProviderContainer(
      overrides: [
        downloaderRepositoryProvider.overrideWithValue(repo),
        persistenceServiceProvider.overrideWithValue(FakePersistence()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(downloadListProvider.notifier);
    // Let _init load the catalog.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(
      container.read(downloadListProvider).valueOrNull?.map((e) => e.id),
      containsAll(['keep', 'gone']),
    );

    await notifier.deleteDownload('gone');
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final ids = container
        .read(downloadListProvider)
        .valueOrNull!
        .map((e) => e.id);
    expect(ids, ['keep']);
  });
}
