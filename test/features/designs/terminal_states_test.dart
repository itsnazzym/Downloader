// Terminal design: the readable error reason, and the "done" line typed in
// when a running download completes.
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
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/designs/terminal/terminal_states.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/onboarding/data/onboarding_store.dart';
import 'package:tapload/l10n/app_localizations.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';
import 'package:tapload/features/designs/shared/design_data.dart';

void main() {
  group('downloadErrorReason', () {
    test('drops the ERROR prefix and yt-dlp boilerplate', () {
      expect(
        downloadErrorReason(
          'ERROR: Unable to download: HTTP Error 403: Forbidden',
        ),
        'HTTP Error 403: Forbidden',
      );
      expect(
        downloadErrorReason(
          'WARNING: slow\nERROR: [youtube] dQw4w9WgXcQ: Video unavailable',
        ),
        'Video unavailable',
      );
      expect(
        downloadErrorReason(
          'ERROR: Something broke; please report this issue on GitHub',
        ),
        'Something broke',
      );
      expect(downloadErrorReason(null), '');
      expect(downloadErrorReason('Disk full'), 'Disk full');
    });
  });

  group('terminal home', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await setUpVisualEnvironment();
      await prefs.setBool(OnboardingStore.prefsKey, true);
    });
    tearDown(() => PlatformInfo.debugForceMobile = null);

    testWidgets('a finished download is typed in as a done line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PlatformInfo.debugForceMobile = false;
      final items = sampleDownloads();
      final running = items.firstWhere(
        (i) => i.status == DownloadStatus.downloading,
      );
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
        ],
      );
      addTearDown(container.dispose);
      final preset = ThemePresets.getById('terminal');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
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
      );
      await settle(tester);
      Finder done() => find.textContaining('terminé  ', findRichText: true);
      expect(done(), findsNothing);

      final list = container.read(downloadListProvider.notifier);
      // ignore: invalid_use_of_protected_member
      list.state = AsyncValue.data([
        for (final i in items)
          i.id == running.id
              ? i.copyWith(status: DownloadStatus.completed, progress: 1)
              : i,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(done(), findsOneWidget);
      // Fully typed within the moment (< 1 s).
      final typed = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(TTyped),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(typed.text.toPlainText(), contains(running.title ?? ''));

      await tester.pump(const Duration(seconds: 5));
      expect(done(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
