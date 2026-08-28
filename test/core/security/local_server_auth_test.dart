import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/security/local_server_auth.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

void main() {
  group('LocalServerAuth.isAuthorized', () {
    test('rejects empty expected token', () {
      expect(
        LocalServerAuth.isAuthorized(
          expectedToken: '',
          providedToken: 'anything',
        ),
        isFalse,
      );
    });

    test('rejects missing provided token', () {
      expect(
        LocalServerAuth.isAuthorized(
          expectedToken: 'secret',
          providedToken: null,
        ),
        isFalse,
      );
    });

    test('rejects mismatched token', () {
      expect(
        LocalServerAuth.isAuthorized(
          expectedToken: 'secret',
          providedToken: 'other',
        ),
        isFalse,
      );
    });

    test('accepts exact match', () {
      expect(
        LocalServerAuth.isAuthorized(
          expectedToken: 'secret',
          providedToken: 'secret',
        ),
        isTrue,
      );
    });

    test('rejects different-length tokens', () {
      expect(
        LocalServerAuth.isAuthorized(
          expectedToken: 'secret',
          providedToken: 'secre',
        ),
        isFalse,
      );
    });
  });

  group('LocalServerAuth.tokenFromMessage', () {
    test('reads token string from payload', () {
      expect(LocalServerAuth.tokenFromMessage({'token': 'abc'}), 'abc');
    });

    test('returns null when token is absent or not a string', () {
      expect(LocalServerAuth.tokenFromMessage({}), isNull);
      expect(LocalServerAuth.tokenFromMessage({'token': 1}), isNull);
    });
  });

  group('LocalServerAuth.hostMatchesDomain', () {
    test('matches exact and subdomain hosts', () {
      expect(
        LocalServerAuth.hostMatchesDomain('youtube.com', 'youtube.com'),
        isTrue,
      );
      expect(
        LocalServerAuth.hostMatchesDomain('www.youtube.com', 'youtube.com'),
        isTrue,
      );
      expect(
        LocalServerAuth.hostMatchesDomain('m.youtube.com', 'youtube.com'),
        isTrue,
      );
    });

    test('rejects suffix spoofing', () {
      expect(
        LocalServerAuth.hostMatchesDomain(
          'youtube.com.evil.com',
          'youtube.com',
        ),
        isFalse,
      );
      expect(
        LocalServerAuth.hostMatchesDomain('notyoutube.com', 'youtube.com'),
        isFalse,
      );
    });
  });

  group('LocalServerAuth.sanitizeDomainForFilename', () {
    test('normalizes domain for filesystem use', () {
      expect(
        LocalServerAuth.sanitizeDomainForFilename('.YouTube.COM'),
        'youtube.com',
      );
      expect(LocalServerAuth.sanitizeDomainForFilename('a/b'), 'a_b');
    });
  });

  group('DownloadItem.toExtensionProgressJson', () {
    test('omits cookies and file paths', () {
      final item = DownloadItem(
        id: 'id-1',
        request: DownloadRequest(
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          rawCookies: 'SECRET_COOKIE_VALUE',
        ),
        status: DownloadStatus.downloading,
        progress: 0.42,
        speed: '1.2MiB/s',
        title: 'Demo',
        totalSize: '10MiB',
        filePath: 'C:/secret/path.mp4',
      );

      final json = item.toExtensionProgressJson();

      expect(json['id'], 'id-1');
      expect(json['title'], 'Demo');
      expect(json['status'], DownloadStatus.downloading.index);
      expect(json['progress'], 0.42);
      expect(json['speed'], '1.2MiB/s');
      expect(json['totalSize'], '10MiB');
      expect(json['url'], contains('youtube.com'));
      expect(json.containsKey('request'), isFalse);
      expect(json.containsKey('filePath'), isFalse);
      expect(json.containsKey('tweetId'), isFalse);
      expect(json.toString().contains('SECRET_COOKIE_VALUE'), isFalse);
      expect(json.toString().contains('C:/secret/path.mp4'), isFalse);
    });

    test('adds tweet and media ids without file paths', () {
      final item = DownloadItem(
        id: 'id-x',
        request: DownloadRequest(
          url: 'https://x.com/alice/status/1112223334445556667',
          forceStreamUrl:
              'https://video.twimg.com/ext_tw_video/1891234567890123456/pu/vid/720x1280/x.mp4',
        ),
        status: DownloadStatus.completed,
        filePath: r'C:\secret\clip.mp4',
      );

      final json = item.toExtensionProgressJson();
      expect(json['tweetId'], '1112223334445556667');
      expect(json['mediaId'], '1891234567890123456');
      expect(json.containsKey('filePath'), isFalse);
      expect(json.toString().contains(r'C:\secret'), isFalse);
    });

    test('full toJson still retains request for on-disk persistence', () {
      final item = DownloadItem(
        id: 'id-2',
        request: DownloadRequest(
          url: 'https://example.com/v',
          rawCookies: 'keep-me',
        ),
      );
      final full = item.toJson();
      expect(full['request'], isA<Map<String, dynamic>>());
      expect(
        (full['request'] as Map<String, dynamic>)['rawCookies'],
        'keep-me',
      );
    });
  });
}
