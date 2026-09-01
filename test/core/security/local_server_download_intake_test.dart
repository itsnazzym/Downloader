import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/security/local_server_download_intake.dart';

void main() {
  group('LocalServerDownloadIntake.parse', () {
    test('accepts http(s) video URLs', () {
      final result = LocalServerDownloadIntake.parse({
        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'isAudioOnly': true,
        'isPlaylist': false,
        'preferredQuality': '1080',
      });

      expect(result.isOk, isTrue);
      expect(result.errorCode, isNull);
      expect(result.ingest?.url, contains('youtube.com'));
      expect(result.ingest?.isAudioOnly, isTrue);
      expect(result.ingest?.preferredQuality, '1080');
    });

    test('rejects missing or empty url', () {
      expect(LocalServerDownloadIntake.parse({}).errorCode, 'invalid_url');
      expect(
        LocalServerDownloadIntake.parse({'url': ''}).errorCode,
        'invalid_url',
      );
    });

    test('rejects non-http schemes', () {
      expect(
        LocalServerDownloadIntake.parse({
          'url': 'file:///C:/secret.mp4',
        }).errorCode,
        'invalid_url',
      );
      expect(
        LocalServerDownloadIntake.parse({
          'url': 'javascript:alert(1)',
        }).errorCode,
        'invalid_url',
      );
    });

    test('rejects X CDN URLs without a tweet permalink', () {
      final result = LocalServerDownloadIntake.parse({
        'url':
            'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/720x1280/x.mp4',
      });
      expect(result.errorCode, 'need_tweet_url');
      expect(result.isOk, isFalse);
    });

    test('rejects unsupported external URLs such as Discord invites', () {
      final result = LocalServerDownloadIntake.parse({
        'url': 'https://discord.com/invite/JoinForbidden',
      });
      expect(result.errorCode, 'unsupported_url');
      expect(result.isOk, isFalse);
    });
  });
}
