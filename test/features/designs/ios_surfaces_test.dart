// iOS (Liquid Glass) draws its own chrome and pages on desktop, in dark and
// light: renders build/visual/ios_*.png to look at, and checks the classic
// sidebar, the floating dock and the shared library are gone from them.
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
import 'package:tapload/core/theme/theme_resolver.dart';
import 'package:tapload/core/ui/shell/chromes/ios_chrome.dart';
import 'package:tapload/core/ui/sidebar/sidebar.dart';
import 'package:tapload/core/ui/widgets/floating_nav_dock.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/ios/ios_ambient.dart';
import 'package:tapload/features/designs/ios/ios_archive.dart';
import 'package:tapload/features/designs/ios/ios_home.dart';
import 'package:tapload/features/designs/ios/ios_settings.dart';
import 'package:tapload/features/designs/ios/ios_stats.dart';
import 'package:tapload/features/designs/ios/ios_transfer.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/widgets/toolbar/download_top_bar.dart';
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

  Future<(ProviderContainer, GlobalKey)> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    bool mobile = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 860) * 2;
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
        designFreeSpaceProvider.overrideWith((ref) async => 1 << 40),
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
      ],
    );
    addTearDown(container.dispose);
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
              ThemeResolver.forBrightness(ThemePresets.ios, brightness),
              brightness,
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

  test('each page has its own ambient, paler in light mode', () {
    final hues = {
      for (final p in ['/', '/archive', '/stats', '/transfer', '/settings'])
        p: iosAmbientFor(p).first.color,
    };
    expect(hues.values.toSet(), hasLength(5));
    for (final c in hues.values) {
      final light = iosLightHue(c);
      expect(light.computeLuminance(), greaterThan(c.computeLuminance()));
    }
  });

  for (final mode in Brightness.values) {
    testWidgets('every route is drawn by iOS (${mode.name})', (tester) async {
      final (container, key) = await pump(tester, brightness: mode);
      final router = container.read(routerProvider);
      expect(find.byType(IosChrome), findsOneWidget);
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(FloatingNavDock), findsNothing);
      expect(find.byType(IosHome), findsOneWidget);
      expect(find.byType(IosPoster), findsWidgets);
      expect(find.byType(DownloadTopBar), findsNothing);
      expect(find.byType(DownloadItemCard), findsNothing);
      for (final (route, page) in [
        ('/archive', IosArchive),
        ('/stats', IosStats),
        ('/transfer', IosTransfer),
        ('/settings/general', IosSettings),
      ]) {
        router.go(route);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: route);
        expect(find.byType(page), findsOneWidget, reason: route);
      }
      await capture(tester, key, 'ios_settings_${mode.name}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final mode in Brightness.values) {
    testWidgets('archive and transfer options frame the shared views '
        '(${mode.name})', (tester) async {
      final (container, key) = await pump(tester, brightness: mode);
      final router = container.read(routerProvider);
      for (final route in ['/archive', '/transfer']) {
        router.go(route);
        await settle(tester);
        // A round button (archive) or a labelled capsule (transfer).
        final byTip = find.byTooltip('Toutes les options');
        await tester.tap(
          (byTip.evaluate().isNotEmpty
                  ? byTip
                  : find.text('Toutes les options'))
              .hitTestable()
              .first,
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: route);
        expect(find.text('Vue simple'), findsWidgets, reason: route);
        await capture(
          tester,
          key,
          'ios_options${route.replaceAll('/', '_')}_${mode.name}',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the sidebar filters the library and opens settings', (
    tester,
  ) async {
    final (container, _) = await pump(tester);
    await tester.tap(find.text('Échecs').first);
    await settle(tester);
    expect(find.text('Clip court'), findsWidgets);
    expect(find.text('Concert acoustique, session live'), findsNothing);

    await tester.tap(find.text('Paramètres').first);
    await settle(tester);
    expect(find.byType(IosSettings), findsOneWidget);
    // Réglages: the sidebar lists the sections and leads back.
    await tester.tap(find.text('Plugins').first);
    await settle(tester);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/settings/plugins',
    );
    await tester.tap(find.text('Bibliothèque').first);
    await settle(tester);
    expect(find.byType(IosHome), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // Pages are desktop-only by platform (DesignedPage); the phone shell is
  // what a forced-mobile test can check.
  testWidgets('the phone shell keeps today\'s iOS chrome', (tester) async {
    await pump(tester, mobile: true);
    expect(find.byType(IosChrome), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
