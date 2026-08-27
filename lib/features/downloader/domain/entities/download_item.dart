import '../enums/download_status.dart';
import 'download_request.dart';
import 'package:modern_downloader/core/download/media_source_resolver.dart';

class DownloadItem {
  final String id;
  final DownloadRequest request;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String eta;
  final String speed;
  final String? title;
  final String? error;
  final String downloadedSize; // e.g., "10.5MiB"
  final String totalSize; // e.g., "300MiB"
  final int sortOrder;
  final bool usesAria2c;
  final String? thumbnailUrl; // Added field

  const DownloadItem({
    required this.id,
    required this.request,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.eta = '',
    this.speed = '',
    this.title,
    this.error,
    this.downloadedSize = '',
    this.totalSize = '',
    this.step = '',
    this.filePath,
    this.sortOrder = 0,
    this.usesAria2c = false,
    this.thumbnailUrl,
  });

  final String step; // Current step (e.g., "Merging audio/video...")

  final String? filePath;

  String get source {
    return MediaSourceResolver.resolve(url: request.url, filePath: filePath) ??
        '';
  }

  DownloadItem copyWith({
    DownloadRequest? request,
    DownloadStatus? status,
    double? progress,
    String? eta,
    String? speed,
    String? title,
    String? error,
    bool clearError = false,
    String? downloadedSize,
    String? totalSize,
    String? step,
    String? filePath,
    bool clearFilePath = false,
    int? sortOrder,
    bool? usesAria2c,
    String? thumbnailUrl, // Added param
    bool clearThumbnailUrl = false,
  }) {
    return DownloadItem(
      id: id,
      request: request ?? this.request,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      eta: eta ?? this.eta,
      speed: speed ?? this.speed,
      title: title ?? this.title,
      error: clearError ? null : (error ?? this.error),
      downloadedSize: downloadedSize ?? this.downloadedSize,
      totalSize: totalSize ?? this.totalSize,
      step: step ?? this.step,
      filePath: clearFilePath ? filePath : (filePath ?? this.filePath),
      sortOrder: sortOrder ?? this.sortOrder,
      usesAria2c: usesAria2c ?? this.usesAria2c,
      thumbnailUrl: clearThumbnailUrl
          ? thumbnailUrl
          : (thumbnailUrl ?? this.thumbnailUrl),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request': request.toJson(),
      'status': status.index,
      'progress': progress,
      'eta': eta,
      'speed': speed,
      'title': title,
      'error': error,
      'downloadedSize': downloadedSize,
      'totalSize': totalSize,
      'step': step,
      'filePath': filePath,
      'sortOrder': sortOrder,
      'usesAria2c': usesAria2c,
      'thumbnailUrl': thumbnailUrl, // Added
    };
  }

  /// Sanitized payload for browser-extension PROGRESS broadcasts.
  /// Intentionally omits cookies, file paths, and full request secrets.
  Map<String, dynamic> toExtensionProgressJson() {
    return {
      'id': id,
      'title': title,
      'status': status.index,
      'progress': progress,
      'speed': speed,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
      'eta': eta,
      'error': error,
      'url': request.url,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      request: DownloadRequest.fromJson(
        json['request'] as Map<String, dynamic>,
      ),
      status: DownloadStatus.values[json['status'] as int? ?? 0],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      eta: json['eta'] as String? ?? '',
      speed: json['speed'] as String? ?? '',
      title: json['title'] as String?,
      error: json['error'] as String?,
      downloadedSize: json['downloadedSize'] as String? ?? '',
      totalSize: json['totalSize'] as String? ?? '',
      step: json['step'] as String? ?? '',
      filePath: json['filePath'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      usesAria2c: json['usesAria2c'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?, // Added
    );
  }
}
