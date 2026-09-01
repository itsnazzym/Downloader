import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/platform/android_ytdlp_args.dart';

void main() {
  group('AndroidYtDlpArgs.sanitize', () {
    test('rewrites aria2c downloader to the Android shared library', () {
      expect(
        AndroidYtDlpArgs.sanitize([
          '--downloader',
          'aria2c',
          '--no-playlist',
          'https://example.com/watch',
        ]),
        [
          '--downloader',
          'libaria2c.so',
          '--no-playlist',
          'https://example.com/watch',
        ],
      );
    });

    test('drops desktop --cookies-from-browser', () {
      expect(
        AndroidYtDlpArgs.sanitize([
          '--cookies-from-browser',
          'firefox',
          '--no-warnings',
          'https://x.com/a/status/1',
        ]),
        ['--no-warnings', 'https://x.com/a/status/1'],
      );
    });

    test('keeps cookies file arguments', () {
      expect(
        AndroidYtDlpArgs.sanitize([
          '--cookies',
          '/tmp/cookies.txt',
          'https://youtube.com/watch?v=1',
        ]),
        ['--cookies', '/tmp/cookies.txt', 'https://youtube.com/watch?v=1'],
      );
    });
  });
}
