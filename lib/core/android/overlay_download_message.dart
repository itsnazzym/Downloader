/// Payload sent by the in-app X WebView overlay (ported from the desktop
/// extension `DOWNLOAD_BTN_CLICK` message).
class OverlayDownloadMessage {
  const OverlayDownloadMessage({
    required this.url,
    this.id,
    this.pageUrl,
    this.isAudioOnly = false,
    this.preferredQuality,
    this.tweetId,
    this.mediaId,
  });

  final String url;
  final String? id;
  final String? pageUrl;
  final bool isAudioOnly;
  final String? preferredQuality;
  final String? tweetId;
  final String? mediaId;

  static OverlayDownloadMessage? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = <String, Object?>{};
    raw.forEach((key, value) {
      if (key is String) map[key] = value;
    });

    final type = map['type']?.toString();
    if (type != null && type != 'DOWNLOAD_BTN_CLICK') return null;

    final url = map['url']?.toString().trim() ?? '';
    if (url.isEmpty) return null;

    final optionsRaw = map['options'];
    Map<String, Object?> options = const {};
    if (optionsRaw is Map) {
      options = <String, Object?>{};
      optionsRaw.forEach((key, value) {
        if (key is String) options[key] = value;
      });
    }

    final quality = options['preferredQuality']?.toString();
    return OverlayDownloadMessage(
      url: url,
      id: map['id']?.toString(),
      pageUrl: map['pageUrl']?.toString(),
      isAudioOnly: options['isAudioOnly'] == true,
      preferredQuality: (quality == null || quality.isEmpty) ? null : quality,
      tweetId: map['tweetId']?.toString(),
      mediaId: map['mediaId']?.toString(),
    );
  }
}
