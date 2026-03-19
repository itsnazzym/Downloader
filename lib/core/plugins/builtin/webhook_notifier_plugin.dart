import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../logger/logger_service.dart';
import '../plugin_interface.dart';

class WebhookNotifierPlugin extends DownloaderPlugin {
  static const _urlKey = 'plugin_webhook_url';
  static const _completeKey = 'plugin_webhook_on_complete';
  static const _failedKey = 'plugin_webhook_on_failed';

  @override
  String get id => 'builtin_webhook_notifier';

  @override
  String get name => 'Webhook Notifier';

  @override
  String get version => '1.0.0';

  @override
  bool get enabledByDefault => false;

  @override
  String get description =>
      'Sends JSON notifications to a configured webhook when a download completes or fails.';

  @override
  String get iconName => 'webhook';

  @override
  Future<PluginModificationResult?> onDownloadComplete(
    PluginDownloadEvent event,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_completeKey) ?? true)) {
      return null;
    }
    await _send('completed', event, prefs);
    return null;
  }

  @override
  Future<void> onDownloadFailed(PluginDownloadEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_failedKey) ?? true)) {
      return;
    }
    await _send('failed', event, prefs);
  }

  Future<void> _send(
    String status,
    PluginDownloadEvent event,
    SharedPreferences prefs,
  ) async {
    final url = prefs.getString(_urlKey)?.trim() ?? '';
    if (url.isEmpty) {
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'app': 'ModernDownloader',
              'status': status,
              'timestamp': DateTime.now().toIso8601String(),
              'downloadId': event.downloadId,
              'source': event.source,
              'title': event.title,
              'url': event.url,
              'filePath': event.filePath,
              'error': event.error,
              'metadata': event.sourceMetadata == null
                  ? null
                  : {
                      'id': event.sourceMetadata!['id'],
                      'extractor': event.sourceMetadata!['extractor'],
                      'thumbnail': event.sourceMetadata!['thumbnail'],
                    },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        LoggerService.w(
          '[WebhookNotifier] Webhook returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      LoggerService.w('[WebhookNotifier] Failed to send webhook: $e');
    }
  }
}
