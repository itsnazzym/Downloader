import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import '../logger/logger_service.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _mobileNotifications =
      FlutterLocalNotificationsPlugin();

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
      if (Platform.isAndroid || Platform.isIOS) {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        const ios = DarwinInitializationSettings();
        await _mobileNotifications.initialize(
          const InitializationSettings(android: android, iOS: ios),
        );
        await _mobileNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'downloads',
                'Downloads',
                description: 'Download status notifications',
                importance: Importance.defaultImportance,
              ),
            );
      } else {
        await localNotifier.setup(
          appName: 'Modern Downloader',
          // The parameter shortcutPolicy argument is only available on Windows
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
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
      // Access prefs directly since NotificationService is a singleton
      try {
        final dnd = prefs.getBool('do_not_disturb') ?? false;
        if (dnd) {
          LoggerService.debug('DND active: suppressing notification: $title');
          return;
        }
      } catch (_) {}

      if (Platform.isAndroid || Platform.isIOS) {
        await _mobileNotifications.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'downloads',
              'Downloads',
              channelDescription: 'Download status notifications',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
        return;
      }

      final notification = LocalNotification(title: title, body: body);

      // We can add onClick listeners here if needed in the future

      await notification.show();
    } catch (e) {
      LoggerService.w('Failed to show notification: $e');
    }
  }
}
