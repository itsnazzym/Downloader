import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/entities/download_request.dart';
import '../../domain/exceptions/yt_dlp_exception.dart';
import '../../../../../core/logger/logger_service.dart';
import '../../../../../services/binary_locator.dart';
import '../../../../../services/process_runner.dart';
import '../../../../../core/services/title_cleaner_service.dart';

class YtDlpSource {
  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;

  YtDlpSource(this._binaryLocator, this._processRunner);

  final _downloadProcesses = <String, Process>{};

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
  }) async {
    final ytDlp = await _binaryLocator.findYtDlp();
    if (ytDlp == null) throw Exception('yt-dlp binary not found');

    // Use verbose flags for clarity and safety
    // --no-warnings is CRITICAL because yt-dlp can print warnings to stdout which breaks jsonDecode
    // --no-playlist ensures we get a single video JSON, preventing multiple JSONs for playlist URLs
    final args = ['--dump-json', '--no-warnings', '--no-playlist', url];

    if (_isCookieHeader(cookies)) {
      args.addAll(['--add-header', 'Cookie:$cookies']);
    } else if (cookiesFilePath != null && cookiesFilePath.isNotEmpty) {
      args.addAll(['--cookies', cookiesFilePath]);
    }

    final result = await _processRunner.run(ytDlp, args);
    if (result.exitCode != 0) {
      throw Exception('Failed to fetch metadata: ${result.stderr}');
    }

    // Sanitize output: sometimes yt-dlp prints empty lines or debug info even with --no-warnings
    final cleanStdout = result.stdout.toString().trim();
    if (cleanStdout.isEmpty) {
      throw Exception('Empty metadata response from yt-dlp');
    }

    return jsonDecode(cleanStdout) as Map<String, dynamic>;
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
    // Check for aria2c (The nuclear option for speed)
    final aria2cPath = await _binaryLocator.findAria2c();

    // Concurrency logic
    int concurrentFragments = request.concurrentFragments;

    // Kick.com optimization: If specifically high concurrency (e.g. 64) is requested,
    // we bypass Aria2c because it's limited to 16 connections.
    // Also, if Aria2c is missing, we use native native downloader.

    if (concurrentFragments > 16) {
      LoggerService.i(
        'High concurrency requested ($concurrentFragments). Using native downloader strategy.',
      );
      // Native yt-dlp fragmentation
      args.addAll(['--concurrent-fragments', concurrentFragments.toString()]);
      args.addAll(['--buffer-size', '64M']);
      // Explicitly disable external downloader args to prevent conflicts
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
        'Aria2c not found, using native optimized downloader (Low Concurrency).',
      );
      args.addAll(['--concurrent-fragments', concurrentFragments.toString()]);
      args.addAll(['--buffer-size', '16M']);
    }

    // Skip playlist checks
    args.add('--no-playlist');

    // Retry on errors (keep .part files for resume capability)
    args.addAll(['--retries', '10']);
    args.addAll(['--fragment-retries', '10']);

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

      // === OUTPUT FORMAT (FFmpeg merge/recode) ===
      // --merge-output-format ensures that if video and audio are separate they merge into this
      args.add('--merge-output-format');
      args.add(request.outputFormat); // mp4, mkv, webm

      // --recode-video forces the final file into the requested container even if it's a single format
      // This is crucial for sites that give files without extensions or incompatible ones.
      args.add('--recode-video');
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

    if (_isCookieHeader(request.rawCookies)) {
      args.addAll(['--add-header', 'Cookie:${request.rawCookies}']);
      LoggerService.i('Using supplied session cookies');
    } else if (request.cookiesFilePath != null &&
        request.cookiesFilePath!.isNotEmpty) {
      args.addAll(['--cookies', request.cookiesFilePath!]);
      LoggerService.i('Using supplied cookies file');
    } else if (request.cookieBrowser != null &&
        request.cookieBrowser!.isNotEmpty) {
      args.addAll(['--cookies-from-browser', request.cookieBrowser!]);
      LoggerService.i(
        'Using browser cookies for authentication: ${request.cookieBrowser}',
      );
    }

    args.addAll(['--retries', '3']);
    args.addAll(['--fragment-retries', '10']);

    // === HEADERS FOR PROTECTED SITES ===
    if (request.userAgent != null) {
      args.addAll(['--user-agent', request.userAgent!]);
      LoggerService.debug('Using custom User-Agent: ${request.userAgent}');
    } else if (_requiresCookies(request.url)) {
      args.addAll([
        '--user-agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0  /537.36',
      ]);
      args.addAll(['--referer', request.url]);
      args.add('--no-check-certificates');
    }

    // === TOR PROXY ===
    if (request.useTorProxy) {
      const torProxy = 'socks5://127.0.0.1:9050';
      args.add('--proxy');
      args.add(torProxy);
      LoggerService.i('Using Tor Proxy: $torProxy');
    }

    // URL
    args.add(request.url);

    LoggerService.i('YtDlpSource: Running: $ytDlp ${args.join(' ')}');

    // Start process
    final process = await Process.start(
      ytDlp,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _downloadProcesses[id] = process;

    LoggerService.i('Process started with PID: ${process.pid}');

    YtDlpException? detectedException;
    StringBuffer errorBuffer = StringBuffer();
    StringBuffer outputBuffer = StringBuffer();

    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((
      data,
    ) {
      errorBuffer.write(data);
      LoggerService.w('yt-dlp stderr: $data');
      if (detectedException != null) return;

      final check = data.toLowerCase();
      if (check.contains('video unavailable')) {
        detectedException = VideoUnavailableException(log: data);
      } else if (check.contains('private video')) {
        detectedException = PrivateVideoException(log: data);
      } else if (check.contains('geo-restricted')) {
        detectedException = GeoBlockedException(log: data);
      }
    });

    // Regex for progress parsing
    final progressRegex = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?\s*([~\d\.]+\w+)\s+at\s+([~\d\.]+\w+/s)\s+ETA\s+([\d:]+)',
    );
    final hlsProgressRegex = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?\s*([~\d\.]+\w+)\s+in\s+[\d:]+\s+at\s+([~\d\.]+\w+/s)',
    );

    final destinationRegex = RegExp(
      r'\[download\] Destination: .*[/\\](.*?)(?:\.\w+)?$',
    );
    final mergerRegex = RegExp(
      r'\[Merger\] Merging formats into "(.*?)(?:\.\w+)?"',
    );

    String? extractedTitle;
    String currentStep = 'Initializing...';
    String? currentFilePath;

    bool hasProgress = false;

    await for (final line
        in process.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())) {
      outputBuffer.writeln(line); // Capture full log
      LoggerService.debug('yt-dlp: $line');

      if (line.contains('[download]')) {
        hasProgress = true; // Mark as having progress
        if (line.contains('Downloading') && line.contains('format')) {
          currentStep = 'Downloading video...';
        } else if (line.contains('Destination')) {
          currentStep = 'Saving file...';
        }
      } else if (line.contains('[Merger]')) {
        currentStep = 'Merging audio/video...';
      } else if (line.contains('[EmbedThumbnail]')) {
        currentStep = 'Embedding thumbnail...';
      }

      if (extractedTitle == null) {
        var titleMatch = destinationRegex.firstMatch(line);
        titleMatch ??= mergerRegex.firstMatch(line);
        if (titleMatch != null) {
          extractedTitle = titleMatch.group(1);
          if (extractedTitle != null) {
            extractedTitle = TitleCleanerService.clean(extractedTitle);
          }
          yield DownloadProgressEvent(
            progress: -1,
            totalSize: '',
            speed: '',
            eta: '',
            title: extractedTitle,
            step: currentStep,
          );
        }
      }

      // capture file path from 'Merging formats into' or 'Destination'
      // Only capture if it looks like a final file (not .part) or if it's a merger result
      // capture file path from 'Merging formats into' or 'Destination'
      if (line.contains('[Merger] Merging formats into')) {
        final match = RegExp(r'Merging formats into "(.*)"').firstMatch(line);
        if (match != null) {
          final rawPath = match.group(1)!;
          // Manual absolute path check for Windows/Linux
          if (rawPath.contains(':') ||
              rawPath.startsWith('/') ||
              rawPath.startsWith('\\')) {
            currentFilePath = rawPath;
          } else {
            currentFilePath = '$baseFolder\\$rawPath';
          }
          LoggerService.debug('Detected merged file path: $currentFilePath');
          yield DownloadProgressEvent(
            progress: -1,
            totalSize: '',
            speed: '',
            eta: '',
            title: extractedTitle,
            step: 'Merging audio/video...',
            filePath: currentFilePath,
          );
        }
      } else if (line.contains('[download] Destination:')) {
        final match = RegExp(r'Destination: (.*)$').firstMatch(line);
        if (match != null) {
          var rawPath = match.group(1)!;

          // Sanitize: strip temporary extensions if present
          rawPath = rawPath.replaceAll('.part', '');
          rawPath = rawPath.replaceAll('.ytdl', '');
          // Note: we don't strip .fhls or .f because those might be part of the actual desired filename before merger
          // and we want to know them to show partial previews if possible.

          if (rawPath.contains(':') ||
              rawPath.startsWith('/') ||
              rawPath.startsWith('\\')) {
            currentFilePath = rawPath;
          } else {
            currentFilePath = '$baseFolder\\$rawPath';
          }
          LoggerService.debug('Detected download file path: $currentFilePath');
          yield DownloadProgressEvent(
            progress: -1,
            totalSize: '',
            speed: '',
            eta: '',
            title: extractedTitle,
            step: 'Starting download...',
            filePath: currentFilePath,
          );
        }
      } else if (line.contains('Already downloaded') ||
          line.contains('has already been downloaded')) {
        // Handle case where file exists
        final match = RegExp(r': (.*)$').firstMatch(line);
        if (match != null) {
          currentFilePath = match.group(1);
        }
        // Yield duplicate event immediately
        yield DownloadProgressEvent(
          progress: 1.0,
          totalSize: '',
          speed: 'Dupliqué',
          eta: '',
          title: extractedTitle,
          step: 'Déjà téléchargé',
          filePath: currentFilePath,
          isDuplicate: true,
        );
        // We can stop here or let it finish naturally, but usually yt-dlp exits soon after.
      }

      // Also check for "Fixup" or "EmbedThumbnail" messages which often indicate final container
      if (line.contains('[Fixup') || line.contains('[EmbedThumbnail]')) {
        // Often regex is like: [FixupM4a] Correcting container of "C:\...\file.m4a"
        // or: [EmbedThumbnail] mutagen: Adding thumbnail to "C:\...\file.mp4"
        final match = RegExp(r'of "(.*?)"|to "(.*?)"').firstMatch(line);
        if (match != null) {
          final detected = match.group(1) ?? match.group(2);
          if (detected != null) {
            currentFilePath = detected;
            LoggerService.debug(
              'Refined path from post-processor: $currentFilePath',
            );
            yield DownloadProgressEvent(
              progress: -1,
              totalSize: '',
              speed: '',
              eta: '',
              title: extractedTitle,
              step: currentStep,
              filePath: currentFilePath,
            );
          }
        }
      }

      // Catch-all: If we see an absolute path in quotes that exists on disk and we don't have a final path yet
      if (currentFilePath == null || currentFilePath.contains('.part')) {
        final absolutePathMatch = RegExp(
          r'"([a-zA-Z]:[\\/][^"]+)"',
        ).firstMatch(line);
        if (absolutePathMatch != null) {
          final detected = absolutePathMatch.group(1);
          if (detected != null &&
              File(detected).existsSync() &&
              !detected.endsWith('.part') &&
              !detected.endsWith('.ytdl')) {
            currentFilePath = detected;
            LoggerService.debug(
              'Caught absolute path from fallback: $currentFilePath',
            );
          }
        }
      }

      // Parse progress
      var match = progressRegex.firstMatch(line);
      if (match != null) {
        hasProgress = true;
        final speedStr = match.group(3) ?? '';
        String displaySpeed = speedStr;

        // Convert to Mbps for display
        try {
          // Example: 2.70MiB/s
          final parts = speedStr.split(RegExp(r'[A-Za-z]'));
          if (parts.isNotEmpty) {
            double val = double.tryParse(parts.first) ?? 0.0;
            if (speedStr.contains('MiB/s')) {
              val = val * 8.388608; // 1 MiB = 8.38 Mb
            } else if (speedStr.contains('KiB/s')) {
              val = val * 0.008192;
            }
            if (val > 80.0) {
              LoggerService.i(
                'High Speed Download: ${val.toStringAsFixed(1)} Mbps',
              );
            }
            displaySpeed = '${val.toStringAsFixed(1)} Mbps';
          }
        } catch (e) {
          // ignore parsing error
        }

        final progress = double.parse(match.group(1)!) / 100;
        final totalSize = match.group(2) ?? '';
        final downloadedSize = _calculateDownloadedSize(totalSize, progress);

        yield DownloadProgressEvent(
          progress: progress,
          totalSize: totalSize,
          downloadedSize: downloadedSize,
          speed: displaySpeed,
          eta: match.group(4) ?? '',
          title: extractedTitle,
          step: currentStep,
          filePath: currentFilePath,
        );
      } else {
        match = hlsProgressRegex.firstMatch(line);
        if (match != null) {
          hasProgress = true;
          // Same speed logic for HLS
          final speedStr = match.group(3) ?? '';
          // ... conversion logic if needed ...
          yield DownloadProgressEvent(
            progress: double.parse(match.group(1)!) / 100,
            totalSize: match.group(2) ?? '',
            speed:
                speedStr, // Keep original for HLS for now to save tokens/time
            eta: '',
            title: extractedTitle,
            step: currentStep,
            filePath: currentFilePath,
          );
        }
      }
    }

    final exitCode = await process.exitCode;
    _downloadProcesses.remove(id);

    LoggerService.i('Process exited with code $exitCode');

    if (exitCode != 0) {
      LoggerService.e('Full Stderr: $errorBuffer'); // Log everything on error
      if (detectedException != null) throw detectedException!;
      throw YtDlpException(
        'yt-dlp exited with code $exitCode. Error: $errorBuffer',
      );
    }

    // Check for silent failure (exit code 0 but no download progress)
    if (!hasProgress) {
      LoggerService.w('No progress detected. Output:\n$outputBuffer');
      throw YtDlpException(
        'yt-dlp exited successfully but no download progress was detected. Output: $outputBuffer',
      );
    }
    // Final yields to ensure UI and Repo have the absolute latest state
    yield DownloadProgressEvent(
      progress: 1.0,
      totalSize: '',
      speed: 'Terminé',
      eta: '',
      title: extractedTitle,
      step: 'Fini',
      filePath: currentFilePath,
    );

    // Cleanup temporary files
    if (currentFilePath != null) {
      _cleanupTempFiles(currentFilePath);
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
              (name.endsWith('.part') ||
                  name.endsWith('.ytdl') ||
                  name.endsWith('.f\\d+') || // fragments like .f134
                  name.endsWith('.temp') ||
                  name.endsWith('.aria2'))) {
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
    } catch (_) {}
    return 'Other';
  }

  String _calculateDownloadedSize(String totalSizeStr, double progressPercent) {
    if (totalSizeStr.isEmpty || progressPercent <= 0) return '';
    if (totalSizeStr.contains('~')) {
      totalSizeStr = totalSizeStr.replaceAll('~', '');
    }

    try {
      // Parse unit
      final unitRegex = RegExp(r'([A-Za-z]+)');
      final valueRegex = RegExp(r'([\d\.]+)');

      final unitMatch = unitRegex.firstMatch(totalSizeStr);
      final valueMatch = valueRegex.firstMatch(totalSizeStr);

      if (unitMatch != null && valueMatch != null) {
        final unit = unitMatch.group(1)!;
        final totalVal = double.parse(valueMatch.group(1)!);

        final downloadedVal = totalVal * progressPercent;
        return '${downloadedVal.toStringAsFixed(2)}$unit';
      }
    } catch (e) {
      // ignore
    }
    return '';
  }

  bool _isCookieHeader(String? rawCookies) {
    if (rawCookies == null || rawCookies.isEmpty) {
      return false;
    }

    return !rawCookies.contains('\t') && rawCookies.contains('=');
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
