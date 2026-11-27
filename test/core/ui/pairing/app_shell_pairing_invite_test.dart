import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/plugins/feature_activation.dart';
import 'package:tapload/core/plugins/feature_catalog.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/ui/app_shell.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/onboarding/data/onboarding_store.dart';
import 'package:tapload/l10n/app_localizations.dart';

import '../../../visual/visual_fakes.dart';

/// [pair] waits for [gate]: the user's approval stays in flight.
class _GatedStore extends PairedBrowsersStore {
  _GatedStore(super.prefs) : super(random: Random(7));

  Completer<void>? gate;

  @override
  Future<(PairedBrowser, String)> pair({
    required String origin,
    required String label,
  }) async {
    await gate?.future;
    return super.pair(origin: origin, label: label);
  }
}

class _NoopTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'window_manager',
      'tray_manager',
      'protocol_handler',
      'desktop_drop',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => true,
      );
    }
  });

  testWidgets('after Autoriser the invite does not reopen while the approval '
      'is stored, and Toujours refuser is never offered for it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({OnboardingStore.prefsKey: true});
    final prefs = await SharedPreferences.getInstance();
    initPrefs(prefs);
    final store = _GatedStore(prefs);
    final coordinator = PairingCoordinator(
      store,
      random: Random(3),
      schedule: (_, _) => _NoopTimer(),
    );
    final catalog = FeatureCatalog.decode(
      File('site/plugin-catalog.json').readAsStringSync(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureCatalogProvider.overrideWithValue(catalog),
          featureActivationProvider.overrideWith(
            (ref) => FeatureActivationController(
              preferences: prefs,
              catalog: catalog,
            ),
          ),
          downloaderRepositoryProvider.overrideWithValue(
            FakeDownloaderRepository([]),
          ),
          mediaPlayerProvider.overrideWith(
            (ref) => MediaPlayerNotifier(testMode: true),
          ),
          dependencyBootstrapProvider.overrideWith(
            (ref) => DependencyBootstrapNotifier.ready(),
          ),
          pairingCoordinatorProvider.overrideWith((ref) => coordinator),
        ],
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              ShellRoute(
                builder: (context, state, child) => AppShell(child: child),
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => const Text('Content'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final s = coordinator.submit(
      origin: 'chrome-extension://abcdefghijklmnopabcdefghijklmnop',
      label: 'Chrome',
    );
    await tester.pumpAndSettle();
    expect(find.text('Toujours refuser'), findsOneWidget);

    store.gate = Completer<void>();
    await tester.tap(find.text('Autoriser'));
    await tester.pumpAndSettle();
    expect(coordinator.state, s.request, reason: 'still being stored');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Toujours refuser'), findsNothing);

    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(await s.outcome, isA<PairingApproved>());
    expect(coordinator.state, isNull);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
