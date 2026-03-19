import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/binary_locator.dart';
import '../../services/process_runner.dart';
import '../../services/service_providers.dart';
import 'plugin_interface.dart';
import 'builtin/auto_rename_plugin.dart';
import 'builtin/duplicate_guard_plugin.dart';
import 'builtin/ffmpeg_normalize_plugin.dart';
import 'builtin/metadata_enricher_plugin.dart';
import 'builtin/post_process_script_plugin.dart';
import 'builtin/smart_organizer_plugin.dart';
import 'builtin/storage_cleaner_plugin.dart';
import 'builtin/thumbnail_sheet_plugin.dart';
import 'builtin/webhook_notifier_plugin.dart';

/// Manages the lifecycle and state of all plugins.
class PluginManager extends StateNotifier<PluginManagerState> {
  PluginManager(this._binaryLocator, this._processRunner)
    : super(PluginManagerState.initial()) {
    _loadPlugins();
  }

  final BinaryLocator _binaryLocator;
  final ProcessRunner _processRunner;

  Future<void> _loadPlugins() async {
    final prefs = await SharedPreferences.getInstance();

    final builtins = <DownloaderPlugin>[
      DuplicateGuardPlugin(),
      AutoRenamePlugin(),
      FfmpegNormalizePlugin(_binaryLocator),
      SmartOrganizerPlugin(),
      MetadataEnricherPlugin(_binaryLocator, _processRunner),
      ThumbnailSheetPlugin(_binaryLocator),
      StorageCleanerPlugin(),
      WebhookNotifierPlugin(),
      PostProcessScriptPlugin(),
    ];

    final plugins = <PluginEntry>[];
    for (final plugin in builtins) {
      final key = 'plugin_enabled_${plugin.id}';
      final enabled = prefs.getBool(key) ?? plugin.enabledByDefault;
      try {
        if (enabled) await plugin.onInit();
        plugins.add(PluginEntry(plugin: plugin, isEnabled: enabled));
      } catch (e) {
        debugPrint('Failed to init plugin ${plugin.id}: $e');
        plugins.add(PluginEntry(plugin: plugin, isEnabled: false, error: '$e'));
      }
    }

    state = PluginManagerState(plugins: plugins, isLoaded: true);
  }

  Future<void> togglePlugin(String pluginId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plugin_enabled_$pluginId', enabled);

    final updated = <PluginEntry>[];
    for (final entry in state.plugins) {
      if (entry.plugin.id == pluginId) {
        try {
          if (enabled) {
            await entry.plugin.onInit();
          } else {
            await entry.plugin.dispose();
          }
          updated.add(PluginEntry(plugin: entry.plugin, isEnabled: enabled));
        } catch (e) {
          updated.add(
            PluginEntry(plugin: entry.plugin, isEnabled: false, error: '$e'),
          );
        }
      } else {
        updated.add(entry);
      }
    }

    state = PluginManagerState(plugins: updated, isLoaded: true);
  }

  Future<PluginPreDownloadResult?> onBeforeDownload(
    PluginDownloadEvent event,
  ) async {
    for (final entry in state.enabledPlugins) {
      try {
        final result = await entry.plugin.onBeforeDownload(event);
        if (result?.shouldCancel == true) {
          return result;
        }
      } catch (e) {
        debugPrint('Plugin ${entry.plugin.id} error before download: $e');
      }
    }
    return null;
  }

  /// Dispatch download start event to all enabled plugins
  Future<void> onDownloadStart(PluginDownloadEvent event) async {
    for (final entry in state.enabledPlugins) {
      try {
        await entry.plugin.onDownloadStart(event);
      } catch (e) {
        debugPrint('Plugin ${entry.plugin.id} error on start: $e');
      }
    }
  }

  /// Dispatch download complete event to all enabled plugins
  /// Returns the final modification result if any plugin modified the item
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    String? currentFilePath = event.filePath;
    String? currentTitle = event.title;
    String? currentThumbnailPath =
        event.sourceMetadata?['thumbnail'] as String?;
    bool modified = false;

    for (final entry in state.enabledPlugins) {
      try {
        // Create updated event for the next plugin in the chain
        final currentEvent = event.copyWith(
          filePath: currentFilePath,
          title: currentTitle,
          sourceMetadata: {
            ...?event.sourceMetadata,
            if (currentThumbnailPath != null) 'thumbnail': currentThumbnailPath,
          },
        );

        final result = await entry.plugin.onDownloadComplete(currentEvent);

        if (result != null) {
          if (result.newFilePath != null) {
            currentFilePath = result.newFilePath;
            modified = true;
          }
          if (result.newTitle != null) {
            currentTitle = result.newTitle;
            modified = true;
          }
          if (result.newThumbnailPath != null) {
            currentThumbnailPath = result.newThumbnailPath;
            modified = true;
          }
        }
      } catch (e) {
        debugPrint('Plugin ${entry.plugin.id} error on complete: $e');
      }
    }

    if (modified) {
      return PluginModificationResult(
        newFilePath: currentFilePath,
        newTitle: currentTitle,
        newThumbnailPath: currentThumbnailPath,
      );
    }
    return null;
  }

  /// Dispatch download failed event to all enabled plugins
  Future<void> onDownloadFailed(PluginDownloadEvent event) async {
    for (final entry in state.enabledPlugins) {
      try {
        await entry.plugin.onDownloadFailed(event);
      } catch (e) {
        debugPrint('Plugin ${entry.plugin.id} error on failed: $e');
      }
    }
  }

  /// Get all menu actions from enabled plugins
  List<PluginMenuAction> getAllMenuActions() {
    return state.enabledPlugins
        .expand((entry) => entry.plugin.getMenuActions())
        .toList();
  }
}

class PluginEntry {
  final DownloaderPlugin plugin;
  final bool isEnabled;
  final String? error;

  const PluginEntry({
    required this.plugin,
    required this.isEnabled,
    this.error,
  });
}

class PluginManagerState {
  final List<PluginEntry> plugins;
  final bool isLoaded;

  const PluginManagerState({required this.plugins, required this.isLoaded});

  factory PluginManagerState.initial() =>
      const PluginManagerState(plugins: [], isLoaded: false);

  List<PluginEntry> get enabledPlugins =>
      plugins.where((p) => p.isEnabled).toList();
}

/// Riverpod provider for the plugin manager
final pluginManagerProvider =
    StateNotifierProvider<PluginManager, PluginManagerState>(
      (ref) => PluginManager(
        ref.read(binaryLocatorProvider),
        ref.read(processRunnerProvider),
      ),
    );
