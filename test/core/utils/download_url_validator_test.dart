import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/utils/download_url_validator.dart';

void main() {
  group('DownloadUrlValidator.isValidHttpUrl', () {
    test('accepts http and https URLs with a host', () {
      expect(
        DownloadUrlValidator.isValidHttpUrl('https://youtube.com/watch?v=1'),
        isTrue,
      );
      expect(
        DownloadUrlValidator.isValidHttpUrl('http://example.com/a'),
        isTrue,
      );
    });

    test('rejects empty, missing host, and non-http schemes', () {
      expect(DownloadUrlValidator.isValidHttpUrl(''), isFalse);
      expect(DownloadUrlValidator.isValidHttpUrl('   '), isFalse);
      expect(DownloadUrlValidator.isValidHttpUrl('not a url'), isFalse);
      expect(
        DownloadUrlValidator.isValidHttpUrl('ftp://files.example'),
        isFalse,
      );
      expect(DownloadUrlValidator.isValidHttpUrl('https://'), isFalse);
    });
  });

  group('DownloadUrlValidator.isAcceptableDownloadUrl', () {
    test('accepts a tweet permalink and YouTube', () {
      expect(
        DownloadUrlValidator.isAcceptableDownloadUrl(
          'https://x.com/alice/status/1112223334445556667',
        ),
        isTrue,
      );
      expect(
        DownloadUrlValidator.isAcceptableDownloadUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        isTrue,
      );
    });

    test('rejects an X CDN media URL', () {
      expect(
        DownloadUrlValidator.isAcceptableDownloadUrl(
          'https://video.twimg.com/amplify_video/2078792104579330048/vid/avc1/640x476/OsNdAqqNEyleFpEm.mp4?tag=14',
        ),
        isFalse,
      );
    });
  });
}
