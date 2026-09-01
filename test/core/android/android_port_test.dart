import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/android/netscape_cookie_codec.dart';
import 'package:modern_downloader/core/android/overlay_download_message.dart';
import 'package:modern_downloader/core/download/download_path_resolver.dart';
import 'package:modern_downloader/core/download/yt_dlp_cookie_args.dart';
import 'package:modern_downloader/core/setup/dependency_catalog.dart';

void main() {
  group('OverlayDownloadMessage', () {
    test('parses a DOWNLOAD_BTN_CLICK payload', () {
      final parsed = OverlayDownloadMessage.tryParse({
        'type': 'DOWNLOAD_BTN_CLICK',
        'id': 'md1',
        'url': 'https://x.com/a/status/1',
        'pageUrl': 'https://x.com/home',
        'options': {'isAudioOnly': true, 'preferredQuality': '720p'},
        'tweetId': '1',
      });
      expect(parsed, isNotNull);
      expect(parsed!.url, 'https://x.com/a/status/1');
      expect(parsed.isAudioOnly, isTrue);
      expect(parsed.preferredQuality, '720p');
      expect(parsed.tweetId, '1');
      expect(parsed.id, 'md1');
    });

    test('rejects missing url', () {
      expect(
        OverlayDownloadMessage.tryParse({'type': 'DOWNLOAD_BTN_CLICK'}),
        isNull,
      );
    });
  });

  group('NetscapeCookieCodec', () {
    test('encodes a Cookie header to Netscape rows', () {
      final body = NetscapeCookieCodec.fromHeader(
        host: 'x.com',
        header: 'auth_token=abc; ct0=xyz',
      );
      expect(body, contains('# Netscape HTTP Cookie File'));
      expect(body, contains('.x.com\tTRUE\t/\tTRUE\t0\tauth_token\tabc'));
      expect(body, contains('.x.com\tTRUE\t/\tTRUE\t0\tct0\txyz'));
    });
  });

  group('DownloadPathResolver Android fallback', () {
    test('uses fallbackFolder when no Windows profile is present', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '',
          itemFolders: const [],
          userProfile: null,
          fallbackFolder: '/storage/emulated/0/Download/ModernDownloader',
        ),
        '/storage/emulated/0/Download/ModernDownloader',
      );
    });
  });

  group('YtDlpCookieArgs Android', () {
    test('skips cookies-from-browser when allowBrowserCookies is false', () {
      expect(
        YtDlpCookieArgs.build(
          cookieBrowser: 'chrome',
          allowBrowserCookies: false,
        ),
        isEmpty,
      );
    });
  });

  group('DependencyCatalog Android', () {
    test('lists native yt-dlp ffmpeg and aria2c packages', () {
      final ids = DependencyCatalog.androidRequired.map((pkg) => pkg.id);
      expect(ids, containsAll(['yt-dlp', 'ffmpeg', 'aria2c']));
      expect(
        DependencyCatalog.androidRequired.every(
          (pkg) => pkg.kind == DependencyKind.nativeBundle,
        ),
        isTrue,
      );
    });
  });
}
