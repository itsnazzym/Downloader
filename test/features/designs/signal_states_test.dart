import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/designs/signal/signal_states.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';

/// A pinned list the test can replace, as a finished download would.
class _FlipList extends PinnedDownloadList {
  _FlipList(super.repository, super.ref, super.items);

  void flip(List<DownloadItem> items) => state = AsyncValue.data(items);
}

void main() {
  group('signalShortError', () {
    test('drops the ERROR: prefix and generic lead-in', () {
      expect(
        signalShortError(
          'ERROR: Unable to download: HTTP Error 403: Forbidden\nmore',
        ),
        'HTTP Error 403: Forbidden',
      );
    });

    test('drops the [extractor] id: tag and the report boilerplate', () {
      expect(
        signalShortError(
          '\nERROR: [youtube] dQw4w9WgXcQ: Video unavailable; please report '
          'this issue on https://github.com/yt-dlp/yt-dlp',
        ),
        'Video unavailable',
      );
    });

    test('empty or missing error gives an empty reason', () {
      expect(signalShortError(null), '');
      expect(signalShortError('  \n '), '');
    });
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
  });

  tearDown(() => PlatformInfo.debugForceMobile = null);

  testWidgets('a download that finishes flashes its check, then leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final running = sampleDownloads().firstWhere(
      (i) => i.status == DownloadStatus.downloading,
    );
    late _FlipList list;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          dependencyBootstrapProvider.overrideWith(
            (ref) => DependencyBootstrapNotifier.ready(),
          ),
          downloaderRepositoryProvider.overrideWith(
            (ref) => FakeDownloaderRepository([running]),
          ),
          persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
          downloadListProvider.overrideWith(
            (ref) => list = _FlipList(
              ref.read(downloaderRepositoryProvider),
              ref,
              [running],
            ),
          ),
          downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
          designFreeSpaceProvider.overrideWith((ref) async => 1 << 30),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.fromPalette(ThemePresets.signal, Brightness.dark),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SignalHome()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    final finish = find.byKey(const ValueKey('signal-finish'));
    expect(finish, findsNothing);

    list.flip([
      running.copyWith(status: DownloadStatus.completed, progress: 1),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(finish, findsOneWidget);
    expect(
      find.descendant(of: finish, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: finish,
        matching: find.text('100%', findRichText: true),
      ),
      findsOne,
    );

    // Under a second, then the card is back to « nothing in progress ».
    await tester.pump(const Duration(milliseconds: 500));
    expect(finish, findsNothing);
  });
}
