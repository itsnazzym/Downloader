import 'package:modern_downloader/core/download/x_download_url.dart';

class DownloadUrlValidator {
  static bool isValidHttpUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  /// True when [raw] is http(s) and not an X CDN file without a tweet permalink.
  static bool isAcceptableDownloadUrl(String raw) {
    if (!isValidHttpUrl(raw)) return false;
    return XDownloadUrl.resolveForDownload(raw) != null;
  }
}
