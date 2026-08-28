import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/download/x_library_title_repair.dart';
import 'package:modern_downloader/core/download/x_tweet_display_title.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

DownloadItem _item({
  required String url,
  String? title,
  String? filePath,
  String? thumbnailUrl,
  DownloadStatus status = DownloadStatus.completed,
}) {
  return DownloadItem(
    id: 'item-1',
    request: DownloadRequest(url: url),
    title: title,
    filePath: filePath,
    thumbnailUrl: thumbnailUrl,
    status: status,
    progress: status == DownloadStatus.completed ? 1.0 : 0.0,
  );
}

void main() {
  group('XDownloadUrl.tweetIdFrom', () {
    test('does not mistake an ext_tw_video media id for a tweet id', () {
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/avc1/720x1280/Wayxcx6DISTAPf95.mp4',
        ),
        isNull,
      );
    });

    test('does not mistake an amplify_video media id for a tweet id', () {
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://video.twimg.com/amplify_video/1999988877766655544/vid/avc1/1280x720/abc.mp4',
        ),
        isNull,
      );
    });

    test('reads snowflake from a status permalink', () {
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://x.com/alice/status/1112223334445556667',
        ),
        '1112223334445556667',
      );
      expect(
        XDownloadUrl.tweetIdFrom('https://x.com/i/status/1112223334445556667'),
        '1112223334445556667',
      );
    });

    test(
      'does not mistake a numeric media id in a filename for a tweet id',
      () {
        expect(
          XDownloadUrl.tweetIdFrom(r'C:\Videos\clip [1891234567890123456].mp4'),
          isNull,
        );
      },
    );

    test('does not mistake an ext_tw_video_thumb media id for a tweet id', () {
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://pbs.twimg.com/ext_tw_video_thumb/1891234567890123456/pu/img/abc.jpg',
        ),
        isNull,
      );
    });

    test('does not treat 720 or 1280 as a tweet id', () {
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://video.twimg.com/tweet_video/Wayxcx6DISTAPf95.mp4',
        ),
        isNull,
      );
      expect(
        XDownloadUrl.tweetIdFrom('https://example.com/vid/720/1280.mp4'),
        isNull,
      );
    });

    test('builds an i/status permalink', () {
      expect(
        XDownloadUrl.permalinkForTweetId('1891234567890123456'),
        'https://x.com/i/status/1891234567890123456',
      );
    });
  });

  group('XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle', () {
    test('detects CDN media-key titles from the library screenshot', () {
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('Yepv3EA8BmQPAOpZ'),
        isTrue,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('Wayxcx6DlSTApF95'),
        isTrue,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('zmCsesatOV DAcsc'),
        isTrue,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('q0cAPJC5cWih8eGW'),
        isTrue,
      );
    });

    test('rejects real human titles', () {
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('My cool video'),
        isFalse,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('Hello World'),
        isFalse,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle('毎日おかず投稿'),
        isFalse,
      );
    });

    test('rejects already-usable Twitter fallback titles', () {
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle(
          'Tweet 1891234567890123456',
        ),
        isFalse,
      );
      expect(
        XLibraryTitleRepair.looksLikeOpaqueMediaKeyTitle(
          'alice - 1891234567890123456',
        ),
        isFalse,
      );
    });
  });

  group('XLibraryTitleRepair.needsRepair', () {
    test(
      'repairs completed X items with opaque titles when a status URL exists',
      () {
        final item = _item(
          url: 'https://x.com/alice/status/1891234567890123456',
          title: 'Wayxcx6DISTAPf95',
        );
        expect(XLibraryTitleRepair.needsRepair(item), isTrue);
        expect(
          XLibraryTitleRepair.tweetIdFromItem(item),
          '1891234567890123456',
        );
      },
    );

    test('does not invent a status URL from an amplify media URL', () {
      final item = _item(
        url:
            'https://video.twimg.com/amplify_video/1891234567890123456/vid/avc1/720x1280/Wayxcx6DISTAPf95.mp4',
        title: 'Wayxcx6DISTAPf95',
      );
      expect(XLibraryTitleRepair.tweetIdFromItem(item), isNull);
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
    });

    test('repairs generic Twitter Video titles when a tweet id exists', () {
      final item = _item(
        url: 'https://x.com/alice/status/1891234567890123456',
        title: 'Twitter Video',
      );
      expect(XLibraryTitleRepair.needsRepair(item), isTrue);
    });

    test('does not infer a tweet id from a rewritten media thumbnail URL', () {
      final item = _item(
        url: 'https://twitter.detected/imported',
        title: 'Yepv3EA8BmQPAOpZ',
        thumbnailUrl:
            'https://pbs.twimg.com/ext_tw_video_thumb/1891234567890123456/pu/img/abc.jpg',
      );
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
      expect(XLibraryTitleRepair.tweetIdFromItem(item), isNull);
    });

    test('skips in-flight downloads', () {
      final item = _item(
        url: 'https://x.com/alice/status/1891234567890123456',
        title: 'Wayxcx6DISTAPf95',
        status: DownloadStatus.extracting,
      );
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
    });

    test('skips real titles even when a tweet id is known', () {
      final item = _item(
        url: 'https://x.com/alice/status/1891234567890123456',
        title: 'A real tweet about cats',
      );
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
    });

    test('skips tweet_video CDN items with no recoverable tweet id', () {
      final item = _item(
        url: 'https://video.twimg.com/tweet_video/Wayxcx6DISTAPf95.mp4',
        title: 'Wayxcx6DISTAPf95',
        filePath: r'C:\Videos\Wayxcx6DISTAPf95.mp4',
      );
      expect(XLibraryTitleRepair.tweetIdFromItem(item), isNull);
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
    });

    test('skips YouTube items with short alphanumeric titles', () {
      final item = _item(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'dQw4w9WgXcQ',
      );
      expect(XLibraryTitleRepair.needsRepair(item), isFalse);
    });
  });

  group('XTweetDisplayTitle.fromMetadata', () {
    test('prefers the tweet text when it is usable', () {
      expect(
        XTweetDisplayTitle.fromMetadata(<String, dynamic>{
          'title': 'Hello from the timeline',
          'id': '1891234567890123456',
          'uploader': 'alice',
        }, tweetId: '1891234567890123456'),
        'Hello from the timeline',
      );
    });

    test('falls back to uploader and id when title is useless', () {
      expect(
        XTweetDisplayTitle.fromMetadata(<String, dynamic>{
          'title': '1891234567890123456',
          'id': '1891234567890123456',
          'uploader': 'alice',
        }, tweetId: '1891234567890123456'),
        'alice - 1891234567890123456',
      );
    });

    test('falls back to Tweet id when uploader is missing', () {
      expect(
        XTweetDisplayTitle.fromMetadata(<String, dynamic>{
          'title': 'https://t.co/abc',
          'id': '1891234567890123456',
        }, tweetId: '1891234567890123456'),
        'Tweet 1891234567890123456',
      );
    });

    test('does not treat a generic fallback as real tweet text', () {
      expect(
        XTweetDisplayTitle.hasUsableTweetText(<String, dynamic>{
          'title': 'Twitter Video',
          'id': '1891234567890123456',
          'uploader': 'alice',
        }, tweetId: '1891234567890123456'),
        isFalse,
      );
      expect(
        XTweetDisplayTitle.hasUsableTweetText(<String, dynamic>{
          'title': 'Hello from the timeline',
          'id': '1891234567890123456',
        }, tweetId: '1891234567890123456'),
        isTrue,
      );
    });
  });

  group('XLibraryTitleRepair.renameVideoFile', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('md_x_rename_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('renames an opaque file to stem plus tweet id', () async {
      final source = File(
        '${dir.path}${Platform.pathSeparator}Wayxcx6DISTAPf95.mp4',
      );
      await source.writeAsBytes(const [1, 2, 3, 4]);

      final renamed = await XLibraryTitleRepair.renameVideoFile(
        currentPath: source.path,
        title: 'Hello from the timeline',
        tweetId: '1891234567890123456',
      );

      expect(renamed, isNotNull);
      expect(
        renamed,
        endsWith('Hello from the timeline [1891234567890123456].mp4'),
      );
      expect(File(renamed!).existsSync(), isTrue);
      expect(source.existsSync(), isFalse);
    });

    test('keeps the current path when destination already exists', () async {
      final source = File(
        '${dir.path}${Platform.pathSeparator}Wayxcx6DISTAPf95.mp4',
      );
      await source.writeAsBytes(const [1, 2, 3, 4]);
      final dest = File(
        '${dir.path}${Platform.pathSeparator}Hello [1891234567890123456].mp4',
      );
      await dest.writeAsBytes(const [9, 9, 9]);

      final renamed = await XLibraryTitleRepair.renameVideoFile(
        currentPath: source.path,
        title: 'Hello',
        tweetId: '1891234567890123456',
      );

      expect(renamed, isNull);
      expect(source.existsSync(), isTrue);
      expect(dest.existsSync(), isTrue);
    });
  });
}
