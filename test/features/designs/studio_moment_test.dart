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
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/designs/studio/studio_home.dart';
import 'package:modern_downloader/features/designs/studio/studio_states.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';

void main() {
  test('studioErrorReason keeps the readable part of a yt-dlp error', () {
    expect(
      studioErrorReason('ERROR: Unable to download: HTTP Error 403: Forbidden'),
      'HTTP Error 403: Forbidden',
    );
    expect(
      studioErrorReason(
        'ERROR: [twitter] 1790234567890123456: No video could be found\nmore',
      ),
      'No video could be found',
    );
    expect(
      studioErrorReason('ERROR: [twitter] No video could be found in this tweet'),
      'No video could be found in this tweet',
    );
    expect(studioErrorReason('\n  Connexion perdue\n'), 'Connexion perdue');
    expect(studioErrorReason(null), '');
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    await prefs.setBool(OnboardingStore.prefsKey, true);
  });
  tearDown(() => PlatformInfo.debugForceMobile = null);

  testWidgets('a row that finishes stamps an ink check, then settles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final items = sampleDownloads();
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
        ],
        child: MaterialApp.router(
          locale: const Locale('fr'),
          theme: AppTheme.fromPalette(ThemePresets.studio, Brightness.light),
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
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(StudioHome), findsOneWidget);
    Finder check() => find.descendant(
      of: find.byType(StudioHome),
      matching: find.byIcon(Icons.check_rounded),
    );
    double checkOpacity() => tester
        .widget<Opacity>(
          find.ancestor(of: check(), matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(check(), findsNothing);

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(StudioHome)),
    );
    final active = items.firstWhere((i) => i.id == 'dl-active');
    scope.read(downloadRuntimeItemProvider(active.id).notifier).state = active
        .copyWith(status: DownloadStatus.completed, progress: 1);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(check(), findsOneWidget);
    expect(checkOpacity(), greaterThan(0.5));

    await tester.pump(const Duration(milliseconds: 700));
    expect(checkOpacity(), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
