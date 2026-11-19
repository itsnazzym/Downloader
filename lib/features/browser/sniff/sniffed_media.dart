/// What the in-app browser saw a page load: manifests and media files, with
/// what is needed to fetch them the same way the browser did.
enum SniffedKind { hls, dash, video, audio }

class SniffedMedia {
  const SniffedMedia({
    required this.url,
    required this.kind,
    required this.page,
    this.referer,
    this.origin,
    this.userAgent,
    this.timestamp = 0,
  });

  final String url;
  final SniffedKind kind;

  /// The page that loaded it (the address in the browser at that time).
  final String page;
  final String? referer;
  final String? origin;
  final String? userAgent;
  final int timestamp;

  Uri? get uri => Uri.tryParse(url);

  String get host => (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');

  /// Last path segment, for display.
  String get fileName {
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments == null || segments.isEmpty) return host;
    return segments.last;
  }

  /// "720" for ".../720p/..." or ".../1280x720...", when the address says so.
  int? get heightHint => SniffedMediaFilter.heightHint(url);

  factory SniffedMedia.fromMap(Map<Object?, Object?> map) {
    final url = (map['url'] as String?) ?? '';
    return SniffedMedia(
      url: url,
      kind: SniffedMediaFilter.classify(url) ?? SniffedKind.video,
      page: (map['page'] as String?) ?? '',
      referer: map['referer'] as String?,
      origin: map['origin'] as String?,
      userAgent: map['userAgent'] as String?,
      timestamp: (map['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Turns the raw list of requests into the few streams worth offering.
class SniffedMediaFilter {
  SniffedMediaFilter._();

  static const List<String> _adHosts = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adnxs.com',
    'outbrain.com',
    'taboola.com',
    'criteo.com',
    'pubmatic.com',
    'scorecardresearch.com',
    'serving-sys.com',
    'adform.net',
    'bidswitch.net',
    'adroll.com',
    'amazon-adsystem.com',
    'moatads.com',
    'innovid.com',
    'imasdk.googleapis.com',
    'adsafeprotected.com',
    'smartadserver.com',
    'rubiconproject.com',
    'openx.net',
  ];

  static bool isAd(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return true;
    for (final ad in _adHosts) {
      if (host == ad || host.endsWith('.$ad')) return true;
    }
    return false;
  }

  static SniffedKind? classify(String url) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    if (path.contains('.m3u8')) return SniffedKind.hls;
    if (path.contains('.mpd') ||
        path.contains('.ism/manifest') ||
        path.endsWith('/manifest')) {
      return SniffedKind.dash;
    }
    if (path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.ogg') ||
        path.endsWith('.opus') ||
        path.endsWith('.flac')) {
      return SniffedKind.audio;
    }
    if (path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.m4v') ||
        path.endsWith('.mov') ||
        path.endsWith('.mkv')) {
      return SniffedKind.video;
    }
    if (path.endsWith('/playlist.json') || path.endsWith('/master.json')) {
      return SniffedKind.dash;
    }
    return null;
  }

  static int? heightHint(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final p = RegExp(r'(?<![0-9])(\d{3,4})p(?![a-z0-9])').firstMatch(path);
    if (p != null) return int.parse(p.group(1)!);
    final x = RegExp(
      r'(?<![0-9])(\d{3,4})x(\d{3,4})(?![0-9])',
    ).firstMatch(path);
    if (x != null) {
      final a = int.parse(x.group(1)!);
      final b = int.parse(x.group(2)!);
      return a < b ? a : b;
    }
    return null;
  }

  /// Variant playlists (a single quality or the audio track of an HLS
  /// stream) that are better left to their master playlist.
  static bool _looksLikeVariant(String url) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    final name = path.split('/').last;
    if (heightHint(url) != null && !name.contains('master')) return true;
    return RegExp(
      r'(chunklist|media_|_audio|audio_|index_\d|playlist_\d|variant|rendition)',
    ).hasMatch(name);
  }

  static bool _looksLikeMaster(String url) {
    final name = (Uri.tryParse(url)?.path ?? '').toLowerCase().split('/').last;
    return name.contains('master') ||
        name.contains('playlist') ||
        name.contains('index') ||
        name.contains('manifest');
  }

  /// Best first: manifests (masters before variants), then files by height.
  static List<SniffedMedia> rank(Iterable<SniffedMedia> raw) {
    final byPath = <String, SniffedMedia>{};
    for (final m in raw) {
      if (isAd(m.url)) continue;
      final uri = m.uri;
      if (uri == null) continue;
      // The same stream is often requested again with a fresh token.
      byPath['${uri.host}${uri.path}'] = m;
    }
    var list = byPath.values.toList();
    final hasMaster = list.any(
      (m) => m.kind == SniffedKind.hls && !_looksLikeVariant(m.url),
    );
    if (hasMaster) {
      list = [
        for (final m in list)
          if (!(m.kind == SniffedKind.hls && _looksLikeVariant(m.url))) m,
      ];
    }
    int weight(SniffedMedia m) {
      switch (m.kind) {
        case SniffedKind.hls:
          return _looksLikeMaster(m.url) ? 0 : 1;
        case SniffedKind.dash:
          return 2;
        case SniffedKind.video:
          return 3;
        case SniffedKind.audio:
          return 4;
      }
    }

    list.sort((a, b) {
      final w = weight(a).compareTo(weight(b));
      if (w != 0) return w;
      final h = (b.heightHint ?? 0).compareTo(a.heightHint ?? 0);
      if (h != 0) return h;
      return b.timestamp.compareTo(a.timestamp);
    });
    return list;
  }

  /// Joins Netscape cookie files (one per host) into one, keeping a single
  /// header line.
  static String mergeNetscape(Iterable<String> bodies) {
    final out = StringBuffer('# Netscape HTTP Cookie File\n');
    final seen = <String>{};
    for (final body in bodies) {
      for (final line in body.split('\n')) {
        final trimmed = line.trimRight();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (seen.add(trimmed)) out.writeln(trimmed);
      }
    }
    return out.toString();
  }
}
