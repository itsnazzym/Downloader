import 'package:path/path.dart' as p;

/// Extracts and sanitizes creator metadata shared by downloader and playback.
class CreatorMetadataParser {
  const CreatorMetadataParser._();

  static String? extractCreatorFromUrl(String url) {
    if (url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      if (host.contains('tiktok.com')) {
        for (final segment in uri.pathSegments) {
          if (segment.startsWith('@')) {
            final clean = segment.replaceFirst(RegExp(r'^@+'), '').trim();
            if (clean.isNotEmpty) return clean;
          }
        }
        final match = RegExp(r'@([a-zA-Z0-9_.-]+)').firstMatch(url);
        if (match != null) return match.group(1);
      }

      if (host.contains('twitter.com') || host.contains('x.com')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final first = segments.first;
          const reserved = {
            'i',
            'intent',
            'search',
            'explore',
            'home',
            'notifications',
          };
          if (!reserved.contains(first.toLowerCase())) {
            return first.replaceFirst(RegExp(r'^@+'), '');
          }
        }
      }

      if (host.contains('youtube.com') || host.contains('youtu.be')) {
        final match = RegExp(r'@([a-zA-Z0-9_.-]+)').firstMatch(url);
        if (match != null) return match.group(1);
      }

      if (host.contains('instagram.com')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final first = segments.first;
          const reserved = {
            'p',
            'reel',
            'reels',
            'stories',
            'explore',
            'direct',
          };
          if (!reserved.contains(first.toLowerCase())) {
            return first.replaceFirst(RegExp(r'^@+'), '');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String sanitizeFolderName(String name) {
    var clean = name.trim().replaceFirst(RegExp(r'^@+'), '');
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
    if (clean.isEmpty) return 'Inconnu';
    return clean;
  }

  static String? extractCreatorFromTitleOrFilename(
    String? title,
    String? filePath,
  ) {
    final candidates = <String>[];
    if (title != null && title.trim().isNotEmpty) {
      candidates.add(title.trim());
    }
    if (filePath != null && filePath.trim().isNotEmpty) {
      candidates.add(p.basenameWithoutExtension(filePath).trim());
    }

    for (final text in candidates) {
      final creditMatch = RegExp(
        r'(?:credit|crédit|by|via|from)\s*[:\-]?\s*@?([a-zA-Z0-9_.-]{2,40})',
        caseSensitive: false,
      ).firstMatch(text);
      if (creditMatch != null) {
        final raw = creditMatch.group(1)!.trim();
        if (_isValidCreatorCandidate(raw)) {
          return sanitizeFolderName(raw);
        }
      }

      final dashMatch = RegExp(
        r'^(?:@)?([^\-\–\—\[\]]{2,50})\s*[\-\–\—]\s*',
      ).firstMatch(text);
      if (dashMatch != null) {
        final raw = dashMatch.group(1)!.trim();
        if (_isValidCreatorCandidate(raw)) {
          return sanitizeFolderName(raw);
        }
      }

      final bracketMatch = RegExp(
        r'^(?:@)?([^\-\–\—\[\]]{2,50})\s*\[[a-zA-Z0-9_\-]+\]',
      ).firstMatch(text);
      if (bracketMatch != null) {
        final raw = bracketMatch.group(1)!.trim();
        if (_isValidCreatorCandidate(raw)) {
          return sanitizeFolderName(raw);
        }
      }
    }
    return null;
  }

  static bool _isValidCreatorCandidate(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleaned.length < 2) return false;
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return false;
    const forbidden = {
      'video',
      'videos',
      'tweet',
      'tweets',
      'clip',
      'clips',
      'fhls',
      'audio',
      'imported',
      'inconnu',
      'unknown',
      'mp4',
      'webm',
      'status',
      'amplify_video',
    };
    return !forbidden.contains(cleaned.toLowerCase());
  }
}
