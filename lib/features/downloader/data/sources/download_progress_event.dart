class DownloadProgressEvent {
  final double progress;
  final String totalSize;
  final String downloadedSize;
  final String speed;
  final String eta;
  final String? title;
  final String step;
  final String? filePath;
  final bool isDuplicate;

  DownloadProgressEvent({
    required this.progress,
    required this.totalSize,
    this.downloadedSize = '',
    required this.speed,
    required this.eta,
    this.title,
    this.step = '',
    this.filePath,
    this.isDuplicate = false,
  });
}
