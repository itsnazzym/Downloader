import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:modern_downloader/features/downloader/domain/exceptions/yt_dlp_exception.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';

class _FakeBinaryLocator extends BinaryLocator {
  @override
  Future<String?> findYtDlp() async => 'yt-dlp';
}

class _FakeProcessRunner extends ProcessRunner {
  _FakeProcessRunner(this.stdout);

  final String stdout;
  List<String>? lastArguments;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    lastArguments = arguments;
    return ProcessResult(1, 0, stdout, '');
  }
}

void main() {
  setUp(YtDlpSource.metadataProbeLimiter.reset);

  test('fetchMetadata accepts one JSON object per media entry', () async {
    final source = YtDlpSource(
      _FakeBinaryLocator(),
      _FakeProcessRunner(
        '{"id":"1891234567890123456","title":"Tweet text","uploader":"alice"}\n'
        '{"id":"1891234567890123457","title":"Tweet text","uploader":"alice"}',
      ),
    );

    final metadata = await source.fetchMetadata(
      'https://x.com/i/status/1891234567890123456',
    );

    expect(metadata['id'], '1891234567890123456');
    expect(metadata['title'], 'Tweet text');
  });

  test(
    'fetchMetadata repairs a TikTok export URL before invoking yt-dlp',
    () async {
      final runner = _FakeProcessRunner(
        '{"id":"761543876078210326","title":"TikTok video"}',
      );
      final source = YtDlpSource(_FakeBinaryLocator(), runner);

      await source.fetchMetadata(
        'https://www.tiktok.com/video/761543876078210326',
      );

      expect(
        runner.lastArguments?.last,
        'https://www.tiktokv.com/share/video/761543876078210326/',
      );
    },
  );

  test('fromLog detects XHamster impersonation and no formats found error', () {
    const errorLog = '''
WARNING: [XHamster] The extractor is attempting impersonation, but no impersonate target is available. If you encounter errors, then see https://github.com/yt-dlp/yt-dlp#impersonation for information on installing the required dependencies
ERROR: [XHamster] Ep7t8d4tldfnKXVO9: No video formats found!; please report this issue on https://github.com/yt-dlp/yt-dlp/issues?q= , filling out the appropriate issue template. Confirm you are on the latest version using yt-dlp -U
''';
    final ex = YtDlpException.fromLog(errorLog);
    expect(ex, isA<NoVideoFormatsException>());
    expect(ex?.message, contains('Aucun format vidéo'));
  });
}
