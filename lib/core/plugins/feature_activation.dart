import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feature_catalog.dart';

const _migrationKey = 'feature_plugins_migration_v1';

String _featurePreferenceKey(String id) => 'feature_enabled_$id';

/// Migrates existing users without changing their current plugin behavior.
/// New profiles get the essential downloader only; all other entries start off.
Future<void> migrateFeaturePluginPreferences(
  SharedPreferences preferences,
  FeatureCatalog catalog,
) async {
  if (preferences.getBool(_migrationKey) == true) return;

  // Run before SettingsNotifier creates its first-run API token. Existing app
  // profiles have at least one persisted preference by the time they upgrade.
  final isExistingProfile = preferences.getKeys().isNotEmpty;
  for (final plugin in catalog.plugins) {
    if (plugin.isModule && !plugin.isCore) {
      final key = _featurePreferenceKey(plugin.id);
      if (!preferences.containsKey(key)) {
        await preferences.setBool(key, isExistingProfile);
      }
    } else if (plugin.isDownloadHook && plugin.preferenceId != null) {
      final key = 'plugin_enabled_${plugin.preferenceId}';
      if (!preferences.containsKey(key)) {
        await preferences.setBool(key, isExistingProfile);
      }
    }
  }
  await preferences.setBool(_migrationKey, true);
}

class FeatureActivationState {
  const FeatureActivationState(this.enabledById);

  final Map<String, bool> enabledById;

  bool isEnabled(FeaturePluginDescriptor plugin) =>
      plugin.isCore || enabledById[plugin.id] == true;

  bool isEnabledById(String id) =>
      id == 'core_downloads' || enabledById[id] == true;
}

class FeatureActivationController
    extends StateNotifier<FeatureActivationState> {
  FeatureActivationController({
    required this.preferences,
    required this.catalog,
  }) : super(
         FeatureActivationState({
           for (final plugin in catalog.plugins.where((p) => p.isModule))
             plugin.id:
                 preferences.getBool(_featurePreferenceKey(plugin.id)) ??
                 plugin.defaultEnabled,
         }),
       );

  final SharedPreferences preferences;
  final FeatureCatalog catalog;

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final plugin = catalog.byId[pluginId];
    if (plugin == null || !plugin.isModule || plugin.isCore) return;
    await preferences.setBool(_featurePreferenceKey(pluginId), enabled);
    state = FeatureActivationState({...state.enabledById, pluginId: enabled});
  }
}

final featureCatalogProvider = Provider<FeatureCatalog>((ref) {
  throw StateError('FeatureCatalog must be provided during app startup');
});

final featureActivationProvider =
    StateNotifierProvider<FeatureActivationController, FeatureActivationState>(
      (ref) => throw StateError(
        'FeatureActivationController must be provided during app startup',
      ),
    );
