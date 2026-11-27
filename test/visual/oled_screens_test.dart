// Renders the Android OLED screens to build/visual/*.png so they can be
// compared by eye with the HTML mockups. This is not a golden test: it never
// compares pixels, it only writes images and reports layout errors.
//
//   flutter test test/visual/oled_screens_test.dart --no-pub
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/ui/mobile/mobile_app_shell.dart';
import 'package:tapload/core/ui/settings/settings_hub_view.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/mobile/tiktok_collections_mobile_view.dart';
import 'package:tapload/features/archive/presentation/views/tiktok_archive_view.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/download_view.dart';
import 'package:tapload/features/downloader/presentation/views/mobile/mobile_add_download_sheet.dart';
import 'package:tapload/features/downloader/presentation/views/mobile/mobile_download_details_sheet.dart';
import 'package:tapload/features/stats/presentation/views/stats_view.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/features/transfer/presentation/transfer_view.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import 'visual_fakes.dart';
import 'visual_harness.dart';

void main() {
  final results = <String, ScreenResult>{};

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
  });

  tearDownAll(() {
    writeReport(results);
    // ignore: avoid_print
    print('[visual] fonts:\n  ${fontReport.join('\n  ')}');
    // ignore: avoid_print
    print('[visual] report: $kVisualOutDir/report.txt');
  });

  List<Override> overrides({List<Override> extra = const []}) => [
    ...baseOverrides(),
    downloaderRepositoryProvider.overrideWith(
      (ref) => FakeDownloaderRepository(sampleDownloads()),
    ),
    persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
    downloadListProvider.overrideWith(
      (ref) => PinnedDownloadList(
        ref.read(downloaderRepositoryProvider),
        ref,
        sampleDownloads(),
      ),
    ),
    downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
    ...extra,
  ];

  Future<GlobalKey> pumpApp(
    WidgetTester tester, {
    required String location,
    required Map<String, Widget Function()> pages,
    List<Override> extra = const [],
  }) async {
    final key = GlobalKey();
    step('pumpWidget');
    await tester.pumpWidget(
      VisualApp(
        boundaryKey: key,
        router: buildRouter(initialLocation: location, pages: pages),
        overrides: overrides(extra: extra),
      ),
    );
    await settle(tester);
    return key;
  }

  Map<String, Widget Function()> libraryPages() => {
    '/': () => const DownloadView(),
  };

  screenTest('01_library', results, (tester, result) async {
    final key = await pumpApp(tester, location: '/', pages: libraryPages());
    result.png = await capture(tester, key, '01_library');
    await teardown(tester);
  });

  screenTest('02_add', results, (tester, result) async {
    final key = await pumpApp(tester, location: '/', pages: libraryPages());
    final context = tester.element(find.byType(MobileAppShell));
    // ignore: unawaited_futures
    MobileAddDownloadSheet.show(
      context,
      initialUrl: 'https://www.youtube.com/watch?v=Zq8Jf2xLk9A',
    );
    await settle(tester);
    // Let the debounced metadata probe run and the preview render.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    result.png = await capture(tester, key, '02_add');
    await teardown(tester);
  });

  screenTest('03_details_failed', results, (tester, result) async {
    final key = await pumpApp(tester, location: '/', pages: libraryPages());
    final context = tester.element(find.byType(MobileAppShell));
    // ignore: unawaited_futures
    MobileDownloadDetailsSheet.show(context, failedItemId);
    await settle(tester);
    result.png = await capture(tester, key, '03_details_failed');
    await teardown(tester);
  });

  screenTest('04_settings', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/settings',
      pages: {'/settings': () => const AdaptiveSettingsHome()},
    );
    result.png = await capture(tester, key, '04_settings');
    await teardown(tester);
  });

  screenTest('05_stats', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/stats',
      pages: {'/stats': () => const StatsView()},
    );
    result.png = await capture(tester, key, '05_stats');
    await teardown(tester);
  });

  screenTest('06_tiktok', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/archive',
      pages: {'/archive': () => const TikTokArchiveView()},
      extra: [
        // Showcase mode makes the notifier seed itself synchronously.
        showcaseModeProvider.overrideWithValue(true),
        tikTokArchiveRepositoryProvider.overrideWith(
          (ref) => FakeArchiveRepository(),
        ),
        tikTokArchiveProvider.overrideWith(
          (ref) => DemoArchiveNotifier(FakeArchiveRepository(), ref),
        ),
      ],
    );
    result.png = await capture(tester, key, '06_tiktok');
    await teardown(tester);
  });

  List<Override> tiktokOverrides() => [
    showcaseModeProvider.overrideWithValue(true),
    tikTokArchiveRepositoryProvider.overrideWith(
      (ref) => FakeArchiveRepository(),
    ),
    tikTokArchiveProvider.overrideWith(
      (ref) => DemoArchiveNotifier(FakeArchiveRepository(), ref),
    ),
  ];

  screenTest('06b_tiktok_collections', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/archive',
      pages: {
        '/archive': () => Consumer(
          builder: (context, ref, _) {
            final catalog = ref.watch(
              tikTokArchiveProvider.select((s) => s.catalog),
            );
            if (catalog == null) return const SizedBox.shrink();
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: TikTokCollectionsMobileView(
                  catalog: catalog,
                  onShowVideos: () {},
                ),
              ),
            );
          },
        ),
      },
      extra: tiktokOverrides(),
    );
    result.png = await capture(tester, key, '06b_tiktok_collections');
    await teardown(tester);
  });

  screenTest('06c_tiktok_collection_detail', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/archive',
      pages: {
        '/archive': () => Consumer(
          builder: (context, ref, _) {
            final catalog = ref.watch(
              tikTokArchiveProvider.select((s) => s.catalog),
            );
            if (catalog == null) return const SizedBox.shrink();
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: TikTokCollectionsMobileView(
                  catalog: catalog,
                  onShowVideos: () {},
                ),
              ),
            );
          },
        ),
      },
      extra: tiktokOverrides(),
    );
    await tester.tap(find.text('Cuisine'));
    await settle(tester);
    result.png = await capture(tester, key, '06c_tiktok_collection_detail');
    await teardown(tester);
  });

  screenTest('07_transfer', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/transfer',
      pages: {'/transfer': () => const TransferView()},
      extra: [
        transferControllerProvider.overrideWith(
          (ref) => FakeTransferController(ref),
        ),
      ],
    );
    result.png = await capture(tester, key, '07_transfer');
    await teardown(tester);
  });

  screenTest('08_navbar_only', results, (tester, result) async {
    final key = await pumpApp(
      tester,
      location: '/',
      pages: {'/': () => const SizedBox.shrink()},
    );
    result.png = await capture(tester, key, '08_navbar_only');
    await teardown(tester);
  });
}
