import 'dart:io';

import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';

/// One progress / status update emitted while parsing a yt-dlp output line.
class YtDlpProgressUpdate {
  final double progress;
  final String totalSize;
  final String downloadedSize;
  final String speed;
  final String eta;
  final String? title;
  final String step;
  final String? filePath;
  final bool isDuplicate;

  const YtDlpProgressUpdate({
    required this.progress,
    this.totalSize = '',
    this.downloadedSize = '',
    this.speed = '',
    this.eta = '',
    this.title,
    this.step = '',
    this.filePath,
    this.isDuplicate = false,
  });
}

/// Parses yt-dlp stdout/stderr lines for progress, destinations, and after_move paths.
///
/// With `--print after_move:%(filepath)s`, the final path is often on stdout while
/// `[download] xx%` lines land on stderr — callers must feed **both** streams here.
class YtDlpProgressParser {
  static final RegExp progressRegex = RegExp(
    r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?\s*([~\d\.]+\w+)\s+at\s+([~\d\.]+\w+/s)\s+ETA\s+([\d:]+)',
  );
  static final RegExp hlsProgressRegex = RegExp(
    r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?\s*([~\d\.]+\w+)\s+in\s+[\d:]+\s+at\s+([~\d\.]+\w+/s)',
  );
  static final RegExp destinationRegex = RegExp(
    r'\[download\] Destination: .*[/\\](.*?)(?:\.\w+)?$',
  );
  static final RegExp mergerRegex = RegExp(
    r'\[Merger\] Merging formats into "(.*?)(?:\.\w+)?"',
  );

  final String baseFolder;
  final String preferredExt;
  final bool Function(String path)? fileExistsSync;
  final int Function(String path)? fileLengthSync;

  bool hasProgress = false;
  String? afterMovePath;
  String? currentFilePath;
  String? extractedTitle;
  String currentStep = 'Initializing...';

  YtDlpProgressParser({
    required this.baseFolder,
    required this.preferredExt,
    this.fileExistsSync,
    this.fileLengthSync,
  });

  /// Process one stdout or stderr line; returns zero or more UI updates.
  List<YtDlpProgressUpdate> onLine(String line) {
    final updates = <YtDlpProgressUpdate>[];
    final trimmedLine = line.trim();

    _captureAfterMovePath(trimmedLine);
    _updateStepFromLine(line);

    if (extractedTitle == null) {
      var titleMatch = destinationRegex.firstMatch(line);
      titleMatch ??= mergerRegex.firstMatch(line);
      if (titleMatch != null) {
        extractedTitle = titleMatch.group(1);
        if (extractedTitle != null) {
          extractedTitle = TitleCleanerService.clean(extractedTitle!);
        }
        updates.add(
          YtDlpProgressUpdate(
            progress: -1,
            title: extractedTitle,
            step: currentStep,
          ),
        );
      }
    }

    final pathUpdate = _captureFilePathFromLine(line);
    if (pathUpdate != null) {
      updates.add(pathUpdate);
    }

    if (line.contains('Already downloaded') ||
        line.contains('has already been downloaded')) {
      hasProgress = true;
      final match = RegExp(r': (.*)$').firstMatch(line);
      if (match != null) {
        currentFilePath = match.group(1);
      }
      updates.add(
        YtDlpProgressUpdate(
          progress: 1.0,
          speed: 'Dupliqué',
          title: extractedTitle,
          step: 'Déjà téléchargé',
          filePath: currentFilePath,
          isDuplicate: true,
        ),
      );
    }

    final progressUpdate = _parseProgress(line);
    if (progressUpdate != null) {
      updates.add(progressUpdate);
    }

    return updates;
  }

  /// Whether exit 0 should count as success without `[download]` percent lines.
  ///
  /// True when [hasProgress] is set, or a non-fragment resolved file exists
  /// with `length > 0`.
  bool isSuccessfulExit({String? outputFolder, String? videoId}) {
    if (hasProgress) return true;
    return resolvedFileHasContent(
      candidatePath: afterMovePath ?? currentFilePath,
      outputFolder: outputFolder ?? baseFolder,
      videoId: videoId,
      preferredExtension: preferredExt,
      fileExistsSync: fileExistsSync,
      fileLengthSync: fileLengthSync,
    );
  }

  /// Resolve [candidatePath] and check non-fragment file length &gt; 0.
  static bool resolvedFileHasContent({
    required String? candidatePath,
    String? outputFolder,
    String? videoId,
    String preferredExtension = '.mp4',
    bool Function(String path)? fileExistsSync,
    int Function(String path)? fileLengthSync,
  }) {
    final resolved = DownloadFileResolver.resolve(
      candidatePath: candidatePath,
      outputFolder: outputFolder,
      videoId: videoId,
      preferredExtension: preferredExtension,
      existsSync: fileExistsSync,
    );
    if (resolved == null) return false;
    if (DownloadFileResolver.isFragmentPath(resolved)) return false;

    try {
      if (fileLengthSync != null) {
        return fileLengthSync(resolved) > 0;
      }
      final file = File(resolved);
      if (!file.existsSync()) return false;
      return file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  void _captureAfterMovePath(String trimmedLine) {
    final exists = fileExistsSync ?? (String p) => File(p).existsSync();
    final looksAbsoluteWindows = DownloadFileResolver.absoluteWindowsPath
        .hasMatch(trimmedLine);
    final looksAbsoluteUnix =
        trimmedLine.startsWith('/') &&
        !trimmedLine.startsWith('--') &&
        trimmedLine.contains('/') &&
        exists(trimmedLine);

    if (!looksAbsoluteWindows && !looksAbsoluteUnix) return;

    if (DownloadFileResolver.isVideoPath(trimmedLine) ||
        trimmedLine.toLowerCase().endsWith(preferredExt)) {
      afterMovePath = DownloadFileResolver.normalizePath(trimmedLine);
      currentFilePath = afterMovePath;
    }
  }

  void _updateStepFromLine(String line) {
    if (line.contains('[download]')) {
      hasProgress = true;
      if (line.contains('Downloading') && line.contains('format')) {
        currentStep = 'Downloading video...';
      } else if (line.contains('Destination')) {
        currentStep = 'Saving file...';
      }
    } else if (line.contains('[Merger]')) {
      currentStep = 'Merging audio/video...';
    } else if (line.contains('[EmbedThumbnail]')) {
      currentStep = 'Embedding thumbnail...';
    } else if (line.contains('[VideoConvertor]') ||
        line.contains('[VideoRemuxer]')) {
      currentStep = 'Converting video...';
    }
  }

  YtDlpProgressUpdate? _captureFilePathFromLine(String line) {
    if (line.contains('[Merger] Merging formats into')) {
      final match = RegExp(r'Merging formats into "(.*)"').firstMatch(line);
      if (match != null) {
        currentFilePath = _toAbsolutePath(match.group(1)!);
        return YtDlpProgressUpdate(
          progress: -1,
          title: extractedTitle,
          step: 'Merging audio/video...',
          filePath: currentFilePath,
        );
      }
    } else if (line.contains('[download] Destination:') ||
        line.contains('[VideoConvertor] Destination:') ||
        line.contains('[VideoRemuxer] Destination:')) {
      final match = RegExp(r'Destination: (.*)$').firstMatch(line);
      if (match != null) {
        var rawPath = match.group(1)!;
        rawPath = rawPath.replaceAll('.part', '');
        rawPath = rawPath.replaceAll('.ytdl', '');
        currentFilePath = _toAbsolutePath(rawPath);
        return YtDlpProgressUpdate(
          progress: -1,
          title: extractedTitle,
          step: line.contains('VideoConvertor') || line.contains('VideoRemuxer')
              ? 'Converting video...'
              : 'Starting download...',
          filePath: currentFilePath,
        );
      }
    }

    if (line.contains('[Fixup') || line.contains('[EmbedThumbnail]')) {
      final match = RegExp(r'of "(.*?)"|to "(.*?)"').firstMatch(line);
      if (match != null) {
        final detected = match.group(1) ?? match.group(2);
        if (detected != null) {
          currentFilePath = detected;
          return YtDlpProgressUpdate(
            progress: -1,
            title: extractedTitle,
            step: currentStep,
            filePath: currentFilePath,
          );
        }
      }
    }

    if (currentFilePath == null || currentFilePath!.contains('.part')) {
      final absolutePathMatch = RegExp(
        r'"([a-zA-Z]:[\\/][^"]+)"',
      ).firstMatch(line);
      if (absolutePathMatch != null) {
        final detected = absolutePathMatch.group(1);
        final exists = fileExistsSync ?? (String p) => File(p).existsSync();
        if (detected != null &&
            exists(detected) &&
            !detected.endsWith('.part') &&
            !detected.endsWith('.ytdl')) {
          currentFilePath = detected;
        }
      }
    }

    return null;
  }

  YtDlpProgressUpdate? _parseProgress(String line) {
    var match = progressRegex.firstMatch(line);
    if (match != null) {
      hasProgress = true;
      final speedStr = match.group(3) ?? '';
      final progress = double.parse(match.group(1)!) / 100;
      final totalSize = match.group(2) ?? '';
      return YtDlpProgressUpdate(
        progress: progress,
        totalSize: totalSize,
        downloadedSize: calculateDownloadedSize(totalSize, progress),
        speed: formatSpeedMbps(speedStr),
        eta: match.group(4) ?? '',
        title: extractedTitle,
        step: currentStep,
        filePath: currentFilePath,
      );
    }

    match = hlsProgressRegex.firstMatch(line);
    if (match != null) {
      hasProgress = true;
      final speedStr = match.group(3) ?? '';
      return YtDlpProgressUpdate(
        progress: double.parse(match.group(1)!) / 100,
        totalSize: match.group(2) ?? '',
        speed: speedStr,
        title: extractedTitle,
        step: currentStep,
        filePath: currentFilePath,
      );
    }

    return null;
  }

  String _toAbsolutePath(String rawPath) {
    if (rawPath.contains(':') ||
        rawPath.startsWith('/') ||
        rawPath.startsWith('\\')) {
      return rawPath;
    }
    return '$baseFolder\\$rawPath';
  }

  /// Convert yt-dlp speed strings (e.g. `2.70MiB/s`) to Mbps display.
  static String formatSpeedMbps(String speedStr) {
    if (speedStr.isEmpty) return speedStr;
    try {
      final parts = speedStr.split(RegExp(r'[A-Za-z]'));
      if (parts.isEmpty) return speedStr;
      var val = double.tryParse(parts.first) ?? 0.0;
      if (speedStr.contains('MiB/s')) {
        val = val * 8.388608;
      } else if (speedStr.contains('KiB/s')) {
        val = val * 0.008192;
      }
      return '${val.toStringAsFixed(1)} Mbps';
    } catch (_) {
      return speedStr;
    }
  }

  static String calculateDownloadedSize(
    String totalSizeStr,
    double progressPercent,
  ) {
    if (totalSizeStr.isEmpty || progressPercent <= 0) return '';
    var cleaned = totalSizeStr;
    if (cleaned.contains('~')) {
      cleaned = cleaned.replaceAll('~', '');
    }

    try {
      final unitRegex = RegExp(r'([A-Za-z]+)');
      final valueRegex = RegExp(r'([\d\.]+)');
      final unitMatch = unitRegex.firstMatch(cleaned);
      final valueMatch = valueRegex.firstMatch(cleaned);
      if (unitMatch != null && valueMatch != null) {
        final unit = unitMatch.group(1)!;
        final totalVal = double.parse(valueMatch.group(1)!);
        final downloadedVal = totalVal * progressPercent;
        return '${downloadedVal.toStringAsFixed(2)}$unit';
      }
    } catch (_) {}
    return '';
  }
}
