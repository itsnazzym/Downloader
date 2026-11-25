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
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/app_shell.dart';
import 'package:modern_downloader/core/ui/settings/settings_hub_view.dart';
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
  }) async {
    tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
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
          ...extra,
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: Locale(locale),
            theme: AppTheme.fromPalette(ThemePresets.midnight, Brightness.dark),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                ShellRoute(
                  builder: (context, state, child) => AppShell(child: child),
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
}
