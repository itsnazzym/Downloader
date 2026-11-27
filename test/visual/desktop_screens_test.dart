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
import 'package:modern_downloader/core/ui/settings/widgets/design_miniature.dart';
import 'package:modern_downloader/core/ui/settings/widgets/design_vitrine.dart';
import 'package:modern_downloader/features/designs/pastille/pastille_kit.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/designs/terminal/terminal_library.dart';
import 'package:modern_downloader/features/designs/terminal/terminal_settings_pages.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/archive/presentation/views/tiktok_archive_view.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
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
    List<DownloadItem>? items,
    bool loading = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final data = items ?? sampleDownloads();
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
            (ref) => loading
                ? LoadingDownloadList(
                    ref.read(downloaderRepositoryProvider),
                    ref,
                  )
                : PinnedDownloadList(
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

  // Each design draws its own settings section navigation: going Plugins ->
  // Général twice must land on the right page every time (a stacked page
  // would hold the Plugins onboarding GlobalKey twice and jam the navigator).
  for (final id in const [
    'signal',
    'porcelaine',
    'pastille',
    'studio',
    'terminal',
    'nocturne',
  ]) {
    testWidgets('design $id switches between settings sections', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      await pump(
        tester,
        () => const SizedBox(),
        router: router,
        preset: ThemePresets.getById(id),
      );
      router.go('/settings/general');
      await settle(tester);
      Future<void> open(String label, String path) async {
        // Terminal writes its sections in lower case.
        final target = find.byWidgetPredicate(
          (w) => w is Text && w.data?.toLowerCase() == label.toLowerCase(),
        );
        await tester.tap(target.hitTestable().first);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(router.routerDelegate.currentConfiguration.uri.path, path);
      }

      for (var round = 0; round < 2; round++) {
        await open('Plugins', '/settings/plugins');
        // Today's view, or a design's own drawing of it (Terminal's page,
        // Nocturne's title): either way the plugins page is on screen.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PluginsSettingsView ||
                w is TerminalPluginsPage ||
                (w is Text &&
                    w.data?.toLowerCase() ==
                        'fonctionnalités de l’application'.toLowerCase()),
          ),
          findsWidgets,
        );
        await open('Général', '/settings/general');
      }
    });
  }

  // Seen in the real app in a 1000 px window: the title broke into "Appearanc / e".
  testWidgets('pastille settings title stays on one line beside its tabs', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await pump(
      tester,
      () => const SizedBox(),
      router: router,
      locale: 'en',
      preset: ThemePresets.pastille,
      // The client area of a 1000 x 720 window.
      size: const Size(984, 680),
    );
    router.go('/settings/appearance');
    await settle(tester);
    final title = find.descendant(
      of: find.byType(PastilleHeader),
      matching: find.text('Appearance'),
    ).first; // the title; the section tab comes after it
    expect(title, findsOneWidget);
    // One line of 44 px Sora at 0.9 line height, not two.
    expect(tester.getSize(title).height, lessThan(60));
  });

  // Seen in the real app: "Smart org / anization" in the narrow System tile.
  testWidgets('pastille system tile keeps its labels whole at 1000 px', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final key = await pump(
      tester,
      () => const SizedBox(),
      router: router,
      locale: 'en',
      preset: ThemePresets.pastille,
      size: const Size(984, 680),
    );
    router.go('/settings/general');
    await settle(tester);
    expect(tester.takeException(), isNull);
    final en = lookupAppLocalizations(const Locale('en'));
    // One line of 12.5 px text, not a word broken over two.
    expect(
      tester.getSize(find.text(en.smartOrganization).first).height,
      lessThan(20),
    );
    await shot(tester, key, 'pastille_settings_984');
  });

  // A design's settings page shows the section title once: the shared view
  // drops its own app bar inside the design's frame.
  for (final id in ['signal', 'porcelaine', 'nocturne']) {
    testWidgets('design $id settings show no second title bar', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      await pump(
        tester,
        () => const SizedBox(),
        router: router,
        preset: ThemePresets.getById(id),
      );
      router.go('/settings/appearance');
      await settle(tester);
      expect(find.byType(AppBar), findsNothing);
      // ...but the section is still named: in its navigation and as title.
      final name = lookupAppLocalizations(const Locale('fr')).settingsAppearance;
      expect(find.text(name), findsAtLeastNWidgets(2));
    });
  }

  // The Vitrine previewing another design than the current one: wide, and at
  // the client width of a 1000 px window.
  for (final (id, size) in const [
    ('signal', Size(1280, 900)),
    ('pastille', Size(984, 680)),
  ]) {
    testWidgets('design $id vitrine previews another design', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final key = await pump(
        tester,
        () => const SizedBox(),
        router: router,
        preset: ThemePresets.getById(id),
        size: size,
      );
      router.go('/settings/appearance');
      await settle(tester);
      final oled = find.descendant(
        of: find.byType(DesignVitrine),
        matching: find.text('OLED'),
      );
      // Mid-viewport: Pastille's floating dock covers the bottom edge.
      Future<void> reveal(Finder f) async {
        Scrollable.ensureVisible(tester.element(f), alignment: 0.3);
        await tester.pump();
      }

      await reveal(oled.first);
      await tester.tap(oled.first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await reveal(find.byType(DesignMiniature));
      await shot(tester, key, 'vitrine_${id}_${size.width.toInt()}');
    });
  }

  // Terminal sets the search field to 30 px: its text must stay inside.
  testWidgets('terminal search field keeps its text inside 30 px', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await pump(
      tester,
      () => const SizedBox(),
      router: router,
      preset: ThemePresets.terminal,
    );
    router.go('/');
    await settle(tester);
    final field = find.byType(TSearchField).first;
    final box = tester.getRect(field);
    final text = tester.getRect(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(box.height, 30);
    // A whole line (it was squeezed to 8 px by the 40 px field's padding).
    expect(text.height, greaterThanOrEqualTo(15));
    expect(text.top, greaterThanOrEqualTo(box.top));
    expect(text.bottom, lessThanOrEqualTo(box.bottom));
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

  // The pieces every design used to borrow from today's views (settings
  // sub-pages, the archive, the inspector): writes
  // build/visual/surface_<id>_<name>.png to check they are drawn in the design.
  const surfaces = {
    'output': '/settings/output',
    'appearance': '/settings/appearance',
    'performance': '/settings/performance',
    'advanced': '/settings/advanced',
    'system': '/settings/system',
    'plugins': '/settings/plugins',
    'smart_organizer': '/settings/smart_organizer',
    'archive': '/archive',
    'inspector': '/',
  };
  for (final id in designs) {
    for (final surface in surfaces.entries) {
      testWidgets('surface $id ${surface.key}', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(routerProvider);
        final items = sampleDownloads();
        final key = await pump(
          tester,
          () => const SizedBox(),
          router: router,
          preset: ThemePresets.getById(id),
          items: items,
          extra: [
            ...archive(),
            transferControllerProvider.overrideWith(
              (ref) => FakeTransferController(ref),
            ),
            // The inspector shows the first item.
            selectedDownloadIdProvider.overrideWith((ref) => items.first.id),
          ],
        );
        router.go(surface.value);
        await settle(tester);
        await shot(tester, key, 'surface_${id}_${surface.key}');
      });
    }
  }

  // The designs' own pages at their mockup's size, for side-by-sides with
  // build/visual/ref/<mockup>.png.
  const mockups = {
    'Main': ('signal', '/', Size(1280, 1180)),
    'Signal-Archives': ('signal', '/archive', Size(1280, 900)),
    'Signal-Stats': ('signal', '/stats', Size(1280, 900)),
    'Signal-Transfert': ('signal', '/transfer', Size(1280, 900)),
    'Signal-Reglages': ('signal', '/settings/general', Size(1280, 900)),
    'Espace': ('porcelaine', '/', Size(1280, 960)),
    'Porcelaine-Archives': ('porcelaine', '/archive', Size(1280, 900)),
    'Porcelaine-Stats': ('porcelaine', '/stats', Size(1280, 900)),
    'Porcelaine-Transfert': ('porcelaine', '/transfer', Size(1280, 900)),
    'Porcelaine-Reglages': ('porcelaine', '/settings/general', Size(1280, 900)),
    'Pastille': ('pastille', '/', Size(1280, 1080)),
    'Pastille-Archives': ('pastille', '/archive', Size(1280, 900)),
    'Pastille-Stats': ('pastille', '/stats', Size(1280, 900)),
    'Pastille-Transfert': ('pastille', '/transfer', Size(1280, 900)),
    'Pastille-Reglages': ('pastille', '/settings/general', Size(1280, 900)),
    'Studio': ('studio', '/', Size(1280, 800)),
    'Studio-Archives': ('studio', '/archive', Size(1280, 900)),
    'Studio-Stats': ('studio', '/stats', Size(1280, 900)),
    'Studio-Transfert': ('studio', '/transfer', Size(1280, 900)),
    'Studio-Reglages': ('studio', '/settings/general', Size(1280, 900)),
    'Terminal': ('terminal', '/', Size(1280, 800)),
    'Terminal-Archives': ('terminal', '/archive', Size(1280, 900)),
    'Terminal-Stats': ('terminal', '/stats', Size(1280, 900)),
    'Terminal-Transfert': ('terminal', '/transfer', Size(1280, 900)),
    'Terminal-Reglages': ('terminal', '/settings/general', Size(1280, 900)),
    'Nocturne': ('nocturne', '/', Size(1280, 800)),
    'Nocturne-Archives': ('nocturne', '/archive', Size(1280, 900)),
    'Nocturne-Stats': ('nocturne', '/stats', Size(1280, 900)),
    'Nocturne-Transfert': ('nocturne', '/transfer', Size(1280, 900)),
    'Nocturne-Reglages': ('nocturne', '/settings/general', Size(1280, 900)),
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

  // The situations every design must draw (build/visual/state_<id>_<case>.png):
  // nothing downloaded yet, a search with no match, the library loading,
  // everything failed, and a narrow window.
  final failedItems = [
    for (final item in sampleDownloads())
      item.copyWith(
        status: DownloadStatus.failed,
        error: 'ERROR: Unable to download: HTTP Error 403: Forbidden',
        progress: 0,
      ),
  ];
  final states =
      <
        String,
        ({List<DownloadItem>? items, bool loading, String search, Size size})
      >{
        'empty': (
          items: const [],
          loading: false,
          search: '',
          size: const Size(1280, 800),
        ),
        'noresults': (
          items: null,
          loading: false,
          search: 'zzzz introuvable',
          size: const Size(1280, 800),
        ),
        'loading': (
          items: const [],
          loading: true,
          search: '',
          size: const Size(1280, 800),
        ),
        'failed': (
          items: failedItems,
          loading: false,
          search: '',
          size: const Size(1280, 800),
        ),
        'narrow': (
          items: null,
          loading: false,
          search: '',
          size: const Size(820, 900),
        ),
      };
  for (final id in const [
    'signal',
    'porcelaine',
    'pastille',
    'studio',
    'terminal',
    'nocturne',
  ]) {
    for (final state in states.entries) {
      testWidgets('state $id ${state.key}', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(routerProvider);
        final key = await pump(
          tester,
          () => const SizedBox(),
          router: router,
          preset: ThemePresets.getById(id),
          size: state.value.size,
          items: state.value.items,
          loading: state.value.loading,
          extra: [
            if (state.value.search.isNotEmpty)
              downloadSearchQueryProvider.overrideWith(
                (ref) => state.value.search,
              ),
          ],
        );
        await settle(tester);
        await shot(tester, key, 'state_${id}_${state.key}');
      });
    }
  }
}
