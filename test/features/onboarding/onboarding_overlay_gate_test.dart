import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/ui/window_chrome.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_service.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_overlay.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_tooltip.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:modern_downloader/core/providers/settings_provider.dart'
    as settings_util;

DependencyBootstrapNotifier _blockingBootstrap() {
  return DependencyBootstrapNotifier(
    DependencyBootstrapService(),
    autoStart: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings_util.initPrefs(await SharedPreferences.getInstance());
  });

  testWidgets('overlay is absent while bootstrap blocks UI', (tester) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependencyBootstrapProvider.overrideWith(
            (ref) => _blockingBootstrap(),
          ),
          onboardingStoreProvider.overrideWithValue(store),
          onboardingControllerProvider.overrideWith(
            (ref) => OnboardingController(store: store, isDesktop: true),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Stack(children: [OnboardingOverlay()])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OnboardingTooltipCard), findsNothing);
  });

  testWidgets('overlay is absent when the tour is already completed', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(completed: true);
    final bootstrap = DependencyBootstrapNotifier.ready();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependencyBootstrapProvider.overrideWith((ref) => bootstrap),
          onboardingStoreProvider.overrideWithValue(store),
          onboardingControllerProvider.overrideWith(
            (ref) => OnboardingController(store: store, isDesktop: true),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Stack(children: [OnboardingOverlay()])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OnboardingTooltipCard), findsNothing);
  });

  testWidgets('active tour sits below the title bar', (tester) async {
    final store = MemoryOnboardingStore();
    final bootstrap = DependencyBootstrapNotifier.ready();
    final controller = OnboardingController(store: store, isDesktop: true);
    controller.tryStart();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependencyBootstrapProvider.overrideWith((ref) => bootstrap),
          onboardingStoreProvider.overrideWithValue(store),
          onboardingControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Stack(children: [OnboardingOverlay()])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OnboardingTooltipCard), findsOneWidget);
    final shells = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .where(
          (positioned) =>
              positioned.top == WindowChrome.titleBarHeight &&
              positioned.left == 0 &&
              positioned.right == 0 &&
              positioned.bottom == 0,
        );
    expect(shells, isNotEmpty);
  });
}
