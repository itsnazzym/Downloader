import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';

void main() {
  group('TitleCleanerService.clean', () {
    test('strips t.co URLs before removing colon/slash', () {
      final cleaned = TitleCleanerService.clean('- https://t.co/CSJbBJRpXf');
      expect(cleaned, isNot(contains('httpst.co')));
      expect(cleaned, isNot(contains('https')));
      expect(cleaned, isNot(contains('t.co')));
    });

    test('strips already-collapsed httpst.co titles', () {
      final cleaned = TitleCleanerService.clean('- httpst.coCSJbBJRpXf');
      expect(cleaned, isEmpty);
    });

    test('preserves Japanese characters', () {
      const title = 'ものがたり。衝撃映像 関西弁';
      final cleaned = TitleCleanerService.clean(title);
      expect(cleaned, contains('ものがたり'));
      expect(cleaned, contains('衝撃映像'));
    });

    test('preserves bullet and at-sign', () {
      final cleaned = TitleCleanerService.clean('· Hello @user (NSFW)');
      expect(cleaned, contains('Hello'));
      expect(cleaned, contains('@user'));
      expect(cleaned, contains('NSFW'));
    });

    test('truncates long stems', () {
      final long = 'A' * 250;
      final cleaned = TitleCleanerService.clean(long);
      expect(
        cleaned.length,
        lessThanOrEqualTo(TitleCleanerService.maxStemLength),
      );
    });
  });

  group('TitleCleanerService.isUrlOnlyTitle', () {
    test('detects raw t.co title', () {
      expect(
        TitleCleanerService.isUrlOnlyTitle('- https://t.co/CSJbBJRpXf'),
        isTrue,
      );
    });

    test('detects collapsed httpst.co title', () {
      expect(
        TitleCleanerService.isUrlOnlyTitle('- httpst.coCSJbBJRpXf'),
        isTrue,
      );
    });

    test('rejects real titles', () {
      expect(TitleCleanerService.isUrlOnlyTitle('My cool video'), isFalse);
      expect(TitleCleanerService.isUrlOnlyTitle('毎日おかず投稿'), isFalse);
    });
  });

  group('TitleCleanerService.filenameStem', () {
    test('returns truncated clean stem', () {
      final stem = TitleCleanerService.filenameStem('https://t.co/abc');
      expect(stem, isNot(contains('http')));
    });
  });
}
