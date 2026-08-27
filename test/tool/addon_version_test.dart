import 'package:flutter_test/flutter_test.dart';

import '../../tool/addon_version.dart';

void main() {
  group('incrementAddonVersion', () {
    test('increments the last numeric segment', () {
      expect(incrementAddonVersion('2.1.0'), '2.1.1');
      expect(incrementAddonVersion('2.1.9'), '2.1.10');
    });

    test('rejects non-numeric versions', () {
      expect(() => incrementAddonVersion('2.1.0-beta'), throwsFormatException);
    });
  });

  group('replaceManifestVersion', () {
    test('replaces only the first version field', () {
      const source = '''
{
  "version": "2.1.0",
  "name": "Modern Downloader"
}
''';
      expect(
        replaceManifestVersion(source, '2.1.1'),
        contains('"version": "2.1.1"'),
      );
      expect(replaceManifestVersion(source, '2.1.1'), isNot(contains('2.1.0')));
    });
  });
}
