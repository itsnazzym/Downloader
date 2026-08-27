/// Resolves a known media platform from a URL, folder, or file path.
/// Never returns "Local" / "Other" — unknown origin is [null].
class MediaSourceResolver {
  MediaSourceResolver._();

  static const Set<String> knownFolders = {
    'twitter',
    'youtube',
    'instagram',
    'tiktok',
    'twitch',
    'kick',
    'reddit',
    'facebook',
    'xnxx',
    'xhamster',
    'pornhub',
    'xvideos',
    'vimeo',
    'dailymotion',
    'soundcloud',
  };

  static const Map<String, String> _labels = {
    'youtube': 'YouTube',
    'youtu': 'YouTube',
    'twitter': 'Twitter',
    'instagram': 'Instagram',
    'tiktok': 'TikTok',
    'twitch': 'Twitch',
    'kick': 'Kick',
    'reddit': 'Reddit',
    'redd': 'Reddit',
    'facebook': 'Facebook',
    'fb': 'Facebook',
    'xnxx': 'Xnxx',
    'xhamster': 'Xhamster',
    'pornhub': 'Pornhub',
    'xvideos': 'XVideos',
    'vimeo': 'Vimeo',
    'dailymotion': 'Dailymotion',
    'soundcloud': 'SoundCloud',
  };

  static String? resolve({String? url, String? filePath}) {
    final fromUrl = fromUrlString(url);
    if (fromUrl != null) return fromUrl;
    return fromFilePath(filePath);
  }

  static String? fromUrlString(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url.trim());
      var host = uri.host.toLowerCase();
      if (host.isEmpty && uri.scheme == 'imported') {
        host = uri.path.toLowerCase();
      }
      if (host.isEmpty) return null;

      if (host.endsWith('.detected')) {
        final folder = host.split('.').first;
        if (folder == 'local' || folder == 'unknown') return null;
        return _labelForToken(folder);
      }

      if (host == 'x.com' || host.endsWith('.x.com')) return 'Twitter';
      if (host.contains('twitter')) return 'Twitter';
      if (host.contains('youtu')) return 'YouTube';
      if (host.contains('instagram')) return 'Instagram';
      if (host.contains('tiktok')) return 'TikTok';
      if (host.contains('twitch')) return 'Twitch';
      if (host.contains('kick') && !host.contains('kickstarter')) {
        return 'Kick';
      }
      if (host.contains('reddit') || host.contains('redd.it')) return 'Reddit';
      if (host.contains('facebook') ||
          host.contains('fb.com') ||
          host.contains('fb.watch')) {
        return 'Facebook';
      }
      if (host.contains('xnxx')) return 'Xnxx';
      if (host.contains('xhamster')) return 'Xhamster';
      if (host.contains('pornhub')) return 'Pornhub';
      if (host.contains('xvideos')) return 'XVideos';
      if (host.contains('vimeo')) return 'Vimeo';
      if (host.contains('dailymotion')) return 'Dailymotion';
      if (host.contains('soundcloud')) return 'SoundCloud';

      return null;
    } catch (_) {
      return null;
    }
  }

  static String? fromFilePath(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return null;
    final parts = filePath
        .replaceAll('\\', '/')
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    // Parent folders first (skip filename).
    for (var i = parts.length - 2; i >= 0 && i >= parts.length - 5; i--) {
      final label = _labelForToken(parts[i].toLowerCase());
      if (label != null) return label;
    }
    return null;
  }

  static String? _labelForToken(String token) {
    if (!knownFolders.contains(token) && !_labels.containsKey(token)) {
      return null;
    }
    return _labels[token] ??
        (token.isEmpty
            ? null
            : '${token[0].toUpperCase()}${token.substring(1)}');
  }
}
