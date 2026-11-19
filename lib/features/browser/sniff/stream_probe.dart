import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:modern_downloader/features/browser/sniff/sniffed_media.dart';

/// What a detected stream turns out to be, read from its own manifest: the
/// name in the address ("i6CYFRr8Omivno_A.m3u8") says nothing.
class StreamInfo {
  const StreamInfo({this.height, this.duration, this.bytes});

  /// Short side of the best picture, so a portrait 720x1280 reads as 720p.
  final int? height;
  final Duration? duration;
  final int? bytes;
}

class HlsVariant {
  const HlsVariant(this.uri, this.width, this.height, this.bandwidth);

  final Uri uri;
  final int? width;
  final int? height;
  final int bandwidth;
}

/// Variants of an HLS master playlist, best first. Empty for a media playlist.
List<HlsVariant> parseHlsVariants(String text, Uri base) {
  final lines = const LineSplitter().convert(text);
  final variants = <HlsVariant>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
    final bandwidth =
        int.tryParse(
          RegExp(r'(?:^|[:,])BANDWIDTH=(\d+)').firstMatch(line)?.group(1) ?? '',
        ) ??
        0;
    final size = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
    for (var j = i + 1; j < lines.length; j++) {
      final next = lines[j].trim();
      if (next.isEmpty || next.startsWith('#')) continue;
      variants.add(
        HlsVariant(
          base.resolve(next),
          int.tryParse(size?.group(1) ?? ''),
          int.tryParse(size?.group(2) ?? ''),
          bandwidth,
        ),
      );
      break;
    }
  }
  variants.sort((a, b) {
    final byHeight = _shortSide(b).compareTo(_shortSide(a));
    return byHeight != 0 ? byHeight : b.bandwidth.compareTo(a.bandwidth);
  });
  return variants;
}

int _shortSide(HlsVariant v) {
  final w = v.width, h = v.height;
  if (w == null || h == null) return 0;
  return w < h ? w : h;
}

/// Total length of an HLS media playlist, or null when it has no segments
/// (or is a live stream, which has no end).
Duration? parseHlsDuration(String text) {
  if (!text.contains('#EXT-X-ENDLIST') && text.contains('#EXTINF')) {
    // Live or event playlist: the sum is only what is available so far.
    if (!text.contains('#EXT-X-PLAYLIST-TYPE:VOD')) return null;
  }
  var seconds = 0.0;
  for (final m in RegExp(r'#EXTINF:([\d.]+)').allMatches(text)) {
    seconds += double.tryParse(m.group(1)!) ?? 0;
  }
  return seconds > 0 ? Duration(milliseconds: (seconds * 1000).round()) : null;
}

/// Duration and tallest picture of a DASH manifest.
StreamInfo parseDash(String text) {
  Duration? duration;
  final iso = RegExp(
    r'mediaPresentationDuration="PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?"',
  ).firstMatch(text);
  if (iso != null) {
    final ms =
        ((int.tryParse(iso.group(1) ?? '0') ?? 0) * 3600 +
            (int.tryParse(iso.group(2) ?? '0') ?? 0) * 60 +
            (double.tryParse(iso.group(3) ?? '0') ?? 0)) *
        1000;
    if (ms > 0) duration = Duration(milliseconds: ms.round());
  }
  var best = 0;
  for (final m in RegExp(r'\bheight="(\d+)"').allMatches(text)) {
    final h = int.tryParse(m.group(1)!) ?? 0;
    if (h > best) best = h;
  }
  return StreamInfo(height: best > 0 ? best : null, duration: duration);
}

/// Reads the manifest (or the headers of a plain file) with the headers the
/// page used. Returns null when it cannot be read: the row then just says what
/// kind of stream it is.
Future<StreamInfo?> probeStream(
  SniffedMedia media, {
  HttpClient? client,
}) async {
  final http = client ?? HttpClient();
  http.connectionTimeout = const Duration(seconds: 6);
  try {
    final uri = Uri.parse(media.url);
    switch (media.kind) {
      case SniffedKind.hls:
        return await _probeHls(http, media, uri);
      case SniffedKind.dash:
        return parseDash(await _get(http, media, uri));
      case SniffedKind.video:
      case SniffedKind.audio:
        final length = await _contentLength(http, media, uri);
        return length == null ? null : StreamInfo(bytes: length);
    }
  } catch (_) {
    return null;
  } finally {
    if (client == null) http.close(force: true);
  }
}

Future<StreamInfo?> _probeHls(
  HttpClient http,
  SniffedMedia media,
  Uri uri,
) async {
  final text = await _get(http, media, uri);
  final variants = parseHlsVariants(text, uri);
  if (variants.isEmpty) {
    final duration = parseHlsDuration(text);
    return duration == null ? null : StreamInfo(duration: duration);
  }
  final best = variants.first;
  Duration? duration;
  try {
    duration = parseHlsDuration(await _get(http, media, best.uri));
  } catch (_) {}
  final side = _shortSide(best);
  return StreamInfo(
    height: side > 0 ? side : null,
    duration: duration,
    bytes: duration == null || best.bandwidth <= 0
        ? null
        : (best.bandwidth / 8 * duration.inMilliseconds / 1000).round(),
  );
}

Future<String> _get(HttpClient http, SniffedMedia media, Uri uri) async {
  final request = await http.getUrl(uri).timeout(const Duration(seconds: 8));
  _headers(request, media);
  final response = await request.close().timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    await response.drain<void>();
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  // A manifest is small: refuse anything that is not.
  final bytes = await response
      .fold<List<int>>(<int>[], (all, chunk) {
        if (all.length > 2 * 1024 * 1024) throw const HttpException('too big');
        return all..addAll(chunk);
      })
      .timeout(const Duration(seconds: 8));
  return utf8.decode(bytes, allowMalformed: true);
}

Future<int?> _contentLength(
  HttpClient http,
  SniffedMedia media,
  Uri uri,
) async {
  final request = await http.headUrl(uri).timeout(const Duration(seconds: 8));
  _headers(request, media);
  final response = await request.close().timeout(const Duration(seconds: 8));
  await response.drain<void>();
  final length = response.contentLength;
  return length > 0 ? length : null;
}

void _headers(HttpClientRequest request, SniffedMedia media) {
  final ua = media.userAgent;
  if (ua != null && ua.isNotEmpty) {
    request.headers.set(HttpHeaders.userAgentHeader, ua);
  }
  final referer = media.referer;
  if (referer != null && referer.isNotEmpty) {
    request.headers.set(HttpHeaders.refererHeader, referer);
  }
}

/// "0:42", "12:05", "1:02:03".
String clockLabel(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
