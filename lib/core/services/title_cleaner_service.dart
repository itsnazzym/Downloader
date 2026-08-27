import 'package:modern_downloader/core/logger/logger_service.dart';

class TitleCleanerService {
  static final RegExp _spamPatterns = RegExp(
    r'(\(Official Video\)|\[Official Video\]|\(Lyrics\)|\(Audio\)|\[4K\]|\[HD\]|\(feat\..*?\)|\(ft\..*?\))',
    caseSensitive: false,
  );

  static final RegExp _emojiPattern = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  /// Full URLs and common short-link forms that must be stripped *before*
  /// removing Windows-illegal characters (`:` `/`), otherwise
  /// `https://t.co/abc` collapses into `httpst.coabc`.
  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"]+'
    r'|www\.[^\s<>"]+'
    r'|t\.co/[A-Za-z0-9]+'
    r'|x\.com/[^\s<>"]+'
    r'|twitter\.com/[^\s<>"]+',
    caseSensitive: false,
  );

  /// Already-collapsed short links after a prior bad sanitize, e.g. `httpst.coCSJb`.
  static final RegExp _collapsedUrlPattern = RegExp(
    r'https?t\.co[A-Za-z0-9]+'
    r'|https?x\.com[A-Za-z0-9/_-]+'
    r'|https?twitter\.com[A-Za-z0-9/_-]+',
    caseSensitive: false,
  );

  /// Max length for the human-readable stem (id suffix kept separately).
  static const int maxStemLength = 100;

  static String clean(String title) {
    String cleaned = title;

    // Remove Emoji
    cleaned = cleaned.replaceAll(_emojiPattern, '');

    // Remove Spam patterns
    cleaned = cleaned.replaceAll(_spamPatterns, '');

    // Strip URLs BEFORE removing `:` and `/` (critical for t.co titles)
    cleaned = cleaned.replaceAll(_urlPattern, ' ');
    cleaned = cleaned.replaceAll(_collapsedUrlPattern, ' ');

    // Remove pipes and other separators often used in YouTube titles
    cleaned = cleaned.replaceAll('|', '-');

    // Remove strictly restricted Windows characters: < > : " / \ | ? *
    cleaned = cleaned.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    // Remove technical suffixes (yt-dlp fragments)
    cleaned = cleaned.replaceAll(RegExp(r'\.fhls-\d+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\.f\d+'), '');
    cleaned = cleaned.replaceAll('.part', '');
    cleaned = cleaned.replaceAll('.ytdl', '');

    // Remove [id] suffixes added for filesystem uniqueness
    // Matches patterns like [abc123], [dQw4w9WgXcQ], [1234567890], [z8f3k]
    cleaned = cleaned.replaceAll(RegExp(r'\s*\[[a-zA-Z0-9_-]+\]\s*$'), '');

    // Collapse multiple spaces / leftover hyphens from URL-only titles
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^[-_.\s]+|[-_.\s]+$'), '');
    cleaned = cleaned.trim();

    // Truncate stem to avoid path length issues (keep room for [id].ext)
    if (cleaned.length > maxStemLength) {
      cleaned = '${cleaned.substring(0, maxStemLength - 3)}...';
    }

    if (cleaned != title) {
      LoggerService.debug('Title cleaned: "$title" -> "$cleaned"');
    }

    return cleaned;
  }

  /// True when the title is empty or only a (possibly collapsed) URL / punctuation.
  static bool isUrlOnlyTitle(String? title) {
    if (title == null) return true;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return true;
    if (RegExp(r'^[-_.\s]+$').hasMatch(trimmed)) return true;

    // Raw URL
    if (_urlPattern.hasMatch(trimmed)) {
      final withoutUrls = trimmed
          .replaceAll(_urlPattern, '')
          .replaceAll(RegExp(r'[-_.\s]+'), '')
          .trim();
      if (withoutUrls.isEmpty) return true;
    }

    // Collapsed form produced by old sanitizer: `- httpst.coCSJbBJRpXf`
    if (_collapsedUrlPattern.hasMatch(trimmed)) {
      final without = trimmed
          .replaceAll(_collapsedUrlPattern, '')
          .replaceAll(RegExp(r'[-_.\s]+'), '')
          .trim();
      if (without.isEmpty) return true;
    }

    // After clean(), URL-only becomes empty
    final cleaned = clean(trimmed);
    return cleaned.isEmpty;
  }

  /// Build a filesystem-safe filename stem, truncated for MAX_PATH.
  static String filenameStem(String title, {int maxLength = maxStemLength}) {
    var stem = clean(title);
    if (stem.length > maxLength) {
      stem = '${stem.substring(0, maxLength - 3)}...';
    }
    return stem;
  }

  static String deriveTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Strategy 1: Last path segment
      if (uri.pathSegments.isNotEmpty) {
        String lastSegment = uri.pathSegments.last;

        // Remove file extension if present
        if (lastSegment.contains('.')) {
          lastSegment = lastSegment.split('.').first;
        }

        // Replace hyphens/underscores with spaces
        lastSegment = lastSegment.replaceAll(RegExp(r'[-_]'), ' ');

        // Filter out obviously bad titles (just numbers)
        if (RegExp(r'^\d+$').hasMatch(lastSegment)) {
          // If it's x.com or twitter.com, try to get the uploader/handle from the URL
          if (url.contains('x.com') || url.contains('twitter.com')) {
            String? handle;
            if (uri.pathSegments.length >= 2) {
              handle = uri.pathSegments[0];
            }
            if (handle != null && handle != 'status' && handle != 'i') {
              return '$handle - $lastSegment';
            }
            return 'Tweet $lastSegment';
          }
          return 'Video $lastSegment';
        }

        return clean(lastSegment);
      }
    } catch (e) {
      // ignore
    }
    return 'Video_${DateTime.now().millisecondsSinceEpoch}';
  }
}
