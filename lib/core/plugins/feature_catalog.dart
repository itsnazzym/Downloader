import 'dart:convert';

const Map<String, String> _compiledModuleRoutes = {
  'x_browser': '/browse',
  'tiktok_archives': '/archive',
  'statistics': '/stats',
  'device_transfer': '/transfer',
};

class FeaturePluginDescriptor {
  const FeaturePluginDescriptor({
    required this.id,
    required this.kind,
    required this.platforms,
    required this.names,
    required this.descriptions,
    required this.icon,
    required this.route,
    required this.defaultEnabled,
    this.preferenceId,
  });

  final String id;
  final String kind;
  final Set<String> platforms;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final String icon;
  final String route;
  final bool defaultEnabled;
  final String? preferenceId;

  bool get isCore => kind == 'core';
  bool get isModule => kind == 'module';
  bool get isDownloadHook => kind == 'download_hook';
  bool get isExternalExtension => kind == 'external_extension';
  bool supportsPlatform(String platform) => platforms.contains(platform);

  String nameFor(String locale) =>
      names[locale] ?? names['en'] ?? names.values.first;

  String descriptionFor(String locale) =>
      descriptions[locale] ?? descriptions['en'] ?? descriptions.values.first;

  factory FeaturePluginDescriptor.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    final platforms = json['platforms'];
    final route = json['route'];
    if (id is! String || !RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
      throw const FormatException('Invalid plugin id');
    }
    if (!const {
      'core',
      'module',
      'download_hook',
      'external_extension',
    }.contains(kind)) {
      throw FormatException('Invalid plugin kind for $id');
    }
    if (platforms is! List ||
        platforms.isEmpty ||
        platforms.any(
          (value) =>
              value is! String || !const {'windows', 'android'}.contains(value),
        ) ||
        platforms.toSet().length != platforms.length) {
      throw FormatException('Invalid platforms for $id');
    }
    if (route is! String || !route.startsWith('/')) {
      throw FormatException('Invalid plugin route for $id');
    }
    if (kind == 'module' && _compiledModuleRoutes[id] != route) {
      throw FormatException('Module route is not registered for $id');
    }
    if (kind != 'module' && route != '/' && route != '/settings/plugins') {
      throw FormatException('Unsupported plugin route for $id');
    }
    return FeaturePluginDescriptor(
      id: id,
      kind: kind as String,
      platforms: Set.unmodifiable(platforms.cast<String>()),
      names: _readLocalizedMap(json['name'], 'name', id),
      descriptions: _readLocalizedMap(json['description'], 'description', id),
      icon: json['icon'] is String ? json['icon'] as String : 'extension',
      route: route,
      defaultEnabled: json['defaultEnabled'] == true,
      preferenceId: json['preferenceId'] is String
          ? json['preferenceId'] as String
          : null,
    );
  }

  static Map<String, String> _readLocalizedMap(
    Object? value,
    String field,
    String id,
  ) {
    if (value is! Map<String, dynamic> || value.isEmpty) {
      throw FormatException('Missing $field translations for $id');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.value is! String || (entry.value as String).trim().isEmpty) {
        throw FormatException('Invalid $field translation for $id');
      }
      result[entry.key] = entry.value as String;
    }
    return Map.unmodifiable(result);
  }
}

class FeatureCatalog {
  FeatureCatalog._(this.schemaVersion, this.plugins)
    : byId = Map.unmodifiable({
        for (final plugin in plugins) plugin.id: plugin,
      });

  final int schemaVersion;
  final List<FeaturePluginDescriptor> plugins;
  final Map<String, FeaturePluginDescriptor> byId;

  factory FeatureCatalog.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != 1 ||
        decoded['plugins'] is! List) {
      throw const FormatException('Unsupported plugin catalog');
    }
    final plugins = <FeaturePluginDescriptor>[];
    final ids = <String>{};
    for (final item in decoded['plugins'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid plugin catalog item');
      }
      final plugin = FeaturePluginDescriptor.fromJson(item);
      if (!ids.add(plugin.id)) {
        throw FormatException('Duplicate plugin id: ${plugin.id}');
      }
      plugins.add(plugin);
    }
    if (!plugins.any(
      (plugin) => plugin.id == 'core_downloads' && plugin.isCore,
    )) {
      throw const FormatException('Plugin catalog must include core downloads');
    }
    return FeatureCatalog._(1, List.unmodifiable(plugins));
  }

  List<FeaturePluginDescriptor> get modules =>
      plugins.where((plugin) => plugin.isCore || plugin.isModule).toList();

  List<FeaturePluginDescriptor> get downloadHooks =>
      plugins.where((plugin) => plugin.isDownloadHook).toList();

  List<FeaturePluginDescriptor> get externalExtensions =>
      plugins.where((plugin) => plugin.isExternalExtension).toList();
}
