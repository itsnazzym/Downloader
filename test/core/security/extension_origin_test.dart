import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/security/extension_origin.dart';

void main() {
  group('ExtensionOrigin.isExtensionOrigin', () {
    test('accepts chrome-extension and moz-extension origins', () {
      expect(
        ExtensionOrigin.isExtensionOrigin(
          'chrome-extension://abcdefghijklmnopabcdefghijklmnop',
        ),
        isTrue,
      );
      expect(
        ExtensionOrigin.isExtensionOrigin(
          'moz-extension://9a8b7c6d-1111-2222-3333-444455556666',
        ),
        isTrue,
      );
    });

    test('rejects web pages and malformed origins', () {
      for (final origin in <String?>[
        'https://evil.example',
        'http://127.0.0.1',
        'null',
        '',
        null,
        'file://',
        'chrome-extension://',
        'chrome-extension://../x',
        'moz-extension://x y',
        'chrome-extension://abcdefghijklmnop/path',
        'chrome-extension://abcdefghijklmnop\n',
        'https://abcdefghijklmnop.chrome-extension://abcdefghijklmnop',
      ]) {
        expect(
          ExtensionOrigin.isExtensionOrigin(origin),
          isFalse,
          reason: '$origin',
        );
      }
    });
  });

  group('ExtensionOrigin.browserLabel', () {
    test('names the browser from the User-Agent', () {
      expect(
        ExtensionOrigin.browserLabel(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        ),
        'Chrome',
      );
      expect(
        ExtensionOrigin.browserLabel(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
        ),
        'Edge',
      );
      expect(
        ExtensionOrigin.browserLabel(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) '
          'Gecko/20100101 Firefox/128.0',
        ),
        'Firefox',
      );
      expect(
        ExtensionOrigin.browserLabel(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 OPR/112.0.0.0',
        ),
        'Opera',
      );
      expect(
        ExtensionOrigin.browserLabel(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Vivaldi/6.8',
        ),
        'Vivaldi',
      );
    });

    test('falls back to a generic label', () {
      expect(ExtensionOrigin.browserLabel(null), 'Navigateur');
      expect(ExtensionOrigin.browserLabel(''), 'Navigateur');
      expect(ExtensionOrigin.browserLabel('curl/8.0'), 'Navigateur');
    });
  });

  group('ExtensionOrigin.originScheme', () {
    test('logs a well-formed scheme only', () {
      expect(ExtensionOrigin.originScheme(null), 'none');
      expect(ExtensionOrigin.originScheme('https://evil.example'), 'https');
      expect(
        ExtensionOrigin.originScheme('chrome-extension://abcdefghijklmnop'),
        'chrome-extension',
      );
      expect(ExtensionOrigin.originScheme('null'), 'other');
      expect(ExtensionOrigin.originScheme(''), 'other');
      expect(ExtensionOrigin.originScheme('EVIL://x'), 'other');
      expect(ExtensionOrigin.originScheme('${'a' * 21}://x'), 'other');
      expect(ExtensionOrigin.originScheme('a b://x'), 'other');
    });
  });
}
