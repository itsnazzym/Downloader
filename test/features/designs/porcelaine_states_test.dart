import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/designs/porcelaine/porcelaine_home.dart';
import 'package:tapload/features/designs/porcelaine/porcelaine_states.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/l10n/app_localizations.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';
import 'package:tapload/features/designs/shared/design_data.dart';

/// A list the test can change.
class _Flip extends DownloadListNotifier {
  _Flip(super.repository, super.ref, List<DownloadItem> items) {
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (mounted) state = AsyncValue.data(items);
    });
  }

  void set(List<DownloadItem> items) => state = AsyncValue.data(items);
}

void main() {
  group('downloadErrorReason', () {
    test('drops the ERROR: prefix and yt-dlp noise', () {
      expect(
        downloadErrorReason('ERROR: Unable to download: HTTP Error 403: Forbidden'),
        'HTTP Error 403: Forbidden',
      );
      expect(
        downloadErrorReason(
          '\nERROR: [youtube] dQw4w9WgXcQ: Video unavailable\nmore noise',
        ),
        'Video unavailable',
      );
      expect(
        downloadErrorReason('Requested format is not available'),
        'Requested format is not available',
      );
    });

    test('is empty without an error', () {
      expect(downloadErrorReason(null), '');
      expect(downloadErrorReason('  \n '), '');
    });
  });

  group('pJustFinished', () {
    final sample = sampleDownloads();
    final active = sample.firstWhere(
      (i) => i.status == DownloadStatus.downloading,
    );
    List<DownloadItem> withStatus(DownloadStatus s) => [
      for (final i in sample) i.id == active.id ? i.copyWith(status: s) : i,
    ];

    test('finds an active item that completed', () {
      final done = pJustFinished(sample, withStatus(DownloadStatus.completed));
      expect(done.map((i) => i.id), [active.id]);
    });

    test('ignores the first load and failures', () {
      expect(
        pJustFinished(null, withStatus(DownloadStatus.completed)),
        isEmpty,
      );
      expect(pJustFinished(sample, withStatus(DownloadStatus.failed)), isEmpty);
    });
  });

  group('finished moment', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await setUpVisualEnvironment();
    });
    tearDown(() => PlatformInfo.debugForceMobile = null);

    testWidgets('the En cours widget shows the check, then settles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 960) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PlatformInfo.debugForceMobile = false;
      final items = sampleDownloads();
      final active = items.firstWhere(
        (i) => i.status == DownloadStatus.downloading,
      );
      late _Flip list;
      final container = ProviderContainer(
        overrides: [
          ...baseOverrides(),
          downloaderRepositoryProvider.overrideWith(
            (ref) => FakeDownloaderRepository(items),
          ),
          persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
          downloadListProvider.overrideWith(
            (ref) => list = _Flip(
              ref.read(downloaderRepositoryProvider),
              ref,
              items,
            ),
          ),
          downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
          designFreeSpaceProvider.overrideWith((ref) async => 1 << 30),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('fr'),
            theme: AppTheme.fromPalette(
              ThemePresets.getById('porcelaine'),
              Brightness.light,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: PorcelaineHome()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(porcelaineFinishProvider), isNull);

      list.set([
        for (final i in items)
          i.id == active.id
              ? i.copyWith(status: DownloadStatus.completed, progress: 1)
              : i,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(porcelaineFinishProvider)?.id, active.id);
      expect(find.text('Terminé'), findsOneWidget);

      // Under a second later the moment is over.
      await tester.pump(const Duration(milliseconds: 800));
      expect(container.read(porcelaineFinishProvider), isNull);
      expect(find.text('Terminé'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      // The speed tile's provider is autoDispose: its 2 s timer only stops
      // once the container goes, which teardown does after the pending-timer
      // check (seen on CI, Flutter 3.44).
      container.dispose();
    });
  });
}
