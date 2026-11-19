import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';

/// A direct media address found without yt-dlp's extractors.
class ResolvedMedia {
  const ResolvedMedia({
    required this.candidates,
    this.title,
    this.thumbnail,
    this.id,
    this.source = 'fallback',
  });

  /// Direct streams, best first. Each has a height when it is known.
  final List<MediaCandidate> candidates;
  final String? title;
  final String? thumbnail;
  final String? id;

  /// Where it was found (`fxtwitter`, `vxtwitter`, `page`), for the logs.
  final String source;

  /// The candidate closest to [quality] ('best' or a height) without going
  /// above it; the tallest when nothing fits or [quality] is 'best'.
  MediaCandidate pick(String quality) {
    final cap = int.tryParse(quality);
    if (cap == null) return candidates.first;
    MediaCandidate? best;
    for (final c in candidates) {
      final h = c.height;
      if (h == null || h > cap) continue;
      if (best == null || h > (best.height ?? 0)) best = c;
    }
    return best ?? candidates.last;
  }
}

class MediaCandidate {
  const MediaCandidate(this.url, {this.height});
  final String url;
  final int? height;
}

/// Finds media when yt-dlp could not (X posts needing a login, pages whose
/// player yt-dlp has no extractor for). Everything here is a best effort:
/// any failure just returns null and the caller keeps yt-dlp's error.
class FallbackMediaResolver {
  FallbackMediaResolver({
    Future<String?> Function(Uri url)? fetchText,
    this.timeout = const Duration(seconds: 10),
  }) : _fetchText = fetchText;

  final Future<String?> Function(Uri url)? _fetchText;
  final Duration timeout;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  Future<ResolvedMedia?> resolve(
    String pageUrl, {
    bool Function()? isCancelled,
  }) async {
    final uri = Uri.tryParse(pageUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    try {
      if (XDownloadUrl.isXFamilyUrl(pageUrl)) {
        final tweetId = XDownloadUrl.tweetIdFrom(pageUrl);
        if (tweetId != null) {
          for (final api in const ['fxtwitter', 'vxtwitter']) {
            if (isCancelled?.call() ?? false) return null;
            final body = await _get(
              Uri.parse(
                api == 'fxtwitter'
                    ? 'https://api.fxtwitter.com/i/status/$tweetId'
                    : 'https://api.vxtwitter.com/i/status/$tweetId',
              ),
            );
            if (body == null) continue;
            final media = api == 'fxtwitter'
                ? parseFxTwitter(body, tweetId: tweetId)
                : parseVxTwitter(body, tweetId: tweetId);
            if (media != null) return media;
          }
        }
        return null;
      }
      if (isCancelled?.call() ?? false) return null;
      final html = await _get(uri, maxBytes: 2 * 1024 * 1024);
      if (html == null) return null;
      return parsePage(html, base: uri);
    } catch (e) {
      LoggerService.w('Fallback media resolver failed: $e');
      return null;
    }
  }

  Future<String?> _get(Uri url, {int maxBytes = 512 * 1024}) async {
    final custom = _fetchText;
    if (custom != null) return custom(url);
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = _userAgent;
    try {
      final request = await client.getUrl(url).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) break;
      }
      return utf8.decode(builder.takeBytes(), allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }

  // ---- parsers (pure, unit tested) --------------------------------------

  static int? _heightFromUrl(String url) {
    final m = RegExp(r'/(\d{3,4})x(\d{3,4})/').firstMatch(url);
    if (m == null) return null;
    final w = int.parse(m.group(1)!);
    final h = int.parse(m.group(2)!);
    // Portrait videos list "720x1280": the shorter side is the usual
    // "quality" number.
    return w < h ? w : h;
  }

  static String _titleFromText(String? text, {String? user, String? id}) {
    final cleaned = (text ?? '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final head = cleaned.length > 80
        ? cleaned.substring(0, 80).trim()
        : cleaned;
    if (head.isNotEmpty) return head;
    if (user != null && user.isNotEmpty && id != null) return '$user - $id';
    return id == null ? 'Tweet' : 'Tweet $id';
  }

  static List<MediaCandidate> _sorted(List<MediaCandidate> list) {
    final seen = <String>{};
    final out = [
      for (final c in list)
        if (seen.add(c.url)) c,
    ];
    out.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    return out;
  }

  static ResolvedMedia? parseFxTwitter(String body, {required String tweetId}) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map || json['tweet'] is! Map) return null;
    final tweet = json['tweet'] as Map;
    final media = tweet['media'];
    if (media is! Map) return null;
    final candidates = <MediaCandidate>[];
    String? thumb;
    for (final v in (media['videos'] as List? ?? const [])) {
      if (v is! Map) continue;
      thumb ??= v['thumbnail_url'] as String?;
      final formats = v['formats'] as List? ?? const [];
      for (final f in formats) {
        if (f is Map && f['container'] == 'mp4' && f['url'] is String) {
          candidates.add(
            MediaCandidate(
              f['url'] as String,
              height: _heightFromUrl(f['url'] as String),
            ),
          );
        }
      }
      final main = v['url'];
      if (main is String && main.contains('.mp4')) {
        candidates.add(MediaCandidate(main, height: _heightFromUrl(main)));
      }
    }
    if (candidates.isEmpty) return null;
    final author = tweet['author'];
    final user = author is Map ? author['screen_name'] as String? : null;
    return ResolvedMedia(
      candidates: _sorted(candidates),
      title: _titleFromText(tweet['text'] as String?, user: user, id: tweetId),
      thumbnail: thumb,
      id: tweetId,
      source: 'fxtwitter',
    );
  }

  static ResolvedMedia? parseVxTwitter(String body, {required String tweetId}) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    final candidates = <MediaCandidate>[];
    String? thumb;
    for (final m in (json['media_extended'] as List? ?? const [])) {
      if (m is! Map) continue;
      final type = m['type'];
      final url = m['url'];
      if ((type == 'video' || type == 'gif') && url is String) {
        candidates.add(MediaCandidate(url, height: _heightFromUrl(url)));
        thumb ??= m['thumbnail_url'] as String?;
      }
    }
    if (candidates.isEmpty) return null;
    return ResolvedMedia(
      candidates: _sorted(candidates),
      title: _titleFromText(
        json['text'] as String?,
        user: json['user_screen_name'] as String?,
        id: tweetId,
      ),
      thumbnail: thumb,
      id: tweetId,
      source: 'vxtwitter',
    );
  }

  /// Reads declared video addresses from a page: Open Graph / Twitter player
  /// tags, then `<video>` and `<source>` tags. Only streams the page itself
  /// declares as its video are taken (never loose `.mp4` strings, which are
  /// often ads or previews).
  static ResolvedMedia? parsePage(String html, {required Uri base}) {
    String? meta(String name) {
      final tag = RegExp(
        '<meta[^>]+(?:property|name)=["\']$name["\'][^>]*>',
        caseSensitive: false,
      ).firstMatch(html)?.group(0);
      if (tag == null) return null;
      return RegExp(
        'content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);
    }

    String? absolute(String? raw) {
      if (raw == null) return null;
      final cleaned = raw.replaceAll('&amp;', '&').trim();
      final uri = Uri.tryParse(cleaned);
      if (uri == null) return null;
      final resolved = base.resolveUri(uri);
      return resolved.isScheme('http') || resolved.isScheme('https')
          ? resolved.toString()
          : null;
    }

    bool isMedia(String url) {
      final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      return path.endsWith('.mp4') ||
          path.endsWith('.m3u8') ||
          path.endsWith('.webm') ||
          path.endsWith('.mov') ||
          path.endsWith('.m4v');
    }

    final found = <String>[];
    for (final key in const [
      'og:video:secure_url',
      'og:video:url',
      'og:video',
      'twitter:player:stream',
    ]) {
      final url = absolute(meta(key));
      if (url != null && isMedia(url)) found.add(url);
    }
    for (final m in RegExp(
      r'''<(?:video|source)\b[^>]*\bsrc=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = absolute(m.group(1));
      if (url != null && isMedia(url)) found.add(url);
    }
    if (found.isEmpty) return null;

    final title =
        (meta('og:title') ??
                RegExp(
                  r'<title[^>]*>([^<]+)</title>',
                  caseSensitive: false,
                ).firstMatch(html)?.group(1))
            ?.replaceAll('&amp;', '&')
            .trim();
    return ResolvedMedia(
      candidates: [for (final u in found.toSet()) MediaCandidate(u)],
      title: title,
      thumbnail: absolute(meta('og:image')),
      source: 'page',
    );
  }
}
