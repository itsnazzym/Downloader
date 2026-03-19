import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/app_config.dart';
import 'core/platform/platform_info.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/runtime_palette.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

import 'package:modern_downloader/core/services/single_instance_service.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:modern_downloader/core/providers/launch_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:modern_downloader/core/services/notification_service.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/startup_cleanup_service.dart';
import 'package:modern_downloader/core/services/ytdlp_updater_service.dart';
import 'package:modern_downloader/services/binary_locator.dart';
import 'dart:io';
import 'package:media_kit/media_kit.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Initialize SharedPreferences BEFORE anything else
  final prefsInstance = await SharedPreferences.getInstance();
  initPrefs(prefsInstance); // Initialize global prefs holder

  // Init Notifications
  await NotificationService().init();

  // Protocol Handler Setup
  await protocolHandler.register('moderndownloader');

  // Single Instance Check
  final container = ProviderContainer();
  final alreadyRunning = await SingleInstanceService.check(args, container);
  if (alreadyRunning) {
    debugPrint('App already running. Terminating this instance.');
    exit(0);
  }

  String? initialUrl;
  final initialUrlStr = await protocolHandler.getInitialUrl();
  if (initialUrlStr != null) initialUrl = _extractUrlFromUri(initialUrlStr);

  if (initialUrl == null && args.isNotEmpty) {
    final protocolArg = args.firstWhere(
      (arg) => arg.contains('moderndownloader://'),
      orElse: () => '',
    );
    if (protocolArg.isNotEmpty) initialUrl = _extractUrlFromUri(protocolArg);
  }

  if (initialUrl != null) {
    container.read(launchDataProvider.notifier).state = LaunchData.dialog(
      initialUrl,
    );
  }

  if (PlatformInfo.isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(AppConfig.initialWindowWidth, AppConfig.initialWindowHeight),
      minimumSize: Size(AppConfig.minWindowWidth, AppConfig.minWindowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Listen for deep links
  protocolHandler.addListener(_ProtocolListener(container));

  // Auto-update yt-dlp (non-blocking, fire-and-forget)
  final autoUpdate = prefsInstance.getBool('auto_update_ytdlp') ?? true;
  if (autoUpdate) {
    YtDlpUpdaterService(BinaryLocator()).checkForUpdate();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ModernDownloaderApp(),
    ),
  );
}

// ... _extractUrlFromUri and _ProtocolListener remain the same ...
String? _extractUrlFromUri(String uriString) {
  try {
    final uri = Uri.parse(uriString);
    if (uri.queryParameters.containsKey('url')) {
      return uri.queryParameters['url'];
    }
    if (uri.host == 'open' && uri.queryParameters.containsKey('url')) {
      return uri.queryParameters['url'];
    }
  } catch (e) {
    debugPrint('Error parsing URI: $e');
  }
  return null;
}

class _ProtocolListener extends ProtocolListener {
  final ProviderContainer container;
  _ProtocolListener(this.container);

  @override
  void onProtocolUrlReceived(String url) {
    final extractedUrl = _extractUrlFromUri(url);
    if (extractedUrl != null) {
      container.read(launchDataProvider.notifier).state = LaunchData.dialog(
        extractedUrl,
      );
      windowManager.show();
      windowManager.focus();
    }
  }
}

class ModernDownloaderApp extends ConsumerStatefulWidget {
  const ModernDownloaderApp({super.key});

  @override
  ConsumerState<ModernDownloaderApp> createState() =>
      _ModernDownloaderAppState();
}

class _ModernDownloaderAppState extends ConsumerState<ModernDownloaderApp>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();

    // Start Clipboard Monitor
    ref.read(clipboardServiceProvider).startMonitoring();

    // Start Local Server for Extension
    ref.read(localServerServiceProvider).start();

    // Listen to clipboard stream
    ref.read(clipboardServiceProvider).clipboardStream.listen((url) {
      _handleClipboardUrl(url);
    });

    // Cleanup Loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      StartupCleanupService.cleanup(settings.outputFolder);
    });
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    // If specific icon is needed, we would need to add it to pubspec assets and use a helper
    // For now assuming standard windows path or fallback.
    // If this fails, tray just won't show icon but won't crash app (hopefully).
  }

  void _handleClipboardUrl(String url) {
    // Show Notification with action or just a toast
    NotificationService().showClipboardDetected(url);
    ref.read(launchDataProvider.notifier).state = LaunchData.dialog(url);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    ref.read(clipboardServiceProvider).stopMonitoring();
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    final minimizeToTray = ref.read(settingsProvider).minimizeToTray;
    if (minimizeToTray) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    ThemeMode themeMode;
    Brightness effectiveBrightness;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        effectiveBrightness = Brightness.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        effectiveBrightness = Brightness.dark;
        break;
      default:
        themeMode = ThemeMode.system;
        effectiveBrightness = systemBrightness;
    }

    AppThemeRuntime.setActivePalette(
      themePreset: settings.themePreset,
      accentValue: settings.customAccentColor,
      brightness: effectiveBrightness,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.buildTheme(
        themePreset: settings.themePreset,
        accentColor: settings.customAccentColor,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.buildTheme(
        themePreset: settings.themePreset,
        accentColor: settings.customAccentColor,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      locale: Locale(settings.locale),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
