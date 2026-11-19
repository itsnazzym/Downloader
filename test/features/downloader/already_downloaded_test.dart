import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/yt_dlp_progress_parser.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual/visual_fakes.dart';

YtDlpProgressParser _parser() =>
    YtDlpProgressParser(baseFolder: '/tmp', preferredExt: '.mp4');

DownloadItem _item(
  DownloadStatus status, {
  double progress = 0,
  String speed = '',
  String totalSize = '',
}) {
  return DownloadItem(
    id: 'a',
    request: const DownloadRequest(url: 'https://example.com/v'),
    status: status,
    progress: progress,
    speed: speed,
    totalSize: totalSize,
    title: 'Clip',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('already downloaded detection', () {
    test('a bare 100 % line without any transfer means already on disk', () {
      // What yt-dlp prints (with --print) when the file was complete.
      final parser = _parser();
      parser.onLine('[download] 100% of   59.01MiB');
      expect(parser.wasAlreadyDownloaded, isTrue);
    });

    test('a real download is not mistaken for it', () {
      final parser = _parser();
      parser.onLine(
        '[download]   1.7% of   59.01MiB at  926.19KiB/s ETA 01:04',
      );
      parser.onLine(
        '[download]  50.0% of   59.01MiB at    4.71MiB/s ETA 00:07',
      );
      parser.onLine(
        '[download] 100.0% of   59.01MiB at   12.43MiB/s ETA 00:00',
      );
      parser.onLine('[download] 100% of   59.01MiB in 00:00:05 at 11.01MiB/s');
      expect(parser.wasAlreadyDownloaded, isFalse);
    });

    test('a bare finish after a resumed transfer is still a download', () {
      final parser = _parser();
      parser.onLine(
        '[download]  80.0% of   59.01MiB at    4.71MiB/s ETA 00:02',
      );
      parser.onLine('[download] 100% of   59.01MiB');
      expect(parser.wasAlreadyDownloaded, isFalse);
    });

    test('other lines never set it', () {
      final parser = _parser();
      parser.onLine('[generic] Extracting URL');
      parser.onLine('/storage/emulated/0/Download/clip [id].mp4');
      expect(parser.wasAlreadyDownloaded, isFalse);
    });
  });

  group('already downloaded reaches the app', () {
    test(
      'a completed item flagged as already downloaded is published once',
      () async {
        SharedPreferences.setMockInitialValues({});
        initPrefs(await SharedPreferences.getInstance());
        final repo = FakeDownloaderRepository([]);
        final container = ProviderContainer(
          overrides: [
            downloaderRepositoryProvider.overrideWithValue(repo),
            persistenceServiceProvider.overrideWithValue(FakePersistence()),
          ],
        );
        addTearDown(container.dispose);
        container.read(downloadListProvider.notifier);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        final seen = <String?>[];
        container.listen<DownloadItem?>(
          alreadyDownloadedProvider,
          (previous, next) => seen.add(next?.id),
        );

        final done = _item(
          DownloadStatus.completed,
          progress: 1,
        ).copyWith(alreadyDownloaded: true);
        repo.emit(done);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(seen, ['a']);

        // A later update of the same row must not pop the sheet again.
        repo.emit(done.copyWith(title: 'Clip (renamed)'));
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(seen, ['a']);
      },
    );

    test('a normal completion publishes nothing', () async {
      SharedPreferences.setMockInitialValues({});
      initPrefs(await SharedPreferences.getInstance());
      final repo = FakeDownloaderRepository([]);
      final container = ProviderContainer(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(repo),
          persistenceServiceProvider.overrideWithValue(FakePersistence()),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadListProvider.notifier);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      repo.emit(_item(DownloadStatus.completed, progress: 1));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(container.read(alreadyDownloadedProvider), isNull);
    });

    test('the flag is not part of the saved data', () {
      final json = _item(
        DownloadStatus.completed,
      ).copyWith(alreadyDownloaded: true).toJson();
      expect(json.containsKey('alreadyDownloaded'), isFalse);
      expect(DownloadItem.fromJson(json).alreadyDownloaded, isFalse);
    });
  });

  group('livePhase', () {
    test('says what is happening before bytes flow', () {
      expect(
        livePhase(_item(DownloadStatus.extracting), null),
        LivePhase.analyzing,
      );
      expect(
        livePhase(_item(DownloadStatus.downloading), null),
        LivePhase.connecting,
      );
      expect(
        livePhase(_item(DownloadStatus.processing, progress: 1), null),
        LivePhase.finalizing,
      );
    });

    test('is null once the transfer has started', () {
      expect(
        livePhase(_item(DownloadStatus.downloading, progress: 0.02), null),
        isNull,
      );
      // A speed alone is enough: the first percent may not be printed yet.
      expect(
        livePhase(_item(DownloadStatus.downloading), 1024.0 * 1024),
        isNull,
      );
    });

    test('is null for rows that are not running', () {
      for (final status in [
        DownloadStatus.queued,
        DownloadStatus.paused,
        DownloadStatus.completed,
        DownloadStatus.failed,
        DownloadStatus.canceled,
        DownloadStatus.duplicate,
      ]) {
        expect(livePhase(_item(status), null), isNull, reason: '$status');
      }
    });

    test('every phase has a label in every language', () {
      for (final code in ['en', 'fr', 'ar']) {
        final l10n = lookupAppLocalizations(Locale(code));
        for (final phase in LivePhase.values) {
          expect(livePhaseLabel(l10n, phase), isNotEmpty, reason: code);
        }
      }
    });
  });

  group('completion summary', () {
    final start = DateTime(2026, 11, 19, 12);

    test('reports size, duration and the average speed', () {
      final summary = summarizeCompletion(
        _item(DownloadStatus.completed, progress: 1, totalSize: '59.0MB'),
        firstBytesAt: start,
        now: start.add(const Duration(seconds: 5)),
        title: 'Clip',
      );
      expect(summary.duration, const Duration(seconds: 5));
      expect(summary.sizeText, '59.0MB');
      expect(summary.bytesPerSecond, closeTo(59.0 * 1024 * 1024 / 5, 1));
    });

    test('has no average when the transfer was too short to mean anything', () {
      final summary = summarizeCompletion(
        _item(DownloadStatus.completed, progress: 1, totalSize: '770.0KB'),
        firstBytesAt: start,
        now: start.add(const Duration(milliseconds: 300)),
        title: 'Clip',
      );
      expect(summary.bytesPerSecond, isNull);
      expect(summary.sizeText, '770.0KB');
    });

    test('has no average when the size is unknown', () {
      final summary = summarizeCompletion(
        _item(DownloadStatus.completed, progress: 1),
        firstBytesAt: start,
        now: start.add(const Duration(seconds: 4)),
        title: 'Clip',
      );
      expect(summary.bytesPerSecond, isNull);
    });

    test('a clock that went backwards gives a zero duration, not a crash', () {
      final summary = summarizeCompletion(
        _item(DownloadStatus.completed, progress: 1, totalSize: '1.0MB'),
        firstBytesAt: start,
        now: start.subtract(const Duration(seconds: 3)),
        title: 'Clip',
      );
      expect(summary.duration, Duration.zero);
      expect(summary.bytesPerSecond, isNull);
    });

    test('durationLabel is readable and never says 0 s', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(durationLabel(en, const Duration(milliseconds: 200)), '1 s');
      expect(durationLabel(en, const Duration(seconds: 5)), '5 s');
      expect(durationLabel(en, const Duration(seconds: 72)), '1 min 12 s');
      expect(durationLabel(en, const Duration(minutes: 65)), '1 h 5 min');
    });
  });
}
