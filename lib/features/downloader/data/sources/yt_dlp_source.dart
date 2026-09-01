import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/entities/download_request.dart';
import '../../domain/exceptions/yt_dlp_exception.dart';
import '../../../../../core/logger/logger_service.dart';
import '../../../../../core/services/binary/binary_locator.dart';
import '../../../../../core/services/binary/process_runner.dart';
import '../../../../../core/download/cookie_browser_args.dart';
import '../../../../../core/download/temp_file_cleanup.dart';
import '../../../../../core/download/download_file_resolver.dart';
import '../../../../../core/download/tor_proxy_guard.dart';
import '../../../../../core/download/yt_dlp_cookie_args.dart';
import '../../../../../core/download/yt_dlp_progress_parser.dart';
import '../../../../../core/download/download_status_guard.dart';
import '../../../../../core/download/fragment_budget.dart';
import '../../../../../core/download/metadata_probe_limiter.dart';

class YtDlpSource {
  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;

  YtDlpSource(this._binaryLocator, this._processRunner);

  final _downloadProcesses = <String, Process>{};
  int _activeDownloadCount = 0;

  static final metadataProbeLimiter = MetadataProbeLimiter(maxParallel: 2);

  /// Fetch video title quickly
  Future<String?> fetchTitle(String url) async {
    try {
      final ytDlp = await _binaryLocator.findYtDlp();
      if (ytDlp == null) return null;

      final result = await _processRunner.run(ytDlp, [
        '--get-title',
        '--no-warnings',
        url,
      ]);

      if (result.exitCode == 0) {
        final title = result.stdout.toString().trim().split('\n').first;
        LoggerService.debug('Fetched title: $title');
        return title;
      }
    } catch (e) {
      LoggerService.w('Failed to fetch title: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    String? cookiesFilePath,
    String? cookieBrowser,
    bool useTorProxy = false,
    bool Function()? isCancelled,
  }) async {
    await metadataProbeLimiter.acquire(isCancelled: isCancelled);
    try {
      if (isCancelled != null && isCancelled()) {
        throw const MetadataProbeCancelledException();
      }
      return await _fetchMetadataUnlocked(
        url,
        cookies: cookies,
        cookiesFilePath: cookiesFilePath,
        cookieBrowser: cookieBrowser,
        useTorProxy: useTorProxy,
      );
    } finally {
      metadataProbeLimiter.release();
    }
  }

  Future<Map<String, dynamic>> _fetchMetadataUnlocked(
    String url, {
    String? cookies,
    String? cookiesFilePath,
    String? cookieBrowser,
    bool useTorProxy = false,
  }) async {
    final ytDlp = await _binaryLocator.findYtDlp();
    if (ytDlp == null) throw Exception('yt-dlp binary not found');

    // Use verbose flags for clarity and safety
    // --no-warnings is CRITICAL because yt-dlp can print warnings to stdout which breaks jsonDecode
    // --no-playlist ensures we get a single video JSON, preventing multiple JSONs for playlist URLs
    final args = <String>['--dump-json', '--no-warnings', '--no-playlist'];

    File? tempNetscapeFile;
    try {
      var effectiveCookiesPath = cookiesFilePath;
      if ((effectiveCookiesPath == null || effectiveCookiesPath.isEmpty) &&
          YtDlpCookieArgs.isNetscapeFormat(cookies)) {
        tempNetscapeFile = File(
          '${Directory.systemTemp.path}/md_meta_cookies_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await tempNetscapeFile.writeAsString(cookies!);
        effectiveCookiesPath = tempNetscapeFile.path;
      }

      args.addAll(
        YtDlpCookieArgs.build(
          cookiesFilePath: effectiveCookiesPath,
          rawCookies: cookies,
          cookieBrowser: cookieBrowser,
        ),
      );

      final proxy = await TorProxyGuard.resolveProxyUrl(
        useTorProxy: useTorProxy,
      );
      if (proxy != null) {
        args.addAll(['--proxy', proxy]);
      } else if (useTorProxy) {
        LoggerService.w(
          'Tor enabled but ${TorProxyGuard.host}:${TorProxyGuard.port} unreachable — metadata without proxy',
        );
      }

      args.add(url);

      final result = await _processRunner.run(ytDlp, args);
      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        if (DownloadStatusGuard.isNonRetryableProxyError(stderr)) {
          throw YtDlpException(
            DownloadStatusGuard.userFacingProxyErrorMessage(stderr),
          );
        }
        throw YtDlpException.fromLog(stderr) ??
            Exception('Failed to fetch metadata: $stderr');
      }

      // Sanitize output: sometimes yt-dlp prints empty lines or debug info even with --no-warnings
      final cleanStdout = result.stdout.toString().trim();
      if (cleanStdout.isEmpty) {
        throw Exception('Empty metadata response from yt-dlp');
      }

      final decoded = _decodeFirstMetadataObject(cleanStdout);
      if (decoded == null) {
        throw const FormatException('No metadata JSON object found');
      }
      return decoded;
    } finally {
      try {
        if (tempNetscapeFile != null && await tempNetscapeFile.exists()) {
          await tempNetscapeFile.delete();
        }
      } catch (e) {
        LoggerService.w('Failed to delete temp Netscape cookies file: $e');
      }
    }
  }

  Map<String, dynamic>? _decodeFirstMetadataObject(String output) {
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // A tweet with multiple media entries can emit one JSON object per line.
    }

    for (final line in const LineSplitter().convert(output)) {
      final candidate = line.trim();
      if (candidate.isEmpty) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Ignore non-JSON lines and continue with the next media entry.
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPlaylist(String url) async {
    final ytDlp = await _binaryLocator.findYtDlp();
    if (ytDlp == null) return [];

    final result = await _processRunner.run(ytDlp, [
      '--flat-playlist',
      '--dump-single-json',
      '--no-warnings',
      url,
    ]);

    if (result.exitCode == 0) {
      try {
        final cleanStdout = result.stdout.toString().trim();
        if (cleanStdout.isEmpty) return [];

        final dynamic data = jsonDecode(cleanStdout);
        if (data is Map<String, dynamic> && data.containsKey('entries')) {
          final List entriesData = data['entries'] as List;
          return entriesData
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else if (data is Map<String, dynamic>) {
          return [data];
        }
      } catch (e) {
        LoggerService.w('Failed to parse playlist JSON: $e');
      }
    }
    return [];
  }

  Stream<DownloadProgressEvent> download(
    String id,
    DownloadRequest request,
  ) async* {
    _activeDownloadCount++;
    try {
      yield* _downloadUnlocked(id, request);
    } finally {
      if (_activeDownloadCount > 0) {
        _activeDownloadCount--;
      }
    }
  }

  Stream<DownloadProgressEvent> _downloadUnlocked(
    String id,
    DownloadRequest request,
  ) async* {
    LoggerService.i('YtDlpSource: Looking for yt-dlp binary...');
    final ytDlp = await _binaryLocator.findYtDlp();
    if (ytDlp == null) {
      LoggerService.e('yt-dlp binary NOT FOUND!');
      throw Exception('yt-dlp binary not found. Please install yt-dlp.');
    }
    LoggerService.i('YtDlpSource: Found yt-dlp: $ytDlp');

    // Build args
    final args = <String>[];

    // === SPEED OPTIMIZATION FLAGS ===
    final aria2cPath = await _binaryLocator.findAria2c();

    final maxSpeedMode = request.maxSpeedMode;
    final perJobFragments = maxSpeedMode
        ? kMaxSpeedFragmentsPerJob
        : request.concurrentFragments;
    final activeCount = _activeDownloadCount < 1 ? 1 : _activeDownloadCount;
    final concurrentFragments = computeConcurrentFragments(
      perJob: perJobFragments,
      activeCount: activeCount,
    );
    final bufferSize = computeYtDlpBufferSize(
      concurrentFragments: concurrentFragments,
      activeCount: activeCount,
    );

    // Native multi-fragment downloader scales beyond aria2c's 16-connection cap.
    // Max speed stays on; the global fragment budget only shares 64 across jobs.
    if (concurrentFragments >= 16 || maxSpeedMode) {
      LoggerService.i(
        'Native high-speed downloader: $concurrentFragments parallel fragments'
        '${maxSpeedMode ? ' (max speed mode)' : ''} '
        '($activeCount active, budget $kFragmentGlobalBudget).',
      );
      args.addAll(['--concurrent-fragments', concurrentFragments.toString()]);
      args.addAll(['--buffer-size', bufferSize]);
      if (concurrentFragments >= 32 &&
          activeCount <= kBufferSizeCapActiveCount) {
        args.addAll(['--http-chunk-size', '10M']);
      }
    } else if (aria2cPath != null) {
      LoggerService.i(
        'Activating Aria2c engine: $aria2cPath with $concurrentFragments threads',
      );
      args.addAll([
        '--downloader',
        'aria2c',
        '--downloader-args',
        'aria2c:-x $concurrentFragments -s $concurrentFragments -k 1M',
      ]);
    } else {
      LoggerService.i(
        'Aria2c not found, using native downloader with $concurrentFragments fragments.',
      );
      args.addAll(['--concurrent-fragments', concurrentFragments.toString()]);
      args.addAll(['--buffer-size', '16M']);
    }

    // Skip playlist checks unless Twitter replies were requested
    final isTwitter =
        request.url.contains('twitter.com') || request.url.contains('x.com');
    if (!(isTwitter && request.twitterIncludeReplies)) {
      args.add('--no-playlist');
    }

    // Output template - Use proper Windows path separators
    String outputPath;
    String baseFolder = request.outputFolder ?? '';

    // Standard User Downloads directory if none provided
    if (baseFolder.isEmpty) {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          baseFolder = '$userProfile\\Downloads';
        }
      }
      baseFolder = baseFolder.isEmpty ? 'Downloads' : baseFolder;
    }

    baseFolder = baseFolder.replaceAll('/', '\\');

    // Organize by site: Add subfolder
    if (request.organizeBySite) {
      // Use DownloadItem.source logic but for the request URL
      final siteFolder = _getSiteName(request.url);
      baseFolder = '$baseFolder\\$siteFolder';
    }

    final downloadsDir = Directory(baseFolder);
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }

    // Include %(id)s in the filename to prevent false duplicates when
    // yt-dlp extracts the same generic title for different videos on unknown sites.
    // The ID is unique per video (e.g. YouTube video ID, tweet status ID, etc.)
    final filename = request.customFilename ?? '%(title)s [%(id)s].%(ext)s';
    outputPath = '$baseFolder\\$filename';

    args.add('-o');
    args.add(outputPath);
    // Emit final path after all post-processors (merge/remux/embed).
    args.add('--print');
    args.add('after_move:%(filepath)s');
    // Ensure percent lines are emitted (often on stderr when --print is used).
    args.add('--progress');
    args.add('--newline');
    LoggerService.debug('Output path: $outputPath');

    // === AUDIO ONLY MODE ===
    if (request.audioOnly) {
      args.add('-x'); // Extract audio
      args.add('--audio-format');
      args.add(request.audioFormat); // mp3, aac, opus
      args.add('--audio-quality');
      args.add('0'); // Best quality
      LoggerService.debug('Mode: Audio only (${request.audioFormat})');
    }
    // === VIDEO MODE ===
    else {
      // Quality selection
      if (request.videoFormatId != null) {
        args.add('-f');
        args.add(
          '${request.videoFormatId}+bestaudio/best[format_id=${request.videoFormatId}]',
        );
      } else if (request.preferredQuality == 'best' ||
          request.preferredQuality == 'manual' ||
          request.preferredQuality == 'manual+') {
        args.add('-f');
        args.add('bestvideo+bestaudio/best');
      } else if (request.preferredQuality == 'worst') {
        args.add('-f');
        args.add('worst');
      } else {
        final height = request.preferredQuality.replaceAll('p', '');
        args.add('-f');
        args.add('bestvideo[height<=$height]+bestaudio/best[height<=$height]');
      }

      final isTwitch = request.url.contains('twitch.tv');
      if (isTwitch && request.videoFormatId == null) {
        final twitchHeight = request.twitchQuality.replaceAll(
          RegExp(r'[^0-9].*'),
          '',
        );
        if (twitchHeight.isNotEmpty) {
          args.add('-f');
          args.add(
            'bestvideo[height<=$twitchHeight]+bestaudio/best[height<=$twitchHeight]',
          );
        }
      }

      // === OUTPUT FORMAT (FFmpeg merge/recode) ===
      // --merge-output-format ensures that if video and audio are separate they merge into this
      args.add('--merge-output-format');
      args.add(request.outputFormat); // mp4, mkv, webm

      // --remux-video is much faster than --recode-video (no re-encoding).
      // In max speed mode, always remux; otherwise recode for max compatibility.
      if (request.maxSpeedMode) {
        args.add('--remux-video');
      } else {
        args.add('--recode-video');
      }
      args.add(request.outputFormat);

      // For MP4: Re-encode audio to AAC if merging for max compatibility
      if (request.outputFormat == 'mp4') {
        args.add('--postprocessor-args');
        args.add(
          'ffmpeg:-c:a aac -b:a 192k',
        ); // 192k is plenty for compatibility
      }

      LoggerService.debug(
        'Quality: ${request.preferredQuality}, Format: ${request.outputFormat}',
      );
    }

    // Embed options
    if (request.embedThumbnail) {
      args.add('--embed-thumbnail');
    }
    // Force thumbnail check logic might happen outside, but here we respect the request
    if (request.embedSubtitles) {
      args.add('--embed-subs');
      args.add('--sub-langs');
      args.add('all');
      args.add('--convert-subs');
      args.add('srt'); // Convert all subs to srt for better support
    }

    if (request.url.contains('twitch.tv') && request.twitchDownloadChat) {
      args.addAll(['--write-subs', '--sub-langs', 'live_chat']);
    }

    File? tempNetscapeCookies;
    var cookiesFilePath = request.cookiesFilePath;
    if ((cookiesFilePath == null || cookiesFilePath.isEmpty) &&
        YtDlpCookieArgs.isNetscapeFormat(request.rawCookies)) {
      tempNetscapeCookies = File(
        '${Directory.systemTemp.path}/md_dl_cookies_$id.txt',
      );
      await tempNetscapeCookies.writeAsString(request.rawCookies!);
      cookiesFilePath = tempNetscapeCookies.path;
    }

    final cookieArgs = YtDlpCookieArgs.build(
      cookiesFilePath: cookiesFilePath,
      rawCookies: request.rawCookies,
      cookieBrowser: request.cookieBrowser,
    );
    args.addAll(cookieArgs);
    if (cookieArgs.contains('--cookies')) {
      LoggerService.i('Using cookies file for authentication');
    } else if (cookieArgs.contains('--add-header')) {
      LoggerService.i('Using supplied Cookie header');
    } else if (cookieArgs.contains('--cookies-from-browser')) {
      LoggerService.i(
        'Using ${CookieBrowserArgs.resolve(request.cookieBrowser)} cookies for authentication',
      );
    }

    args.addAll(['--retries', '3']);
    args.addAll(['--fragment-retries', '10']);
    args.add('--continue');

    // === HEADERS FOR PROTECTED SITES ===
    if (request.userAgent != null) {
      args.addAll(['--user-agent', request.userAgent!]);
      LoggerService.debug('Using custom User-Agent: ${request.userAgent}');
    } else if (_requiresCookies(request.url)) {
      args.addAll([
        '--user-agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ]);
      args.addAll(['--referer', request.url]);
      args.add('--no-check-certificates');
    }

    // === TOR PROXY (skip when 9050 is down) ===
    final torProxy = await TorProxyGuard.resolveProxyUrl(
      useTorProxy: request.useTorProxy,
    );
    if (torProxy != null) {
      args.add('--proxy');
      args.add(torProxy);
      LoggerService.i('Using Tor Proxy: $torProxy');
    } else if (request.useTorProxy) {
      LoggerService.w(
        'Tor enabled but ${TorProxyGuard.host}:${TorProxyGuard.port} unreachable — downloading without proxy',
      );
    }

    if ((request.forceStreamUrl != null &&
            request.forceStreamUrl!.contains('stream.kick.com')) ||
        request.url.contains('kick.com')) {
      args.addAll(['--add-header', 'Origin:https://kick.com']);
    }

    // URL — prefer a resolved direct stream (Kick HLS master/variant)
    final downloadUrl =
        (request.forceStreamUrl != null && request.forceStreamUrl!.isNotEmpty)
        ? request.forceStreamUrl!
        : request.url;
    args.add(downloadUrl);

    LoggerService.i('YtDlpSource: Running: $ytDlp ${args.join(' ')}');

    // Start process
    final process = await Process.start(
      ytDlp,
      args,
      runInShell: false,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _downloadProcesses[id] = process;

    LoggerService.i('Process started with PID: ${process.pid}');

    YtDlpException? detectedException;
    final errorBuffer = StringBuffer();
    final outputBuffer = StringBuffer();

    final preferredExt = request.audioOnly
        ? '.${request.audioFormat}'
        : '.${request.outputFormat}';
    final videoIdFromFilename = DownloadFileResolver.extractBracketId(
      request.customFilename ?? filename,
    );

    final parser = YtDlpProgressParser(
      baseFolder: baseFolder,
      preferredExt: preferredExt,
    );

    // Merge stdout + stderr line-by-line into one handler (progress often on stderr
    // when --print after_move is used).
    final lineController = StreamController<String>();
    var openStreams = 2;

    void markStreamDone() {
      openStreams--;
      if (openStreams <= 0 && !lineController.isClosed) {
        unawaited(lineController.close());
      }
    }

    void detectYtDlpException(String data) {
      if (detectedException != null) return;
      detectedException = YtDlpException.fromLog(data);
    }

    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            outputBuffer.writeln(line);
            if (!lineController.isClosed) {
              lineController.add(line);
            }
          },
          onDone: markStreamDone,
          onError: (Object e, StackTrace st) {
            if (!lineController.isClosed) {
              lineController.addError(e, st);
            }
            markStreamDone();
          },
          cancelOnError: false,
        );

    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            errorBuffer.writeln(line);
            outputBuffer.writeln(line);
            detectYtDlpException(line);
            if (!lineController.isClosed) {
              lineController.add(line);
            }
          },
          onDone: markStreamDone,
          onError: (Object e, StackTrace st) {
            if (!lineController.isClosed) {
              lineController.addError(e, st);
            }
            markStreamDone();
          },
          cancelOnError: false,
        );

    await for (final line in lineController.stream) {
      for (final update in parser.onLine(line)) {
        yield DownloadProgressEvent(
          progress: update.progress,
          totalSize: update.totalSize,
          downloadedSize: update.downloadedSize,
          speed: update.speed,
          eta: update.eta,
          title: update.title,
          step: update.step,
          filePath: update.filePath,
          isDuplicate: update.isDuplicate,
        );
      }
    }

    try {
      final exitCode = await process.exitCode;
      _downloadProcesses.remove(id);

      LoggerService.i('Process exited with code $exitCode');

      if (exitCode != 0) {
        LoggerService.e('Full Stderr: $errorBuffer');
        if (detectedException != null) throw detectedException!;
        final errText = errorBuffer.toString();
        if (DownloadStatusGuard.isNonRetryableProxyError(errText)) {
          throw YtDlpException(
            DownloadStatusGuard.userFacingProxyErrorMessage(errText),
          );
        }
        throw YtDlpException.fromLog(errText) ??
            YtDlpException(
              'yt-dlp exited with code $exitCode. Error: $errorBuffer',
            );
      }

      // Prefer after_move print, then resolve against disk (fragments / remux).
      var currentFilePath = parser.afterMovePath ?? parser.currentFilePath;
      final resolvedPath = DownloadFileResolver.resolve(
        candidatePath: currentFilePath,
        outputFolder: baseFolder,
        videoId: videoIdFromFilename,
        preferredExtension: preferredExt,
      );
      if (resolvedPath != null) {
        currentFilePath = resolvedPath;
        parser.currentFilePath = resolvedPath;
        LoggerService.debug('Resolved final file path: $currentFilePath');
      } else if (currentFilePath != null) {
        LoggerService.w('Could not verify file on disk: $currentFilePath');
      }

      // Success if we saw download progress OR a non-fragment file exists with size > 0.
      if (!parser.isSuccessfulExit(
        outputFolder: baseFolder,
        videoId: videoIdFromFilename,
      )) {
        LoggerService.w('No progress detected. Output:\n$outputBuffer');
        throw YtDlpException(
          'yt-dlp exited successfully but no download progress was detected. Output: $outputBuffer',
        );
      }

      final diskSize = DownloadFileResolver.formattedFileSize(currentFilePath);
      yield DownloadProgressEvent(
        progress: 1.0,
        totalSize: diskSize ?? '',
        downloadedSize: diskSize ?? '',
        speed: 'Terminé',
        eta: '',
        title: parser.extractedTitle,
        step: 'Fini',
        filePath: currentFilePath,
      );

      if (currentFilePath != null) {
        unawaited(_cleanupTempFiles(currentFilePath));
      }
    } finally {
      try {
        if (tempNetscapeCookies != null && await tempNetscapeCookies.exists()) {
          await tempNetscapeCookies.delete();
        }
      } catch (e) {
        LoggerService.w('Failed to delete temp Netscape cookies file: $e');
      }
    }
  }

  Future<void> _cleanupTempFiles(String finalFilePath) async {
    try {
      final file = File(finalFilePath);
      final directory = file.parent;
      final filename = file.uri.pathSegments.last.replaceAll(
        RegExp(r'\.\w+$'),
        '',
      );

      if (!await directory.exists()) return;

      await for (final entity in directory.list()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          // Check for common temp extensions and matching filename base
          if (name.contains(filename) &&
              TempFileCleanup.isFragmentOrTemp(name)) {
            try {
              await entity.delete();
              LoggerService.debug('Cleaned up temp file: $name');
            } catch (e) {
              LoggerService.w('Failed to delete temp file: $name');
            }
          }
        }
      }
    } catch (e) {
      LoggerService.w('Error during temp file cleanup: $e');
    }
  }

  Future<void> cancel(String id) async {
    final process = _downloadProcesses[id];
    if (process != null) {
      await _processRunner.kill(process); // Use robust kill
      _downloadProcesses.remove(id);
    }
  }

  bool _requiresCookies(String url) {
    // ... same as origin
    return url.contains('twitter.com') ||
        url.contains('kick.com') ||
        url.contains('pornhub.com');
    // Added kick.com just in case
  }

  String _getSiteName(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host.toLowerCase();

      if (host.contains('youtube') || host.contains('youtu.be')) {
        return 'YouTube';
      }
      if (host.contains('twitter') || host.contains('x.com')) return 'Twitter';
      if (host.contains('twitch')) return 'Twitch';
      if (host.contains('tiktok')) return 'TikTok';
      if (host.contains('kick.com')) return 'Kick';
      if (host.contains('facebook') || host.contains('fb.com')) {
        return 'Facebook';
      }
      if (host.contains('xnxx')) return 'XNXX';
      if (host.contains('xvideos')) return 'XVideos';
      if (host.contains('instagram')) return 'Instagram';

      // Fallback: extract domain name
      var domain = host.replaceFirst('www.', '');
      final parts = domain.split('.');
      if (parts.length >= 2) {
        domain = parts[parts.length - 2];
        return domain[0].toUpperCase() + domain.substring(1);
      }
    } catch (e) {
      LoggerService.debug('Failed to extract site name from URL: $e');
    }
    return 'Other';
  }
}

class DownloadProgressEvent {
  final double progress;
  final String totalSize;
  final String downloadedSize;
  final String speed;
  final String eta;
  final String? title;
  final String step;
  final String? filePath;
  final bool isDuplicate;

  DownloadProgressEvent({
    required this.progress,
    required this.totalSize,
    this.downloadedSize = '',
    required this.speed,
    required this.eta,
    this.title,
    this.step = '',
    this.filePath,
    this.isDuplicate = false,
  });
}
