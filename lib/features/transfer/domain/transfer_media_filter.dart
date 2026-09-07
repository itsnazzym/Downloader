import 'package:path/path.dart' as p;

class TransferMediaFilter {
  const TransferMediaFilter._();

  static const _supportedExtensions = {
    // Video
    '.mp4', '.mkv', '.webm', '.avi', '.mov', '.flv', '.m4v',
    // Audio
    '.mp3', '.m4a', '.wav', '.flac', '.opus', '.aac', '.ogg',
    // Archives
    '.zip',
  };

  static bool isTransferableMedia(String pathOrName) {
    final base = p.basename(pathOrName).toLowerCase();
    if (base.isEmpty) return false;
    if (base.endsWith('.part') ||
        base.endsWith('.ytdl') ||
        base.endsWith('.tmp') ||
        base.endsWith('.crdownload') ||
        base.contains('.part.')) {
      return false;
    }
    for (final ext in _supportedExtensions) {
      if (base.endsWith(ext)) return true;
    }
    return false;
  }

  static bool isMp4Video(String pathOrName) {
    final base = p.basename(pathOrName).toLowerCase();
    if (base.isEmpty) return false;
    if (base.endsWith('.part') ||
        base.endsWith('.ytdl') ||
        base.endsWith('.tmp') ||
        base.endsWith('.crdownload') ||
        base.contains('.part.')) {
      return false;
    }
    return base.endsWith('.mp4');
  }
}
