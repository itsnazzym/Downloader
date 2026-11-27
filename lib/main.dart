import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/android/android_share_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/logger/logger_service.dart';
import 'core/platform/platform_info.dart';
import 'core/plugins/feature_activation.dart';
import 'core/plugins/feature_catalog.dart';
import 'core/providers/launch_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/single_instance_service.dart';
import 'core/services/tor/tor_proxy_service.dart';
import 'showcase/showcase_app.dart';
import 'showcase/showcase_data.dart';
import 'features/designs/design_skins.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDesignSkins();
  // This path must stay before preferences, single-instance handling and services.
  if (Platform.isWindows && args.contains('--showcase')) {
    // The demo process gets its own volatile preferences instance. No call to
    // the platform preference store is made in this branch.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'pane_inspector_width': 400.0});
    initPrefs(await SharedPreferences.getInstance());
    HttpOverrides.global = _ShowcaseRestrictedNetwork();
    final catalog = FeatureCatalog.decode(
      await rootBundle.loadString('site/plugin-catalog.json'),
    );
    await AppBootstrap.initDesktopWindow();
    await windowManager.setSize(const Size(1440, 900));
    await windowManager.center();
    String flag(String name, String fallback) =>
        args
            .where((arg) => arg.startsWith('--$name='))
            .map((arg) => arg.substring(name.length + 3))
            .firstOrNull ??
        fallback;
    runApp(
      ShowcaseApp(
        catalog: catalog,
        initialScreen: flag('showcase-screen', 'library'),
        initialTheme: flag('showcase-theme', 'ios'),
      ),
    );
    return;
  }
  LoggerService.i(
    'Initializing TapLoad on ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
  );

  final prefsInstance = await SharedPreferences.getInstance();
  initPrefs(prefsInstance);

  final featureCatalog = FeatureCatalog.decode(
    await rootBundle.loadString('site/plugin-catalog.json'),
  );
  await migrateFeaturePluginPreferences(prefsInstance, featureCatalog);

  final container = ProviderContainer(
    overrides: [
      featureCatalogProvider.overrideWithValue(featureCatalog),
      featureActivationProvider.overrideWith(
        (ref) => FeatureActivationController(
          preferences: prefsInstance,
          catalog: featureCatalog,
        ),
      ),
    ],
  );
  final alreadyRunning = await SingleInstanceService.check(args, container);
  if (alreadyRunning) {
    debugPrint('App already running. Terminating this instance.');
    exit(0);
  }

  // Start Tor in the background when the saved preference is enabled.
  container.read(torProxyServiceProvider);

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
      child: const TapLoadApp(),
    ),
  );

  unawaited(AppBootstrap.initAfterFirstFrame(container));
}

class _ShowcaseRestrictedNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _ShowcaseThumbnailHttpClient(super.createHttpClient(context));
  }
}

/// Allows only fixed, read-only thumbnail requests from the showcase catalog.
/// All other HTTP operations remain unavailable in the isolated demo process.
class _ShowcaseThumbnailHttpClient implements HttpClient {
  _ShowcaseThumbnailHttpClient(this._inner);

  final HttpClient _inner;

  // Flutter's NetworkImage client sets this when its shared client is created.
  // Forward it so the image loader can initialize while request methods remain
  // restricted to the fixed thumbnail allow-list below.
  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  Future<HttpClientRequest> _getUrl(Uri uri) async {
    if (!isAllowedShowcaseThumbnailUrl(uri)) {
      throw HttpException('Request blocked in Windows showcase mode: $uri');
    }
    final request = await _inner.getUrl(uri);
    request.followRedirects = false;
    request.maxRedirects = 0;
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _getUrl(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    if (method.toUpperCase() != 'GET') {
      throw HttpException('Only thumbnail GET requests are allowed');
    }
    return _getUrl(url);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw HttpException('Network operation blocked in Windows showcase mode');
}
