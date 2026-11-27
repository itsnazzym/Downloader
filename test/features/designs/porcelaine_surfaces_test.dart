// Renders Porcelaine's own library (toolbar, rows, folders, inspector) and
// archive states to build/visual/surface_porcelaine_*.png, to check by eye
// that none of today's look is left. Fails only on a crash.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/router/app_router.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/porcelaine/porcelaine_workspace_model.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
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

  /// Pumps the app on [path] in Porcelaine; [setUp] runs on the live
  /// container before the shot.
  Future<void> render(
    WidgetTester tester,
    String name,
    String path, {
    List<Override> extra = const [],
    Size size = const Size(1280, 800),
    void Function(ProviderContainer c)? setUp,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final items = sampleDownloads();
    final routerHost = ProviderContainer();
    addTearDown(routerHost.dispose);
    final router = routerHost.read(routerProvider);
    final key = GlobalKey();
    const preset = ThemePresets.porcelaine;
    await tester.pumpWidget(
      ProviderScope(
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
          showcaseModeProvider.overrideWithValue(true),
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
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr'),
            theme: AppTheme.fromPalette(preset, Brightness.light),
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
    router.go(path);
    await settle(tester);
    if (setUp != null) {
      setUp(ProviderScope.containerOf(tester.element(find.byKey(key))));
      await settle(tester);
    }
    final out = await capture(tester, key, 'surface_porcelaine_$name');
    // ignore: avoid_print
    print('[porcelaine] $name -> $out');
    await tester.pumpWidget(const SizedBox());
  }

  final library = [porcelaineLibraryOpenProvider.overrideWith((ref) => true)];
  Override selectFirst() => selectedDownloadIdProvider.overrideWith(
    (ref) => sampleDownloads().first.id,
  );

  testWidgets('porcelaine library list', (tester) async {
    await render(tester, 'library', '/', extra: [...library, selectFirst()]);
  });

  testWidgets('porcelaine library failed selected', (tester) async {
    final failed = sampleDownloads().lastWhere((i) => i.error != null);
    await render(
      tester,
      'library_failed',
      '/',
      extra: [
        ...library,
        selectedDownloadIdProvider.overrideWith((ref) => failed.id),
      ],
    );
  });

  testWidgets('porcelaine library detailed', (tester) async {
    await render(
      tester,
      'library_detailed',
      '/',
      extra: [
        ...library,
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.detailed,
        ),
      ],
    );
  });

  testWidgets('porcelaine library folders', (tester) async {
    await render(
      tester,
      'library_folders',
      '/',
      extra: [
        ...library,
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.folders,
        ),
      ],
    );
  });

  testWidgets('porcelaine library reorder', (tester) async {
    // Desktop drag handles only show on a desktop platform.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await render(
        tester,
        'library_reorder',
        '/',
        extra: [
          ...library,
          downloadSortProvider.overrideWith((ref) => DownloadSort.dateAsc),
        ],
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('porcelaine library narrow', (tester) async {
    await render(
      tester,
      'library_narrow',
      '/',
      size: const Size(820, 640),
      extra: [...library, selectFirst()],
    );
  });

  // Whole settings pages, below the fold too.
  for (final page in ['plugins', 'advanced', 'smart_organizer']) {
    testWidgets('porcelaine settings $page tall', (tester) async {
      await prefs.setStringList('smart_organizer_rules', [
        jsonEncode({
          'id': 'rule-1',
          'name': 'Musique',
          'pattern': 'mp3',
          'isRegex': false,
          'targetFolder': 'Musique',
          'active': true,
        }),
      ]);
      addTearDown(() => prefs.remove('smart_organizer_rules'));
      await render(
        tester,
        'settings_${page}_tall',
        '/settings/$page',
        size: const Size(1280, 2400),
      );
    });
  }

  testWidgets('porcelaine archive hub', (tester) async {
    await render(
      tester,
      'archive_hub',
      '/archive',
      setUp: (c) => c
          .read(tikTokArchiveProvider.notifier)
          .setViewMode(TikTokViewMode.hub),
    );
  });

  testWidgets('porcelaine archive collections', (tester) async {
    await render(
      tester,
      'archive_collections',
      '/archive',
      setUp: (c) => c
          .read(tikTokArchiveProvider.notifier)
          .setViewMode(TikTokViewMode.collections),
    );
  });

  testWidgets('porcelaine archive collection opened', (tester) async {
    await render(
      tester,
      'archive_collection',
      '/archive',
      setUp: (c) {
        final n = c.read(tikTokArchiveProvider.notifier);
        n.setViewMode(TikTokViewMode.collections);
        n.selectCollection(
          c.read(tikTokArchiveProvider).catalog!.collections.first.name,
        );
      },
    );
  });

  testWidgets('porcelaine archive narrow', (tester) async {
    await render(
      tester,
      'archive_narrow',
      '/archive',
      size: const Size(820, 640),
    );
  });
}
