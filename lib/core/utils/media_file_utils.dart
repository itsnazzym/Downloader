class MediaFileUtils {
  const MediaFileUtils._();

  static const videoExtensions = [
    '.mp4',
    '.mkv',
    '.webm',
    '.mov',
    '.avi',
    '.flv',
    '.m4v',
    '.3gp',
    '.wmv',
  ];

  static const audioExtensions = [
    '.mp3',
    '.aac',
    '.opus',
    '.m4a',
    '.ogg',
    '.flac',
    '.wav',
    '.wma',
  ];

  static const imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.tiff',
  ];

  static bool isVideoFile(String path) {
    final lower = path.toLowerCase();
    return videoExtensions.any(lower.endsWith);
  }

  static bool isAudioFile(String path) {
    final lower = path.toLowerCase();
    return audioExtensions.any(lower.endsWith);
  }

  static bool isImageFile(String path) {
    final lower = path.toLowerCase();
    return imageExtensions.any(lower.endsWith);
  }

  static bool isMediaFile(String path) {
    return isVideoFile(path) || isAudioFile(path) || isImageFile(path);
  }

  static bool isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
