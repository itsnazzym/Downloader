import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/yt_dlp_cookie_args.dart';

void main() {
  group('YtDlpCookieArgs', () {
    test('prefers cookies file over raw cookies and browser', () {
      expect(
        YtDlpCookieArgs.build(
          cookiesFilePath: r'C:\temp\cookies.txt',
          rawCookies: 'a=b; c=d',
          cookieBrowser: 'chrome',
        ),
        ['--cookies', r'C:\temp\cookies.txt'],
      );
    });

    test('does not put Netscape body into Cookie header', () {
      const netscape =
          '# Netscape HTTP Cookie File\n.x.com\tTRUE\t/\tTRUE\t0\tauth\ttoken\n';
      expect(YtDlpCookieArgs.isNetscapeFormat(netscape), isTrue);
      expect(
        YtDlpCookieArgs.build(rawCookies: netscape, cookieBrowser: 'chrome'),
        isEmpty,
      );
    });

    test('uses Cookie header for header-style cookies', () {
      expect(YtDlpCookieArgs.build(rawCookies: 'auth_token=abc; ct0=xyz'), [
        '--add-header',
        'Cookie:auth_token=abc; ct0=xyz',
      ]);
    });

    test('falls back to cookies-from-browser when no cookies provided', () {
      expect(YtDlpCookieArgs.build(cookieBrowser: 'edge'), [
        '--cookies-from-browser',
        'edge',
      ]);
    });

    test('usesCookiesFile detects file and Netscape', () {
      expect(
        YtDlpCookieArgs.usesCookiesFile(cookiesFilePath: '/tmp/c.txt'),
        isTrue,
      );
      expect(YtDlpCookieArgs.usesCookiesFile(rawCookies: 'a\tb\tc'), isTrue);
      expect(YtDlpCookieArgs.usesCookiesFile(rawCookies: 'a=b'), isFalse);
    });

    test(
      'resolveCookiesFilePath prefers host-specific over global YouTube file',
      () {
        const twitterHeartbeat = r'C:\Temp\heartbeat_cookies_twitter.com.txt';
        const youtubeGlobal = r'C:\Temp\heartbeat_cookies_youtube.com.txt';

        expect(
          YtDlpCookieArgs.resolveCookiesFilePath(
            urlSpecificPath: twitterHeartbeat,
            globalPath: youtubeGlobal,
          ),
          twitterHeartbeat,
        );
        expect(
          YtDlpCookieArgs.build(
            cookiesFilePath: YtDlpCookieArgs.resolveCookiesFilePath(
              urlSpecificPath: twitterHeartbeat,
              globalPath: youtubeGlobal,
            ),
          ),
          ['--cookies', twitterHeartbeat],
        );
      },
    );

    test('resolveCookiesFilePath falls back to global when no host file', () {
      const youtubeGlobal = r'C:\Temp\heartbeat_cookies_youtube.com.txt';
      expect(
        YtDlpCookieArgs.resolveCookiesFilePath(
          urlSpecificPath: null,
          globalPath: youtubeGlobal,
        ),
        youtubeGlobal,
      );
    });
  });
}
