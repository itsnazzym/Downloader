/// Base class for all plugins in TapLoad.
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

  /// Called when the plugin is loaded
  Future<void> onInit() async {}

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

  const PluginModificationResult({this.newFilePath, this.newTitle});
}

/// Data passed to plugin lifecycle hooks
class PluginDownloadEvent {
  final String downloadId;
  final String url;
  final String? filePath;
  final String? title;
  final String source;
  final double progress;
  final String? error;

  const PluginDownloadEvent({
    required this.downloadId,
    required this.url,
    this.filePath,
    this.title,
    required this.source,
    this.progress = 0.0,
    this.error,
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
