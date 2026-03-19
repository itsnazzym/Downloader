import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../logger/logger_service.dart';
import '../plugin_interface.dart';

class PostProcessScriptPlugin extends DownloaderPlugin {
  static const _scriptPathKey = 'plugin_post_process_script_path';
  static const _timeoutKey = 'plugin_post_process_timeout_seconds';

  @override
  String get id => 'builtin_post_process_script';

  @override
  String get name => 'Post-Process Script';

  @override
  String get version => '1.0.0';

  @override
  bool get enabledByDefault => false;

  @override
  String get description =>
      'Runs a local script after the download finishes, with environment variables describing the job.';

  @override
  String get iconName => 'terminal';

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    await _run(event, 'completed');
    return null;
  }

  @override
  Future<void> onDownloadFailed(PluginDownloadEvent event) async {
    await _run(event, 'failed');
  }

  Future<void> _run(PluginDownloadEvent event, String stage) async {
    final prefs = await SharedPreferences.getInstance();
    final scriptPath = prefs.getString(_scriptPathKey)?.trim() ?? '';
    if (scriptPath.isEmpty) {
      return;
    }

    final scriptFile = File(scriptPath);
    if (!await scriptFile.exists()) {
      LoggerService.w('[PostProcessScript] Script not found: $scriptPath');
      return;
    }

    final timeoutSeconds = prefs.getInt(_timeoutKey) ?? 60;
    final invocation = _buildInvocation(scriptPath, event, stage);
    if (invocation == null) {
      return;
    }

    try {
      final result = await Process.run(
        invocation.executable,
        invocation.arguments,
        runInShell: true,
        environment: invocation.environment,
      ).timeout(Duration(seconds: timeoutSeconds));

      if (result.exitCode != 0) {
        LoggerService.w(
          '[PostProcessScript] Script exited with ${result.exitCode}: ${result.stderr}',
        );
      }
    } catch (e) {
      LoggerService.w('[PostProcessScript] Failed to run script: $e');
    }
  }

  _ScriptInvocation? _buildInvocation(
    String scriptPath,
    PluginDownloadEvent event,
    String stage,
  ) {
    final env = {
      ...Platform.environment,
      'MD_EVENT': stage,
      'MD_DOWNLOAD_ID': event.downloadId,
      'MD_SOURCE': event.source,
      'MD_URL': event.url,
      'MD_TITLE': event.title ?? '',
      'MD_FILE_PATH': event.filePath ?? '',
      'MD_ERROR': event.error ?? '',
    };

    final lower = scriptPath.toLowerCase();
    final args = [
      '--download-id',
      event.downloadId,
      '--event',
      stage,
      '--url',
      event.url,
      '--source',
      event.source,
    ];
    if (event.title != null) {
      args.addAll(['--title', event.title!]);
    }
    if (event.filePath != null) {
      args.addAll(['--file', event.filePath!]);
    }
    if (event.error != null) {
      args.addAll(['--error', event.error!]);
    }

    if (lower.endsWith('.ps1')) {
      return _ScriptInvocation(
        executable: 'powershell',
        arguments: ['-ExecutionPolicy', 'Bypass', '-File', scriptPath, ...args],
        environment: env,
      );
    }

    if (lower.endsWith('.cmd') || lower.endsWith('.bat')) {
      return _ScriptInvocation(
        executable: 'cmd',
        arguments: ['/c', scriptPath, ...args],
        environment: env,
      );
    }

    return _ScriptInvocation(
      executable: scriptPath,
      arguments: args,
      environment: env,
    );
  }
}

class _ScriptInvocation {
  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;

  const _ScriptInvocation({
    required this.executable,
    required this.arguments,
    required this.environment,
  });
}
