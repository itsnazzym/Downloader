import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/x_download_url.dart';

void main() {
  group('XDownloadUrl.canonicalize', () {
    test('rewrites a twimg CDN URL to the tweet permalink from pageUrl', () {
      expect(
        XDownloadUrl.canonicalize(
          'https://video.twimg.com/tweet_video/Wayxcx6DISTAPf95.mp4',
          'https://x.com/alice/status/111',
        ),
        'https://x.com/alice/status/111',
      );
    });

    test('keeps an existing status URL even when pageUrl is the home feed', () {
      expect(
        XDownloadUrl.canonicalize(
          'https://x.com/alice/status/111',
          'https://x.com/home',
        ),
        'https://x.com/alice/status/111',
      );
    });

    test('does not replace a media URL with x.com/home', () {
      const cdn = 'https://video.twimg.com/ext_tw_video/111.mp4';
      expect(XDownloadUrl.canonicalize(cdn, 'https://x.com/home'), cdn);
      expect(XDownloadUrl.canonicalize(cdn, 'https://x.com/home?lang=en'), cdn);
    });

    test(
      'treats twitter.com and x.com status URLs as equivalent permalinks',
      () {
        const cdn = 'https://video.twimg.com/ext_tw_video/111.mp4';
        expect(
          XDownloadUrl.canonicalize(
            cdn,
            'https://twitter.com/alice/status/111',
          ),
          'https://twitter.com/alice/status/111',
        );
        expect(
          XDownloadUrl.canonicalize(
            'https://twitter.com/alice/status/111',
            'https://x.com/home',
          ),
          'https://twitter.com/alice/status/111',
        );
        expect(
          XDownloadUrl.canonicalize(
            'https://x.com/alice/status/111',
            'https://twitter.com/home',
          ),
          'https://x.com/alice/status/111',
        );
      },
    );
  });

  group('XDownloadUrl.resolveForDownload', () {
    const amplify =
        'https://video.twimg.com/amplify_video/2078792104579330048/vid/avc1/640x476/OsNdAqqNEyleFpEm.mp4?tag=14';

    test('rejects a CDN URL when pageUrl is the home feed', () {
      expect(
        XDownloadUrl.resolveForDownload(amplify, 'https://x.com/home'),
        isNull,
      );
      expect(
        XDownloadUrl.resolveForDownload(amplify, 'https://x.com/home?lang=en'),
        isNull,
      );
      expect(XDownloadUrl.resolveForDownload(amplify), isNull);
    });

    test('rewrites a CDN URL when pageUrl is a status permalink', () {
      expect(
        XDownloadUrl.resolveForDownload(
          amplify,
          'https://x.com/alice/status/1112223334445556667',
        ),
        'https://x.com/alice/status/1112223334445556667',
      );
    });

    test('keeps an existing status permalink', () {
      expect(
        XDownloadUrl.resolveForDownload(
          'https://x.com/alice/status/1112223334445556667?s=20',
          'https://x.com/home',
        ),
        'https://x.com/alice/status/1112223334445556667',
      );
    });

    test('passes non-X URLs through unchanged', () {
      const youtube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(XDownloadUrl.resolveForDownload(youtube), youtube);
      expect(
        XDownloadUrl.resolveForDownload(youtube, 'https://x.com/home'),
        youtube,
      );
    });
  });

  group('XDownloadUrl.mediaAssetIdFrom', () {
    test('reads ext_tw_video and matching thumb ids', () {
      expect(
        XDownloadUrl.mediaAssetIdFrom(
          'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/avc1/720x1280/abc.mp4',
        ),
        '1891234567890123456',
      );
      expect(
        XDownloadUrl.mediaAssetIdFrom(
          'https://pbs.twimg.com/ext_tw_video_thumb/1891234567890123456/pu/img/abc.jpg',
        ),
        '1891234567890123456',
      );
    });

    test('reads amplify_video ids', () {
      expect(
        XDownloadUrl.mediaAssetIdFrom(
          'https://video.twimg.com/amplify_video/2078792104579330048/vid/avc1/640x476/OsNdAqqNEyleFpEm.mp4?tag=14',
        ),
        '2078792104579330048',
      );
    });

    test('does not treat a status permalink as a media asset id', () {
      expect(
        XDownloadUrl.mediaAssetIdFrom(
          'https://x.com/alice/status/1112223334445556667',
        ),
        isNull,
      );
      expect(
        XDownloadUrl.tweetIdFrom(
          'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/avc1/720x1280/abc.mp4',
        ),
        isNull,
      );
    });
  });
}
