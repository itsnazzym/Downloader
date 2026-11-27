import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/download/yt_dlp_cookie_args.dart';
import 'package:tapload/core/services/binary/binary_locator.dart';
import 'package:tapload/core/services/binary/process_runner.dart';
import 'package:tapload/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';

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
    Duration? timeout,
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
  TestWidgetsFlutterBinding.ensureInitialized();
  downloadRetryTests();
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
    'a sniffed stream is fetched with the page as referer and origin',
    () async {
      final runner = _StartRecordingRunner([
        _FakeProcess(stdoutLines: const [], stderrLines: const [], exit: 0),
      ]);
      final source = YtDlpSource(_Locator(), runner);
      final out = Directory.systemTemp.createTempSync('md_sniff_');
      addTearDown(() => out.deleteSync(recursive: true));

      await source
          .download(
            'sn1',
            DownloadRequest(
              url: 'https://example.com/watch/1',
              outputFolder: out.path,
              userAgent: 'Browser UA',
              forceStreamUrl: 'https://cdn.example.com/v/master.m3u8',
            ),
          )
          .drain<void>()
          .catchError((_) {});

      final args = runner.starts.single;
      expect(args.last, 'https://cdn.example.com/v/master.m3u8');
      expect(
        args,
        containsAllInOrder(['--referer', 'https://example.com/watch/1']),
      );
      expect(args, contains('Origin:https://example.com'));
      expect(args, containsAllInOrder(['--user-agent', 'Browser UA']));
    },
  );

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

class _FakeProcess implements Process {
  _FakeProcess({
    required this.stdoutLines,
    required this.stderrLines,
    required int exit,
    this.onExit,
  }) : _exit = exit;

  /// Runs when the exit code is awaited (e.g. to cancel mid-download).
  final void Function()? onExit;
  final List<String> stdoutLines;
  final List<String> stderrLines;
  final int _exit;

  @override
  int get pid => 4242;
  @override
  Future<int> get exitCode async {
    onExit?.call();
    return _exit;
  }

  @override
  Stream<List<int>> get stdout =>
      Stream.fromIterable(stdoutLines.map((l) => utf8.encode('$l\n')));
  @override
  Stream<List<int>> get stderr =>
      Stream.fromIterable(stderrLines.map((l) => utf8.encode('$l\n')));
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _StartRecordingRunner extends ProcessRunner {
  _StartRecordingRunner(this.responses);
  final List<_FakeProcess> responses;
  final starts = <List<String>>[];

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    starts.add(arguments);
    return responses[starts.length - 1];
  }
}

void downloadRetryTests() {
  group('download()', () {
    late Directory out;
    setUp(() => out = Directory.systemTemp.createTempSync('md_cookie_'));
    tearDown(() => out.deleteSync(recursive: true));

    test(
      'retries once without browser cookies on a cookie ERROR',
      () async {
        final runner = _StartRecordingRunner([
          _FakeProcess(
            stdoutLines: const [],
            stderrLines: const ['ERROR: Failed to decrypt with DPAPI. See x'],
            exit: 1,
          ),
          _FakeProcess(stdoutLines: const [], stderrLines: const [], exit: 0),
        ]);
        final source = YtDlpSource(_Locator(), runner);

        await source
            .download(
              'id1',
              DownloadRequest(
                url: 'https://www.youtube.com/watch?v=abc',
                outputFolder: out.path,
                cookieBrowser: 'chrome',
              ),
            )
            .drain<void>()
            .catchError((_) {});

        expect(runner.starts, hasLength(2));
        expect(runner.starts.first, contains('--cookies-from-browser'));
        expect(runner.starts.last, isNot(contains('--cookies-from-browser')));
      },
      skip: Platform.isAndroid ? 'no browser cookies on Android' : false,
    );

    test(
      'retries without browser cookies when they hide every format',
      () async {
        // Signed-in YouTube needs a JS challenge yt-dlp may not solve; the
        // parsed "no formats" error used to win over the cookie retry.
        final runner = _StartRecordingRunner([
          _FakeProcess(
            stdoutLines: const [],
            stderrLines: const [
              'ERROR: [youtube] abc: No video formats found!; please report',
            ],
            exit: 1,
          ),
          _FakeProcess(stdoutLines: const [], stderrLines: const [], exit: 0),
        ]);
        final source = YtDlpSource(_Locator(), runner);

        await source
            .download(
              'id4',
              DownloadRequest(
                url: 'https://www.youtube.com/watch?v=abc',
                outputFolder: out.path,
                cookieBrowser: 'firefox',
              ),
            )
            .drain<void>()
            .catchError((_) {});

        expect(runner.starts, hasLength(2));
        expect(runner.starts.last, isNot(contains('--cookies-from-browser')));
      },
      skip: Platform.isAndroid ? 'no browser cookies on Android' : false,
    );

    test(
      'does not retry when the download was cancelled meanwhile',
      () async {
        late final YtDlpSource source;
        final runner = _StartRecordingRunner([
          _FakeProcess(
            stdoutLines: const [],
            stderrLines: const ['ERROR: Failed to decrypt with DPAPI. See x'],
            exit: 1,
            onExit: () => source.cancel('id3'),
          ),
          _FakeProcess(stdoutLines: const [], stderrLines: const [], exit: 0),
        ]);
        source = YtDlpSource(_Locator(), runner);

        await source
            .download(
              'id3',
              DownloadRequest(
                url: 'https://www.youtube.com/watch?v=abc',
                outputFolder: out.path,
                cookieBrowser: 'chrome',
              ),
            )
            .drain<void>()
            .catchError((_) {});

        expect(runner.starts, hasLength(1));
      },
      skip: Platform.isAndroid ? 'no browser cookies on Android' : false,
    );

    test(
      'does not retry on a WARNING about cookies or a non-cookie error',
      () async {
        final runner = _StartRecordingRunner([
          _FakeProcess(
            stdoutLines: const [],
            stderrLines: const [
              'WARNING: failed to decrypt cookie (AES-GCM) because the MAC check failed',
              'ERROR: unable to download video data: HTTP Error 403: Forbidden',
            ],
            exit: 1,
          ),
        ]);
        final source = YtDlpSource(_Locator(), runner);

        await expectLater(
          source
              .download(
                'id2',
                DownloadRequest(
                  url: 'https://www.youtube.com/watch?v=abc',
                  outputFolder: out.path,
                  cookieBrowser: 'chrome',
                ),
              )
              .drain<void>(),
          throwsA(isA<Exception>()),
        );
        expect(runner.starts, hasLength(1));
      },
      skip: Platform.isAndroid ? 'no browser cookies on Android' : false,
    );
  });
}
