/// Kick HLS catalog helpers.
///
/// Reconstructs public IVS/HLS playlist URLs from Kick VOD metadata
/// (channel id, recording id, UTC start time). Inspired by the
/// Apache-2.0 KickNoSub project (Enmn/KickNoSub), rewritten and extended.
library;

import 'dart:convert';

enum KickContentKind { vod, live, clip, unknown }

class KickPageRef {
  final KickContentKind kind;
  final String channelSlug;
  final String? contentId;

  const KickPageRef({
    required this.kind,
    required this.channelSlug,
    this.contentId,
  });

  bool get isVod => kind == KickContentKind.vod;
  bool get isLive => kind == KickContentKind.live;
  bool get isClip => kind == KickContentKind.clip;

  static bool isKickHost(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'kick.com' ||
        host == 'www.kick.com' ||
        host == 'web.kick.com' ||
        host.endsWith('.kick.com');
  }

  static KickPageRef? tryParse(String rawUrl) {
    if (!isKickHost(rawUrl)) return null;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;

    final channelSlug = segments.first;
    if (_reservedSlugs.contains(channelSlug.toLowerCase())) return null;

    if (segments.length >= 3) {
      final kindSegment = segments[1].toLowerCase();
      final id = segments[2];
      if (kindSegment == 'videos' || kindSegment == 'video') {
        return KickPageRef(
          kind: KickContentKind.vod,
          channelSlug: channelSlug,
          contentId: id,
        );
      }
      if (kindSegment == 'clips' || kindSegment == 'clip') {
        return KickPageRef(
          kind: KickContentKind.clip,
          channelSlug: channelSlug,
          contentId: id,
        );
      }
    }

    if (segments.length == 1) {
      return KickPageRef(kind: KickContentKind.live, channelSlug: channelSlug);
    }

    return KickPageRef(
      kind: KickContentKind.unknown,
      channelSlug: channelSlug,
      contentId: segments.length > 1 ? segments.last : null,
    );
  }

  static const Set<String> _reservedSlugs = {
    'api',
    'search',
    'categories',
    'category',
    'browse',
    'following',
    'settings',
    'login',
    'signup',
    'register',
    'terms',
    'privacy',
    'community',
  };
}

class KickIdPair {
  final String channelId;
  final String videoId;

  const KickIdPair({required this.channelId, required this.videoId});

  @override
  bool operator ==(Object other) =>
      other is KickIdPair &&
      other.channelId == channelId &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(channelId, videoId);
}

class KickStreamVariant {
  final String id;
  final String url;
  final String label;
  final int? height;
  final int? bandwidth;
  final int? frameRate;

  const KickStreamVariant({
    required this.id,
    required this.url,
    required this.label,
    this.height,
    this.bandwidth,
    this.frameRate,
  });
}

class KickResolvedStream {
  final String masterPlaylistUrl;
  final String? title;
  final String? thumbnailUrl;
  final String? videoId;
  final String? channelSlug;
  final List<KickStreamVariant> variants;

  const KickResolvedStream({
    required this.masterPlaylistUrl,
    this.title,
    this.thumbnailUrl,
    this.videoId,
    this.channelSlug,
    this.variants = const [],
  });

  /// Direct playlist for a user-picked format, otherwise the master playlist
  /// so yt-dlp can apply height filters itself.
  String playlistFor({String? formatId}) {
    if (formatId == null || formatId.isEmpty || formatId == 'best') {
      return masterPlaylistUrl;
    }
    for (final variant in variants) {
      if (variant.id == formatId) return variant.url;
    }
    return masterPlaylistUrl;
  }

  Map<String, dynamic> toYtDlpMetadata() {
    final formats = <Map<String, dynamic>>[
      {
        'format_id': 'best',
        'ext': 'mp4',
        'height': _bestHeight,
        'resolution': 'best',
        'url': masterPlaylistUrl,
        'protocol': 'm3u8',
      },
      ...variants.map(
        (variant) => {
          'format_id': variant.id,
          'ext': 'mp4',
          'height': variant.height,
          'resolution': variant.label,
          'url': variant.url,
          'protocol': 'm3u8',
          'tbr': variant.bandwidth,
          'fps': variant.frameRate,
        },
      ),
    ];

    return {
      'id': videoId ?? channelSlug ?? 'kick',
      'title': title ?? 'Kick Video',
      'thumbnail': thumbnailUrl,
      'extractor': 'Kick',
      'webpage_url': null,
      'formats': formats,
    };
  }

  int? get _bestHeight {
    var maxHeight = 0;
    for (final variant in variants) {
      final height = variant.height ?? 0;
      if (height > maxHeight) maxHeight = height;
    }
    return maxHeight > 0 ? maxHeight : null;
  }
}

class KickHlsCatalog {
  static const List<String> cdnBases = [
    'https://stream.kick.com/ivs/v1/196233775518',
    'https://stream.kick.com/3c81249a5ce0/ivs/v1/196233775518',
    'https://stream.kick.com/0f3cb0ebce7/ivs/v1/196233775518',
  ];

  static const int defaultOffsetMinutes = 10;

  static List<int> offsets({int minutes = defaultOffsetMinutes}) {
    final values = <int>[0];
    for (var i = 1; i <= minutes; i++) {
      values.add(i);
      values.add(-i);
    }
    return values;
  }

  static List<KickIdPair> idPairsFromThumbnail(String? thumbnailUrl) {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return const [];
    final pairs = <KickIdPair>[];

    final thumbMatch = RegExp(
      r'video_thumbnails/([^/]+)/([^/]+)',
    ).firstMatch(thumbnailUrl);
    if (thumbMatch != null) {
      pairs.add(
        KickIdPair(
          channelId: thumbMatch.group(1)!,
          videoId: thumbMatch.group(2)!,
        ),
      );
    }

    final uri = Uri.tryParse(thumbnailUrl);
    if (uri != null) {
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final ivsIndex = parts.indexOf('ivs');
      if (ivsIndex >= 0 &&
          ivsIndex + 3 < parts.length &&
          parts[ivsIndex + 1] == 'v1') {
        pairs.add(
          KickIdPair(
            channelId: parts[ivsIndex + 2],
            videoId: parts[ivsIndex + 3],
          ),
        );
      }
    }

    return _uniquePairs(pairs);
  }

  static List<String> buildMasterUrls({
    required List<KickIdPair> idPairs,
    required DateTime startTimeUtc,
    int offsetMinutes = defaultOffsetMinutes,
  }) {
    if (idPairs.isEmpty) return const [];
    final urls = <String>[];
    final seen = <String>{};

    void add(String url) {
      if (seen.add(url)) urls.add(url);
    }

    for (final offset in offsets(minutes: offsetMinutes)) {
      final instant = startTimeUtc.add(Duration(minutes: offset));
      for (final datePath in datePathVariants(instant)) {
        for (final pair in idPairs) {
          for (final base in cdnBases) {
            add(
              '$base/${pair.channelId}/$datePath/${pair.videoId}/media/hls/master.m3u8',
            );
          }
        }
      }
    }
    return urls;
  }

  static List<String> datePathVariants(DateTime utc) {
    final unpadded =
        '${utc.year}/${utc.month}/${utc.day}/${utc.hour}/${utc.minute}';
    final padded =
        '${utc.year}/${_two(utc.month)}/${_two(utc.day)}/${_two(utc.hour)}/${_two(utc.minute)}';
    if (unpadded == padded) return [unpadded];
    return [unpadded, padded];
  }

  static DateTime? parseKickTimestamp(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final spaceNormalized = trimmed.contains('T')
        ? trimmed
        : trimmed.replaceFirst(' ', 'T');

    final withZone = _ensureUtcSuffix(spaceNormalized);
    final parsed = DateTime.tryParse(withZone);
    if (parsed == null) return null;
    return parsed.toUtc();
  }

  static String extractThumbnailUrl(Object? thumbnail) {
    if (thumbnail is String) return thumbnail;
    if (thumbnail is Map) {
      final src = thumbnail['src'] ?? thumbnail['url'] ?? thumbnail['srcset'];
      if (src is String && src.isNotEmpty) return src;
    }
    return '';
  }

  static List<KickIdPair> _uniquePairs(List<KickIdPair> pairs) {
    final seen = <KickIdPair>{};
    final unique = <KickIdPair>[];
    for (final pair in pairs) {
      if (pair.channelId.isEmpty || pair.videoId.isEmpty) continue;
      if (seen.add(pair)) unique.add(pair);
    }
    return unique;
  }

  static String _ensureUtcSuffix(String value) {
    if (value.endsWith('Z')) return value;
    if (RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value)) return value;
    return '${value}Z';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class KickHlsPlaylistParser {
  static List<KickStreamVariant> parseMaster({
    required String body,
    required String masterUrl,
  }) {
    final variants = <KickStreamVariant>[];
    final lines = const LineSplitter().convert(body);
    final masterUri = Uri.parse(masterUrl);

    Map<String, String> pendingAttrs = {};
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pendingAttrs = _parseAttrList(
          line.substring('#EXT-X-STREAM-INF:'.length),
        );
        continue;
      }
      if (line.isEmpty || line.startsWith('#')) continue;
      if (pendingAttrs.isEmpty) continue;

      final resolved = masterUri.resolve(line).toString();
      final height = _parseResolutionHeight(pendingAttrs['RESOLUTION']);
      final bandwidth = int.tryParse(pendingAttrs['BANDWIDTH'] ?? '');
      final frameRate = double.tryParse(
        pendingAttrs['FRAME-RATE'] ?? '',
      )?.round();
      final label = _labelFor(
        height: height,
        frameRate: frameRate,
        url: resolved,
      );
      variants.add(
        KickStreamVariant(
          id: label,
          url: resolved,
          label: label,
          height: height,
          bandwidth: bandwidth,
          frameRate: frameRate,
        ),
      );
      pendingAttrs = {};
    }
    return variants;
  }

  static Map<String, String> _parseAttrList(String raw) {
    final attrs = <String, String>{};
    final regex = RegExp(r'([A-Z0-9-]+)=("([^"]+)"|[^,]+)');
    for (final match in regex.allMatches(raw)) {
      final key = match.group(1);
      if (key == null) continue;
      final quoted = match.group(3);
      final plain = match.group(2);
      attrs[key] = quoted ?? (plain ?? '').trim();
    }
    return attrs;
  }

  static int? _parseResolutionHeight(String? resolution) {
    if (resolution == null) return null;
    final parts = resolution.split('x');
    if (parts.length != 2) return null;
    return int.tryParse(parts[1]);
  }

  static String _labelFor({
    required int? height,
    required int? frameRate,
    required String url,
  }) {
    final fromPath = RegExp(
      r'/(\d+p(?:\d+)?)/playlist\.m3u8',
    ).firstMatch(url)?.group(1);
    if (fromPath != null) return fromPath;
    if (height == null) return 'auto';
    if (frameRate != null && frameRate >= 50) return '${height}p$frameRate';
    return '${height}p';
  }
}
