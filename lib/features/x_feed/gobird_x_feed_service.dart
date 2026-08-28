import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/logger/logger_service.dart';
import '../../services/binary_locator.dart';
import '../../services/process_runner.dart';
import 'x_feed_cookie_credentials.dart';
import 'x_feed_models.dart';

typedef GobirdProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

typedef GobirdProcessRunnerWithEnvironment =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
    );

typedef GobirdCredentialsResolver =
    Future<XFeedCredentials?> Function(String? cookiesFilePath);

typedef ContentLengthProbe = Future<int?> Function(String url);

/// Read-only gobird adapter for the experimental X feed engine.
///
/// Only builds the allowlisted read command:
/// `gobird --json --quiet --count 1..10000 --max-pages 500 home`
/// Credentials are supplied through the child process environment when the
/// extension heartbeat is available; browser flags are only the fallback.
class GobirdXFeedService {
  /// Tweet budget passed to gobird `--count` (not the displayed video cap).
  static const int maxTweetCount = 10000;

  /// UI / parser cap on video and GIF items kept from gobird JSON.
  static const int maxVideoItems = 10000;

  static const int maxPages = 500;
  static const Duration defaultTimeout = Duration(minutes: 12);
  static const int maxStdoutBytes = 32 * 1024 * 1024;

  final BinaryLocator _locator;
  final GobirdProcessRunner _runProcess;
  final GobirdProcessRunnerWithEnvironment _runProcessWithEnvironment;
  final GobirdCredentialsResolver _resolveCredentials;
  final ContentLengthProbe? _contentLengthProbe;
  final bool _useBrowserCookieFallback;

  GobirdXFeedService({
    BinaryLocator? locator,
    GobirdProcessRunner? runProcess,
    GobirdProcessRunnerWithEnvironment? runProcessWithEnvironment,
    GobirdCredentialsResolver? resolveCredentials,
    ContentLengthProbe? contentLengthProbe,
    bool? useBrowserCookieFallback,
  }) : _locator = locator ?? BinaryLocator(),
       _runProcess = runProcess ?? _defaultRun,
       _runProcessWithEnvironment =
           runProcessWithEnvironment ?? _defaultRunWithEnvironment,
       _resolveCredentials = resolveCredentials ?? _defaultResolveCredentials,
       _contentLengthProbe = contentLengthProbe,
       _useBrowserCookieFallback =
           useBrowserCookieFallback ?? !Platform.isWindows;

  static Future<ProcessResult> _defaultRun(
    String executable,
    List<String> arguments,
  ) {
    return ProcessRunner().run(executable, arguments);
  }

  static Future<ProcessResult> _defaultRunWithEnvironment(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) {
    return ProcessRunner().run(executable, arguments, environment: environment);
  }

  static Future<XFeedCredentials?> _defaultResolveCredentials(
    String? cookiesFilePath,
  ) {
    return XFeedCookieCredentials.resolve(cookiesFilePath: cookiesFilePath);
  }

  /// Builds allowlisted argv. Throws [ArgumentError] on invalid input.
  static List<String> buildHomeArgs({
    required String browser,
    required int count,
  }) {
    return <String>[
      '--browser',
      normalizeBrowser(browser),
      ..._homeFlags(count),
    ];
  }

  /// Builds the command used when credentials are supplied through the
  /// process environment instead of browser profile auto-detection.
  static List<String> buildHomeArgsFromEnvironment({required int count}) {
    return _homeFlags(count);
  }

  static String normalizeBrowser(String browser) {
    final value = browser.trim().toLowerCase();
    if (value == 'chrome' || value == 'firefox') return value;
    throw ArgumentError.value(
      browser,
      'browser',
      'Only chrome or firefox are allowed',
    );
  }

  static int clampCount(int count) {
    if (count < 1) return 1;
    if (count > maxTweetCount) return maxTweetCount;
    return count;
  }

  static List<String> _homeFlags(int count) {
    return <String>[
      '--json',
      '--quiet',
      '--count',
      '${clampCount(count)}',
      '--max-pages',
      '$maxPages',
      'home',
    ];
  }

  Future<XFeedResult> fetchHomeFeed({
    required String browser,
    int count = maxTweetCount,
    Duration timeout = defaultTimeout,
    bool probeContentLength = false,
    FutureOr<void>? cancelSignal,
    String? cookiesFilePath,
  }) async {
    String? executable;
    try {
      executable = await _locator.ensureGobirdStaged();
      executable ??= await _locator.findGobird();
    } catch (e) {
      LoggerService.w('gobird lookup failed: $e');
    }
    if (executable == null || executable.isEmpty) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.missingBinary.name,
        error: 'gobird binary not found',
      );
    }

    final credentials = await _resolveCredentialsWithRetry(cookiesFilePath);

    final List<String> args;
    Map<String, String>? environment;
    try {
      if (credentials != null) {
        LoggerService.i('gobird: using local X heartbeat credentials');
        args = buildHomeArgsFromEnvironment(count: count);
        // Pass only the two gobird credential vars. Process.run merges them
        // with the parent environment; copying Platform.environment on
        // Windows can include keys the child process rejects.
        environment = <String, String>{
          'AUTH_TOKEN': credentials.authToken,
          'CT0': credentials.ct0,
        };
      } else if (_useBrowserCookieFallback) {
        LoggerService.w(
          'gobird: no local X heartbeat credentials; using browser fallback',
        );
        args = buildHomeArgs(browser: browser, count: count);
      } else {
        return XFeedResult.failure(
          errorCode: GobirdErrorKind.auth.name,
          error:
              'X session cookies were not found. Open x.com in the same '
              'browser as the extension with Auto-Cookies enabled.',
        );
      }
    } on ArgumentError catch (e) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.invalidArgs.name,
        error: e.message?.toString() ?? 'invalid gobird arguments',
      );
    }

    try {
      final Future<ProcessResult> runFuture = environment == null
          ? _runProcess(executable, args)
          : _runProcessWithEnvironment(executable, args, environment);
      final ProcessResult result;
      if (cancelSignal != null) {
        result = await Future.any(<Future<ProcessResult>>[
          runFuture,
          Future.sync(() async {
            await cancelSignal;
            throw GobirdCancelledException();
          }),
        ]).timeout(timeout);
      } else {
        result = await runFuture.timeout(timeout);
      }

      if (result.exitCode != 0) {
        return _mapProcessFailure(result);
      }

      final stdoutText = result.stdout.toString();
      final stdoutBytes = utf8.encode(stdoutText);
      if (stdoutBytes.length > maxStdoutBytes) {
        return XFeedResult.failure(
          errorCode: GobirdErrorKind.parse.name,
          error: 'gobird output exceeded size limit',
        );
      }

      final parsed = _parseGobirdHomeJsonRaw(
        stdoutText,
        maxItems: maxVideoItems,
      );
      var items = parsed.items;
      if (probeContentLength) {
        items = await _attachContentLengths(items);
      }
      items = [for (final item in items) _withPermalinkDownloadUrl(item)];

      return XFeedResult(
        ok: true,
        source: 'gobird',
        items: items,
        truncated: parsed.truncated,
      );
    } on TimeoutException {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.timeout.name,
        error: 'gobird timed out',
      );
    } on GobirdCancelledException {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.cancelled.name,
        error: 'gobird cancelled',
      );
    } on FormatException catch (e) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.parse.name,
        error: e.message,
      );
    } catch (e, st) {
      LoggerService.e('gobird fetch failed', e, st);
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.unknown.name,
        error: e.toString(),
      );
    }
  }

  Future<XFeedCredentials?> _resolveCredentialsWithRetry(
    String? cookiesFilePath,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final credentials = await _resolveCredentials(cookiesFilePath);
        if (credentials != null) return credentials;
      } catch (e) {
        lastError = e;
      }
      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (lastError != null) {
      LoggerService.w('X cookie credential lookup failed: $lastError');
    }
    return null;
  }

  Future<List<XFeedItem>> _attachContentLengths(List<XFeedItem> items) async {
    final probe = _contentLengthProbe ?? _defaultContentLengthProbe;
    final out = <XFeedItem>[];
    for (final item in items) {
      if (item.sizeBytes != null) {
        out.add(item);
        continue;
      }
      try {
        final size = await probe(item.url).timeout(const Duration(seconds: 2));
        if (size != null && size > 0) {
          out.add(
            XFeedItem(
              id: item.id,
              url: item.url,
              pageUrl: item.pageUrl,
              title: item.title,
              author: item.author,
              thumbnailUrl: item.thumbnailUrl,
              durationSeconds: item.durationSeconds,
              width: item.width,
              height: item.height,
              sizeBytes: size,
              source: item.source,
            ),
          );
          continue;
        }
      } catch (_) {
        // Size stays explicitly unknown.
      }
      out.add(item);
    }
    return out;
  }

  XFeedResult _mapProcessFailure(ProcessResult result) {
    final stderrText = result.stderr.toString().trim();
    final combined = '${result.stdout}\n$stderrText'.toLowerCase();
    final code = result.exitCode;

    if (code == 3 ||
        combined.contains('unauthorized') ||
        combined.contains('missing credentials') ||
        combined.contains('credential') ||
        combined.contains('cookie') ||
        combined.contains('profile directory') ||
        combined.contains('auth')) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.auth.name,
        error: stderrText.isEmpty ? 'gobird authentication failed' : stderrText,
      );
    }
    if (code == 4 ||
        combined.contains('rate limit') ||
        combined.contains('429')) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.rateLimit.name,
        error: stderrText.isEmpty ? 'gobird rate limited' : stderrText,
      );
    }
    if (combined.contains('network') ||
        combined.contains('timeout') ||
        combined.contains('connection')) {
      return XFeedResult.failure(
        errorCode: GobirdErrorKind.network.name,
        error: stderrText.isEmpty ? 'gobird network error' : stderrText,
      );
    }
    return XFeedResult.failure(
      errorCode: GobirdErrorKind.unknown.name,
      error: stderrText.isEmpty ? 'gobird exited with code $code' : stderrText,
    );
  }

  static Future<int?> _defaultContentLengthProbe(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return null;
      }
      final response = await http.head(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return null;
      }
      final raw = response.headers['content-length'];
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Parses gobird `--json` home timeline output into video feed items.
  /// Download [XFeedItem.url] is the tweet permalink; CDN URLs are only used
  /// internally for optional Content-Length probes.
  static ({List<XFeedItem> items, bool truncated}) parseGobirdHomeJson(
    String raw, {
    int maxItems = GobirdXFeedService.maxVideoItems,
  }) {
    final parsed = _parseGobirdHomeJsonRaw(raw, maxItems: maxItems);
    return (
      items: [for (final item in parsed.items) _withPermalinkDownloadUrl(item)],
      truncated: parsed.truncated,
    );
  }

  static ({List<XFeedItem> items, bool truncated}) _parseGobirdHomeJsonRaw(
    String raw, {
    int maxItems = GobirdXFeedService.maxVideoItems,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (items: const <XFeedItem>[], truncated: false);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const FormatException('Invalid gobird JSON');
    }

    final tweets = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          tweets.add(entry);
        } else if (entry is Map) {
          tweets.add(Map<String, dynamic>.from(entry));
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      final nested = decoded['items'] ?? decoded['tweets'];
      if (nested is List) {
        for (final entry in nested) {
          if (entry is Map<String, dynamic>) {
            tweets.add(entry);
          } else if (entry is Map) {
            tweets.add(Map<String, dynamic>.from(entry));
          }
        }
      } else {
        tweets.add(decoded);
      }
    } else if (decoded is Map) {
      tweets.add(Map<String, dynamic>.from(decoded));
    } else {
      throw const FormatException('Unexpected gobird JSON root');
    }

    final items = <XFeedItem>[];
    final seen = <String>{};
    var videoCandidates = 0;

    for (final tweet in tweets) {
      final mediaList = _asMapList(tweet['media']);
      var videoIndex = 0;
      for (final media in mediaList) {
        final type = (media['type'] as String?)?.toLowerCase() ?? '';
        if (type != 'video' && type != 'animated_gif') continue;

        final videoUrl = _firstHttpUrl(<String?>[
          media['videoUrl'] as String?,
          media['url'] as String?,
        ]);
        if (videoUrl == null) continue;

        videoCandidates++;
        if (items.length >= maxItems) continue;

        final tweetId = (tweet['id'] as String?)?.trim() ?? '';
        if (tweetId.isEmpty) continue;
        final itemId = videoIndex == 0 ? tweetId : '$tweetId-video-$videoIndex';
        videoIndex++;
        if (seen.contains(itemId)) continue;
        seen.add(itemId);

        final authorMap = tweet['author'];
        String username = '';
        String displayName = '';
        if (authorMap is Map) {
          username = (authorMap['username'] as String?)?.trim() ?? '';
          displayName = (authorMap['name'] as String?)?.trim() ?? '';
        }
        final author = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? '@$username' : 'X user');

        final text = (tweet['text'] as String?)?.trim() ?? '';
        final title = text.isNotEmpty
            ? text
            : (username.isNotEmpty ? 'X video — @$username' : 'X video');

        final pageUrl = username.isNotEmpty
            ? 'https://x.com/$username/status/$tweetId'
            : 'https://x.com/i/status/$tweetId';

        final durationMs = media['durationMs'];
        double? durationSeconds;
        if (durationMs is int && durationMs > 0) {
          durationSeconds = durationMs / 1000.0;
        } else if (durationMs is num && durationMs > 0) {
          durationSeconds = durationMs.toDouble() / 1000.0;
        }

        final width = media['width'] is int
            ? media['width'] as int
            : (media['width'] is num ? (media['width'] as num).toInt() : null);
        final height = media['height'] is int
            ? media['height'] as int
            : (media['height'] is num
                  ? (media['height'] as num).toInt()
                  : null);

        final thumb = _firstHttpUrl(<String?>[
          media['previewUrl'] as String?,
          type == 'photo' ? media['url'] as String? : null,
        ]);

        items.add(
          XFeedItem(
            id: itemId,
            url: videoUrl,
            pageUrl: pageUrl,
            title: title,
            author: author,
            thumbnailUrl: thumb,
            durationSeconds: durationSeconds,
            width: width,
            height: height,
            sizeBytes: null,
            source: 'gobird',
          ),
        );
      }
    }

    return (items: items, truncated: videoCandidates > maxItems);
  }

  static XFeedItem _withPermalinkDownloadUrl(XFeedItem item) {
    if (item.pageUrl.isEmpty || item.url == item.pageUrl) {
      return item;
    }
    return XFeedItem(
      id: item.id,
      url: item.pageUrl,
      pageUrl: item.pageUrl,
      title: item.title,
      author: item.author,
      thumbnailUrl: item.thumbnailUrl,
      durationSeconds: item.durationSeconds,
      width: item.width,
      height: item.height,
      sizeBytes: item.sizeBytes,
      source: item.source,
    );
  }

  static List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in value) {
      if (entry is Map<String, dynamic>) {
        out.add(entry);
      } else if (entry is Map) {
        out.add(Map<String, dynamic>.from(entry));
      }
    }
    return out;
  }

  static String? _firstHttpUrl(List<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      if ((uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}

class GobirdCancelledException implements Exception {}
