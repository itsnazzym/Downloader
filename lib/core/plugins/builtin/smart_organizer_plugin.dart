import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../plugin_interface.dart';

class SmartOrganizerPlugin extends DownloaderPlugin {
  static const String _rulesKey = 'smart_organizer_rules';
  static const String _smartGuessKey = 'smart_organizer_smart_guess';

  static List<OrganizationRule> get defaultPresets => [
    OrganizationRule(
      id: 'preset_music',
      name: 'Musique & Audio',
      pattern: r'(official audio|lyrics|feat\.|prod\.|remix|\.mp3|\.flac|\.wav|\.m4a)',
      isRegex: true,
      targetFolder: 'Musique',
      active: true,
    ),
    OrganizationRule(
      id: 'preset_series',
      name: 'Séries TV (SxxExx)',
      pattern: r'(s\d{1,2}e\d{1,2}|season\s*\d+|episode\s*\d+)',
      isRegex: true,
      targetFolder: 'Séries',
      active: true,
    ),
    OrganizationRule(
      id: 'preset_tutorials',
      name: 'Tutoriels & Guides',
      pattern: r'(tuto|tutorial|course|formation|how to|guide)',
      isRegex: true,
      targetFolder: 'Tutoriels',
      active: true,
    ),
    OrganizationRule(
      id: 'preset_platforms_yt',
      name: 'YouTube',
      pattern: r'(youtube|youtu\.be)',
      isRegex: true,
      targetFolder: 'YouTube',
      active: false,
    ),
    OrganizationRule(
      id: 'preset_platforms_x',
      name: 'X / Twitter',
      pattern: r'(twitter|x\.com)',
      isRegex: true,
      targetFolder: 'Twitter',
      active: false,
    ),
    OrganizationRule(
      id: 'preset_platforms_twitch',
      name: 'Twitch',
      pattern: r'(twitch\.tv)',
      isRegex: true,
      targetFolder: 'Twitch',
      active: false,
    ),
  ];

  @override
  String get id => 'builtin_smart_organizer';

  @override
  String get name => 'Smart Organizer (AI Curator)';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Automatically organizes downloaded files into folders based on custom rules and intelligent guessing.';

  @override
  String get iconName => 'folder_special';

  @override
  bool get isBuiltIn => true;

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    if (event.filePath == null) return null;
    return organizeFile(File(event.filePath!), title: event.title);
  }

  /// Organizes a single file based on rules and AI.
  /// Returns the result if moved, or null if no action taken.
  Future<PluginModificationResult?> organizeFile(
    File file, {
    String? title,
  }) async {
    if (!await file.exists()) return null;

    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getStringList(_rulesKey) ?? [];
    final rules = rulesJson
        .map((e) => OrganizationRule.fromJson(jsonDecode(e)))
        .where((r) => r.active)
        .toList();

    final fileName = file.uri.pathSegments.last;
    // Use provided title or fallback to filename
    final effectiveTitle = title ?? fileName;

    // 1. Check user-defined rules
    for (final rule in rules) {
      if (_matches(rule, effectiveTitle, fileName)) {
        return _moveFile(file, rule.targetFolder);
      }
    }

    // 2. Smart Guess (Offline Heuristics)
    final smartGuessEnabled = prefs.getBool(_smartGuessKey) ?? false;
    if (smartGuessEnabled) {
      final category = _smartGuessCategory(effectiveTitle, fileName);
      if (category != null) {
        final targetDir =
            '${file.parent.path}${Platform.pathSeparator}$category';
        return _moveFile(file, targetDir);
      }
    }

    return null;
  }

  bool _matches(OrganizationRule rule, String title, String fileName) {
    final input = title; // Analyze title mainly
    try {
      if (rule.isRegex) {
        return RegExp(rule.pattern, caseSensitive: false).hasMatch(input) ||
            RegExp(rule.pattern, caseSensitive: false).hasMatch(fileName);
      } else {
        return input.toLowerCase().contains(rule.pattern.toLowerCase()) ||
            fileName.toLowerCase().contains(rule.pattern.toLowerCase());
      }
    } catch (e) {
      debugPrint('[SmartOrganizer] Invalid Regex: ${rule.pattern}');
      return false;
    }
  }

  String? _smartGuessCategory(String title, String fileName) {
    final lower = title.toLowerCase();

    // Music
    if (lower.contains('official video') ||
        lower.contains('lyrics') ||
        lower.contains('feat.') ||
        lower.contains('ft.') ||
        lower.contains('audio') ||
        lower.contains('music video')) {
      return 'Music';
    }

    // Series (S01E01 pattern)
    if (RegExp(r'[sS]\d{1,2}[eE]\d{1,2}').hasMatch(title)) {
      return 'Series';
    }

    // Tutorials / Dev
    if (lower.contains('tutorial') ||
        lower.contains('how to') ||
        lower.contains('crash course') ||
        lower.contains('lesson')) {
      return 'Tutorials';
    }

    return null;
  }

  Future<PluginModificationResult?> _moveFile(
    File file,
    String targetDirBox,
  ) async {
    try {
      final targetDir = Directory(targetDirBox);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = file.uri.pathSegments.last;
      final newPath = '${targetDir.path}${Platform.pathSeparator}$fileName';

      // Handle collision
      String uniquePath = newPath;
      int counter = 1;
      while (await File(uniquePath).exists()) {
        final dot = fileName.lastIndexOf('.');
        final name = dot == -1 ? fileName : fileName.substring(0, dot);
        final ext = dot == -1 ? '' : fileName.substring(dot);
        uniquePath =
            '${targetDir.path}${Platform.pathSeparator}$name ($counter)$ext';
        counter++;
      }

      // Rename Sidecars if exist (e.g. .jpg thumbnail, .en.vtt subtitle)
      final dotIndex = file.path.lastIndexOf('.');
      final oldBase = dotIndex == -1
          ? file.path
          : file.path.substring(0, dotIndex);
      final uniqueDotIndex = uniquePath.lastIndexOf('.');
      final newBase = uniqueDotIndex == -1
          ? uniquePath
          : uniquePath.substring(0, uniqueDotIndex);

      final parentDir = file.parent;
      await for (final entity in parentDir.list()) {
        if (entity is File &&
            entity.path.startsWith(oldBase) &&
            entity.path != file.path) {
          // It's a related file (thumbnail, json, subtitle)
          // e.g. video.mp4, video.jpg, video.en.srt
          final suffix = entity.path.substring(oldBase.length);
          final sidecarNewPath = '$newBase$suffix';
          try {
            await entity.rename(sidecarNewPath);
          } catch (e) {
            debugPrint('Failed to move sidecar: $e');
          }
        }
      }

      await file.rename(uniquePath);
      debugPrint('[SmartOrganizer] Moved to: $uniquePath');
      return PluginModificationResult(newFilePath: uniquePath);
    } catch (e) {
      debugPrint('[SmartOrganizer] Failed to move file: $e');
      return null;
    }
  }
}

class OrganizationRule {
  final String id;
  final String name;
  final String pattern;
  final bool isRegex;
  final String targetFolder;
  final bool active;

  OrganizationRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.isRegex,
    required this.targetFolder,
    required this.active,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'isRegex': isRegex,
    'targetFolder': targetFolder,
    'active': active,
  };

  factory OrganizationRule.fromJson(Map<String, dynamic> json) =>
      OrganizationRule(
        id: json['id'] ?? const Uuid().v4(),
        name: json['name'] ?? 'Rule',
        pattern: json['pattern'] ?? '',
        isRegex: json['isRegex'] ?? false,
        targetFolder: json['targetFolder'] ?? '',
        active: json['active'] ?? true,
      );
}
