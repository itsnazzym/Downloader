import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/features/designs/pastille/pastille_home.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';
import 'package:modern_downloader/features/designs/shared/design_data.dart';

/// A library the test can change by hand.
class _Driven extends DownloadListNotifier {
  _Driven(super.repository, super.ref, List<DownloadItem> items) {
    state = AsyncValue.data(items);
  }

  void set(List<DownloadItem> items) => state = AsyncValue.data(items);
}

void main() {
  group('downloadErrorReason', () {
    test('drops the ERROR:, extractor and "Unable to" prefixes', () {
      expect(
        downloadErrorReason('ERROR: Unable to download: HTTP Error 403: Forbidden'),
        'HTTP Error 403: Forbidden',
      );
      expect(
        downloadErrorReason(
          'WARNING: slow\nERROR: [youtube] abc123: Video unavailable\nmore',
        ),
        'Video unavailable',
      );
      expect(downloadErrorReason('  Plain reason  '), 'Plain reason');
      expect(downloadErrorReason(null), '');
      expect(downloadErrorReason('\n \n'), '');
    });
  });

  group('finish moment', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await setUpVisualEnvironment();
    });
    tearDown(() => PlatformInfo.debugForceMobile = null);

    final active = sampleDownloads().firstWhere(
      (i) => i.status == DownloadStatus.downloading,
    );

    Future<_Driven> pumpHome(WidgetTester tester, {bool reduce = false}) async {
      tester.view.physicalSize = const Size(1280, 1080) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PlatformInfo.debugForceMobile = false;
      late _Driven list;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(),
            dependencyBootstrapProvider.overrideWith(
              (ref) => DependencyBootstrapNotifier.ready(),
            ),
            downloaderRepositoryProvider.overrideWith(
              (ref) => FakeDownloaderRepository([active]),
            ),
            persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
            downloadListProvider.overrideWith(
              (ref) => list = _Driven(
                ref.read(downloaderRepositoryProvider),
                ref,
                [active],
              ),
            ),
            downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
            designFreeSpaceProvider.overrideWith((ref) async => 1 << 30),
          ],
          child: MaterialApp.router(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // The app shell normally supplies the Material.
            builder: (context, child) => Material(
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: child!,
              ),
            ),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const PastilleHome(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      return list;
    }

    testWidgets('a download that completes shows 100 % and « Terminé »', (
      tester,
    ) async {
      final list = await pumpHome(tester);
      expect(find.text('Terminé'), findsNothing);

      list.set([
        active.copyWith(status: DownloadStatus.completed, progress: 1),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.textContaining('100', findRichText: true), findsWidgets);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('Terminé'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no moment when animations are off', (tester) async {
      final list = await pumpHome(tester, reduce: true);
      list.set([
        active.copyWith(status: DownloadStatus.completed, progress: 1),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Terminé'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
