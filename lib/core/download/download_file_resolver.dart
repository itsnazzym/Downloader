import 'dart:io';

import 'package:modern_downloader/core/download/temp_file_cleanup.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';

/// Resolves the real on-disk video file after yt-dlp finishes.
///
/// yt-dlp often reports intermediate destinations (fragments, pre-remux
/// containers). The UI preview needs a path that [File.existsSync] accepts.
class DownloadFileResolver {
  static const List<String> videoExtensions = [
    '.mp4',
    '.mkv',
    '.webm',
    '.mov',
    '.avi',
    '.m4v',
    '.flv',
    '.3gp',
  ];

  static const List<String> audioExtensions = [
    '.mp3',
    '.aac',
    '.opus',
    '.m4a',
    '.ogg',
    '.flac',
    '.wav',
    '.wma',
  ];

  /// Matches yt-dlp fragment names like `name.f401.mp4` or `name.f401`.
  static final RegExp _fragmentName = RegExp(
    r'\.f\d+(?:\.\w+)?$',
    caseSensitive: false,
  );

  /// Bracket id embedded in filenames: `Title [209191506225657].mp4`.
  static final RegExp _bracketId = RegExp(r'\[([^\]]+)\]');

  /// Absolute Windows path printed by yt-dlp `--print after_move:…`.
  static final RegExp absoluteWindowsPath = RegExp(r'^[a-zA-Z]:[\\/].+');

  /// Trim + normalize separators for existence checks.
  static String normalizePath(String path) {
    var cleaned = path.trim();
    if (cleaned.startsWith('"') &&
        cleaned.endsWith('"') &&
        cleaned.length > 1) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    return cleaned;
  }

  /// True when [name] looks like a yt-dlp intermediate fragment.
  static bool isFragmentPath(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    if (TempFileCleanup.isFragmentOrTemp(name)) return true;
    return _fragmentName.hasMatch(name);
  }

  /// Prefer an existing non-fragment file for [candidatePath].
  ///
  /// Falls back to extension swaps and optional [videoId] directory scan.
  static String? resolve({
    required String? candidatePath,
    String? outputFolder,
    String? videoId,
    String preferredExtension = '.mp4',
    bool Function(String path)? existsSync,
  }) {
    final exists = existsSync ?? _defaultExists;
    final preferred = preferredExtension.startsWith('.')
        ? preferredExtension.toLowerCase()
        : '.$preferredExtension'.toLowerCase();

    final candidates = <String>[];

    if (candidatePath != null && candidatePath.trim().isNotEmpty) {
      final normalized = normalizePath(candidatePath);
      candidates.add(normalized);
      candidates.addAll(_extensionSwapCandidates(normalized, preferred));
      candidates.addAll(_fragmentStripCandidates(normalized, preferred));
    }

    for (final path in candidates) {
      final resolved = _firstExistingNonFragment(path, exists);
      if (resolved != null) return resolved;
    }

    final searchDir = _searchDirectory(candidatePath, outputFolder);
    if (searchDir != null && videoId != null && videoId.isNotEmpty) {
      final byId = findByVideoId(
        directory: searchDir,
        videoId: videoId,
        preferredExtension: preferred,
        existsSync: exists,
      );
      if (byId != null) return byId;
    }

    return null;
  }

  /// Scan [directory] for `*[videoId]*` video files; prefer preferred ext, then newest.
  static String? findByVideoId({
    required String directory,
    required String videoId,
    String preferredExtension = '.mp4',
    bool Function(String path)? existsSync,
  }) {
    final exists = existsSync ?? _defaultExists;
    final dir = Directory(directory);
    if (!dir.existsSync()) return null;

    final needle = videoId.toLowerCase();
    final preferred = preferredExtension.toLowerCase();
    final matches = <File>[];

    try {
      for (final entity in dir.listSync(recursive: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path.split(RegExp(r'[/\\]')).last;
        if (isFragmentPath(entity.path)) continue;
        if (!isVideoPath(entity.path)) continue;
        final lower = name.toLowerCase();
        if (!lower.contains(needle)) continue;
        if (!exists(entity.path)) continue;
        matches.add(entity);
      }
    } catch (_) {
      return null;
    }

    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final aPref = a.path.toLowerCase().endsWith(preferred) ? 0 : 1;
      final bPref = b.path.toLowerCase().endsWith(preferred) ? 0 : 1;
      if (aPref != bPref) return aPref.compareTo(bPref);
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return 0;
      }
    });

    return matches.first.path;
  }

  /// Extract bracket id from a title or filename: `foo [abc].mp4` → `abc`.
  static String? extractBracketId(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _bracketId.firstMatch(text);
    return match?.group(1);
  }

  static bool isVideoPath(String path) {
    final lower = path.toLowerCase();
    return videoExtensions.any(lower.endsWith);
  }

  static bool isAudioPath(String path) {
    final lower = path.toLowerCase();
    return audioExtensions.any(lower.endsWith);
  }

  /// Video, audio, or inspector-previewable partial / HLS paths.
  static bool isMediaPath(String path) {
    final lower = path.toLowerCase();
    if (isVideoPath(lower) || isAudioPath(lower)) return true;
    return lower.contains('.fhls') || lower.endsWith('.part');
  }

  /// Resolve an on-disk playable media path for [candidatePath].
  ///
  /// Same resolution strategy as the download inspector preview, then
  /// returns null when the result is missing or not media.
  static String? resolvePlayablePath(
    String? candidatePath, {
    String? title,
    String? outputFolder,
    bool Function(String path)? existsSync,
  }) {
    final exists = existsSync ?? _defaultExists;
    final videoId = extractBracketId(candidatePath) ?? extractBracketId(title);

    if (candidatePath != null && candidatePath.isNotEmpty) {
      final resolved = resolve(
        candidatePath: candidatePath,
        outputFolder: outputFolder,
        videoId: videoId,
        preferredExtension: '.mp4',
        existsSync: exists,
      );
      if (resolved != null && isMediaPath(resolved)) return resolved;

      // Legacy fallback: append common extensions if path has none
      final extensions = ['.mp4', '.mkv', '.webm', '.mov'];
      for (final ext in extensions) {
        if (!candidatePath.toLowerCase().endsWith(ext)) {
          final newPath = '$candidatePath$ext';
          if (exists(newPath) && isMediaPath(newPath)) return newPath;
        }
      }
    }

    // Path missing/stale: try locating by video id in the parent folder
    if (videoId != null && candidatePath != null && candidatePath.isNotEmpty) {
      try {
        final dir = File(normalizePath(candidatePath)).parent.path;
        final byId = findByVideoId(
          directory: dir,
          videoId: videoId,
          existsSync: exists,
        );
        if (byId != null && isMediaPath(byId)) return byId;
      } catch (_) {}
    }

    return null;
  }

  /// Try long-path prefix on Windows when a long path fails [existsSync].
  static String? withLongPathPrefix(String path) {
    if (!Platform.isWindows) return path;
    final normalized = normalizePath(path);
    if (normalized.startsWith(r'\\?\')) return normalized;
    if (normalized.length <= 240) return normalized;
    final absolute = normalized.contains(':')
        ? normalized
        : File(normalized).absolute.path;
    return r'\\?\' + absolute.replaceAll('/', r'\');
  }

  static bool _defaultExists(String path) {
    try {
      if (File(path).existsSync()) return true;
      final long = withLongPathPrefix(path);
      if (long != null && long != path && File(long).existsSync()) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String? _firstExistingNonFragment(
    String path,
    bool Function(String path) exists,
  ) {
    if (!exists(path)) {
      final long = withLongPathPrefix(path);
      if (long != null && long != path && exists(long)) {
        // Return the form that exists; prefer unprefixed if both work
        return exists(path) ? path : long;
      }
      return null;
    }
    if (isFragmentPath(path)) return null;
    return path;
  }

  static List<String> _extensionSwapCandidates(String path, String preferred) {
    final results = <String>[];
    final lower = path.toLowerCase();

    // Strip known video extension then append preferred / alternatives
    String? stem;
    for (final ext in videoExtensions) {
      if (lower.endsWith(ext)) {
        stem = path.substring(0, path.length - ext.length);
        break;
      }
    }
    stem ??= path;

    final exts = <String>[preferred, ...videoExtensions];
    final seen = <String>{};
    for (final ext in exts) {
      final candidate = '$stem$ext';
      if (seen.add(candidate.toLowerCase()) && candidate != path) {
        results.add(candidate);
      }
    }
    return results;
  }

  /// `video.f401.mp4` → `video.mp4`; `video.f401` → `video.mp4`
  static List<String> _fragmentStripCandidates(String path, String preferred) {
    final results = <String>[];
    final match = _fragmentName.firstMatch(path);
    if (match == null) return results;

    final stem = path.substring(0, match.start);
    results.add('$stem$preferred');
    for (final ext in videoExtensions) {
      final candidate = '$stem$ext';
      if (candidate != results.first) results.add(candidate);
    }
    return results;
  }

  /// Human-readable size from disk, or null if the file is missing/empty.
  static String? formattedFileSize(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(normalizePath(path));
      if (!file.existsSync()) return null;
      final bytes = file.lengthSync();
      if (bytes <= 0) return null;
      return FormatUtils.formatBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Stored yt-dlp size if present, otherwise the on-disk size.
  static String displaySize({
    required String storedTotalSize,
    String? filePath,
    required String unknownLabel,
  }) {
    if (storedTotalSize.trim().isNotEmpty) return storedTotalSize;
    return formattedFileSize(filePath) ?? unknownLabel;
  }

  static String? _searchDirectory(String? candidatePath, String? outputFolder) {
    if (candidatePath != null && candidatePath.trim().isNotEmpty) {
      try {
        final parent = File(normalizePath(candidatePath)).parent.path;
        if (parent.isNotEmpty) return parent;
      } catch (_) {}
    }
    if (outputFolder != null && outputFolder.trim().isNotEmpty) {
      return outputFolder.trim();
    }
    return null;
  }
}
