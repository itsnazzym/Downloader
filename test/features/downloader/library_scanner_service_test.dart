import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/services/library_scanner_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/services/binary_locator.dart';

void main() {
  group('LibraryScannerService path recovery', () {
    late Directory dir;
    late LibraryScannerService scanner;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('md_scanner_');
      scanner = LibraryScannerService(BinaryLocator());
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('recovers file by bracket id when stored path is stale', () async {
      final real = File(
        '${dir.path}${Platform.pathSeparator}uploader - 99 [209191506225657].mp4',
      );
      await real.writeAsBytes([0, 0, 0, 0]);

      final item = DownloadItem(
        id: 'test-1',
        request: const DownloadRequest(url: 'https://x.com/a/status/1'),
        title: '- httpst.coCSJbBJRpXf',
        status: DownloadStatus.completed,
        progress: 1.0,
        // Stale fragment path still carries the tweet id in brackets
        filePath:
            '${dir.path}${Platform.pathSeparator}'
            'gone [209191506225657].f401.mp4',
      );

      final fixed = await scanner.scanAndFix([item], dir.path);
      expect(fixed, hasLength(1));
      expect(fixed.first.filePath, real.path);
      expect(fixed.first.status, DownloadStatus.completed);
    });

    test('recovers Japanese title via unicode normalize fuzzy match', () async {
      final real = File(
        '${dir.path}${Platform.pathSeparator}ものがたり 衝撃映像 [jp001].mp4',
      );
      await real.writeAsBytes([0, 0, 0, 0]);

      final item = DownloadItem(
        id: 'test-2',
        request: const DownloadRequest(url: 'https://x.com/a/status/2'),
        title: 'ものがたり 衝撃映像',
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: '${dir.path}${Platform.pathSeparator}wrong-name.mp4',
      );

      final fixed = await scanner.scanAndFix([item], dir.path);
      expect(fixed.first.filePath, real.path);
    });

    test(
      'promotes failed item with valid file and clears error/Retry',
      () async {
        final real = File('${dir.path}${Platform.pathSeparator}clip [abc].mp4');
        await real.writeAsBytes([1, 2, 3, 4]);

        final item = DownloadItem(
          id: 'test-promote',
          request: const DownloadRequest(url: 'https://x.com/a/status/3'),
          title: 'clip',
          status: DownloadStatus.failed,
          progress: 0.0,
          speed: 'Retry 3/3...',
          error:
              'yt-dlp exited successfully but no download progress was detected',
          filePath: real.path,
        );

        final fixed = await scanner.scanAndFix([item], dir.path);
        expect(fixed.first.status, DownloadStatus.completed);
        expect(fixed.first.progress, 1.0);
        expect(fixed.first.error, isNull);
        expect(fixed.first.speed, 'Terminé');
      },
    );

    test('clears COMPLETED Retry 3/3 ghost when file is valid', () async {
      final real = File('${dir.path}${Platform.pathSeparator}hijab [id1].mp4');
      await real.writeAsBytes([1, 2, 3, 4, 5]);

      final item = DownloadItem(
        id: 'ghost-completed',
        request: const DownloadRequest(url: 'https://x.com/a/status/4'),
        title: 'hijab',
        status: DownloadStatus.completed,
        progress: 0.0,
        speed: 'Retry 3/3...',
        error:
            'yt-dlp exited successfully but no download progress was detected',
        filePath: real.path,
      );

      final fixed = await scanner.scanAndFix([item], dir.path);
      expect(fixed.first.status, DownloadStatus.completed);
      expect(fixed.first.progress, 1.0);
      expect(fixed.first.error, isNull);
      expect(fixed.first.speed, 'Terminé');
    });

    test('fills empty totalSize from on-disk file length', () async {
      final real = File(
        '${dir.path}${Platform.pathSeparator}tweet [size1].mp4',
      );
      await real.writeAsBytes([1, 2, 3, 4, 5]);

      final item = DownloadItem(
        id: 'unknown-size',
        request: const DownloadRequest(url: 'https://x.com/a/status/5'),
        title: 'pretty blowers',
        status: DownloadStatus.completed,
        progress: 1.0,
        speed: 'Terminé',
        totalSize: '',
        filePath: real.path,
      );

      final fixed = await scanner.scanAndFix([item], dir.path);
      expect(fixed.first.totalSize, isNotEmpty);
      expect(fixed.first.totalSize, isNot(contains('Unknown')));
      expect(fixed.first.downloadedSize, fixed.first.totalSize);
    });

    test(
      'does not promote failed item when file is empty or fragment',
      () async {
        final empty = File(
          '${dir.path}${Platform.pathSeparator}empty [e1].mp4',
        );
        await empty.writeAsBytes([]);

        final fragment = File(
          '${dir.path}${Platform.pathSeparator}frag [e2].f401.mp4',
        );
        await fragment.writeAsBytes([1, 2, 3]);

        final emptyItem = DownloadItem(
          id: 'empty',
          request: const DownloadRequest(url: 'https://x.com/a/status/4'),
          title: 'empty',
          status: DownloadStatus.failed,
          error: 'fail',
          speed: 'Retry 3/3...',
          filePath: empty.path,
        );
        final fragItem = DownloadItem(
          id: 'frag',
          request: const DownloadRequest(url: 'https://x.com/a/status/5'),
          title: 'frag',
          status: DownloadStatus.failed,
          error: 'fail',
          speed: 'Retry 3/3...',
          filePath: fragment.path,
        );

        final fixed = await scanner.scanAndFix([emptyItem, fragItem], dir.path);
        expect(fixed[0].status, DownloadStatus.failed);
        expect(fixed[0].error, 'fail');
        expect(fixed[1].status, DownloadStatus.failed);
        expect(fixed[1].error, 'fail');
      },
    );

    test(
      'does not attach zina title to hijab file via one shared word',
      () async {
        final hijab = File(
          '${dir.path}${Platform.pathSeparator}hijab [111222333444].mp4',
        );
        final zina = File(
          '${dir.path}${Platform.pathSeparator}'
          'zina - Die besten Hijab Inhalte [555666777888].mp4',
        );
        await hijab.writeAsBytes([1, 2, 3, 4]);
        await zina.writeAsBytes([5, 6, 7, 8]);

        final zinaItem = DownloadItem(
          id: 'zina',
          request: const DownloadRequest(
            url: 'https://x.com/user/status/555666777888',
          ),
          title: 'zina - Die besten Hijab-Amateur-Selbstgemachten-Inhalte',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: hijab.path,
        );
        final hijabItem = DownloadItem(
          id: 'hijab',
          request: const DownloadRequest(
            url: 'https://x.com/hijabi/status/111222333444',
          ),
          title: 'hijab',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: hijab.path,
        );

        final fixed = await scanner.scanAndFix([zinaItem, hijabItem], dir.path);
        expect(fixed, hasLength(2));
        final byId = {for (final item in fixed) item.id: item};
        expect(byId['hijab']!.filePath, hijab.path);
        expect(byId['zina']!.filePath, zina.path);
      },
    );

    test(
      'drops imported ghost that shares a file with a real download',
      () async {
        final real = File('${dir.path}${Platform.pathSeparator}clip [999].mp4');
        await real.writeAsBytes([1, 2, 3, 4]);

        final downloaded = DownloadItem(
          id: 'real',
          request: const DownloadRequest(url: 'https://x.com/a/status/999'),
          title: 'clip',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: real.path,
        );
        final imported = DownloadItem(
          id: 'ghost',
          request: const DownloadRequest(
            url: 'https://twitter.detected/imported',
          ),
          title: 'clip [999].mp4',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: real.path,
        );

        final fixed = await scanner.scanAndFix([
          downloaded,
          imported,
        ], dir.path);
        expect(fixed, hasLength(1));
        expect(fixed.first.id, 'real');
        expect(fixed.first.filePath, real.path);
      },
    );

    test(
      'drops failed ghost that duplicates a completed row for the same tweet',
      () async {
        final real = File(
          '${dir.path}${Platform.pathSeparator}'
          'interracial bunnies - Being a good girl for daddy [2092727271098621952].mp4',
        );
        await real.writeAsBytes([1, 2, 3, 4]);

        const url = 'https://x.com/bbc_breeds/status/2092727515949551766';
        final completed = DownloadItem(
          id: 'completed-twin',
          request: const DownloadRequest(url: url),
          title: 'interracial bunnies - Being a good girl for daddy',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: real.path,
        );
        final ghost = DownloadItem(
          id: 'failed-ghost',
          request: const DownloadRequest(url: url),
          title: 'interracial bunnies - Being a good girl for daddy',
          status: DownloadStatus.failed,
          progress: 1.0,
          error: 'File missing from disk',
          filePath: null,
        );

        final fixed = await scanner.scanAndFix([ghost, completed], dir.path);
        expect(fixed, hasLength(1));
        expect(fixed.first.id, 'completed-twin');
        expect(fixed.first.status, DownloadStatus.completed);
        expect(fixed.first.filePath, real.path);
        expect(fixed.first.error, isNull);
      },
    );

    test(
      'does not mark a different-url row missing when it shares a file',
      () async {
        final real = File(
          '${dir.path}${Platform.pathSeparator}shared [111].mp4',
        );
        await real.writeAsBytes([1, 2, 3, 4]);

        final owner = DownloadItem(
          id: 'owner',
          request: const DownloadRequest(url: 'https://x.com/a/status/111'),
          title: 'shared clip title uniqueaaa',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: real.path,
        );
        final other = DownloadItem(
          id: 'other',
          request: const DownloadRequest(url: 'https://x.com/b/status/222'),
          title: 'shared clip title uniqueaaa',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: real.path,
        );

        final fixed = await scanner.scanAndFix([owner, other], dir.path);
        expect(fixed, hasLength(2));
        expect(
          fixed.every((item) => item.status == DownloadStatus.completed),
          isTrue,
        );
        expect(
          fixed.every((item) => item.error != 'File missing from disk'),
          isTrue,
        );
      },
    );

    test(
      'rebuilds cache so a later scan recovers a file added after first scan',
      () async {
        final item = DownloadItem(
          id: 'late-file',
          request: const DownloadRequest(url: 'https://x.com/a/status/10'),
          title: 'interracial bunnies - Being a good girl for daddy',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath:
              '${dir.path}${Platform.pathSeparator}'
              'interracial bunnies - Being a good girl for daddy.mp4',
        );

        final first = await scanner.scanAndFix([item], dir.path);
        expect(first.first.status, DownloadStatus.failed);
        expect(first.first.error, 'File missing from disk');

        final real = File(item.filePath!);
        await real.writeAsBytes([1, 2, 3, 4]);

        final second = await scanner.scanAndFix(first, dir.path);
        expect(second.first.status, DownloadStatus.completed);
        expect(second.first.error, isNull);
        expect(second.first.filePath, real.path);
      },
    );

    test(
      'recovers remuxed .mp4 when stored path still points at .webm',
      () async {
        final mp4 = File(
          '${dir.path}${Platform.pathSeparator}clip [webm1].mp4',
        );
        await mp4.writeAsBytes([1, 2, 3, 4]);

        final item = DownloadItem(
          id: 'ext-swap',
          request: const DownloadRequest(url: 'https://x.com/a/status/11'),
          title: 'clip',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: '${dir.path}${Platform.pathSeparator}clip [webm1].webm',
        );

        final fixed = await scanner.scanAndFix([item], dir.path);
        expect(fixed.first.status, DownloadStatus.completed);
        expect(fixed.first.error, isNull);
        expect(fixed.first.filePath, mp4.path);
      },
    );

    test(
      'recovers file moved into a site subfolder when stored path is the parent',
      () async {
        final siteDir = Directory(
          '${dir.path}${Platform.pathSeparator}Pornhub',
        )..createSync();
        final real = File(
          '${siteDir.path}${Platform.pathSeparator}'
          'interracial bunnies - Being a good girl for daddy [ph1].mp4',
        );
        await real.writeAsBytes([1, 2, 3, 4]);

        final item = DownloadItem(
          id: 'subfolder',
          request: const DownloadRequest(url: 'https://example.com/v/1'),
          title: 'interracial bunnies - Being a good girl for daddy',
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath:
              '${dir.path}${Platform.pathSeparator}'
              'interracial bunnies - Being a good girl for daddy [ph1].mp4',
        );

        final fixed = await scanner.scanAndFix([item], dir.path);
        expect(fixed.first.status, DownloadStatus.completed);
        expect(fixed.first.error, isNull);
        expect(fixed.first.filePath, real.path);
      },
    );
  });
}
