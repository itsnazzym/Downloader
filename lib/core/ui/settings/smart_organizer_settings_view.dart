import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io'; // Added for Directory/File
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
import '../settings_view.dart';

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
  static const String _aiModeKey = 'smart_organizer_ai_mode';
  static const String _ollamaUrlKey = 'smart_organizer_ollama_url';
  static const String _ollamaModelKey = 'smart_organizer_ollama_model';

  List<OrganizationRule> _rules = [];
  bool _smartGuessEnabled = false;
  String _aiMode = 'offline';
  final TextEditingController _ollamaUrlController = TextEditingController();
  final TextEditingController _ollamaModelController =
      TextEditingController(); // Keep as backup or for manual entry
  bool _isLoading = true;
  List<String> _availableModels = [];
  bool _isFetchingModels = false;

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
        _aiMode = prefs.getString(_aiModeKey) ?? 'offline';
        _ollamaUrlController.text =
            prefs.getString(_ollamaUrlKey) ?? 'http://localhost:11434';
        _ollamaModelController.text =
            prefs.getString(_ollamaModelKey) ?? 'llama3';
        _isLoading = false;
      });
      if (_aiMode == 'ollama') {
        await _fetchModels();
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = _rules.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_rulesKey, rulesJson);
    await prefs.setBool(_smartGuessKey, _smartGuessEnabled);
    await prefs.setString(_aiModeKey, _aiMode);
    await prefs.setString(_ollamaUrlKey, _ollamaUrlController.text);
    await prefs.setString(_ollamaModelKey, _ollamaModelController.text);
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
          backgroundColor: AppColors.surface,
          title: Text(isEditing ? 'Edit Rule' : 'New Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                TextField(
                  controller: patternController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Pattern (Keyword or Regex)',
                    labelStyle: TextStyle(color: AppColors.textPrimary),
                    helperText: isRegex ? 'RegExp pattern' : 'Contains text',
                    helperStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                CheckboxListTile(
                  title: Text('Is Regex'),
                  value: isRegex,
                  onChanged: (v) => setState(() => isRegex = v ?? false),
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: targetController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Target Subfolder',
                          labelStyle: TextStyle(color: AppColors.textPrimary),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.folder_open,
                        color: AppColors.textPrimary,
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
                  title: Text('Active'),
                  value: active,
                  onChanged: (v) => setState(() => active = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
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
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchModels() async {
    setState(() => _isFetchingModels = true);
    try {
      final url = _ollamaUrlController.text.trim();
      final uri = Uri.parse('$url/api/tags');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((m) => m['name'].toString())
            .toList();
        setState(() => _availableModels = models);
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      // Keep existing models or empty
    } finally {
      setState(() => _isFetchingModels = false);
    }
  }

  Future<void> _pullModel(String modelName) async {
    // Basic implementation: fire and forget or simple alert
    // Improving this would require streaming response
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Requesting Ollama to pull $modelName... This may take a while.',
        ),
      ),
    );
    try {
      final url = _ollamaUrlController.text.trim();
      await http
          .post(
            Uri.parse('$url/api/pull'),
            body: jsonEncode({'name': modelName, 'stream': false}),
          )
          .timeout(
            const Duration(seconds: 1),
          ); // We don't wait for full download here in basic version
      // Wait, if stream is false, it waits until done. That might timeout.
      // Better to set stream: true and ignore response? Or just let user handle it in terminal.

      // For this "demo", we just show the message.
      // If user really wants to download, they should use terminal or we implement robust background task.
    } catch (e) {
      // Ignore timeout as we expect it to take long
    }
  }

  void _showDownloadModelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a popular model to pull:'),
            const Gap(16),
            Wrap(
              spacing: 8,
              children: ['llama3', 'mistral', 'gemma', 'phi3']
                  .map(
                    (m) => ActionChip(
                      label: Text(m),
                      avatar: Icon(Icons.download, size: 16),
                      onPressed: () {
                        _pullModel(m);
                        Navigator.pop(context);
                      },
                    ),
                  )
                  .toList(),
            ),
            const Gap(16),
            Text(
              'Note: This requires a fast internet connection. Check Ollama logs for progress.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
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
              'Organization Complete. Scanned $totalCount files, moved $movedCount.',
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
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Smart Organization'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
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
                    title: Text('Smart Guess (AI Curator)'),
                    subtitle: Text(
                      'Automatically categorize files based on common patterns or Local AI.',
                    ),
                    value: _smartGuessEnabled,
                    onChanged: (v) async {
                      setState(() => _smartGuessEnabled = v);
                      await _saveSettings();
                    },
                  ),
                  if (_smartGuessEnabled) ...[
                    Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            dropdownColor: AppColors.surface,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'AI Mode',
                              labelStyle: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            initialValue: _aiMode,
                            items: [
                              DropdownMenuItem(
                                value: 'offline',
                                child: Text(
                                  'Offline (Heuristic - Fast)',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'ollama',
                                child: Text(
                                  'Ollama / LocalAI',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) async {
                              if (v != null) {
                                setState(() => _aiMode = v);
                                await _saveSettings();
                              }
                            },
                          ),
                          if (_aiMode == 'ollama') ...[
                            const Gap(16),
                            TextField(
                              controller: _ollamaUrlController,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Ollama API URL',
                                labelStyle: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                hintText: 'http://localhost:11434',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                _saveSettings();
                                _fetchModels(); // Refresh available models
                              },
                            ),
                            const Gap(16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ollamaModelController,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Model Name',
                                      labelStyle: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      border: OutlineInputBorder(),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      helperText:
                                          'Select from list or type manually',
                                      helperStyle: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                      suffixIcon: PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: AppColors.textPrimary,
                                        ),
                                        color: AppColors.surface,
                                        onSelected: (String value) {
                                          _ollamaModelController.text = value;
                                          _saveSettings();
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return _availableModels.map((
                                            String choice,
                                          ) {
                                            return PopupMenuItem<String>(
                                              value: choice,
                                              child: Text(
                                                choice,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    onChanged: (_) => _saveSettings(),
                                  ),
                                ),
                                IconButton(
                                  icon: _isFetchingModels
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.refresh),
                                  onPressed: _fetchModels,
                                  tooltip: 'Refresh Models',
                                ),
                                IconButton(
                                  icon: Icon(Icons.download),
                                  onPressed: _showDownloadModelDialog,
                                  tooltip: 'Download Model',
                                ),
                              ],
                            ),
                            const Gap(8),
                            Text(
                              'Make sure Ollama is running (`ollama serve`).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
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
                const SectionTitle('Custom Rules'),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _showRuleDialog(),
                  tooltip: 'Add Rule',
                ),
              ],
            ),
            if (_rules.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No rules defined. Add one using the + button.'),
              ),
            ..._rules.map(
              (rule) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text('${rule.pattern} -> ${rule.targetFolder}'),
                  leading: Icon(
                    rule.isRegex ? Icons.code : Icons.text_fields,
                    color: rule.active ? AppColors.primary : Colors.grey,
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
                        icon: Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _deleteRule(rule.id),
                      ),
                    ],
                  ),
                  onTap: () => _showRuleDialog(rule: rule),
                ),
              ),
            ),
            const Gap(24),
            const SectionTitle('Tools'),
            Card(
              child: ListTile(
                leading: Icon(Icons.drive_file_move, color: AppColors.primary),
                title: Text('Organize Existing Files'),
                subtitle: Text(
                  'Scan a folder and organize files using current rules/AI.',
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: _organizeFolder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
