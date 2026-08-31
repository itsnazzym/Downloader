import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/x_feed/gobird_x_feed_service.dart';
import 'package:modern_downloader/features/x_feed/x_feed_cookie_credentials.dart';
import 'package:modern_downloader/features/x_feed/x_feed_ws_contract.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';

class _FakeLocator extends BinaryLocator {
  _FakeLocator(this.path);
  final String? path;

  @override
  Future<String?> findGobird({bool allowPathProbe = false}) async => path;

  @override
  Future<String?> ensureGobirdStaged() async => path;
}

void main() {
  group('GobirdXFeedService.buildHomeArgs', () {
    test('builds allowlisted chrome command', () {
      expect(
        GobirdXFeedService.buildHomeArgs(browser: 'chrome', count: 50),
        <String>[
          '--browser',
          'chrome',
          '--json',
          '--quiet',
          '--count',
          '50',
          '--max-pages',
          '500',
          'home',
        ],
      );
    });

    test('clamps count to 1..10000', () {
      expect(
        GobirdXFeedService.buildHomeArgs(
          browser: 'firefox',
          count: 0,
        ).contains('1'),
        isTrue,
      );
      final high = GobirdXFeedService.buildHomeArgs(
        browser: 'firefox',
        count: 99999,
      );
      final countIndex = high.indexOf('--count');
      expect(countIndex, greaterThanOrEqualTo(0));
      expect(high[countIndex + 1], '10000');
      expect(high.contains('99999'), isFalse);
    });

    test('keeps tweet budget 10000 and max-pages 500 on the allowlist', () {
      expect(GobirdXFeedService.defaultTimeout, const Duration(minutes: 12));
      final args = GobirdXFeedService.buildHomeArgs(
        browser: 'chrome',
        count: 10000,
      );
      expect(args[args.indexOf('--count') + 1], '10000');
      expect(args[args.indexOf('--max-pages') + 1], '500');
    });

    test('rejects non-allowlisted browser', () {
      expect(
        () => GobirdXFeedService.buildHomeArgs(browser: 'edge', count: 10),
        throwsArgumentError,
      );
    });

    test('builds the environment-credential command without browser flags', () {
      expect(
        GobirdXFeedService.buildHomeArgsFromEnvironment(count: 25),
        <String>[
          '--json',
          '--quiet',
          '--count',
          '25',
          '--max-pages',
          '500',
          'home',
        ],
      );
    });
  });

  group('XFeedCookieCredentials', () {
    test('extracts auth_token and ct0 from X Netscape cookies', () {
      final authToken = List<String>.filled(40, 'a').join();
      final ct0 = List<String>.filled(32, 'b').join();
      final contents =
          '''
# Netscape HTTP Cookie File
.x.com\tTRUE\t/\tTRUE\t1893456000\tauth_token\t$authToken
.x.com\tTRUE\t/\tTRUE\t1893456000\tct0\t$ct0
''';

      final credentials = XFeedCookieCredentials.parseNetscapeCookies(contents);

      expect(credentials, isNotNull);
      expect(credentials!.authToken, authToken);
      expect(credentials.ct0, ct0);
    });

    test('accepts a 160-character alphanumeric ct0', () {
      final authToken = List<String>.filled(40, 'c').join();
      final ct0 = List<String>.filled(160, 'd').join();
      final contents =
          '''
.x.com\tTRUE\t/\tTRUE\t1893456000\tauth_token\t$authToken
.x.com\tTRUE\t/\tTRUE\t1893456000\tct0\t$ct0
''';

      final credentials = XFeedCookieCredentials.parseNetscapeCookies(contents);
      expect(credentials, isNotNull);
      expect(credentials!.ct0.length, 160);
    });

    test('rejects gobird-incompatible auth_token length', () {
      final contents =
          '''
.x.com\tTRUE\t/\tTRUE\t1893456000\tauth_token\tshorttokenvalue
.x.com\tTRUE\t/\tTRUE\t1893456000\tct0\t${List<String>.filled(32, 'b').join()}
''';
      expect(XFeedCookieCredentials.parseNetscapeCookies(contents), isNull);
    });

    test('ignores credentials from unrelated domains', () {
      final authToken = List<String>.filled(40, 'a').join();
      final ct0 = List<String>.filled(32, 'b').join();
      final contents =
          '''
.example.com\tTRUE\t/\tTRUE\t1893456000\tauth_token\t$authToken
.example.com\tTRUE\t/\tTRUE\t1893456000\tct0\t$ct0
''';

      expect(XFeedCookieCredentials.parseNetscapeCookies(contents), isNull);
    });
  });

  group('GobirdXFeedService.parseGobirdHomeJson', () {
    test('filters video media and builds tweet URLs', () {
      final raw = jsonEncode([
        {
          'id': '111',
          'text': 'Hello video',
          'author': {'username': 'alice', 'name': 'Alice'},
          'media': [
            {'type': 'photo', 'url': 'https://pbs.twimg.com/media/photo.jpg'},
            {
              'type': 'video',
              'url': 'https://x.com/i/status/111',
              'videoUrl': 'https://video.twimg.com/ext_tw_video/111.mp4',
              'previewUrl': 'https://pbs.twimg.com/ext_tw_video_thumb/111.jpg',
              'width': 1280,
              'height': 720,
              'durationMs': 12500,
            },
          ],
        },
        {
          'id': '222',
          'text': 'No video',
          'author': {'username': 'bob', 'name': 'Bob'},
          'media': [
            {'type': 'photo', 'url': 'https://pbs.twimg.com/media/x.jpg'},
          ],
        },
      ]);

      final parsed = GobirdXFeedService.parseGobirdHomeJson(raw);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.first.id, '111');
      expect(parsed.items.first.url, 'https://x.com/alice/status/111');
      expect(parsed.items.first.pageUrl, 'https://x.com/alice/status/111');
      expect(parsed.items.first.author, 'Alice');
      expect(parsed.items.first.durationSeconds, closeTo(12.5, 0.01));
      expect(parsed.items.first.width, 1280);
      expect(parsed.items.first.height, 720);
      expect(parsed.items.first.sizeBytes, isNull);
      expect(parsed.truncated, isFalse);
    });

    test('rejects non-http media URLs', () {
      final raw = jsonEncode([
        {
          'id': '333',
          'text': 'bad',
          'author': {'username': 'x', 'name': 'X'},
          'media': [
            {'type': 'video', 'videoUrl': 'file:///tmp/video.mp4'},
          ],
        },
      ]);
      final parsed = GobirdXFeedService.parseGobirdHomeJson(raw);
      expect(parsed.items, isEmpty);
    });

    test('honors hard video item limit', () {
      final tweets = List<Map<String, dynamic>>.generate(5200, (i) {
        return {
          'id': '$i',
          'text': 'v$i',
          'author': {'username': 'u$i', 'name': 'U$i'},
          'media': [
            {'type': 'video', 'videoUrl': 'https://video.twimg.com/$i.mp4'},
          ],
        };
      });
      final parsed = GobirdXFeedService.parseGobirdHomeJson(
        jsonEncode(tweets),
        maxItems: 5000,
      );
      expect(parsed.items, hasLength(5000));
      expect(parsed.truncated, isTrue);
    });

    test('does not truncate when video count is at the cap', () {
      final tweets = List<Map<String, dynamic>>.generate(
        GobirdXFeedService.maxVideoItems,
        (i) {
          return {
            'id': '$i',
            'text': 'v$i',
            'author': {'username': 'u$i', 'name': 'U$i'},
            'media': [
              {'type': 'video', 'videoUrl': 'https://video.twimg.com/$i.mp4'},
            ],
          };
        },
      );
      final parsed = GobirdXFeedService.parseGobirdHomeJson(jsonEncode(tweets));
      expect(parsed.items, hasLength(GobirdXFeedService.maxVideoItems));
      expect(parsed.truncated, isFalse);
    });
  });

  group('GobirdXFeedService.fetchHomeFeed', () {
    test('returns missingBinary when locator finds nothing', () async {
      final service = GobirdXFeedService(
        locator: _FakeLocator(null),
        runProcess: (exe, args) async => ProcessResult(0, 0, '[]', ''),
      );
      final result = await service.fetchHomeFeed(browser: 'chrome');
      expect(result.ok, isFalse);
      expect(result.errorCode, 'missingBinary');
    });

    test('maps auth exit code 3', () async {
      final service = GobirdXFeedService(
        locator: _FakeLocator('gobird.exe'),
        resolveCredentials: (_) async => null,
        useBrowserCookieFallback: true,
        runProcess: (exe, args) async {
          expect(args, containsAll(<String>['--json', '--quiet', 'home']));
          return ProcessResult(1, 3, '', 'unauthorized');
        },
      );
      final result = await service.fetchHomeFeed(browser: 'firefox', count: 10);
      expect(result.ok, isFalse);
      expect(result.errorCode, 'auth');
    });

    test('parses successful stdout JSON', () async {
      final payload = jsonEncode([
        {
          'id': '42',
          'text': 'ok',
          'author': {'username': 'gopher', 'name': 'Gopher'},
          'media': [
            {
              'type': 'video',
              'videoUrl': 'https://video.twimg.com/42.mp4',
              'previewUrl': 'https://pbs.twimg.com/42.jpg',
            },
          ],
        },
      ]);
      String? probedUrl;
      final service = GobirdXFeedService(
        locator: _FakeLocator('gobird.exe'),
        resolveCredentials: (_) async => null,
        useBrowserCookieFallback: true,
        runProcess: (exe, args) async => ProcessResult(1, 0, payload, ''),
        contentLengthProbe: (url) async {
          probedUrl = url;
          return 4096;
        },
      );
      final result = await service.fetchHomeFeed(
        browser: 'chrome',
        count: 5,
        probeContentLength: true,
      );
      expect(result.ok, isTrue);
      expect(result.items, hasLength(1));
      expect(probedUrl, 'https://video.twimg.com/42.mp4');
      expect(result.items.first.url, 'https://x.com/gopher/status/42');
      expect(result.items.first.sizeBytes, 4096);
    });

    test(
      'passes extension credentials through the process environment',
      () async {
        final authToken = List<String>.filled(40, 'a').join();
        final ct0 = List<String>.filled(32, 'b').join();
        Map<String, String>? receivedEnvironment;
        final service = GobirdXFeedService(
          locator: _FakeLocator('gobird.exe'),
          resolveCredentials: (_) async =>
              XFeedCredentials(authToken: authToken, ct0: ct0),
          runProcessWithEnvironment: (exe, args, environment) async {
            receivedEnvironment = environment;
            expect(args, isNot(contains('--browser')));
            return ProcessResult(1, 0, '[]', '');
          },
        );

        final result = await service.fetchHomeFeed(
          browser: 'chrome',
          count: 10,
        );

        expect(result.ok, isTrue);
        expect(receivedEnvironment?['AUTH_TOKEN'], authToken);
        expect(receivedEnvironment?['CT0'], ct0);
        expect(receivedEnvironment?.containsKey('PATH'), isFalse);
      },
    );

    test(
      'skips broken Windows browser fallback when cookies are missing',
      () async {
        var ranProcess = false;
        final service = GobirdXFeedService(
          locator: _FakeLocator('gobird.exe'),
          resolveCredentials: (_) async => null,
          useBrowserCookieFallback: false,
          runProcess: (exe, args) async {
            ranProcess = true;
            return ProcessResult(1, 0, '[]', '');
          },
        );

        final result = await service.fetchHomeFeed(
          browser: 'firefox',
          count: 10,
        );
        expect(ranProcess, isFalse);
        expect(result.ok, isFalse);
        expect(result.errorCode, 'auth');
      },
    );
  });

  group('XFeedWsContract', () {
    test('rejects cookie fields', () {
      expect(XFeedWsContract.containsCookieFields({'cookies': 'x'}), isTrue);
      expect(
        XFeedWsContract.containsCookieFields({'count': 10, 'requestId': 'a'}),
        isFalse,
      );
    });

    test('normalizes count ceiling to tweet budget', () {
      expect(XFeedWsContract.normalizeCount(0), 1);
      expect(XFeedWsContract.normalizeCount(250), 250);
      expect(XFeedWsContract.normalizeCount(9999), 9999);
      expect(XFeedWsContract.normalizeCount(10000), 10000);
      expect(XFeedWsContract.normalizeCount(99999), 10000);
      expect(XFeedWsContract.normalizeCount('25'), 25);
    });
  });
}
