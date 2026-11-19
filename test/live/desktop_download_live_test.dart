@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/binary/binary_locator.dart';
import 'package:modern_downloader/core/services/binary/process_runner.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';

/// Public metadata probe (YouTube) and a small direct file (~800 KB) for the
/// real download path. yt-dlp's BaW_jenozKc test video is no longer served.
const _metaUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
const _url = 'https://www.w3schools.com/html/mov_bbb.mp4';

String _bin(String name) => '${Directory.current.path}${Platform.pathSeparator}'
    'bin${Platform.pathSeparator}$name.exe';

class _RepoBinLocator extends BinaryLocator {
  @override
  Future<String?> findYtDlp() async => _bin('yt-dlp');
  @override
  Future<String?> findFfmpeg() async => _bin('ffmpeg');
  @override
  Future<String?> findFfprobe() async => _bin('ffprobe');
  @override
  Future<String?> findAria2c() async => _bin('aria2c');
}

Future<bool> _online() async {
  try {
    final r = await InternetAddress.lookup('www.youtube.com');
    return r.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<DownloadProgressEvent> _downloadLast(
  YtDlpSource source,
  DownloadRequest request,
) async {
  DownloadProgressEvent? last;
  await for (final e in source.download('live-test', request)) {
    last = e;
  }
  expect(last, isNotNull, reason: 'no progress event received');
  return last!;
}

void main() {
  late YtDlpSource source;
  late Directory out;

  setUp(() {
    source = YtDlpSource(_RepoBinLocator(), ProcessRunner());
    out = Directory.systemTemp.createTempSync('md_live_');
  });
  tearDown(() {
    if (out.existsSync()) out.deleteSync(recursive: true);
  });

  test('binaries are present and runnable', () async {
    for (final entry in {
      'yt-dlp': ['--version'],
      'ffmpeg': ['-version'],
      'ffprobe': ['-version'],
      'aria2c': ['--version'],
    }.entries) {
      final r = await Process.run(_bin(entry.key), entry.value);
      expect(r.exitCode, 0, reason: '${entry.key}: ${r.stderr}');
      if (entry.key == 'yt-dlp') {
        // ignore: avoid_print
        print('yt-dlp version: ${(r.stdout as String).trim()}');
      }
    }
  });

  test('fetchMetadata returns formats for the public YouTube video', () async {
    if (!await _online()) {
      markTestSkipped('pas de réseau');
      return;
    }
    final m = await source.fetchMetadata(_metaUrl);
    expect(m['id'], 'dQw4w9WgXcQ');
    expect((m['formats'] as List).isNotEmpty, isTrue);
    expect(m['duration'], isA<num>());
  });

  test('download writes a playable file', () async {
    if (!await _online()) {
      markTestSkipped('pas de réseau');
      return;
    }
    final last = await _downloadLast(
      source,
      DownloadRequest(url: _url, outputFolder: out.path),
    );
    expect(last.progress, 1.0);
    final file = File(last.filePath!);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(100 * 1024));
    final probe = await Process.run(_bin('ffprobe'), [file.path]);
    expect(probe.exitCode, 0, reason: '${probe.stderr}');
  });

  test('audio only produces an mp3', () async {
    if (!await _online()) {
      markTestSkipped('pas de réseau');
      return;
    }
    final last = await _downloadLast(
      source,
      DownloadRequest(url: _url, outputFolder: out.path, audioOnly: true),
    );
    expect(last.filePath, endsWith('.mp3'));
    expect(File(last.filePath!).existsSync(), isTrue);
  });
}
