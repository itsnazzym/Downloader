import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:modern_downloader/core/launch/protocol_url_parser.dart';
import 'core/config/app_config.dart';
import 'core/platform/platform_info.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_resolver.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/ui/setup/dependency_setup_overlay.dart';

import 'package:modern_downloader/core/services/single_instance_service.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:modern_downloader/core/providers/launch_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:modern_downloader/core/services/notification_service.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/features/downloader/data/datasources/startup_cleanup_service.dart';
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
    container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
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

    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Listen for deep links
  protocolHandler.addListener(_ProtocolListener(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ModernDownloaderApp(),
    ),
  );
}

String? _extractUrlFromUri(String uriString) {
  return ProtocolUrlParser.extractMediaUrl(uriString);
}

class _ProtocolListener extends ProtocolListener {
  final ProviderContainer container;
  _ProtocolListener(this.container);

  @override
  void onProtocolUrlReceived(String url) {
    final extractedUrl = _extractUrlFromUri(url);
    if (extractedUrl != null) {
      container.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
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
    try {
      await trayManager.setIcon('assets/icons/tray.ico');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show_window', label: 'Show'),
            MenuItem.separator(),
            MenuItem(key: 'exit_app', label: 'Exit'),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
  }

  void _handleClipboardUrl(String url) {
    // Show Notification with action or just a toast
    NotificationService().showClipboardDetected(url);
    // Optionally we could show a dialog if the window is focused
    // But simply updating the variable or notifying is safer for now.

    // We can also auto-set the launchUrlProvider if we want the "Add Download" dialog
    // to pick it up immediately when the user clicks "+"
    ref.read(launchDataProvider.notifier).state = LaunchData.fromUrl(url);
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
  void onWindowClose() async {
    final minimizeToTray = ref.read(settingsProvider).minimizeToTray;
    if (minimizeToTray) {
      await windowManager.hide();
      return;
    }
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    ThemeMode themeMode;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    final resolved = ThemeResolver.resolve(
      presetId: settings.themePreset,
      customAccentArgb: settings.customAccentColor,
    );

    ref.watch(dependencyBootstrapProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.fromPalette(
        ThemeResolver.forBrightness(resolved, Brightness.light),
        Brightness.light,
      ),
      darkTheme: AppTheme.fromPalette(
        ThemeResolver.forBrightness(resolved, Brightness.dark),
        Brightness.dark,
      ),
      themeMode: themeMode,
      locale: Locale(settings.locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final content = Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const DependencySetupOverlay(),
          ],
        );
        // Native video textures inject AX nodes that Flutter's Windows
        // accessibility bridge cannot reconcile ("will not be in the tree").
        if (Platform.isWindows) {
          return ExcludeSemantics(child: content);
        }
        return content;
      },
    );
  }
}
