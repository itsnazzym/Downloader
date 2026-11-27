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
import '../plugins/feature_activation.dart';
import '../providers/launch_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';

/// Centralized application bootstrap routines.
/// Handles desktop window initialization, protocol handlers, and post-frame background setups.
class AppBootstrap {
  AppBootstrap._();

  static Future<void>? _postFrameInitialization;

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
  static void handleLaunchArgs(List<String> args, ProviderContainer container) {
    if (args.isEmpty) return;
    final protocolArg = args.firstWhere(
      ProtocolUrlParser.isProtocolUrl,
      orElse: () => '',
    );
    if (protocolArg.isNotEmpty) {
      dispatchProtocolUrl(protocolArg, container);
    }
  }

  /// Dispatches one allowlisted app intent: a download URL or a catalog ID.
  static bool dispatchProtocolUrl(
    String protocolUrl,
    ProviderContainer container,
  ) {
    final pluginId = ProtocolUrlParser.extractPluginId(protocolUrl);
    final descriptor = pluginId == null
        ? null
        : container.read(featureCatalogProvider).byId[pluginId];
    if (descriptor != null &&
        descriptor.supportsPlatform(
          PlatformInfo.isAndroid ? 'android' : 'windows',
        )) {
      container.read(pluginInstallRequestProvider.notifier).state = pluginId;
      return true;
    }

    final mediaUrl = ProtocolUrlParser.extractMediaUrl(protocolUrl);
    if (mediaUrl == null) return false;
    container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
      mediaUrl,
      shouldAutoStart: PlatformInfo.isMobile,
    );
    return true;
  }

  /// Asynchronous background services initialized right after the first frame renders.
  static Future<void> initAfterFirstFrame(ProviderContainer container) {
    return _postFrameInitialization ??= _initAfterFirstFrame(container);
  }

  static Future<void> _initAfterFirstFrame(ProviderContainer container) async {
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
      for (final scheme in ProtocolUrlParser.schemes) {
        await protocolHandler.register(scheme);
      }
    } catch (e) {
      debugPrint('Protocol handler register skipped: $e');
    }

    try {
      final initialUrlStr = await protocolHandler.getInitialUrl();
      if (initialUrlStr != null) {
        if (container.read(pluginInstallRequestProvider) == null &&
            container.read(launchDataProvider) == null) {
          dispatchProtocolUrl(initialUrlStr, container);
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
    if (AppBootstrap.dispatchProtocolUrl(url, container)) {
      if (PlatformInfo.isDesktop) {
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
      }
    }
  }
}
