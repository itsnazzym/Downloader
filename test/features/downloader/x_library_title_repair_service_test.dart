import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/services/x_library_title_repair_service.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

void main() {
  group('XLibraryTitleRepairService', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('md_x_repair_svc_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test(
      'updates title, permalink and filename from fetched metadata',
      () async {
        final video = File(
          '${dir.path}${Platform.pathSeparator}Wayxcx6DISTAPf95.mp4',
        );
        await video.writeAsBytes(const [1, 2, 3, 4]);

        final item = DownloadItem(
          id: 'job-1',
          request: DownloadRequest(
            url: 'https://x.com/alice/status/1891234567890123456',
          ),
          title: 'Wayxcx6DISTAPf95',
          filePath: video.path,
          status: DownloadStatus.completed,
          progress: 1.0,
        );

        final service = XLibraryTitleRepairService(
          fetchMetadata:
              (permalink, {String? cookiesFilePath, String? rawCookies}) async {
                expect(permalink, 'https://x.com/i/status/1891234567890123456');
                return <String, dynamic>{
                  'title': 'Hello from the timeline',
                  'id': '1891234567890123456',
                  'uploader': 'alice',
                  'thumbnail': 'https://pbs.twimg.com/media/thumb.jpg',
                };
              },
        );

        final repaired = await service.repairItem(item);
        expect(repaired, isNotNull);
        expect(repaired!.title, 'Hello from the timeline');
        expect(
          repaired.request.url,
          'https://x.com/i/status/1891234567890123456',
        );
        expect(
          repaired.filePath,
          endsWith('Hello from the timeline [1891234567890123456].mp4'),
        );
        expect(File(repaired.filePath!).existsSync(), isTrue);
        expect(video.existsSync(), isFalse);
      },
    );

    test('prefers sidecar info.json and skips the network fetcher', () async {
      final video = File(
        '${dir.path}${Platform.pathSeparator}Yepv3EA8BmQPAOpZ.mp4',
      );
      await video.writeAsBytes(const [1, 2, 3, 4]);
      final sidecar = File(
        '${dir.path}${Platform.pathSeparator}Yepv3EA8BmQPAOpZ.info.json',
      );
      await sidecar.writeAsString(
        jsonEncode(<String, Object?>{
          'title': 'Sidecar tweet text',
          'id': '1999988877766655544',
          'uploader': 'bob',
          'webpage_url': 'https://x.com/bob/status/1999988877766655544',
        }),
      );

      var fetchCalls = 0;
      final service = XLibraryTitleRepairService(
        fetchMetadata:
            (permalink, {String? cookiesFilePath, String? rawCookies}) async {
              fetchCalls += 1;
              return null;
            },
      );

      final item = DownloadItem(
        id: 'job-2',
        request: const DownloadRequest(
          url: 'https://twitter.detected/imported',
        ),
        title: 'Yepv3EA8BmQPAOpZ',
        filePath: video.path,
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      final repaired = await service.repairItem(item);
      expect(fetchCalls, 0);
      expect(repaired, isNotNull);
      expect(repaired!.title, 'Sidecar tweet text');
      expect(
        repaired.request.url,
        'https://x.com/i/status/1999988877766655544',
      );
    });

    test(
      'still updates the display title when rename is not possible',
      () async {
        final item = DownloadItem(
          id: 'job-3',
          request: const DownloadRequest(
            url: 'https://x.com/alice/status/1891234567890123456',
          ),
          title: 'Twitter Video',
          status: DownloadStatus.completed,
          progress: 1.0,
        );

        final service = XLibraryTitleRepairService(
          fetchMetadata:
              (permalink, {String? cookiesFilePath, String? rawCookies}) async {
                return <String, dynamic>{
                  'title': 'Only metadata',
                  'id': '1891234567890123456',
                };
              },
        );

        final repaired = await service.repairItem(item);
        expect(repaired, isNotNull);
        expect(repaired!.title, 'Only metadata');
        expect(repaired.filePath, isNull);
      },
    );

    test('returns null when metadata cannot be fetched', () async {
      final item = DownloadItem(
        id: 'job-4',
        request: const DownloadRequest(
          url: 'https://x.com/alice/status/1891234567890123456',
        ),
        title: 'Twitter Video',
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      final service = XLibraryTitleRepairService(
        fetchMetadata:
            (permalink, {String? cookiesFilePath, String? rawCookies}) async {
              return null;
            },
      );

      expect(await service.repairItem(item), isNull);
    });
  });
}
