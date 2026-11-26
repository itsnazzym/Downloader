// Renders Pastille's library (with the inspector), its view modes and the
// archive's inner views to build/visual/surface_pastille_*.png, to check by
// eye that none of them still shows the shared look. Fails only on a crash.
//
//   flutter test --no-pub test/features/designs/pastille_surfaces_test.dart
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
import 'package:modern_downloader/features/designs/design_skins.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
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
    registerDesignSkins();
  });

  tearDown(() => PlatformInfo.debugForceMobile = null);

  Future<void> render(
    WidgetTester tester,
    String name,
    String location, {
    Size size = const Size(1280, 800),
    List<Override> extra = const [],
    Future<void> Function(ProviderContainer c)? then,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final routerContainer = ProviderContainer();
    addTearDown(routerContainer.dispose);
    final router = routerContainer.read(routerProvider);
    final items = sampleDownloads();
    final key = GlobalKey();
    const preset = ThemePresets.pastille;
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
          selectedDownloadIdProvider.overrideWith((ref) => items.first.id),
          ...extra,
        ],
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
    await settle(tester);
    router.go(location);
    await settle(tester);
    if (then != null) {
      final c = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await then(c);
      await settle(tester);
    }
    await capture(tester, key, 'surface_pastille_$name');
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('pastille library list', (tester) async {
    await render(tester, 'library', '/?view=library');
  });

  testWidgets('pastille library tall inspector', (tester) async {
    await render(
      tester,
      'library_tall',
      '/?view=library',
      size: const Size(1280, 1700),
    );
  });

  testWidgets('pastille library narrow', (tester) async {
    await render(
      tester,
      'library_1000',
      '/?view=library',
      size: const Size(1000, 760),
    );
  });

  testWidgets('pastille library grid', (tester) async {
    await render(
      tester,
      'library_grid',
      '/?view=library',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.detailed,
        ),
      ],
    );
  });

  testWidgets('pastille library folders', (tester) async {
    await render(
      tester,
      'library_folders',
      '/?view=library',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.folders,
        ),
      ],
    );
  });

  testWidgets('pastille archive videos', (tester) async {
    await render(
      tester,
      'archive_videos',
      '/archive',
      size: const Size(1280, 1500),
    );
  });

  testWidgets('pastille archive open collection', (tester) async {
    await render(
      tester,
      'archive_collection',
      '/archive',
      size: const Size(1280, 1500),
      then: (c) async {
        final n = c.read(tikTokArchiveProvider.notifier);
        n.setViewMode(TikTokViewMode.collections);
        final first = c.read(tikTokArchiveProvider).catalog!.collections.first;
        n.selectCollection(first.name);
      },
    );
  });

  testWidgets('pastille archive hub', (tester) async {
    await render(
      tester,
      'archive_hub',
      '/archive',
      then: (c) async => c
          .read(tikTokArchiveProvider.notifier)
          .setViewMode(TikTokViewMode.hub),
    );
  });
}
