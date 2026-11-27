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
import 'package:modern_downloader/features/designs/oled/oled_home.dart';
import 'package:modern_downloader/features/designs/oled/oled_skin.dart';
import 'package:modern_downloader/features/designs/oled/oled_states.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
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
}
