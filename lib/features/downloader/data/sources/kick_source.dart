import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/logger/logger_service.dart';
import 'kick/kick_hls.dart';

class KickSource {
  KickSource({http.Client? client, this.cacheTtl = const Duration(minutes: 20)})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration cacheTtl;
  final Map<String, _KickCacheEntry> _cache = {};

  static const _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _apiHeaders = {
    'User-Agent': _browserUserAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://kick.com/',
    'Origin': 'https://kick.com',
  };

  static const _cdnHeaders = {
    'User-Agent': _browserUserAgent,
    'Accept': '*/*',
    'Referer': 'https://kick.com/',
    'Origin': 'https://kick.com',
  };

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, String?>> fetchKickDetails(String url) async {
    final resolved = await resolve(url);
    if (resolved == null) return {};
    return {
      'streamUrl': resolved.masterPlaylistUrl,
      if (resolved.thumbnailUrl != null) 'thumbnailUrl': resolved.thumbnailUrl,
      if (resolved.title != null) 'title': resolved.title,
    };
  }

  Future<KickResolvedStream?> resolve(String url, {String? cookies}) async {
    final page = KickPageRef.tryParse(url);
    if (page == null) return null;

    final cacheKey =
        '${page.kind.name}:${page.channelSlug}:${page.contentId ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      LoggerService.debug('KickSource: cache hit for $cacheKey');
      return cached.stream;
    }

    try {
      KickResolvedStream? resolved;
      switch (page.kind) {
        case KickContentKind.vod:
          resolved = await _resolveVod(page, cookies: cookies);
          break;
        case KickContentKind.live:
          resolved = await _resolveLive(page, cookies: cookies);
          break;
        case KickContentKind.clip:
          resolved = await _resolveClip(page, cookies: cookies);
          break;
        case KickContentKind.unknown:
          resolved =
              await _resolveVod(page, cookies: cookies) ??
              await _resolveLive(page, cookies: cookies);
          break;
      }

      if (resolved != null) {
        _cache[cacheKey] = _KickCacheEntry(
          stream: resolved,
          expiresAt: DateTime.now().add(cacheTtl),
        );
      }
      return resolved;
    } catch (e, st) {
      LoggerService.e('KickSource: resolve failed', e, st);
      return null;
    }
  }

  Future<KickResolvedStream?> _resolveVod(
    KickPageRef page, {
    String? cookies,
  }) async {
    final videoUuid = page.contentId;
    if (videoUuid == null || videoUuid.isEmpty) return null;

    LoggerService.i(
      'KickSource: resolving VOD $videoUuid on ${page.channelSlug}',
    );

    final videoMeta = await _fetchVodMetadata(
      channelSlug: page.channelSlug,
      videoUuid: videoUuid,
      cookies: cookies,
    );
    if (videoMeta == null) {
      LoggerService.w('KickSource: no VOD metadata for $videoUuid');
      return null;
    }

    final idPairs = _collectIdPairs(videoMeta);
    final startTime =
        KickHlsCatalog.parseKickTimestamp(videoMeta.startTime) ??
        DateTime.now().toUtc();
    final candidateUrls = KickHlsCatalog.buildMasterUrls(
      idPairs: idPairs,
      startTimeUtc: startTime,
    );

    LoggerService.debug(
      'KickSource: probing ${candidateUrls.length} HLS candidates '
      '(${idPairs.length} id pairs)',
    );

    final masterUrl = await _probeFirstReachable(candidateUrls);
    if (masterUrl == null) {
      LoggerService.w('KickSource: no reachable HLS playlist for $videoUuid');
      return null;
    }

    LoggerService.i('KickSource: found HLS master $masterUrl');

    final variants = await _loadVariants(masterUrl);
    return KickResolvedStream(
      masterPlaylistUrl: masterUrl,
      title: videoMeta.title,
      thumbnailUrl: videoMeta.thumbnailUrl,
      videoId: videoUuid,
      channelSlug: page.channelSlug,
      variants: variants,
    );
  }

  Future<KickResolvedStream?> _resolveLive(
    KickPageRef page, {
    String? cookies,
  }) async {
    LoggerService.i('KickSource: resolving live channel ${page.channelSlug}');
    final channel = await _fetchChannel(page.channelSlug, cookies: cookies);
    if (channel == null) return null;

    final playbackUrl = channel.playbackUrl;
    if (playbackUrl == null || playbackUrl.isEmpty) {
      LoggerService.w(
        'KickSource: channel ${page.channelSlug} has no playback_url (offline?)',
      );
      return null;
    }

    final variants = playbackUrl.contains('.m3u8')
        ? await _loadVariants(playbackUrl)
        : const <KickStreamVariant>[];

    return KickResolvedStream(
      masterPlaylistUrl: playbackUrl,
      title: channel.title ?? page.channelSlug,
      thumbnailUrl: channel.thumbnailUrl,
      videoId: page.channelSlug,
      channelSlug: page.channelSlug,
      variants: variants,
    );
  }

  Future<KickResolvedStream?> _resolveClip(
    KickPageRef page, {
    String? cookies,
  }) async {
    final clipId = page.contentId;
    if (clipId == null) return null;
    LoggerService.i('KickSource: resolving clip $clipId');

    for (final endpoint in [
      'https://kick.com/api/v2/clips/$clipId',
      'https://kick.com/api/v1/clips/$clipId',
      'https://web.kick.com/api/v1/clips/$clipId',
    ]) {
      final json = await _getJson(endpoint, cookies: cookies);
      if (json == null) continue;
      final clip = _asMap(json['clip']) ?? json;
      final playback =
          _asString(clip['clip_url']) ??
          _asString(clip['video_url']) ??
          _asString(clip['playback_url']) ??
          _asString(_asMap(clip['video'])?['url']);
      if (playback == null || playback.isEmpty) continue;

      var thumbnail = KickHlsCatalog.extractThumbnailUrl(clip['thumbnail']);
      if (thumbnail.isEmpty) {
        thumbnail = _asString(clip['thumbnail_url']) ?? '';
      }
      final title =
          _asString(clip['title']) ??
          _asString(clip['session_title']) ??
          'Kick Clip';

      final variants = playback.contains('.m3u8')
          ? await _loadVariants(playback)
          : const <KickStreamVariant>[];

      return KickResolvedStream(
        masterPlaylistUrl: playback,
        title: title,
        thumbnailUrl: thumbnail.isEmpty ? null : thumbnail,
        videoId: clipId,
        channelSlug: page.channelSlug,
        variants: variants,
      );
    }
    return null;
  }

  Future<_KickVideoMeta?> _fetchVodMetadata({
    required String channelSlug,
    required String videoUuid,
    String? cookies,
  }) async {
    final direct = await _fetchVideoById(videoUuid, cookies: cookies);
    final channel = await _fetchChannel(channelSlug, cookies: cookies);
    final listed = await _findVideoInChannel(
      channelSlug: channelSlug,
      channel: channel,
      videoUuid: videoUuid,
      cookies: cookies,
    );

    final merged = _KickVideoMeta.merge(direct, listed, channel);
    return merged;
  }

  Future<_KickVideoMeta?> _fetchVideoById(
    String videoUuid, {
    String? cookies,
  }) async {
    for (final endpoint in [
      'https://kick.com/api/v1/video/$videoUuid',
      'https://kick.com/api/v2/videos/$videoUuid',
      'https://web.kick.com/api/v1/video/$videoUuid',
      'https://web.kick.com/api/v1/videos/$videoUuid',
      'https://kick.com/api/v1/videos/$videoUuid',
    ]) {
      final json = await _getJson(endpoint, cookies: cookies);
      if (json == null) continue;
      final video = _asMap(json['video']) ?? json;
      final meta = _KickVideoMeta.fromJson(video, fallbackUuid: videoUuid);
      if (meta != null) return meta;
    }
    return null;
  }

  Future<_KickChannelMeta?> _fetchChannel(
    String channelSlug, {
    String? cookies,
  }) async {
    for (final endpoint in [
      'https://kick.com/api/v2/channels/$channelSlug',
      'https://kick.com/api/v1/channels/$channelSlug',
      'https://web.kick.com/api/v1/channels/$channelSlug',
    ]) {
      final json = await _getJson(endpoint, cookies: cookies);
      if (json == null) continue;
      final meta = _KickChannelMeta.fromJson(json, slug: channelSlug);
      if (meta != null) return meta;
    }
    return null;
  }

  Future<_KickVideoMeta?> _findVideoInChannel({
    required String channelSlug,
    required _KickChannelMeta? channel,
    required String videoUuid,
    String? cookies,
  }) async {
    final lists = <List<Map<String, dynamic>>>[];
    if (channel != null) {
      if (channel.previousLivestreams.isNotEmpty) {
        lists.add(channel.previousLivestreams);
      }
    }

    final channelId = channel?.id;
    final videoEndpoints = <String>[
      'https://kick.com/api/v2/channels/$channelSlug/videos',
      'https://web.kick.com/api/v1/channels/$channelSlug/videos',
      if (channelId != null) ...[
        'https://kick.com/api/v2/channels/$channelId/videos',
        'https://kick.com/api/v1/channels/$channelId/videos',
        'https://web.kick.com/api/v1/channels/$channelId/videos',
      ],
    ];

    for (final endpoint in videoEndpoints) {
      final json = await _getJson(endpoint, cookies: cookies);
      if (json == null) continue;
      final videos = _extractVideoList(json);
      if (videos.isNotEmpty) lists.add(videos);
    }

    for (final list in lists) {
      final match = _matchVideo(list, videoUuid);
      if (match != null) {
        return _KickVideoMeta.fromJson(
          match,
          fallbackUuid: videoUuid,
          channelId: channelId,
        );
      }
    }
    return null;
  }

  List<KickIdPair> _collectIdPairs(_KickVideoMeta meta) {
    final pairs = <KickIdPair>[
      ...KickHlsCatalog.idPairsFromThumbnail(meta.thumbnailUrl),
    ];
    if (meta.channelId != null) {
      if (meta.recordingId != null) {
        pairs.add(
          KickIdPair(channelId: meta.channelId!, videoId: meta.recordingId!),
        );
      }
      if (meta.uuid != null) {
        pairs.add(KickIdPair(channelId: meta.channelId!, videoId: meta.uuid!));
      }
      if (meta.livestreamId != null) {
        pairs.add(
          KickIdPair(channelId: meta.channelId!, videoId: meta.livestreamId!),
        );
      }
    }
    final unique = <KickIdPair>[];
    final seen = <KickIdPair>{};
    for (final pair in pairs) {
      if (seen.add(pair)) unique.add(pair);
    }
    return unique;
  }

  Future<List<KickStreamVariant>> _loadVariants(String masterUrl) async {
    try {
      final response = await _client
          .get(Uri.parse(masterUrl), headers: _cdnHeaders)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.body.isEmpty) {
        return const [];
      }
      return KickHlsPlaylistParser.parseMaster(
        body: response.body,
        masterUrl: masterUrl,
      );
    } catch (e) {
      LoggerService.w('KickSource: failed to parse master playlist: $e');
      return const [];
    }
  }

  Future<String?> _probeFirstReachable(
    List<String> urls, {
    int batchSize = 12,
  }) async {
    for (var i = 0; i < urls.length; i += batchSize) {
      final end = i + batchSize > urls.length ? urls.length : i + batchSize;
      final batch = urls.sublist(i, end);
      final hit = await _probeBatch(batch);
      if (hit != null) return hit;
    }
    return null;
  }

  Future<String?> _probeBatch(List<String> batch) async {
    final completer = Completer<String?>();
    var pending = batch.length;
    if (pending == 0) return null;

    for (final url in batch) {
      unawaited(
        _isReachable(url).then((ok) {
          if (ok && !completer.isCompleted) {
            completer.complete(url);
          }
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }),
      );
    }
    return completer.future;
  }

  Future<bool> _isReachable(String url) async {
    final uri = Uri.parse(url);
    try {
      final head = await _client
          .head(uri, headers: _cdnHeaders)
          .timeout(const Duration(seconds: 4));
      if (head.statusCode == 200) return true;
      if (head.statusCode == 403 ||
          head.statusCode == 405 ||
          head.statusCode == 501) {
        return await _getRangeOk(uri);
      }
    } catch (_) {
      return await _getRangeOk(uri);
    }
    return false;
  }

  Future<bool> _getRangeOk(Uri uri) async {
    try {
      final get = await _client
          .get(uri, headers: {..._cdnHeaders, 'Range': 'bytes=0-64'})
          .timeout(const Duration(seconds: 5));
      return get.statusCode == 200 || get.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getJson(String url, {String? cookies}) async {
    try {
      final headers = Map<String, String>.from(_apiHeaders);
      if (cookies != null && cookies.isNotEmpty) {
        headers['Cookie'] = cookies;
      }
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      final body = response.body.trim();
      if (body.isEmpty || !(body.startsWith('{') || body.startsWith('['))) {
        LoggerService.debug(
          'KickSource: non-JSON ${response.statusCode} from $url',
        );
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) return {'data': decoded};
    } catch (e) {
      LoggerService.debug('KickSource: GET $url failed: $e');
    }
    return null;
  }

  Map<String, dynamic>? _matchVideo(
    List<Map<String, dynamic>> videos,
    String videoUuid,
  ) {
    final target = videoUuid.toLowerCase();
    for (final video in videos) {
      final slug = _asString(video['slug'])?.toLowerCase();
      final uuid =
          (_asString(video['uuid']) ??
                  _asString(_asMap(video['video'])?['uuid']))
              ?.toLowerCase();
      final id = _asString(video['id'])?.toLowerCase();
      if (slug == target || uuid == target || id == target) return video;
    }
    if (target.length > 5) {
      for (final video in videos) {
        if (jsonEncode(video).toLowerCase().contains(target)) return video;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractVideoList(Map<String, dynamic> json) {
    final raw = json['videos'] ?? json['data'] ?? json['previous_livestreams'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }
}

class _KickCacheEntry {
  final KickResolvedStream stream;
  final DateTime expiresAt;
  _KickCacheEntry({required this.stream, required this.expiresAt});
}

class _KickChannelMeta {
  final String? id;
  final String slug;
  final String? playbackUrl;
  final String? title;
  final String? thumbnailUrl;
  final List<Map<String, dynamic>> previousLivestreams;

  const _KickChannelMeta({
    required this.slug,
    this.id,
    this.playbackUrl,
    this.title,
    this.thumbnailUrl,
    this.previousLivestreams = const [],
  });

  static _KickChannelMeta? fromJson(
    Map<String, dynamic> json, {
    required String slug,
  }) {
    final nestedChannel = _asMap(json['channel']);
    final id =
        _asString(json['id']) ??
        _asString(json['channel_id']) ??
        _asString(nestedChannel?['id']);
    final livestream = _asMap(json['livestream']);
    final playback =
        _asString(json['playback_url']) ??
        _asString(livestream?['playback_url']) ??
        _asString(nestedChannel?['playback_url']);
    final user = _asMap(json['user']);
    final thumbnail =
        _asString(user?['profile_pic']) ??
        KickHlsCatalog.extractThumbnailUrl(json['thumbnail']);
    final title =
        _asString(livestream?['session_title']) ??
        _asString(json['session_title']) ??
        _asString(user?['username']) ??
        slug;
    final previous = <Map<String, dynamic>>[];
    for (final key in ['previous_livestreams', 'videos']) {
      final list = json[key];
      if (list is List) {
        previous.addAll(
          list.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
        );
      }
    }
    if (id == null && playback == null && previous.isEmpty) return null;
    return _KickChannelMeta(
      id: id,
      slug: slug,
      playbackUrl: playback,
      title: title,
      thumbnailUrl: thumbnail.isEmpty ? null : thumbnail,
      previousLivestreams: previous,
    );
  }
}

class _KickVideoMeta {
  final String? uuid;
  final String? channelId;
  final String? recordingId;
  final String? livestreamId;
  final String? startTime;
  final String? thumbnailUrl;
  final String? title;

  const _KickVideoMeta({
    this.uuid,
    this.channelId,
    this.recordingId,
    this.livestreamId,
    this.startTime,
    this.thumbnailUrl,
    this.title,
  });

  static _KickVideoMeta? fromJson(
    Map<String, dynamic> json, {
    String? fallbackUuid,
    String? channelId,
  }) {
    final nestedVideo = _asMap(json['video']);
    final uuid =
        _asString(json['uuid']) ??
        _asString(nestedVideo?['uuid']) ??
        fallbackUuid;
    final resolvedChannelId =
        _asString(json['channel_id']) ??
        _asString(_asMap(json['channel'])?['id']) ??
        channelId;
    final livestreamId =
        _asString(json['live_stream_id']) ??
        _asString(json['livestream_id']) ??
        _asString(json['id']);
    final startTime =
        _asString(json['start_time']) ??
        _asString(json['created_at']) ??
        _asString(nestedVideo?['created_at']);
    final thumbnail = KickHlsCatalog.extractThumbnailUrl(
      json['thumbnail'] ?? nestedVideo?['thumbnail'],
    );
    final title =
        _asString(json['session_title']) ??
        _asString(json['title']) ??
        _asString(nestedVideo?['title']);

    final recordingFromThumb = KickHlsCatalog.idPairsFromThumbnail(thumbnail);

    if (uuid == null &&
        resolvedChannelId == null &&
        thumbnail.isEmpty &&
        startTime == null) {
      return null;
    }

    return _KickVideoMeta(
      uuid: uuid,
      channelId: resolvedChannelId,
      recordingId: recordingFromThumb.isNotEmpty
          ? recordingFromThumb.first.videoId
          : _asString(nestedVideo?['id']),
      livestreamId: livestreamId,
      startTime: startTime,
      thumbnailUrl: thumbnail.isEmpty ? null : thumbnail,
      title: title,
    );
  }

  static _KickVideoMeta? merge(
    _KickVideoMeta? a,
    _KickVideoMeta? b,
    _KickChannelMeta? channel,
  ) {
    if (a == null && b == null && channel == null) return null;
    final thumbnail = a?.thumbnailUrl ?? b?.thumbnailUrl;
    return _KickVideoMeta(
      uuid: a?.uuid ?? b?.uuid,
      channelId: a?.channelId ?? b?.channelId ?? channel?.id,
      recordingId: a?.recordingId ?? b?.recordingId,
      livestreamId: a?.livestreamId ?? b?.livestreamId,
      startTime: a?.startTime ?? b?.startTime,
      thumbnailUrl: thumbnail,
      title: a?.title ?? b?.title ?? channel?.title,
    );
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _asString(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return value.toString();
  return null;
}
