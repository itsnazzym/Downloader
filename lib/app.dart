import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'core/android/android_share_service.dart';
import 'core/config/app_config.dart';
import 'core/bootstrap/app_warmup_models.dart';
import 'core/bootstrap/app_warmup_provider.dart';
import 'core/download/x_download_url.dart';
import 'core/logger/logger_service.dart';
import 'core/platform/platform_info.dart';
import 'core/providers/launch_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/clipboard_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/tor/tor_proxy_service.dart';
import 'core/setup/dependency_bootstrap_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_spec.dart';
import 'core/theme/theme_presets.dart';
import 'core/theme/theme_resolver.dart';
import 'core/ui/setup/app_launch_overlay.dart';
import 'features/downloader/data/repositories/downloader_repository_impl.dart';
import 'features/downloader/presentation/providers/downloader_provider.dart';
import 'features/onboarding/presentation/mobile/mobile_onboarding.dart';
import 'l10n/app_localizations.dart';

/// Root application widget configuring routing, themes, locales, window lifecycle, and post-bootstrap services.
class TapLoadApp extends ConsumerStatefulWidget {
  const TapLoadApp({super.key});

  @override
  ConsumerState<TapLoadApp> createState() =>
      _TapLoadAppState();
}

class _TapLoadAppState extends ConsumerState<TapLoadApp>
    with WindowListener, TrayListener {
  bool _postBootstrapStarted = false;
  ProviderSubscription<AppWarmupState>? _warmupSub;
  StreamSubscription<String>? _clipboardSub;
  StreamSubscription<String>? _shareSub;
  bool _windowTickersEnabled = true;
  Object? _themeKey;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  void _setWindowTickersEnabled(bool enabled) {
    if (!mounted || _windowTickersEnabled == enabled) return;
    setState(() => _windowTickersEnabled = enabled);
  }

  @override
  void initState() {
    super.initState();
    if (PlatformInfo.isDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmupSub = ref.listenManual<AppWarmupState>(appWarmupProvider, (
        previous,
        next,
      ) {
        if (next.isCompleted) {
          _startPostBootstrapWork();
        }
      }, fireImmediately: true);
    });
  }

  void _startPostBootstrapWork() {
    if (_postBootstrapStarted || !mounted) return;
    _postBootstrapStarted = true;
    try {
      if (PlatformInfo.isDesktop) {
        unawaited(_initTray());
        _clipboardSub = ref
            .read(clipboardServiceProvider)
            .clipboardStream
            .listen((url) {
              _handleClipboardUrl(url);
            });
      } else {
        AndroidShareService.instance.start();
        _shareSub = AndroidShareService.instance.urlStream.listen((url) {
          ref.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
            url,
            shouldAutoStart: true,
          );
          unawaited(NotificationService().showLinksQueued(1));
        });
      }
      LoggerService.i('Post-bootstrap listeners initialized');
    } catch (e) {
      LoggerService.e('Post-bootstrap startup failed', e);
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
    final effectiveUrl = url.trim();
    if (effectiveUrl.isEmpty) return;

    if (XDownloadUrl.isCdnUrl(effectiveUrl)) {
      final resolved = XDownloadUrl.resolveForDownload(effectiveUrl);
      if (resolved == null) {
        final l10n = _l10nForLocale(ref.read(settingsProvider).locale);
        NotificationService().showError(
          l10n.needTweetLink,
          l10n.xCdnUrlRejected,
        );
        return;
      }
      NotificationService().showClipboardDetected(resolved);
      ref.read(launchDataProvider.notifier).state = LaunchData.fromUrl(
        resolved,
      );
      return;
    }

    final resolved =
        XDownloadUrl.resolveForDownload(effectiveUrl) ?? effectiveUrl;
    NotificationService().showClipboardDetected(resolved);
    ref.read(launchDataProvider.notifier).state = LaunchData.fromUrl(resolved);
  }

  @override
  void dispose() {
    _clipboardSub?.cancel();
    _shareSub?.cancel();
    if (PlatformInfo.isDesktop) {
      _warmupSub?.close();
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      ref.read(clipboardServiceProvider).stopMonitoring();
    } else {
      _warmupSub?.close();
    }
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
    await _exitApplication();
  }

  Future<void> _exitApplication() async {
    try {
      final repository = ref.read(downloaderRepositoryProvider);
      await Future.wait([
        ref.read(torProxyServiceProvider.notifier).shutdown(),
        // Otherwise yt-dlp/ffmpeg/aria2c keep running after the window closes.
        if (repository is DownloaderRepositoryImpl)
          repository.shutdown().timeout(
            const Duration(seconds: 5),
            onTimeout: () {},
          ),
      ]);
    } catch (e) {
      LoggerService.e('Shutdown cleanup failed', e);
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
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
      await _exitApplication();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(settingsProvider.select((s) => s.locale), (
      previous,
      next,
    ) {
      if (previous != next && PlatformInfo.isDesktop) {
        unawaited(_initTray());
      }
    });
    final router = ref.watch(routerProvider);
    // Only the fields the root reads: any other settings change must not
    // rebuild MaterialApp (and restart its theme animation).
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          themeMode: s.themeMode,
          themePreset: s.themePreset,
          customAccentColor: s.customAccentColor,
          locale: s.locale,
          reduceEffects: s.reduceEffects,
        ),
      ),
    );
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

    // The OLED preset is dark-only. New Android installs start on it (see the
    // settings default); any preset the user picked, Midnight included, stays.
    final useOled = settings.themePreset == 'oled';
    if (useOled) {
      themeMode = ThemeMode.dark;
    }
    final resolved = useOled
        ? ThemePresets.oled
        : ThemeResolver.resolve(
            presetId: settings.themePreset,
            customAccentArgb: settings.customAccentColor,
          );
    // Each desktop design has its own brightness (Porcelaine and Studio are
    // light, the others dark); only iOS follows the light/dark setting.
    final designBrightness = DesignSpec.forId(resolved.id).brightness;
    if (designBrightness != null) {
      themeMode = designBrightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark;
    }

    final bootstrap = ref.watch(dependencyBootstrapProvider);
    final warmup = ref.watch(appWarmupProvider);
    final libraryReady = ref.watch(
      downloadListProvider.select((s) => s.hasValue || s.hasError),
    );

    // ThemeData has no value equality here (AppPalette), so a fresh instance
    // would animate the whole tree; rebuild it only when the palette changes.
    final themeKey = (settings.themePreset, settings.customAccentColor);
    if (themeKey != _themeKey) {
      _themeKey = themeKey;
      _lightTheme = AppTheme.fromPalette(
        ThemeResolver.forBrightness(resolved, Brightness.light),
        designBrightness ?? Brightness.light,
      );
      _darkTheme = AppTheme.fromPalette(
        ThemeResolver.forBrightness(resolved, Brightness.dark),
        designBrightness ?? Brightness.dark,
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: _lightTheme,
      darkTheme: _darkTheme,
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
        Widget content = Stack(
          fit: StackFit.expand,
          children: [
            TickerMode(
              enabled:
                  warmup.isCompleted &&
                  libraryReady &&
                  !bootstrap.blocksUi &&
                  _windowTickersEnabled,
              child: child ?? const SizedBox.shrink(),
            ),
            if (PlatformInfo.isMobile)
              MobileOnboardingGate(
                ready:
                    warmup.isCompleted && libraryReady && !bootstrap.blocksUi,
              ),
            AppLaunchOverlay(libraryReady: libraryReady),
          ],
        );
        // Blur / ambient-motion guards read disableAnimations; the setting
        // turns them off at once on modest PCs. Scope: blur and continuous
        // background motion only; one-shot flutter_animate entrance effects
        // (settings lists, stats cards, empty states) still play. Always
        // present so toggling it does not remount the router below.
        final mediaQuery = MediaQuery.of(context);
        content = MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations:
                settings.reduceEffects || mediaQuery.disableAnimations,
          ),
          child: content,
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
