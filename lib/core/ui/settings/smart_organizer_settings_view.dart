import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../plugins/builtin/smart_organizer_plugin.dart';
import '../../plugins/plugin_manager.dart'; // Added
import 'widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'widgets/settings_app_bar_leading.dart';
import 'widgets/settings_app_bar.dart';

class SmartOrganizerSettingsView extends ConsumerStatefulWidget {
  const SmartOrganizerSettingsView({super.key});

  @override
  ConsumerState<SmartOrganizerSettingsView> createState() =>
      _SmartOrganizerSettingsViewState();
}

class _SmartOrganizerSettingsViewState
    extends ConsumerState<SmartOrganizerSettingsView> {
  static const String _rulesKey = 'smart_organizer_rules';
  static const String _smartGuessKey = 'smart_organizer_smart_guess';
  List<OrganizationRule> _rules = [];
  bool _smartGuessEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getStringList(_rulesKey) ?? [];
    if (mounted) {
      setState(() {
        _rules = rulesJson
            .map((e) => OrganizationRule.fromJson(jsonDecode(e)))
            .toList();
        _smartGuessEnabled = prefs.getBool(_smartGuessKey) ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = _rules.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_rulesKey, rulesJson);
    await prefs.setBool(_smartGuessKey, _smartGuessEnabled);
  }

  Future<void> _addOrUpdateRule(OrganizationRule rule) async {
    setState(() {
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) {
        _rules[index] = rule;
      } else {
        _rules.add(rule);
      }
    });
    await _saveSettings();
  }

  Future<void> _deleteRule(String id) async {
    setState(() {
      _rules.removeWhere((r) => r.id == id);
    });
    await _saveSettings();
  }

  void _showRuleDialog({OrganizationRule? rule}) {
    final isEditing = rule != null;
    final nameController = TextEditingController(text: rule?.name);
    final patternController = TextEditingController(text: rule?.pattern);
    final targetController = TextEditingController(text: rule?.targetFolder);
    bool isRegex = rule?.isRegex ?? false;
    bool active = rule?.active ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.of(context).surface,
          title: Text(isEditing ? context.l10n.editRule : context.l10n.newRule),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.nameLabel,
                    labelStyle: TextStyle(
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                ),
                TextField(
                  controller: patternController,
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.patternKeywordOrRegex,
                    labelStyle: TextStyle(
                      color: AppColors.of(context).textPrimary,
                    ),
                    helperText: isRegex
                        ? context.l10n.regexpPattern
                        : context.l10n.containsText,
                    helperStyle: TextStyle(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ),
                CheckboxListTile(
                  title: Text(context.l10n.isRegex),
                  value: isRegex,
                  onChanged: (v) => setState(() => isRegex = v ?? false),
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: targetController,
                        style: TextStyle(
                          color: AppColors.of(context).textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.targetSubfolder,
                          labelStyle: TextStyle(
                            color: AppColors.of(context).textPrimary,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.of(context).textSecondary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.of(context).primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.folder_open,
                        color: AppColors.of(context).textPrimary,
                      ),
                      onPressed: () async {
                        final result = await FilePicker.platform
                            .getDirectoryPath();
                        if (result != null) {
                          targetController.text = result;
                        }
                      },
                    ),
                  ],
                ),
                CheckboxListTile(
                  title: Text(context.l10n.active),
                  value: active,
                  onChanged: (v) => setState(() => active = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    patternController.text.isEmpty ||
                    targetController.text.isEmpty) {
                  return;
                }
                final newRule = OrganizationRule(
                  id: rule?.id ?? const Uuid().v4(),
                  name: nameController.text,
                  pattern: patternController.text,
                  isRegex: isRegex,
                  targetFolder: targetController.text,
                  active: active,
                );
                _addOrUpdateRule(newRule);
                Navigator.pop(context);
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _organizeFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    // Find the plugin instance
    final pluginState = ref.read(pluginManagerProvider);
    final pluginEntry = pluginState.plugins.firstWhere(
      (p) => p.plugin is SmartOrganizerPlugin,
      orElse: () => throw Exception('Smart Organizer plugin not found'),
    );
    final plugin = pluginEntry.plugin as SmartOrganizerPlugin;

    // Show progress
    if (!mounted) return;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),
    );

    int movedCount = 0;
    int totalCount = 0;

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalCount++;
          // Optional: Check if file is already in a category folder?
          // For now, just try to organize it.
          final result = await plugin.organizeFile(entity);
          if (result != null) {
            movedCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error during bulk organization: $e');
    } finally {
      if (mounted) {
        Navigator.pop(context); // Close progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.organizationCompleteDetail(totalCount, movedCount),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: SettingsFramed.of(context)
          ? null
          : AppBar(
              leading: const SettingsAppBarLeading(),
              title: Text(context.l10n.smartOrganization),
              backgroundColor: AppColors.of(context).background,
              surfaceTintColor: useOledSettingsStyle(context)
                  ? Colors.transparent
                  : null,
              scrolledUnderElevation: useOledSettingsStyle(context) ? 0 : null,
              elevation: 0,
              foregroundColor: AppColors.of(context).textPrimary,
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smart Guess
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(context.l10n.smartGuessTitle),
                    subtitle: Text(context.l10n.smartGuessDesc),
                    value: _smartGuessEnabled,
                    onChanged: (v) async {
                      setState(() => _smartGuessEnabled = v);
                      await _saveSettings();
                    },
                  ),
                  if (_smartGuessEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.l10n.aiModeOffline,
                        style: TextStyle(
                          color: AppColors.of(context).textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionTitle(context.l10n.customRules),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(
                        Icons.playlist_add_check_rounded,
                        size: 18,
                      ),
                      label: Text(context.l10n.settingsSmartRecommendedRules),
                      onPressed: () async {
                        for (final preset
                            in SmartOrganizerPlugin.defaultPresets) {
                          if (!_rules.any((r) => r.id == preset.id)) {
                            _rules.add(preset);
                          }
                        }
                        await _saveSettings();
                        if (mounted) setState(() {});
                      },
                    ),
                    const Gap(8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showRuleDialog(),
                      tooltip: context.l10n.addRule,
                    ),
                  ],
                ),
              ],
            ),
            if (_rules.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(context.l10n.noRulesDefined),
              ),
            ..._rules.map(
              (rule) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text('${rule.pattern} -> ${rule.targetFolder}'),
                  leading: Icon(
                    rule.isRegex ? Icons.code : Icons.text_fields,
                    color: rule.active
                        ? AppColors.of(context).primary
                        : Colors.grey,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.active,
                        onChanged: (v) {
                          final updated = OrganizationRule(
                            id: rule.id,
                            name: rule.name,
                            pattern: rule.pattern,
                            isRegex: rule.isRegex,
                            targetFolder: rule.targetFolder,
                            active: v,
                          );
                          _addOrUpdateRule(updated);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: AppColors.of(context).error,
                        ),
                        onPressed: () => _deleteRule(rule.id),
                      ),
                    ],
                  ),
                  onTap: () => _showRuleDialog(rule: rule),
                ),
              ),
            ),
            const Gap(24),
            SectionTitle(context.l10n.toolsSection),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.drive_file_move,
                  color: AppColors.of(context).primary,
                ),
                title: Text(context.l10n.organizeExistingFiles),
                subtitle: Text(context.l10n.organizeExistingFilesDesc),
                trailing: const Icon(Icons.chevron_right),
                onTap: _organizeFolder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
