import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/plugins/feature_catalog.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/mobile/mobile_app_shell.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_downloader/features/designs/design_skins.dart';

/// Where the PNGs and the report land.
const String kVisualOutDir =
    'C:/Users/entre/Documents/Dev/Downloader-main/build/visual';

const Size kPhoneSize = Size(390, 844);
const double kPhoneDpr = 2.0;

/// Which fonts were really available to the renderer (filled by
/// [setUpVisualEnvironment], printed in the final report).
final List<String> fontReport = <String>[];

late FeatureCatalog visualCatalog;

/// One-time environment: real HTTP for google_fonts, a writable path_provider,
/// SharedPreferences, the plugin catalog, and a legible fallback for the
/// default (Roboto) family, which `flutter test` otherwise renders as boxes.
Future<void> setUpVisualEnvironment() async {
  HttpOverrides.global = null;
  registerDesignSkins();
  Directory(kVisualOutDir).createSync(recursive: true);

  final cacheDir = Directory('$kVisualOutDir/.font_cache')
    ..createSync(recursive: true);
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathChannel, (call) async => cacheDir.path);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  initPrefs(preferences);

  visualCatalog = FeatureCatalog.decode(
    File('site/plugin-catalog.json').readAsStringSync(),
  );

  await _loadFallbackFont();
  await _loadIconFonts();
  await _preloadGoogleFonts();
}

/// google_fonts downloads from fonts.gstatic.com (same as the app at runtime).
/// The requests must start outside the fake-async zone of `testWidgets`, or
/// the TLS handshake never completes. So request every face up front here.
Future<void> _preloadGoogleFonts() async {
  final families = <String, List<FontWeight>>{
    'Instrument Sans': const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ],
    'Doto': const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ],
    'Inter': const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ],
    'JetBrains Mono': const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ],
    'Outfit': const [FontWeight.w400, FontWeight.w500, FontWeight.w600],
    // The desktop designs (DesignSpec): display, UI and mono faces.
    for (final family in const [
      'Geist',
      'Geist Mono',
      'Bricolage Grotesque',
      'Plus Jakarta Sans',
      'Sora',
      'DM Sans',
      'DM Mono',
      'Manrope',
      'Inter Tight',
      'IBM Plex Mono',
    ])
      family: const [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ],
  };
  for (final entry in families.entries) {
    for (final weight in entry.value) {
      try {
        GoogleFonts.getFont(entry.key, fontWeight: weight);
      } catch (e) {
        fontReport.add('google_fonts cannot resolve ${entry.key} $weight: $e');
      }
    }
  }
  try {
    await GoogleFonts.pendingFonts();
    fontReport.add(
      'google_fonts requested (cache $kVisualOutDir/.font_cache): '
      '${families.keys.join(', ')}',
    );
  } catch (e) {
    fontReport.add('google_fonts preload FAILED: $e');
  }
}

/// `flutter test` leaves the icon fonts unregistered (icons render as boxes).
Future<void> _loadIconFonts() async {
  const fonts = <String, String>{
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    'packages/cupertino_icons/CupertinoIcons':
        'packages/cupertino_icons/assets/CupertinoIcons.ttf',
  };
  for (final entry in fonts.entries) {
    try {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
      fontReport.add('icon font loaded: ${entry.key}');
    } catch (e) {
      fontReport.add('icon font NOT loaded (${entry.key}): $e');
    }
  }
}

Future<void> _loadFallbackFont() async {
  const candidates = <String>[
    'C:/Windows/Fonts/segoeui.ttf',
    'C:/Windows/Fonts/arial.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    // Roboto is the framework default: map it (and a generic fallback) to a
    // real face so un-styled text and missing glyphs are legible.
    for (final family in const ['Roboto', 'VisualFallback']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    fontReport.add('fallback for default family (Roboto): $path');
    return;
  }
  fontReport.add('NO system fallback font found: default text is boxes');
}

/// Result of one screen: PNG path (or null) and every captured Flutter error.
class ScreenResult {
  ScreenResult(this.name);
  final String name;
  String? png;
  final List<String> errors = <String>[];
  String? fatal;

  bool get hasOverflow => errors.any((e) => e.contains('overflowed'));
}

/// Wraps the router in a [RepaintBoundary] so [capture] can snapshot it.
class VisualApp extends StatelessWidget {
  const VisualApp({
    super.key,
    required this.boundaryKey,
    required this.router,
    required this.overrides,
  });

  final GlobalKey boundaryKey;
  final GoRouter router;
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          theme: AppTheme.fromPalette(ThemePresets.oled, Brightness.dark),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }
}

/// A router whose only shell is the real [MobileAppShell].
GoRouter buildRouter({
  required String initialLocation,
  required Map<String, Widget Function()> pages,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MobileAppShell(child: child),
        routes: [
          for (final entry in pages.entries)
            GoRoute(
              path: entry.key,
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: entry.value()),
            ),
        ],
      ),
    ],
  );
}

FeatureActivationController buildFeatureActivation() {
  final controller = FeatureActivationController(
    preferences: prefs,
    catalog: visualCatalog,
  );
  for (final id in const [
    'x_browser',
    'statistics',
    'device_transfer',
    'tiktok_archives',
  ]) {
    controller.setEnabled(id, true);
  }
  return controller;
}

List<Override> baseOverrides() => [
  featureCatalogProvider.overrideWithValue(visualCatalog),
  featureActivationProvider.overrideWith((ref) => buildFeatureActivation()),
];

/// Pumps frames, then lets google_fonts finish its real network/cache loads.
/// Progress trace, only with VISUAL_DEBUG=1 in the environment.
void step(String s) {
  if (Platform.environment['VISUAL_DEBUG'] == null) return;
  // ignore: avoid_print
  print('[visual-step] $s');
}

Future<void> settle(WidgetTester tester) async {
  step('settle: first pumps');
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  step('settle: pendingFonts #1');
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts().timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        step('pendingFonts #1 TIMEOUT');
        return <void>[];
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  step('settle: pumps 2');
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  // A second pass: fonts requested by widgets that only built after the first.
  step('settle: pendingFonts #2');
  await tester.runAsync(
    () => GoogleFonts.pendingFonts().timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        step('pendingFonts #2 TIMEOUT');
        return <void>[];
      },
    ),
  );
  step('settle: last pumps');
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<String> capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  final path = '$kVisualOutDir/$name.png';
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: kPhoneDpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  return path;
}

/// Runs one screen fail-soft and records every Flutter error it raises.
void screenTest(
  String name,
  Map<String, ScreenResult> results,
  Future<void> Function(WidgetTester tester, ScreenResult result) body,
) {
  testWidgets('visual $name', (tester) async {
    HttpOverrides.global = null;
    final result = ScreenResult(name);
    results[name] = result;

    tester.view.physicalSize = Size(
      kPhoneSize.width * kPhoneDpr,
      kPhoneSize.height * kPhoneDpr,
    );
    tester.view.devicePixelRatio = kPhoneDpr;
    PlatformInfo.debugForceMobile = true;

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      final stack = details.stack?.toString().split('\n') ?? const [];
      final here = stack
          .where((l) => l.contains('package:modern_downloader/'))
          .take(3)
          .join(' | ');
      result.errors.add('$text${here.isEmpty ? '' : '  @ $here'}');
      // Overflow reports name the creating widget as file:///...dart:line:col.
      final location = RegExp(
        r'(file:///\S+?\.dart:\d+(?::\d+)?)',
      ).firstMatch(details.toDiagnosticsNode().toStringDeep());
      if (location != null) {
        result.errors.add('   widget at ${location.group(1)}');
      }
    };

    try {
      await body(tester, result);
    } catch (e, st) {
      result.fatal = '$e\n${st.toString().split('\n').take(6).join('\n')}';
    } finally {
      FlutterError.onError = originalOnError;
      PlatformInfo.debugForceMobile = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    final status = result.fatal != null
        ? 'FAIL'
        : result.errors.isNotEmpty
        ? 'RENDERED+${result.errors.length}ERR'
        : 'OK';
    // ignore: avoid_print
    print('[visual] $name: $status ${result.png ?? ''}');
    for (final e in result.errors) {
      // ignore: avoid_print
      print('[visual]   error: ${e.split('\n').first}');
    }
    if (result.fatal != null) {
      // ignore: avoid_print
      print('[visual]   fatal: ${result.fatal!.split('\n').first}');
    }
  });
}

/// Drops the widget tree so timers and listeners die before the next screen.
Future<void> teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}

/// Writes build/visual/report.txt from all results.
void writeReport(Map<String, ScreenResult> results) {
  final b = StringBuffer()..writeln('Fonts:');
  for (final f in fontReport) {
    b.writeln('  $f');
  }
  for (final r in results.values) {
    b.writeln('\n${r.name}: ${r.png ?? 'NO PNG'}');
    if (r.fatal != null) b.writeln('  FATAL: ${r.fatal}');
    for (final e in r.errors) {
      b.writeln('  ERR: $e');
    }
  }
  File('$kVisualOutDir/report.txt').writeAsStringSync(b.toString());
}
