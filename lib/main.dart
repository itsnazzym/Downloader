import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/android/android_share_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/logger/logger_service.dart';
import 'core/platform/platform_info.dart';
import 'core/providers/launch_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/single_instance_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerService.i(
    'Initializing Modern Downloader on ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
  );

  final prefsInstance = await SharedPreferences.getInstance();
  initPrefs(prefsInstance);

  final container = ProviderContainer();
  final alreadyRunning = await SingleInstanceService.check(args, container);
  if (alreadyRunning) {
    debugPrint('App already running. Terminating this instance.');
    exit(0);
  }

  AppBootstrap.handleLaunchArgs(args, container);

  if (PlatformInfo.isAndroid) {
    final shared = await AndroidShareService.instance.peekInitialUrl();
    if (shared != null) {
      container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
        shared,
        shouldAutoStart: true,
      );
    }
    await AppBootstrap.initAndroidStorage(container);
  }

  await AppBootstrap.initDesktopWindow();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ModernDownloaderApp(),
    ),
  );

  unawaited(AppBootstrap.initAfterFirstFrame(container));
}
