import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/download/yt_dlp_cookie_args.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';

class _Locator extends BinaryLocator {
  @override
  Future<String?> findYtDlp() async => 'yt-dlp';
}

/// First call fails like a locked / undecryptable browser profile.
class _CookieFailingRunner extends ProcessRunner {
  final calls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add(arguments);
    if (arguments.contains('--cookies-from-browser')) {
      return ProcessResult(
        1,
        1,
        '',
        'ERROR: Failed to decrypt with DPAPI. See  https://github.com/yt-dlp/yt-dlp/issues/10927  for more info',
      );
    }
    return ProcessResult(1, 0, '{"id":"abc","title":"Public video"}', '');
  }
}

void main() {
  setUp(YtDlpSource.metadataProbeLimiter.reset);

  group('YtDlpCookieArgs.isBrowserCookieError', () {
    test('detects browser cookie extraction failures', () {
      for (final log in [
        'ERROR: Failed to decrypt with DPAPI. See https://x',
        'ERROR: Could not copy Chrome cookie database. See https://x',
        'ERROR: could not find firefox cookies database in C:/x',
      ]) {
        expect(YtDlpCookieArgs.isBrowserCookieError(log), isTrue, reason: log);
      }
    });

    test('ignores unrelated errors', () {
      expect(
        YtDlpCookieArgs.isBrowserCookieError('ERROR: Video unavailable'),
        isFalse,
      );
      expect(YtDlpCookieArgs.isBrowserCookieError(''), isFalse);
    });
  });

  test(
    'fetchMetadata retries without browser cookies when they cannot be read',
    () async {
      final runner = _CookieFailingRunner();
      final source = YtDlpSource(_Locator(), runner);

      final metadata = await source.fetchMetadata(
        'https://www.youtube.com/watch?v=BaW_jenozKc',
        cookieBrowser: 'chrome',
      );

      expect(metadata['title'], 'Public video');
      expect(runner.calls, hasLength(2));
      expect(runner.calls.first, contains('--cookies-from-browser'));
      expect(runner.calls.last, isNot(contains('--cookies-from-browser')));
    },
    skip: Platform.isAndroid ? 'Android never uses browser cookies' : false,
  );
}
