// Renders Studio's own library, inspector and archive surfaces in the states
// the shared `surface studio` renders do not reach, to
// build/visual/studio_<name>.png. Like the other visual tests it never
// compares pixels: it fails only on a crash.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/router/app_router.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    await prefs.setBool(OnboardingStore.prefsKey, true);
  });

  tearDown(() => PlatformInfo.debugForceMobile = null);

  Future<(GlobalKey, ProviderContainer)> pump(
    WidgetTester tester,
    String route, {
    List<Override> extra = const [],
    List<DownloadItem>? items,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final data = items ?? sampleDownloads();
    final preset = ThemePresets.getById('studio');
    final container = ProviderContainer(
      overrides: [
        ...baseOverrides(),
        dependencyBootstrapProvider.overrideWith(
          (ref) => DependencyBootstrapNotifier.ready(),
        ),
        downloaderRepositoryProvider.overrideWith(
          (ref) => FakeDownloaderRepository(data),
        ),
        persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
        downloadListProvider.overrideWith(
          (ref) => PinnedDownloadList(
            ref.read(downloaderRepositoryProvider),
            ref,
            data,
          ),
        ),
        downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
        showcaseModeProvider.overrideWithValue(true),
        tikTokArchiveRepositoryProvider.overrideWith(
          (ref) => FakeArchiveRepository(),
        ),
        tikTokArchiveProvider.overrideWith(
          (ref) => DemoArchiveNotifier(FakeArchiveRepository(), ref),
        ),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr'),
            theme: AppTheme.fromPalette(
              preset,
              DesignSpec.forId(preset.id).brightness ?? Brightness.light,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await settle(tester);
    router.go(route);
    await settle(tester);
    return (key, container);
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    final path = await capture(tester, key, 'studio_$name');
    // ignore: avoid_print
    print('[studio] $name -> $path');
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('studio surface grid', (tester) async {
    final (key, _) = await pump(
      tester,
      '/',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.detailed,
        ),
        selectedDownloadIdProvider.overrideWith((ref) => failedItemId),
      ],
    );
    await shot(tester, key, 'grid_failed');
  });

  testWidgets('studio surface done inspector', (tester) async {
    final (key, _) = await pump(
      tester,
      '/',
      extra: [selectedDownloadIdProvider.overrideWith((ref) => 'dl-done-1')],
    );
    await shot(tester, key, 'inspector_done');
  });

  testWidgets('studio surface folders', (tester) async {
    final (key, container) = await pump(
      tester,
      '/',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.folders,
        ),
      ],
    );
    await capture(tester, key, 'studio_folders');
    final folder = container.read(creatorFoldersProvider).folders.first.key;
    container.read(openedCreatorFolderKeyProvider.notifier).state = folder;
    container.read(folderContentsViewModeProvider.notifier).state =
        DownloadViewMode.list;
    container.read(selectedDownloadIdProvider.notifier).state = 'dl-done-2';
    await settle(tester);
    await shot(tester, key, 'folder_opened');
  });

  testWidgets('studio surface inspector with a file', (tester) async {
    final dir = Directory.systemTemp.createTempSync('studio_inspector');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}concert.mp3')
      ..writeAsBytesSync(List.filled(64, 0));
    final items = [
      for (final i in sampleDownloads())
        i.id == 'dl-done-1' ? i.copyWith(filePath: file.path) : i,
    ];
    final (key, _) = await pump(
      tester,
      '/',
      items: items,
      extra: [selectedDownloadIdProvider.overrideWith((ref) => 'dl-done-1')],
    );
    await shot(tester, key, 'inspector_file');
  });

  testWidgets('studio surface narrow window', (tester) async {
    const size = Size(820, 900);
    final (key, container) = await pump(
      tester,
      '/settings/performance',
      size: size,
    );
    await capture(tester, key, 'studio_narrow_settings');
    final notifier = container.read(tikTokArchiveProvider.notifier);
    container.read(routerProvider).go('/archive');
    await settle(tester);
    await capture(tester, key, 'studio_narrow_archive');
    notifier.setViewMode(TikTokViewMode.collections);
    await settle(tester);
    await capture(tester, key, 'studio_narrow_collections');
    notifier.selectCollection('cuisine');
    await settle(tester);
    await shot(tester, key, 'narrow_opened');
  });

  testWidgets('studio surface archive views', (tester) async {
    final (key, container) = await pump(tester, '/archive');
    final notifier = container.read(tikTokArchiveProvider.notifier);
    notifier.setViewMode(TikTokViewMode.collections);
    await settle(tester);
    await capture(tester, key, 'studio_archive_collections');
    notifier.selectCollection('cuisine');
    await settle(tester);
    await capture(tester, key, 'studio_archive_opened');
    notifier.selectCollection(null);
    notifier.setViewMode(TikTokViewMode.list);
    notifier.setSearchQuery('zzz');
    await settle(tester);
    await capture(tester, key, 'studio_archive_noresult');
    notifier.setSearchQuery('');
    notifier.setViewMode(TikTokViewMode.hub);
    await settle(tester);
    await shot(tester, key, 'archive_hub');
  });
}
