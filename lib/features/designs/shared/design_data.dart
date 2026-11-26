import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

/// Data helpers shared by the designs' own pages.

enum MediaKind { video, audio, image }

const _audioExt = {'mp3', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wav'};
const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};

MediaKind mediaKindOf(DownloadItem item) {
  final path = item.filePath ?? '';
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  if (_audioExt.contains(ext)) return MediaKind.audio;
  if (_imageExt.contains(ext)) return MediaKind.image;
  if (ext.isEmpty && item.request.audioOnly) return MediaKind.audio;
  return MediaKind.video;
}

/// "MP4", "M4A"...: the file's extension, else the requested format.
String formatLabelOf(DownloadItem item) {
  final path = item.filePath ?? '';
  final dot = path.lastIndexOf('.');
  if (dot >= 0 && dot < path.length - 1) {
    return path.substring(dot + 1).toUpperCase();
  }
  return (item.request.audioOnly
          ? item.request.audioFormat
          : item.request.outputFormat)
      .toUpperCase();
}

int bytesOf(DownloadItem item) {
  final total = FormatUtils.parseBytes(item.totalSize);
  return total > 0 ? total : FormatUtils.parseBytes(item.downloadedSize);
}

/// "3,8 Go": binary units, localised unit and decimal separator.
String localBytes(AppLocalizations l10n, int bytes) {
  if (bytes <= 0) return '0 ${l10n.statsMobileUnitB}';
  const k = 1024.0;
  final sep = l10n.localeName.startsWith('en') ? '.' : ',';
  String fmt(double v) =>
      v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', sep);
  if (bytes >= k * k * k) {
    return '${fmt(bytes / (k * k * k))} ${l10n.statsMobileUnitGB}';
  }
  if (bytes >= k * k)
    return '${fmt(bytes / (k * k))} ${l10n.statsMobileUnitMB}';
  if (bytes >= k) return '${fmt(bytes / k)} ${l10n.statsMobileUnitKB}';
  return '$bytes ${l10n.statsMobileUnitB}';
}

/// "D:" from a Windows folder path, or null.
String? driveOf(String folder) {
  if (folder.length >= 2 && folder[1] == ':') {
    return '${folder[0].toUpperCase()}:';
  }
  return null;
}

/// The readable cause of a failed download: yt-dlp's `ERROR:` line (else the
/// first line), without the exit-code lead-in, the level, the
/// `[extractor] id:` tag, the "Unable to download…:" lead-in and the
/// "please report this issue" tail. Empty when there is nothing to say.
String downloadErrorReason(String? raw) {
  final exitCode = RegExp(
    r'^yt-dlp exited with code -?\d+\.?\s*(Error:\s*)?',
    caseSensitive: false,
  );
  final lines = [
    for (final l in (raw ?? '').split(RegExp(r'\r?\n')))
      if (l.trim().replaceFirst(exitCode, '').isNotEmpty)
        l.trim().replaceFirst(exitCode, ''),
  ];
  if (lines.isEmpty) return '';
  final line = lines.firstWhere(
    (l) => l.toUpperCase().startsWith('ERROR'),
    orElse: () => lines.first,
  );
  return line
      .replaceFirst(
        RegExp(r'^(ERROR|WARNING)\s*[:\-]\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w.\-]+:\s+)?'), '')
      .replaceFirst(
        RegExp(r'^Unable to (download|extract)( [\w ]+?)?:\s*',
            caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'[;.]?\s*please report this issue.*$', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'\s*\(caused by .*\)$', caseSensitive: false), '')
      .trim();
}
