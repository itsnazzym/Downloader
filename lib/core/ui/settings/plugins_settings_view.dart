import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../plugins/plugin_manager.dart';

class PluginsSettingsView extends ConsumerWidget {
  const PluginsSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginState = ref.watch(pluginManagerProvider);
    final pluginManager = ref.read(pluginManagerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: SizedBox(),
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "Plugins",
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xl + 20,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: !pluginState.isLoaded
                ? Center(child: CircularProgressIndicator())
                : pluginState.plugins.isEmpty
                ? _buildEmptyState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pluginState.plugins
                        .map(
                          (entry) => _PluginCard(
                            entry: entry,
                            onToggle: (enabled) {
                              pluginManager.togglePlugin(
                                entry.plugin.id,
                                enabled,
                              );
                            },
                          ),
                        )
                        .toList()
                        .animate(interval: 80.ms)
                        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.1, end: 0, duration: 300.ms),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Gap(80),
          Icon(
            Icons.extension_off_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const Gap(AppSpacing.m),
          Text(
            "No plugins installed",
            style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
          ),
          const Gap(AppSpacing.xs),
          Text(
            "Plugins extend the functionality of Modern Downloader",
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PluginCard extends StatelessWidget {
  final PluginEntry entry;
  final ValueChanged<bool> onToggle;

  const _PluginCard({required this.entry, required this.onToggle});

  IconData _getIcon(String name) {
    switch (name) {
      case 'drive_file_rename_outline':
        return Icons.drive_file_rename_outline;
      case 'content_copy':
        return Icons.content_copy;
      case 'movie_filter':
        return Icons.movie_filter;
      case 'info_outline':
        return Icons.info_outline;
      case 'webhook':
        return Icons.webhook;
      case 'grid_view':
        return Icons.grid_view;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'terminal':
        return Icons.terminal;
      case 'folder_special':
        return Icons.folder_special;
      case 'extension':
        return Icons.extension;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isEnabled
              ? AppColors.border
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.isEnabled
                  ? AppColors.surfaceHighlight
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIcon(entry.plugin.iconName),
              color: entry.isEnabled
                  ? AppColors.textPrimary
                  : AppColors.textDisabled,
              size: 22,
            ),
          ),
          const Gap(AppSpacing.m),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.plugin.name,
                      style: AppTypography.label.copyWith(
                        color: entry.isEnabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'v${entry.plugin.version}',
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                    ),
                    if (entry.plugin.isBuiltIn) ...[
                      const Gap(AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Built-in',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  entry.plugin.description,
                  style: AppTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.error != null) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    'Error: ${entry.error}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Settings Button (if applicable)
          if (_hasSettings(entry.plugin.id)) ...[
            IconButton(
              icon: Icon(
                Icons.build_circle_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _openSettings(context, entry.plugin.id),
              tooltip: "Configure Plugin",
            ),
            const Gap(AppSpacing.s),
          ],

          // Toggle
          Switch(
            value: entry.isEnabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.success,
            inactiveThumbColor: AppColors.textDisabled,
            inactiveTrackColor: AppColors.surfaceHighlight,
          ),
        ],
      ),
    );
  }

  bool _hasSettings(String pluginId) {
    return pluginId == 'builtin_smart_organizer' ||
        pluginId == 'builtin_webhook_notifier' ||
        pluginId == 'builtin_post_process_script';
  }

  Future<void> _openSettings(BuildContext context, String pluginId) async {
    if (pluginId == 'builtin_smart_organizer') {
      context.push('/settings/smart_organizer');
      return;
    }

    if (pluginId == 'builtin_webhook_notifier') {
      await _showWebhookSettingsDialog(context);
      return;
    }

    if (pluginId == 'builtin_post_process_script') {
      await _showPostProcessScriptDialog(context);
    }
  }
}

Future<void> _showWebhookSettingsDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final urlController = TextEditingController(
    text: prefs.getString('plugin_webhook_url') ?? '',
  );
  bool notifyOnComplete = prefs.getBool('plugin_webhook_on_complete') ?? true;
  bool notifyOnFailed = prefs.getBool('plugin_webhook_on_failed') ?? true;

  if (!context.mounted) {
    return;
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Webhook Settings'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'Webhook URL',
                      hintText: 'https://example.com/hooks/modern-downloader',
                    ),
                  ),
                  const Gap(AppSpacing.m),
                  SwitchListTile(
                    value: notifyOnComplete,
                    onChanged: (value) =>
                        setState(() => notifyOnComplete = value),
                    title: Text('Notify on completed download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: notifyOnFailed,
                    onChanged: (value) =>
                        setState(() => notifyOnFailed = value),
                    title: Text('Notify on failed download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await prefs.setString(
                    'plugin_webhook_url',
                    urlController.text.trim(),
                  );
                  await prefs.setBool(
                    'plugin_webhook_on_complete',
                    notifyOnComplete,
                  );
                  await prefs.setBool(
                    'plugin_webhook_on_failed',
                    notifyOnFailed,
                  );

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showPostProcessScriptDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final pathController = TextEditingController(
    text: prefs.getString('plugin_post_process_script_path') ?? '',
  );
  final timeoutController = TextEditingController(
    text: (prefs.getInt('plugin_post_process_timeout_seconds') ?? 60)
        .toString(),
  );

  if (!context.mounted) {
    return;
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Post-Process Script'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pathController,
                          decoration: InputDecoration(
                            labelText: 'Script Path',
                            hintText: 'C:\\\\Scripts\\\\after_download.ps1',
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.s),
                      IconButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            dialogTitle: 'Select a script',
                            allowMultiple: false,
                          );
                          final selected = result?.files.single.path;
                          if (selected != null) {
                            pathController.text = selected;
                            setState(() {});
                          }
                        },
                        icon: Icon(Icons.folder_open_outlined),
                        tooltip: 'Browse',
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.m),
                  TextField(
                    controller: timeoutController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Timeout (seconds)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final timeout =
                      int.tryParse(timeoutController.text.trim()) ?? 60;
                  await prefs.setString(
                    'plugin_post_process_script_path',
                    pathController.text.trim(),
                  );
                  await prefs.setInt(
                    'plugin_post_process_timeout_seconds',
                    timeout,
                  );

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
