import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/utils/format_utils.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/l10n/app_localizations.dart';

export 'package:tapload/core/download/download_error_reason.dart';

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

/// The item's cleaned title, else its link: a failed download often has an
/// empty title, which left its row blank.
String titleOf(DownloadItem item) {
  final title = TitleCleanerService.clean(item.title ?? '');
  return title.trim().isNotEmpty ? title : item.request.url;
}
