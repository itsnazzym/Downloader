import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/x_feed/library_keys_snapshot.dart';

DownloadItem _item({
  required String id,
  required DownloadStatus status,
  required String url,
  String? filePath,
  String? thumbnailUrl,
  String? forceStreamUrl,
}) {
  return DownloadItem(
    id: id,
    request: DownloadRequest(url: url, forceStreamUrl: forceStreamUrl),
    status: status,
    filePath: filePath,
    thumbnailUrl: thumbnailUrl,
  );
}

void main() {
  group('LibraryKeysSnapshot', () {
    test('includes tweet and media ids for completed files still on disk', () {
      final snapshot = LibraryKeysSnapshot.fromDownloads(
        <DownloadItem>[
          _item(
            id: 'a',
            status: DownloadStatus.completed,
            url: 'https://x.com/alice/status/1112223334445556667',
            filePath: r'C:\Videos\keep.mp4',
            thumbnailUrl:
                'https://pbs.twimg.com/ext_tw_video_thumb/1891234567890123456/pu/img/abc.jpg',
          ),
        ],
        fileExists: (path) => path.endsWith('keep.mp4'),
      );

      expect(snapshot.tweetIds, <String>['1112223334445556667']);
      expect(snapshot.mediaIds, <String>['1891234567890123456']);
      expect(snapshot.toJson()['type'], LibraryKeysSnapshot.resultType);
      expect(snapshot.toJson().containsKey('filePath'), isFalse);
      expect(snapshot.toJson().containsKey('cookies'), isFalse);
      expect(snapshot.toJson().toString().contains(r'C:\Videos'), isFalse);
    });

    test('skips completed items whose files are gone', () {
      final snapshot = LibraryKeysSnapshot.fromDownloads(
        <DownloadItem>[
          _item(
            id: 'gone',
            status: DownloadStatus.completed,
            url: 'https://x.com/alice/status/1112223334445556667',
            filePath: r'C:\Videos\missing.mp4',
          ),
        ],
        fileExists: (_) => false,
      );

      expect(snapshot.tweetIds, isEmpty);
      expect(snapshot.mediaIds, isEmpty);
    });

    test('includes duplicate items even without a local file', () {
      final snapshot = LibraryKeysSnapshot.fromDownloads(
        <DownloadItem>[
          _item(
            id: 'dup',
            status: DownloadStatus.duplicate,
            url: 'https://x.com/bob/status/2223334445556667778',
            forceStreamUrl:
                'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/720x1280/x.mp4',
          ),
        ],
        fileExists: (_) => false,
      );

      expect(snapshot.tweetIds, <String>['2223334445556667778']);
      expect(snapshot.mediaIds, <String>['1891234567890123456']);
    });

    test('omits queued and failed downloads', () {
      final snapshot = LibraryKeysSnapshot.fromDownloads(
        <DownloadItem>[
          _item(
            id: 'q',
            status: DownloadStatus.queued,
            url: 'https://x.com/alice/status/1112223334445556667',
          ),
          _item(
            id: 'f',
            status: DownloadStatus.failed,
            url: 'https://x.com/alice/status/1112223334445556668',
            filePath: r'C:\Videos\fail.mp4',
          ),
        ],
        fileExists: (_) => true,
      );

      expect(snapshot.tweetIds, isEmpty);
    });
  });
}
