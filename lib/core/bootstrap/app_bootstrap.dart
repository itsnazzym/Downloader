import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:window_manager/window_manager.dart';
import '../config/app_config.dart';
import '../launch/protocol_url_parser.dart';
import '../logger/logger_service.dart';
import '../platform/default_library_path_resolver.dart';
import '../platform/platform_info.dart';
import '../providers/launch_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';

/// Centralized application bootstrap routines.
/// Handles desktop window initialization, protocol handlers, and post-frame background setups.
class AppBootstrap {
  AppBootstrap._();

  /// Configures window manager options and displays the desktop window.
  static Future<void> initDesktopWindow() async {
    if (!PlatformInfo.isDesktop) return;

    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(AppConfig.initialWindowWidth, AppConfig.initialWindowHeight),
      minimumSize: Size(AppConfig.minWindowWidth, AppConfig.minWindowHeight),
      center: true,
      backgroundColor: Color(0xFF18181C),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      LoggerService.i(
        'Desktop window ready and shown (${AppConfig.initialWindowWidth}x${AppConfig.initialWindowHeight})',
      );
    });
  }

  /// Resolves and ensures default output storage path on Android.
  static Future<void> initAndroidStorage(ProviderContainer container) async {
    if (!PlatformInfo.isAndroid) return;
    try {
      final output =
          await DefaultLibraryPathResolver.resolveDefaultOutputFolder();
      final currentSetting = container.read(settingsProvider).outputFolder;
      if (currentSetting.isEmpty ||
          (prefs.getString('output_folder') ?? '').isEmpty) {
        await prefs.setString('output_folder', output);
        container.read(settingsProvider.notifier).setOutputFolder(output);
      }
    } catch (e) {
      debugPrint('Android default output folder skipped: $e');
    }
  }

  /// Parses deep link / protocol launch arguments into the launch provider.
  static void handleLaunchArgs(
    List<String> args,
    ProviderContainer container,
  ) {
    if (args.isEmpty) return;
    final protocolArg = args.firstWhere(
      (arg) => arg.contains('moderndownloader://'),
      orElse: () => '',
    );
    if (protocolArg.isNotEmpty) {
      final initialUrl = ProtocolUrlParser.extractMediaUrl(protocolArg);
      if (initialUrl != null) {
        container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
          initialUrl,
          shouldAutoStart: PlatformInfo.isMobile,
        );
      }
    }
  }

  /// Asynchronous background services initialized right after the first frame renders.
  static Future<void> initAfterFirstFrame(ProviderContainer container) async {
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      LoggerService.e('MediaKit init skipped', e);
    }

    try {
      await NotificationService().init();
    } catch (e) {
      LoggerService.e('NotificationService init skipped', e);
    }

    try {
      await protocolHandler.register('moderndownloader');
    } catch (e) {
      debugPrint('Protocol handler register skipped: $e');
    }

    try {
      final initialUrlStr = await protocolHandler.getInitialUrl();
      if (initialUrlStr != null) {
        final extracted = ProtocolUrlParser.extractMediaUrl(initialUrlStr);
        if (extracted != null &&
            container.read(launchDataProvider) == null) {
          container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
            extracted,
            shouldAutoStart: PlatformInfo.isMobile,
          );
        }
      }
    } catch (e) {
      debugPrint('Protocol initial URL skipped: $e');
    }

    try {
      protocolHandler.addListener(_ProtocolListener(container));
    } catch (e) {
      debugPrint('Protocol listener skipped: $e');
    }
  }
}

class _ProtocolListener extends ProtocolListener {
  final ProviderContainer container;
  _ProtocolListener(this.container);

  @override
  void onProtocolUrlReceived(String url) {
    final extractedUrl = ProtocolUrlParser.extractMediaUrl(url);
    if (extractedUrl != null) {
      container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
        extractedUrl,
        shouldAutoStart: PlatformInfo.isMobile,
      );
      if (PlatformInfo.isDesktop) {
        windowManager.show();
        windowManager.focus();
      }
    }
  }
}
