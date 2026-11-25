// Renders the Windows desktop screens to build/visual/desktop_*.png so layout
// changes can be checked by eye. Like oled_screens_test, it never compares
// pixels: it writes images and fails only on a crash.
//
//   flutter test test/visual/desktop_screens_test.dart --no-pub
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/router/app_router.dart';
import 'package:modern_downloader/core/ui/app_shell.dart';
import 'package:modern_downloader/core/ui/settings/general_settings_view.dart';
import 'package:modern_downloader/core/ui/settings/plugins_settings_view.dart';
import 'package:modern_downloader/core/ui/sidebar/sidebar.dart';
import 'package:modern_downloader/core/ui/settings/settings_hub_view.dart';
import 'package:modern_downloader/core/ui/shell/shell_strips.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/tiktok_archive_view.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/download_view.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_view.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

import 'visual_fakes.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    await prefs.setBool(OnboardingStore.prefsKey, true);
  });

  tearDown(() => PlatformInfo.debugForceMobile = null);

  Future<GlobalKey> pump(
    WidgetTester tester,
    Widget Function() page, {
    List<Override> extra = const [],
    String locale = 'fr',
    GoRouter? router,
    ThemePreset preset = ThemePresets.signal,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final data = sampleDownloads();
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
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
          // A disk probe spawns a process, which a widget test cannot finish.
          designFreeSpaceProvider.overrideWith(
            (ref) async => 412 * 1024 * 1024 * 1024,
          ),
          ...extra,
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: Locale(locale),
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
            routerConfig:
                router ??
                GoRouter(
                  initialLocation: '/',
                  routes: [
                    ShellRoute(
                      builder: (context, state, child) =>
                          AppShell(child: child),
                      routes: [
                        GoRoute(
                          path: '/',
                          pageBuilder: (context, state) =>
                              NoTransitionPage(child: page()),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
    await settle(tester);
    return key;
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    final path = await capture(tester, key, name);
    // ignore: avoid_print
    print('[desktop] $name -> $path');
    await tester.pumpWidget(const SizedBox());
  }

  List<Override> archive() => [
    showcaseModeProvider.overrideWithValue(true),
    tikTokArchiveRepositoryProvider.overrideWith(
      (ref) => FakeArchiveRepository(),
    ),
    tikTokArchiveProvider.overrideWith(
      (ref) => DemoArchiveNotifier(FakeArchiveRepository(), ref),
    ),
  ];

  testWidgets('desktop library', (tester) async {
    final key = await pump(tester, () => const DownloadView());
    await shot(tester, key, 'desktop_library');
  });

  testWidgets('desktop tiktok archive', (tester) async {
    final key = await pump(
      tester,
      () => const TikTokArchiveView(),
      extra: archive(),
    );
    await shot(tester, key, 'desktop_tiktok');
  });

  testWidgets('desktop tiktok collections purge', (tester) async {
    final key = await pump(
      tester,
      () => const TikTokArchiveView(),
      extra: archive(),
    );
    await tester.tap(find.text('Collections').first);
    await settle(tester);
    await tester.tap(find.text('Sélectionner'));
    await settle(tester);
    await tester.tap(find.text('Cuisine').last);
    await settle(tester);
    final capturePath = await capture(tester, key, 'desktop_tiktok_select');
    // ignore: avoid_print
    print('[desktop] desktop_tiktok_select -> $capturePath');
    await tester.tap(find.text('Supprimer leurs vidéos'));
    await settle(tester);
    await shot(tester, key, 'desktop_tiktok_purge_confirm');
  });

  testWidgets('desktop settings', (tester) async {
    final key = await pump(tester, () => const AdaptiveSettingsHome());
    await shot(tester, key, 'desktop_settings');
  });

  testWidgets('desktop transfer', (tester) async {
    final key = await pump(
      tester,
      () => const TransferView(),
      extra: [
        transferControllerProvider.overrideWith(
          (ref) => FakeTransferController(ref),
        ),
      ],
    );
    await shot(tester, key, 'desktop_transfer');
  });

  testWidgets('desktop sidebar switches between settings pages', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final key = await pump(
      tester,
      () => const SizedBox(),
      router: router,
      preset: ThemePresets.ios,
    );
    Finder inSidebar(IconData icon) => find.descendant(
      of: find.byType(AppSidebar),
      matching: find.byIcon(icon),
    );
    Future<void> open(IconData icon) async {
      await tester.tap(inSidebar(icon));
      await settle(tester);
      expect(tester.takeException(), isNull);
    }

    await open(Icons.settings_outlined); // expand the group
    // Plugins twice: a stacked page would hold its onboarding GlobalKey twice.
    for (final icon in [
      Icons.extension_outlined,
      Icons.tune,
      Icons.extension_outlined,
      Icons.tune,
    ]) {
      await open(icon);
      final shown = icon == Icons.tune
          ? GeneralSettingsView
          : PluginsSettingsView;
      expect(find.byType(shown).hitTestable(), findsOneWidget);
    }
    await shot(tester, key, 'desktop_sidebar_settings');
  });

  testWidgets('designed chromes switch between settings pages', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await pump(tester, () => const SizedBox(), router: router);
    await tester.tap(find.byTooltip('Paramètres'));
    await settle(tester);
    Future<void> open(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsSectionStrip),
          matching: find.text(label),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    }

    // Plugins twice: a stacked page would hold its onboarding GlobalKey twice.
    for (final label in ['Plugins', 'Général', 'Plugins', 'Général']) {
      await open(label);
      final shown = label == 'Général'
          ? GeneralSettingsView
          : PluginsSettingsView;
      expect(find.byType(shown).hitTestable(), findsOneWidget);
    }
  });

  // Every design on every page, on the real routes: writes
  // build/visual/design_<id>_<page>.png to look at, fails only on a crash.
  const designs = [
    'signal',
    'porcelaine',
    'pastille',
    'studio',
    'terminal',
    'nocturne',
  ];
  const pages = {
    'library': '/',
    'archive': '/archive',
    'stats': '/stats',
    'transfer': '/transfer',
    'settings': '/settings/general',
  };
  for (final id in designs) {
    for (final page in pages.entries) {
      testWidgets('design $id ${page.key}', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(routerProvider);
        final key = await pump(
          tester,
          () => const SizedBox(),
          router: router,
          preset: ThemePresets.getById(id),
          extra: [
            ...archive(),
            transferControllerProvider.overrideWith(
              (ref) => FakeTransferController(ref),
            ),
          ],
        );
        router.go(page.value);
        await settle(tester);
        await shot(tester, key, 'design_${id}_${page.key}');
      });
    }
  }

  // The designs' own pages at their mockup's size, for side-by-sides with
  // build/visual/ref/<mockup>.png.
  const mockups = {
    'Main': ('signal', '/', Size(1280, 1180)),
  };
  for (final entry in mockups.entries) {
    testWidgets('mockup ${entry.key}', (tester) async {
      final (id, route, size) = entry.value;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final key = await pump(
        tester,
        () => const SizedBox(),
        router: router,
        preset: ThemePresets.getById(id),
        size: size,
        extra: [
          ...archive(),
          transferControllerProvider.overrideWith(
            (ref) => FakeTransferController(ref),
          ),
        ],
      );
      router.go(route);
      await settle(tester);
      await shot(tester, key, 'app_${entry.key}');
    });
  }
}
