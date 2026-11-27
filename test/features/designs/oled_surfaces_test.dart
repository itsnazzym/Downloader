// OLED draws its own chrome, home, archive, stats, transfer and settings on
// desktop: renders build/visual/oled_*.png to look at, and checks each route
// shows OLED's page (not today's view) and that phones keep the mobile UI.
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
import 'package:modern_downloader/core/ui/shell/chromes/oled_chrome.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/modes/tiktok_collections_view.dart';
import 'package:modern_downloader/features/archive/presentation/views/tiktok_archive_view.dart';
import 'package:modern_downloader/features/designs/oled/oled_archive.dart';
import 'package:modern_downloader/features/designs/oled/oled_home.dart';
import 'package:modern_downloader/features/designs/oled/oled_settings.dart';
import 'package:modern_downloader/features/designs/oled/oled_skin.dart';
import 'package:modern_downloader/features/designs/oled/oled_states.dart';
import 'package:modern_downloader/features/designs/oled/oled_stats.dart';
import 'package:modern_downloader/features/designs/oled/oled_transfer.dart';
import 'package:modern_downloader/features/designs/oled/oled_widgets.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/download_view.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/download_item_card.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
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
    List<Override> extra, {
    Size size = const Size(1280, 800),
    bool mobile = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = mobile;
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
        // A disk probe spawns a process, which a widget test cannot finish.
        designFreeSpaceProvider.overrideWith((ref) async => 412 << 30),
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
    );
    addTearDown(container.dispose);
    final preset = ThemePresets.getById('oled');
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
    print('[oled] $name -> $path');
  }

  testWidgets('home: OLED chrome, hero and rows, no shared list cards', (
    tester,
  ) async {
    final (_, key) = await pump(tester, []);
    expect(find.byType(OledChrome), findsOneWidget);
    expect(find.byType(OledHome), findsOneWidget);
    expect(find.byType(DownloadView), findsNothing);
    expect(find.byType(OledDownloadRow), findsWidgets);
    expect(find.byType(DownloadItemCard), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, key, 'oled_home');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home: the kind and failed tabs filter the rows', (tester) async {
    final (container, key) = await pump(tester, []);
    final all = find.byType(OledDownloadRow).evaluate().length;
    await tester.tap(find.text('Audio').first);
    await settle(tester);
    expect(container.read(oledKindFilterProvider), isNotNull);
    expect(find.byType(OledDownloadRow).evaluate().length, lessThan(all));

    await tester.tap(find.textContaining('Échoués').first);
    await settle(tester);
    expect(
      container.read(downloadStatusFilterProvider),
      DownloadStatusFilter.failed,
    );
    expect(container.read(oledKindFilterProvider), isNull);
    await shot(tester, key, 'oled_home_failed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home: a search with no match offers to clear it', (
    tester,
  ) async {
    final (container, key) = await pump(tester, [
      downloadSearchQueryProvider.overrideWith((ref) => 'zzzz introuvable'),
    ]);
    expect(find.byType(OledNoResults), findsOneWidget);
    await tester.tap(find.text('Effacer la recherche et les filtres'));
    await settle(tester);
    expect(container.read(downloadSearchQueryProvider), isEmpty);
    expect(find.byType(OledDownloadRow), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in const [1280.0, 1000.0, 820.0]) {
    testWidgets('home: detailed cards and an opened folder at $width px', (
      tester,
    ) async {
      final (container, key) = await pump(tester, [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.detailed,
        ),
        selectedDownloadIdProvider.overrideWith((ref) => failedItemId),
      ], size: Size(width, 900));
      expect(find.byType(OledDownloadRow), findsWidgets);
      expect(tester.takeException(), isNull);
      await shot(tester, key, 'oled_detailed_${width.round()}');

      container.read(downloadViewModeProvider.notifier).state =
          DownloadViewMode.folders;
      await settle(tester);
      expect(tester.takeException(), isNull);
      final folder = container.read(creatorFoldersProvider).folders.first;
      container.read(openedCreatorFolderKeyProvider.notifier).state =
          folder.key;
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(OledDownloadRow), findsWidgets);
      await shot(tester, key, 'oled_folder_${width.round()}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('phones keep the mobile shell, rows and theme with OLED', (
    tester,
  ) async {
    // (DesignedPage reads the host OS, so only the shell, the skin and the
    // theme can be checked with a forced phone.)
    await pump(tester, [], size: const Size(400, 860), mobile: true);
    expect(find.byType(OledChrome), findsNothing);
    expect(find.byType(OledDownloadRow), findsNothing);
    final phone = AppTheme.fromPalette(ThemePresets.oled, Brightness.dark);
    expect(phone.snackBarTheme.behavior, isNull);
    PlatformInfo.debugForceMobile = false;
    final desk = AppTheme.fromPalette(ThemePresets.oled, Brightness.dark);
    expect(desk.snackBarTheme.behavior, SnackBarBehavior.floating);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('archive: the running batch can be stopped', (tester) async {
    final (container, key) = await pump(tester, []);
    final archive = container.read(tikTokArchiveProvider.notifier);
    archive.setViewMode(TikTokViewMode.list);
    container.read(routerProvider).go('/archive');
    await settle(tester);
    expect(find.byType(OledArchive), findsOneWidget);
    expect(find.byType(TikTokArchiveView), findsNothing);
    // The demo archive is mid-batch with two videos picked.
    expect(find.text('Arrêter'), findsOneWidget);
    await shot(tester, key, 'oled_archive_batch');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('archive: selection, then collections', (tester) async {
    final (container, key) = await pump(tester, [
      tikTokArchiveProvider.overrideWith(
        (ref) => _IdleArchive(FakeArchiveRepository(), ref),
      ),
    ]);
    container.read(routerProvider).go('/archive');
    await settle(tester);
    expect(find.text('2 sélectionnées'), findsOneWidget);
    expect(find.text('Télécharger la sélection'), findsOneWidget);
    await shot(tester, key, 'oled_archive');
    await tester.tap(find.text('2 sélectionnées'));
    await settle(tester);
    await tester.tap(find.text('Tout sélectionner'));
    await settle(tester);
    expect(container.read(tikTokArchiveProvider).selectedIds, hasLength(12));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Collections').first);
    await settle(tester);
    expect(
      container.read(tikTokArchiveProvider).viewMode,
      TikTokViewMode.collections,
    );
    expect(find.byType(TikTokCollectionsView), findsOneWidget);
    await shot(tester, key, 'oled_archive_collections');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stats: the period switches the figures', (tester) async {
    final (container, key) = await pump(tester, []);
    container.read(routerProvider).go('/stats');
    await settle(tester);
    expect(find.byType(OledStats), findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, key, 'oled_stats');
    await tester.tap(find.text('7 j'));
    await settle(tester);
    expect(find.text('7 derniers jours'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('transfer: radar and send, all options keep today\'s view', (
    tester,
  ) async {
    final (container, key) = await pump(tester, []);
    container.read(routerProvider).go('/transfer');
    await settle(tester);
    expect(find.byType(OledTransfer), findsOneWidget);
    expect(find.text('ce PC'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, key, 'oled_transfer');
    await tester.tap(find.text('Toutes les options'));
    await settle(tester);
    expect(find.text('Vue simple'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: sections as links, tiles drawn by the skin', (
    tester,
  ) async {
    final (container, key) = await pump(tester, []);
    final router = container.read(routerProvider);
    router.go('/settings/general');
    await settle(tester);
    expect(find.byType(OledSettings), findsOneWidget);
    expect(find.byType(OledSettingRow), findsWidgets);
    expect(tester.takeException(), isNull);
    await shot(tester, key, 'oled_settings');
    await tester.tap(find.text('Apparence').first);
    await settle(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/settings/appearance',
    );
    await shot(tester, key, 'oled_settings_appearance');
    await tester.pumpWidget(const SizedBox());
  });

  for (final (name, size) in const [
    ('narrow', Size(820, 900)),
    ('compact', Size(640, 800)),
  ]) {
    testWidgets('every page fits a $name window', (tester) async {
      final (container, key) = await pump(tester, [], size: size);
      final router = container.read(routerProvider);
      for (final route in const [
        '/',
        '/archive',
        '/stats',
        '/transfer',
        '/settings/general',
      ]) {
        router.go(route);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: route);
        await shot(tester, key, 'oled_${name}_${route.replaceAll('/', '_')}');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  double logoDotOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(OledLiveDot).first,
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('the logo dot breathes, and stays lit with reduced motion', (
    tester,
  ) async {
    await pump(tester, []);
    await tester.pump(const Duration(milliseconds: 500));
    expect(logoDotOpacity(tester), lessThan(1));
    await tester.pumpWidget(const SizedBox());

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, []);
    await tester.pump(const Duration(milliseconds: 500));
    expect(logoDotOpacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });
}

/// The demo archive with its batch finished: the selection actions show.
class _IdleArchive extends DemoArchiveNotifier {
  _IdleArchive(super.repo, super.ref) {
    state = state.copyWith(isBatchDownloading: false);
  }
}
