import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import '../logger/logger_service.dart';
import '../platform/platform_info.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _mobilePlugin =
      FlutterLocalNotificationsPlugin();
  bool _mobileReady = false;

  AppLocalizations _l10n() {
    try {
      final code = prefs.getString('locale') ?? 'en';
      return lookupAppLocalizations(Locale(code));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  Future<void> init() async {
    try {
      if (PlatformInfo.isDesktop) {
        await localNotifier.setup(
          appName: 'Modern Downloader',
          // The parameter shortcutPolicy argument is only available on Windows
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
      } else if (Platform.isAndroid) {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        await _mobilePlugin.initialize(
          const InitializationSettings(android: android),
        );
        _mobileReady = true;
      }
      LoggerService.i('NotificationService initialized');
    } catch (e) {
      LoggerService.e('Failed to initialize NotificationService', e);
    }
  }

  Future<void> showDownloadComplete(String title) async {
    await _show(title: _l10n().notificationDownloadCompleted, body: title);
  }

  Future<void> showDownloadFailed(String title, String error) async {
    await _show(
      title: _l10n().notificationDownloadFailed,
      body: '$title\n$error',
    );
  }

  Future<void> showClipboardDetected(String url) async {
    final l10n = _l10n();
    await _show(
      title: l10n.notificationLinkDetected,
      body: l10n.notificationLinkDetectedBody(url),
    );
  }

  Future<void> showLinksQueued(int count) async {
    if (count < 1) return;
    final l10n = _l10n();
    await _show(
      title: l10n.notificationLinksQueuedTitle,
      body: l10n.notificationLinksQueuedBody(count),
    );
  }

  Future<void> showExtensionConnected() async {
    final l10n = _l10n();
    await _show(
      title: l10n.notificationExtensionConnected,
      body: l10n.notificationExtensionConnectedBody,
    );
  }

  Future<void> showBatchComplete(int count, String totalSize) async {
    final l10n = _l10n();
    await _show(
      title: l10n.notificationBatchComplete,
      body: l10n.notificationBatchCompleteBody(count, totalSize),
    );
  }

  Future<void> showUpdateAvailable(String version) async {
    final l10n = _l10n();
    await _show(
      title: l10n.notificationYtDlpUpdated,
      body: l10n.notificationYtDlpUpdatedBody(version),
    );
  }

  Future<void> showError(String title, String details) async {
    await _show(title: title, body: details);
  }

  Future<void> _show({required String title, required String body}) async {
    try {
      try {
        final dnd = prefs.getBool('do_not_disturb') ?? false;
        if (dnd) {
          LoggerService.debug('DND active: suppressing notification: $title');
          return;
        }
      } catch (_) {}

      if (Platform.isAndroid && _mobileReady) {
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'downloads',
            'Downloads',
            channelDescription: 'Download progress and completion',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        );
        await _mobilePlugin.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title,
          body,
          details,
        );
        return;
      }

      final notification = LocalNotification(title: title, body: body);
      await notification.show();
    } catch (e) {
      LoggerService.w('Failed to show notification: $e');
    }
  }
}
