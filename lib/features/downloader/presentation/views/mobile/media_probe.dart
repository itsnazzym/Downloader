/// Summary of what yt-dlp reports for a URL, reduced to what the mobile "add"
/// sheet shows: a preview and a size estimate for each quality.
class MediaProbe {
  const MediaProbe({
    required this.title,
    this.uploader,
    this.thumbnail,
    this.durationSeconds,
    this.maxHeight,
    this.videoFormats = const [],
    this.audioBytes,
  });

  final String title;
  final String? uploader;
  final String? thumbnail;
  final int? durationSeconds;

  /// Tallest video stream, or null when the source exposes no resolution.
  final int? maxHeight;
  final List<VideoStreamInfo> videoFormats;
  final int? audioBytes;

  factory MediaProbe.fromMetadata(
    Map<String, dynamic> metadata, {
    required String untitledTitle,
  }) {
    final duration = _asInt(metadata['duration']);
    final formats = <Map<String, dynamic>>[
      for (final f in (metadata['formats'] as List? ?? const []))
        if (f is Map) Map<String, dynamic>.from(f),
    ];

    int? sizeOf(Map<String, dynamic> f, {String bitrateKey = 'tbr'}) {
      final exact = _asInt(f['filesize']) ?? _asInt(f['filesize_approx']);
      if (exact != null && exact > 0) return exact;
      final kbps = _asDouble(f[bitrateKey]) ?? _asDouble(f['tbr']);
      if (kbps != null && duration != null && kbps > 0) {
        return (kbps * 1000 / 8 * duration).round();
      }
      return null;
    }

    final audioOnly = formats.where(
      (f) => f['vcodec'] == 'none' && f['acodec'] != 'none',
    );
    int? bestAudio;
    for (final f in audioOnly) {
      final size = sizeOf(f, bitrateKey: 'abr');
      if (size != null && (bestAudio == null || size > bestAudio)) {
        bestAudio = size;
      }
    }

    final video = <VideoStreamInfo>[];
    for (final f in formats) {
      final vcodec = f['vcodec'];
      final height = _asInt(f['height']);
      if (vcodec == null || vcodec == 'none' || height == null || height <= 0) {
        continue;
      }
      video.add(
        VideoStreamInfo(
          height: height,
          bytes: sizeOf(f),
          hasAudio: f['acodec'] != null && f['acodec'] != 'none',
        ),
      );
    }

    var tallest = 0;
    for (final f in video) {
      if (f.height > tallest) tallest = f.height;
    }

    final thumb = metadata['thumbnail'];
    return MediaProbe(
      title: (metadata['title'] as String?)?.trim().isNotEmpty == true
          ? (metadata['title'] as String).trim()
          : untitledTitle,
      uploader:
          (metadata['uploader'] ?? metadata['channel'] ?? metadata['creator'])
              as String?,
      thumbnail: thumb is String && thumb.startsWith('http') ? thumb : null,
      durationSeconds: duration,
      maxHeight: tallest > 0 ? tallest : null,
      videoFormats: video,
      audioBytes: bestAudio,
    );
  }

  /// True when [height] is offered by the source. Without resolution data
  /// every choice stays available.
  bool offers(int height) => maxHeight == null || height <= maxHeight!;

  /// Estimated download size in bytes. [quality] is 'best' or a height.
  int? estimateBytes(String quality, {required bool audioOnly}) {
    if (audioOnly) return audioBytes;
    if (videoFormats.isEmpty) return null;
    final cap = quality == 'best' ? (maxHeight ?? 1 << 30) : int.parse(quality);
    VideoStreamInfo? pick;
    for (final f in videoFormats) {
      if (f.height > cap || f.bytes == null) continue;
      if (pick == null ||
          f.height > pick.height ||
          (f.height == pick.height && f.bytes! > pick.bytes!)) {
        pick = f;
      }
    }
    if (pick == null) return null;
    final audio = pick.hasAudio ? 0 : (audioBytes ?? 0);
    return pick.bytes! + audio;
  }

  static int? _asInt(Object? v) => v is num ? v.toInt() : null;
  static double? _asDouble(Object? v) => v is num ? v.toDouble() : null;
}

class VideoStreamInfo {
  const VideoStreamInfo({
    required this.height,
    required this.bytes,
    required this.hasAudio,
  });

  final int height;
  final int? bytes;
  final bool hasAudio;
}

/// "~124 Mo", or null when [bytes] is unknown. [kb], [mb] and [gb] are the
/// localized unit labels.
String? formatApproxSize(
  int? bytes, {
  required String kb,
  required String mb,
  required String gb,
}) {
  if (bytes == null || bytes <= 0) return null;
  const mo = 1024 * 1024;
  if (bytes >= 1024 * mo) {
    return '~${(bytes / (1024 * mo)).toStringAsFixed(1)} $gb';
  }
  if (bytes >= mo) return '~${(bytes / mo).round()} $mb';
  return '~${(bytes / 1024).round()} $kb';
}

/// "12:34" or "1:02:03".
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
