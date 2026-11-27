// The desktop design picker (Vitrine): choosing in the list only previews,
// « Utiliser » switches the design; mobile keeps the old preset grid.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/router/app_router.dart';
import 'package:modern_downloader/core/services/download_stats_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/appearance_settings_view.dart';
import 'package:modern_downloader/core/ui/settings/widgets/design_miniature.dart';
import 'package:modern_downloader/core/ui/settings/widgets/design_vitrine.dart';
import 'package:modern_downloader/features/designs/signal/signal_home.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

import '../../../visual/visual_fakes.dart';
import '../../../visual/visual_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    await prefs.setBool(OnboardingStore.prefsKey, true);
  });
  tearDown(() => PlatformInfo.debugForceMobile = null);

  Future<ProviderContainer> pump(WidgetTester tester, Widget? home) async {
    tester.view.physicalSize = const Size(1280, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = sampleDownloads();
    final container = ProviderContainer(
      overrides: [
        ...baseOverrides(),
        dependencyBootstrapProvider.overrideWith(
          (ref) => DependencyBootstrapNotifier.ready(),
        ),
        downloaderRepositoryProvider.overrideWith(
          (ref) => FakeDownloaderRepository(items),
        ),
        persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
        downloadListProvider.overrideWith(
          (ref) => PinnedDownloadList(
            ref.read(downloaderRepositoryProvider),
            ref,
            items,
          ),
        ),
        downloadStatsProvider.overrideWith((ref) => FakeStatsNotifier()),
        designFreeSpaceProvider.overrideWith((ref) async => 1 << 40),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setThemePreset('signal');
    const delegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    final theme = AppTheme.fromPalette(ThemePresets.signal, Brightness.dark);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: home != null
            ? MaterialApp(
                locale: const Locale('fr'),
                theme: theme,
                localizationsDelegates: delegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: home,
              )
            : MaterialApp.router(
                locale: const Locale('fr'),
                theme: theme,
                localizationsDelegates: delegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: container.read(routerProvider),
              ),
      ),
    );
    if (home == null) container.read(routerProvider).go('/settings/appearance');
    await settle(tester);
    return container;
  }

  String previewed(WidgetTester tester) =>
      tester.widget<DesignMiniature>(find.byType(DesignMiniature)).id;

  FilledButton apply(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(
      of: find.byType(DesignVitrine),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('selecting previews, applying switches the design', (
    tester,
  ) async {
    PlatformInfo.debugForceMobile = false;
    final container = await pump(tester, null);
    expect(find.byType(DesignVitrine), findsOneWidget);
    expect(previewed(tester), 'signal');
    // Nothing to apply on the current design.
    expect(apply(tester).onPressed, isNull);
    expect(find.text('Design actuel'), findsOneWidget);

    final nocturne = find.descendant(
      of: find.byType(DesignVitrine),
      matching: find.text('Nocturne'),
    );
    await tester.tap(nocturne.first);
    // The design pages animate forever: pump past the 220 ms fade instead.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(previewed(tester), 'nocturne');
    expect(container.read(settingsProvider).themePreset, 'signal');
    expect(
      tester.getSemantics(nocturne.first),
      containsSemantics(isSelected: true, isButton: true),
    );
    expect(find.text('Utiliser Nocturne'), findsOneWidget);
    expect(apply(tester).onPressed, isNotNull);

    await tester.tap(find.text('Utiliser Nocturne'));
    // The design pages animate forever: pump past the 220 ms fade instead.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(settingsProvider).themePreset, 'nocturne');
    expect(apply(tester).onPressed, isNull);
  });

  testWidgets('mobile keeps the preset grid', (tester) async {
    PlatformInfo.debugForceMobile = true;
    await pump(tester, const AppearanceSettingsView());
    expect(find.byType(DesignVitrine), findsNothing);
    expect(find.text('Nocturne'), findsOneWidget);
  });
}
