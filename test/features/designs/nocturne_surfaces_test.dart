// Nocturne draws the library rows, toolbar, inspector, creator folders and
// the archive's collections itself: renders build/visual/nocturne_*.png to
// look at, and checks no shared old-look widget is left on those pages.
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
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/widgets/tiktok_video_card.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_archive_parts.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_inspector.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_library.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/toolbar/download_top_bar.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_card.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_grid_card.dart';
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

  Future<(ProviderContainer, GlobalKey)> pump(
    WidgetTester tester,
    List<Override> extra,
  ) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final items = sampleDownloads();
    final container = ProviderContainer(
      overrides: [
        ...baseOverrides(),
        dependencyBootstrapProvider.overrideWith(
          (ref) => DependencyBootstrapNotifier.ready(),
        ),
        downloaderRepositoryProvider.overrideWith(
          (ref) => FakeDownloaderRepository(items),
        ),
        persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
        downloadListProvider.overrideWith(
          (ref) => PinnedDownloadList(
            ref.read(downloaderRepositoryProvider),
            ref,
            items,
          ),
        ),
        downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
        designFreeSpaceProvider.overrideWith((ref) async => 1 << 40),
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
    final preset = ThemePresets.getById('nocturne');
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
              DesignSpec.forId(preset.id).brightness ?? Brightness.dark,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(routerProvider),
          ),
        ),
      ),
    );
    await settle(tester);
    return (container, key);
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    final path = await capture(tester, key, name);
    // ignore: avoid_print
    print('[nocturne] $name -> $path');
  }

  void noOldLibrary() {
    expect(find.byType(DownloadTopBar), findsNothing);
    expect(find.byType(DownloadInspector), findsNothing);
    expect(find.byType(DownloadItemCard), findsNothing);
    expect(find.byType(DownloadItemGridCard), findsNothing);
  }

  testWidgets('detailed cards, toolbar and a failed item inspected', (
    tester,
  ) async {
    final (container, key) = await pump(tester, [
      downloadViewModeProvider.overrideWith((ref) => DownloadViewMode.detailed),
      selectedDownloadIdProvider.overrideWith((ref) => failedItemId),
    ]);
    await tester.ensureVisible(find.byType(NocturneLibraryToolbar));
    await settle(tester);
    expect(find.byType(NocturneDownloadCard), findsWidgets);
    expect(find.byType(NocturneInspector), findsOneWidget);
    noOldLibrary();
    await shot(tester, key, 'nocturne_detailed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('creator folders, then one opened with a done item', (
    tester,
  ) async {
    final (container, key) = await pump(tester, [
      downloadViewModeProvider.overrideWith((ref) => DownloadViewMode.folders),
      selectedDownloadIdProvider.overrideWith((ref) => 'dl-done-1'),
    ]);
    await tester.ensureVisible(find.byType(NocturneLibraryToolbar));
    await settle(tester);
    expect(find.byType(NocturneFolderTile), findsWidgets);
    noOldLibrary();
    await shot(tester, key, 'nocturne_folders');

    final folder = container.read(creatorFoldersProvider).folders.first;
    container.read(openedCreatorFolderKeyProvider.notifier).state = folder.key;
    container.read(selectedDownloadIdProvider.notifier).state =
        folder.itemIds.first;
    await settle(tester);
    expect(find.byType(NocturneFolderHeader), findsOneWidget);
    expect(find.byType(NocturneDownloadRow), findsWidgets);
    noOldLibrary();
    await shot(tester, key, 'nocturne_folder_open');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('archive collections, one opened, and the hub', (tester) async {
    final (container, key) = await pump(tester, []);
    container.read(routerProvider).go('/archive');
    await settle(tester);
    final archive = container.read(tikTokArchiveProvider.notifier);
    archive.setViewMode(TikTokViewMode.collections);
    await settle(tester);
    expect(find.byType(TikTokCollectionsView), findsNothing);
    await shot(tester, key, 'nocturne_collections');

    final first = container
        .read(tikTokArchiveProvider)
        .catalog!
        .collections
        .first;
    archive.selectCollection(first.id ?? first.name);
    await settle(tester);
    expect(find.byType(NocturneCollectionDetail), findsOneWidget);
    expect(find.byType(NocturneVideoCard), findsWidgets);
    expect(find.byType(TikTokVideoCard), findsNothing);
    await shot(tester, key, 'nocturne_collection_open');

    archive.selectCollection(null);
    archive.setViewMode(TikTokViewMode.hub);
    await settle(tester);
    await shot(tester, key, 'nocturne_archive_hub');
    await tester.pumpWidget(const SizedBox());
  });
}
