// Every Espace widget at every size in every library situation must lay out
// without an exception. With PORCELAINE_SHOTS=1 it also writes
// build/visual/pextra_*.png to look at.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/router/app_router.dart';
import 'package:tapload/core/services/download_stats_service.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/porcelaine/porcelaine_workspace_model.dart';
import 'package:tapload/features/designs/signal/signal_home.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/onboarding/data/onboarding_store.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/showcase/showcase_mode.dart';

import '../../visual/visual_fakes.dart';
import '../../visual/visual_harness.dart';

final _shots = Platform.environment['PORCELAINE_SHOTS'] == '1';

class _List extends DownloadListNotifier {
  _List(super.repository, super.ref, this.mode, this.items) {
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      state = switch (mode) {
        'loading' => const AsyncValue.loading(),
        'error' => AsyncValue.error('boom', StackTrace.empty),
        _ => AsyncValue.data(items),
      };
    });
  }

  final String mode;
  final List<DownloadItem> items;

  void set(List<DownloadItem> next) => state = AsyncValue.data(next);
}

class _NoPeers extends FakeTransferController {
  _NoPeers(super.ref);

  @override
  Future<void> start() async {
    state = const TransferUiState(
      started: true,
      pin: '123456',
      port: 53317,
      lanIp: '192.168.1.42',
      fingerprint: 'DEMO-SELF',
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpVisualEnvironment();
    await prefs.setBool(OnboardingStore.prefsKey, true);
  });
  tearDown(() async {
    PlatformInfo.debugForceMobile = null;
    await prefs.remove(kPorcelaineWorkspaceKey);
  });

  final failed = [
    for (final item in sampleDownloads())
      item.copyWith(
        status: DownloadStatus.failed,
        error: 'ERROR: Unable to download: HTTP Error 403: Forbidden',
        progress: 0,
      ),
  ];

  Future<void> render(
    WidgetTester tester,
    String name, {
    String route = '/',
    Size size = const Size(1280, 800),
    List<DownloadItem>? items,
    String mode = 'data',
    bool bare = false,
    String locale = 'fr',
    Future<void> Function(WidgetTester, _List)? act,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformInfo.debugForceMobile = false;
    final data = items ?? sampleDownloads();
    late _List list;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          dependencyBootstrapProvider.overrideWith(
            (ref) => DependencyBootstrapNotifier.ready(),
          ),
          downloaderRepositoryProvider.overrideWith(
            (ref) => FakeDownloaderRepository(data),
          ),
          persistenceServiceProvider.overrideWith((ref) => FakePersistence()),
          downloadListProvider.overrideWith(
            (ref) => list = _List(
              ref.read(downloaderRepositoryProvider),
              ref,
              mode,
              data,
            ),
          ),
          downloadStatsProvider.overrideWith(
            (ref) => bare ? DownloadStatsNotifier() : FakeStatsNotifier(),
          ),
          designFreeSpaceProvider.overrideWith(
            (ref) async => 412 * 1024 * 1024 * 1024,
          ),
          showcaseModeProvider.overrideWithValue(!bare),
          tikTokArchiveRepositoryProvider.overrideWith(
            (ref) => FakeArchiveRepository(),
          ),
          tikTokArchiveProvider.overrideWith(
            (ref) => bare
                ? TikTokArchiveNotifier(FakeArchiveRepository(), ref)
                : DemoArchiveNotifier(FakeArchiveRepository(), ref),
          ),
          transferControllerProvider.overrideWith(
            (ref) => bare ? _NoPeers(ref) : FakeTransferController(ref),
          ),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: Locale(locale),
            theme: AppTheme.fromPalette(
              ThemePresets.getById('porcelaine'),
              Brightness.light,
            ),
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
      ),
    );
    await settle(tester);
    if (route != '/') {
      router.go(route);
      await settle(tester);
    }
    if (act != null) await act(tester, list);
    expect(tester.takeException(), isNull);
    if (_shots) {
      final path = await capture(tester, key, 'pextra_$name');
      // ignore: avoid_print
      print('[pextra] $name -> $path');
    }
    await tester.pumpWidget(const SizedBox());
  }

  // All six widgets at one size; the grid is 4 columns wide.
  for (final size in PWidgetSize.values) {
    for (final (mode, items) in [
      ('data', const <DownloadItem>[]),
      ('loading', null),
      ('error', null),
      ('data', failed),
    ]) {
      final label = items == null ? mode : (items.isEmpty ? 'empty' : 'failed');
      for (final locale in const ['fr', 'ar']) {
        testWidgets('all widgets ${size.name} $label $locale', (t) async {
          await prefs.setString(
            kPorcelaineWorkspaceKey,
            jsonEncode([
              for (final type in PWidgetType.values)
                PWidget('w-${type.name}', type, size).toJson(),
            ]),
          );
          await render(
            t,
            'grid_${size.name}_${label}_$locale',
            size: const Size(1280, 1500),
            items: items,
            mode: mode,
            locale: locale,
          );
        });
      }
    }
  }

  if (!_shots) return;

  testWidgets('stats bare', (t) {
    return render(
      t,
      'stats_bare',
      route: '/stats',
      items: const [],
      bare: true,
    );
  });
  testWidgets('transfer bare', (t) {
    return render(
      t,
      'transfer_bare',
      route: '/transfer',
      items: const [],
      bare: true,
    );
  });
  testWidgets('archive bare', (t) {
    return render(
      t,
      'archive_bare',
      route: '/archive',
      items: const [],
      bare: true,
    );
  });
  testWidgets('finish frame', (t) {
    final items = sampleDownloads();
    final active = items.firstWhere(
      (i) => i.status == DownloadStatus.downloading,
    );
    return render(
      t,
      'finish_frame',
      size: const Size(1280, 960),
      act: (tester, list) async {
        list.set([
          for (final i in items)
            i.id == active.id
                ? i.copyWith(status: DownloadStatus.completed, progress: 1)
                : i,
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      },
    );
  });
}
