import 'package:modern_downloader/core/download/x_download_url.dart';

class DownloadUrlValidator {
  static const Set<String> _nonMediaHosts = <String>{
    'discord.com',
    'discord.gg',
    'discordapp.com',
    'discordapp.net',
  };

  static bool isValidHttpUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  /// Pages that never contain extractable media (invites, app join links).
  static bool isNonMediaPageUrl(String raw) {
    if (!isValidHttpUrl(raw)) return false;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    for (final domain in _nonMediaHosts) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }
    return false;
  }

  /// True when [raw] is http(s), not a non-media page, and not an X CDN
  /// file without a tweet permalink.
  static bool isAcceptableDownloadUrl(String raw) {
    if (!isValidHttpUrl(raw)) return false;
    if (isNonMediaPageUrl(raw)) return false;
    return XDownloadUrl.resolveForDownload(raw) != null;
  }
}
