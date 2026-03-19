import 'package:modern_downloader/core/utils/media_file_utils.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';

enum DownloadMediaType { video, audio, unknown }

class DownloadItemMedia {
  const DownloadItemMedia._();

  static DownloadMediaType detect(DownloadItem item) {
    final filePath = item.filePath?.trim();
    if (filePath != null && filePath.isNotEmpty) {
      if (MediaFileUtils.isVideoFile(filePath)) {
        return DownloadMediaType.video;
      }
      if (MediaFileUtils.isAudioFile(filePath)) {
        return DownloadMediaType.audio;
      }
    }

    if (item.request.audioOnly) {
      return DownloadMediaType.audio;
    }

    return DownloadMediaType.unknown;
  }

  static String label(DownloadMediaType type) {
    switch (type) {
      case DownloadMediaType.video:
        return 'Video';
      case DownloadMediaType.audio:
        return 'Audio';
      case DownloadMediaType.unknown:
        return 'Unknown';
    }
  }
}
