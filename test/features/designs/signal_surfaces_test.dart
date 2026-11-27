// Renders the pieces Signal now draws itself (library rows in list, folders
// and cards; the inspector for a finished and a failed item; an opened
// TikTok collection and the import hub; the settings sub-pages in full) to
// build/visual/signal_surface_*.png, and checks they no longer use today's
// shared widgets.
//
//   flutter test test/features/designs/signal_surfaces_test.dart --no-pub
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/router/app_router.dart';
import 'package:tapload/core/services/binary/binary_verifier.dart';
import 'package:tapload/core/ui/settings/widgets/settings_tiles.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/widgets/tiktok_filter_pane.dart';
import 'package:tapload/features/archive/presentation/views/widgets/tiktok_video_card.dart';
import 'package:tapload/features/designs/signal/signal_archive_parts.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/designs/signal/signal_inspector.dart';
import 'package:tapload/features/designs/signal/signal_library_row.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/download_inspector.dart';
import 'package:tapload/features/downloader/presentation/widgets/download_item_card.dart';
import 'package:tapload/features/onboarding/data/onboarding_store.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/showcase/showcase_mode.dart';

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
    String path, {
    Size size = const Size(1280, 800),
    List<Override> extra = const [],
    bool showcase = true,
  }) async {
    tester.view.physicalSize = size * 2;
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
        designFreeSpaceProvider.overrideWith(
          (ref) async => 412 * 1024 * 1024 * 1024,
        ),
        showcaseModeProvider.overrideWithValue(showcase),
        tikTokArchiveRepositoryProvider.overrideWith(
          (ref) => FakeArchiveRepository(),
        ),
        tikTokArchiveProvider.overrideWith(
          (ref) => DemoArchiveNotifier(FakeArchiveRepository(), ref),
        ),
        transferControllerProvider.overrideWith(
          (ref) => FakeTransferController(ref),
        ),
        ...extra,
      ],
    );
    final router = container.read(routerProvider);
    final key = GlobalKey();
    const preset = ThemePresets.signal;
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
            routerConfig: router,
          ),
        ),
      ),
    );
    router.go(path);
    await settle(tester);
    return (key, container);
  }

  Future<void> shot(
    WidgetTester tester,
    GlobalKey key,
    ProviderContainer container,
    String name,
  ) async {
    await capture(tester, key, 'signal_surface_$name');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('library rows and a finished item in the inspector', (
    tester,
  ) async {
    final (key, c) = await pump(
      tester,
      '/',
      size: const Size(1280, 1500),
      extra: [selectedDownloadIdProvider.overrideWith((ref) => 'dl-done-1')],
    );
    expect(find.byType(SignalLibraryRow), findsWidgets);
    expect(find.byType(DownloadItemCard), findsNothing);
    expect(find.byType(SignalInspector), findsOneWidget);
    expect(find.byType(DownloadInspector), findsNothing);
    await shot(tester, key, c, 'library_list');
  });

  testWidgets('a failed item in the inspector', (tester) async {
    final (key, c) = await pump(
      tester,
      '/',
      extra: [selectedDownloadIdProvider.overrideWith((ref) => failedItemId)],
    );
    expect(find.byType(SignalInspector), findsOneWidget);
    await shot(tester, key, c, 'inspector_failed');
  });

  testWidgets('library by creator: folders, then one as rows and cards', (
    tester,
  ) async {
    final (key, c) = await pump(
      tester,
      '/',
      size: const Size(1280, 1500),
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.folders,
        ),
      ],
    );
    await capture(tester, key, 'signal_surface_folders');
    c.read(openedCreatorFolderKeyProvider.notifier).state = c
        .read(creatorFoldersProvider)
        .folders
        .first
        .key;
    await settle(tester);
    expect(find.byType(SignalLibraryRow), findsWidgets);
    expect(find.byType(DownloadItemCard), findsNothing);
    await capture(tester, key, 'signal_surface_folder_rows');
    c.read(folderContentsViewModeProvider.notifier).state =
        DownloadViewMode.detailed;
    await settle(tester);
    expect(find.byType(SignalLibraryRow), findsWidgets);
    await shot(tester, key, c, 'folder_cards');
  });

  testWidgets('archive: videos, an opened collection and the hub', (
    tester,
  ) async {
    final (key, c) = await pump(tester, '/archive');
    expect(find.byType(SignalVideoRow), findsWidgets);
    expect(find.byType(SignalFilterPane), findsOneWidget);
    expect(find.byType(TikTokVideoCard), findsNothing);
    expect(find.byType(TikTokFilterPane), findsNothing);
    final n = c.read(tikTokArchiveProvider.notifier);
    n.setViewMode(TikTokViewMode.collections);
    final first = c.read(tikTokArchiveProvider).catalog!.collections.first;
    n.selectCollection(first.id ?? first.name);
    await settle(tester);
    expect(find.byType(SignalVideoRow), findsWidgets);
    expect(find.byType(TikTokVideoCard), findsNothing);
    await capture(tester, key, 'signal_surface_archive_collection');
    n.setViewMode(TikTokViewMode.hub);
    await settle(tester);
    expect(find.byType(SignalArchiveHub), findsOneWidget);
    await shot(tester, key, c, 'archive_hub');
  });

  for (final page in [
    // Output's storage chart scans the disk in a process a widget test
    // cannot finish; the shared surface test renders that page.
    'advanced',
    'system',
    'plugins',
    'smart_organizer',
  ]) {
    testWidgets('settings $page in full', (tester) async {
      final (key, c) = await pump(
        tester,
        '/settings/$page',
        size: const Size(1280, 2200),
      );
      // Smart organisation keeps Material switches, in Signal's theme.
      if (page != 'smart_organizer') {
        expect(find.byType(Switch), findsNothing);
      }
      await shot(tester, key, c, 'settings_$page');
    });
  }

  testWidgets('plugins with the browser extensions (not the demo)', (
    tester,
  ) async {
    final (key, c) = await pump(
      tester,
      '/settings/plugins',
      size: const Size(1280, 2600),
      showcase: false,
    );
    await shot(tester, key, c, 'settings_plugins_extensions');
  });

  testWidgets('dependency status and a busy action', (tester) async {
    tester.view.physicalSize = const Size(1280, 500) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    const preset = ThemePresets.signal;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
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
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  StatusTile(
                    'yt-dlp',
                    BinaryStatus(isInstalled: true, version: '2026.09.20'),
                  ),
                  StatusTile(
                    'aria2c',
                    BinaryStatus(isInstalled: false, version: null),
                  ),
                  const ActionTile(
                    title: 'Vérification…',
                    subtitle: 'busy',
                    icon: Icons.build_circle_outlined,
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final busy = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Vérification…'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(busy.opacity, lessThan(1));
    await capture(tester, key, 'signal_surface_status_tiles');
  });
}
