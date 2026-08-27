import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/cookie_browser_args.dart';

void main() {
  group('CookieBrowserArgs', () {
    test('uses the requested browser when provided', () {
      expect(CookieBrowserArgs.resolve('chrome'), 'chrome');
      expect(CookieBrowserArgs.ytDlpArgs('edge'), [
        '--cookies-from-browser',
        'edge',
      ]);
    });

    test('falls back to firefox when browser is missing or auto', () {
      expect(CookieBrowserArgs.resolve(null), 'firefox');
      expect(CookieBrowserArgs.resolve(''), 'firefox');
      expect(CookieBrowserArgs.resolve('auto'), 'firefox');
    });
  });
}
