// Renders Terminal's own library, inspector, archive and settings states the
// shared surface renders do not reach (card and folder views, a failed item
// selected, a narrow window, the archive hub, a scrolled settings page, a
// smart-organizer rule) to build/visual/surface_terminal_*.png. Like the other
// visual tests it writes images and fails only on a crash.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/plugins/builtin/smart_organizer_plugin.dart';
import 'package:tapload/core/router/app_router.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/onboarding/data/onboarding_store.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/showcase/showcase_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingStore.prefsKey, true);
    await prefs.setStringList('smart_organizer_rules', [
      jsonEncode(
        OrganizationRule(
          id: 'r1',
          name: 'Podcasts',
          pattern: 'podcast',
          isRegex: false,
          targetFolder: 'Audio/Podcasts',
          active: true,
        ).toJson(),
      ),
    ]);
  });

  tearDown(() => PlatformInfo.debugForceMobile = null);

  Future<(GlobalKey, ProviderContainer)> pump(
    WidgetTester tester,
    String route, {
    List<Override> extra = const [],
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final data = sampleDownloads();
    final key = GlobalKey();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
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
            theme: AppTheme.fromPalette(
              ThemePresets.getById('terminal'),
              Brightness.dark,
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
    router.go(route);
    await settle(tester);
    return (key, ProviderScope.containerOf(key.currentContext!));
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    final path = await capture(tester, key, 'surface_terminal_$name');
    // ignore: avoid_print
    print('[terminal] $name -> $path');
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('terminal cards view with a failed item selected', (
    tester,
  ) async {
    final (key, _) = await pump(
      tester,
      '/',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.detailed,
        ),
        selectedDownloadIdProvider.overrideWith((ref) => failedItemId),
      ],
    );
    await shot(tester, key, 'cards');
  });

  testWidgets('terminal folders view', (tester) async {
    final (key, c) = await pump(
      tester,
      '/',
      extra: [
        downloadViewModeProvider.overrideWith(
          (ref) => DownloadViewMode.folders,
        ),
      ],
    );
    final path = await capture(tester, key, 'surface_terminal_folders');
    // ignore: avoid_print
    print('[terminal] folders -> $path');
    await tester.tap(find.text('@atelier_nord/'));
    await settle(tester);
    await shot(tester, key, 'folder_open');
  });

  testWidgets('terminal inspector on a finished item', (tester) async {
    final (key, _) = await pump(
      tester,
      '/',
      extra: [selectedDownloadIdProvider.overrideWith((ref) => 'dl-done-1')],
    );
    await shot(tester, key, 'inspector_done');
  });

  testWidgets('terminal narrow window opens the inspector sheet', (
    tester,
  ) async {
    final (key, _) = await pump(tester, '/', size: const Size(1000, 760));
    await tester.tap(find.text('Clip court').first);
    await settle(tester);
    await shot(tester, key, 'narrow_sheet');
  });

  testWidgets('terminal archive hub', (tester) async {
    final (key, c) = await pump(tester, '/archive');
    c.read(tikTokArchiveProvider.notifier).setViewMode(TikTokViewMode.hub);
    await settle(tester);
    await shot(tester, key, 'archive_hub');
  });

  testWidgets('terminal archive collections', (tester) async {
    final (key, c) = await pump(tester, '/archive');
    c
        .read(tikTokArchiveProvider.notifier)
        .setViewMode(TikTokViewMode.collections);
    await settle(tester);
    await shot(tester, key, 'archive_collections');
  });

  testWidgets('terminal advanced settings scrolled', (tester) async {
    final (key, _) = await pump(tester, '/settings/advanced');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await settle(tester);
    await shot(tester, key, 'advanced_scrolled');
  });

  testWidgets('terminal smart organizer with a rule', (tester) async {
    final (key, _) = await pump(tester, '/settings/smart_organizer');
    await shot(tester, key, 'smart_rule');
  });
}
