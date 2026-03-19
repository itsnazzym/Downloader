import '../../features/downloader/domain/entities/download_request.dart';

/// Base class for all plugins in Modern Downloader.
///
/// Plugins can hook into download lifecycle events and provide
/// custom menu actions. Implement this class to create a new plugin.
abstract class DownloaderPlugin {
  /// Unique identifier for this plugin
  String get id;

  /// Display name
  String get name;

  /// Plugin version (semver)
  String get version;

  /// Short description of what this plugin does
  String get description;

  /// Icon data name (Material icon name)
  String get iconName => 'extension';

  /// Whether this is a built-in plugin
  bool get isBuiltIn => false;

  /// Whether the plugin should start enabled when no preference exists yet.
  bool get enabledByDefault => true;

  /// Called when the plugin is loaded
  Future<void> onInit() async {}

  /// Called after metadata resolution but before the actual download starts.
  /// Plugins can veto the download, for example to block duplicates.
  Future<PluginPreDownloadResult?> onBeforeDownload(
    PluginDownloadEvent event,
  ) async {
    return null;
  }

  /// Called when a download starts
  Future<void> onDownloadStart(PluginDownloadEvent event) async {}

  /// Called when a download completes successfully.
  /// Returns a modification result if the plugin changed the file path or title.
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    return null;
  }

  /// Called when a download fails
  Future<void> onDownloadFailed(PluginDownloadEvent event) async {}

  /// Return custom menu actions that appear in the download context menu
  List<PluginMenuAction> getMenuActions() => [];

  /// Called when the plugin is unloaded
  Future<void> dispose() async {}
}

/// Result of a plugin operation that modified the download item
class PluginModificationResult {
  final String? newFilePath;
  final String? newTitle;
  final String? newThumbnailPath;

  const PluginModificationResult({
    this.newFilePath,
    this.newTitle,
    this.newThumbnailPath,
  });
}

/// Data passed to plugin lifecycle hooks
class PluginDownloadEvent {
  final String downloadId;
  final String url;
  final DownloadRequest? request;
  final String? filePath;
  final String? title;
  final String source;
  final double progress;
  final String? error;
  final String? outputDirectory;
  final Map<String, dynamic>? sourceMetadata;
  final List<PluginDownloadSnapshot> existingDownloads;

  const PluginDownloadEvent({
    required this.downloadId,
    required this.url,
    this.request,
    this.filePath,
    this.title,
    required this.source,
    this.progress = 0.0,
    this.error,
    this.outputDirectory,
    this.sourceMetadata,
    this.existingDownloads = const [],
  });

  PluginDownloadEvent copyWith({
    DownloadRequest? request,
    String? filePath,
    String? title,
    double? progress,
    String? error,
    String? outputDirectory,
    Map<String, dynamic>? sourceMetadata,
    List<PluginDownloadSnapshot>? existingDownloads,
  }) {
    return PluginDownloadEvent(
      downloadId: downloadId,
      url: url,
      request: request ?? this.request,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      source: source,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      sourceMetadata: sourceMetadata ?? this.sourceMetadata,
      existingDownloads: existingDownloads ?? this.existingDownloads,
    );
  }
}

class PluginDownloadSnapshot {
  final String downloadId;
  final String url;
  final String status;
  final String? filePath;
  final String? title;

  const PluginDownloadSnapshot({
    required this.downloadId,
    required this.url,
    required this.status,
    this.filePath,
    this.title,
  });
}

class PluginPreDownloadResult {
  final bool shouldCancel;
  final bool isDuplicate;
  final String? message;
  final String? existingFilePath;

  const PluginPreDownloadResult({
    this.shouldCancel = false,
    this.isDuplicate = false,
    this.message,
    this.existingFilePath,
  });
}

/// A custom menu action provided by a plugin
class PluginMenuAction {
  final String label;
  final String iconName;
  final Future<void> Function(String downloadId) onAction;

  const PluginMenuAction({
    required this.label,
    required this.iconName,
    required this.onAction,
  });
}
