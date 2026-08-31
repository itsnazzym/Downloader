import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';

class _FakeBinaryLocator extends BinaryLocator {
  @override
  Future<String?> findYtDlp() async => 'yt-dlp';
}

class _FakeProcessRunner extends ProcessRunner {
  _FakeProcessRunner(this.stdout);

  final String stdout;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
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
}
