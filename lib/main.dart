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
import 'package:modern_downloader/core/download/x_download_url.dart';
import 'package:modern_downloader/features/downloader/data/datasources/startup_cleanup_service.dart';
import 'dart:async';
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
  bool _postBootstrapStarted = false;
  ProviderSubscription<DependencyBootstrapState>? _bootstrapSub;
  bool _windowTickersEnabled = true;

  void _setWindowTickersEnabled(bool enabled) {
    if (!mounted || _windowTickersEnabled == enabled) return;
    setState(() => _windowTickersEnabled = enabled);
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapSub = ref.listenManual<DependencyBootstrapState>(
        dependencyBootstrapProvider,
        (previous, next) {
          if (!next.blocksUi) {
            _startPostBootstrapWork();
          }
        },
        fireImmediately: true,
      );
    });
  }

  void _startPostBootstrapWork() {
    if (_postBootstrapStarted || !mounted) return;
    _postBootstrapStarted = true;
    try {
      _initTray();
      ref.read(clipboardServiceProvider).startMonitoring();
      ref.read(localServerServiceProvider).start();
      ref.read(clipboardServiceProvider).clipboardStream.listen((url) {
        _handleClipboardUrl(url);
      });
      final settings = ref.read(settingsProvider);
      unawaited(StartupCleanupService.cleanup(settings.outputFolder));
    } catch (e) {
      debugPrint('Post-bootstrap startup failed: $e');
    }
  }

  AppLocalizations _l10nForLocale(String localeCode) {
    try {
      return lookupAppLocalizations(Locale(localeCode));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  Future<void> _initTray() async {
    try {
      final l10n = _l10nForLocale(ref.read(settingsProvider).locale);
      await trayManager.setIcon('assets/icons/tray.ico');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show_window', label: l10n.trayShow),
            MenuItem.separator(),
            MenuItem(key: 'exit_app', label: l10n.trayExit),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
  }

  void _handleClipboardUrl(String url) {
    final resolved = XDownloadUrl.resolveForDownload(url);
    if (resolved == null) {
      final l10n = _l10nForLocale(ref.read(settingsProvider).locale);
      NotificationService().showError(l10n.needTweetLink, l10n.xCdnUrlRejected);
      return;
    }
    NotificationService().showClipboardDetected(resolved);
    ref.read(launchDataProvider.notifier).state = LaunchData.fromUrl(resolved);
  }

  @override
  void dispose() {
    _bootstrapSub?.close();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    ref.read(clipboardServiceProvider).stopMonitoring();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    _setWindowTickersEnabled(true);
  }

  @override
  void onWindowBlur() {
    _setWindowTickersEnabled(false);
  }

  @override
  void onWindowRestore() {
    _setWindowTickersEnabled(true);
  }

  @override
  void onWindowMinimize() {
    _setWindowTickersEnabled(false);
    final minimizeToTray = ref.read(settingsProvider).minimizeToTray;
    if (minimizeToTray) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    _setWindowTickersEnabled(true);
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onWindowClose() async {
    final minimizeToTray = ref.read(settingsProvider).minimizeToTray;
    if (minimizeToTray) {
      _setWindowTickersEnabled(false);
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
      _setWindowTickersEnabled(true);
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(settingsProvider.select((s) => s.locale), (
      previous,
      next,
    ) {
      if (previous != next) {
        unawaited(_initTray());
      }
    });
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

    final bootstrap = ref.watch(dependencyBootstrapProvider);

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
            TickerMode(
              enabled: !bootstrap.blocksUi && _windowTickersEnabled,
              child: child ?? const SizedBox.shrink(),
            ),
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
