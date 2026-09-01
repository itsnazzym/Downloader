import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/services/clipboard_service.dart';
import 'package:modern_downloader/core/services/local_server_service.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/ui/app_shell.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart'
    as settings_util;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

// --- MOCKS ---

class MockClipboardService extends ClipboardService {
  MockClipboardService(super.ref);
  @override
  void startMonitoring() {}
  @override
  void stopMonitoring() {}
}

class MockLocalServerService extends LocalServerService {
  MockLocalServerService(super.ref);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class MockDownloaderRepository implements IDownloaderRepository {
  @override
  Future<void> get initialized => Future.value();
  @override
  Future<void> cancelDownload(String id) async {}
  @override
  Future<void> clearHistory() async {}
  @override
  Future<void> deleteDownload(String id) async {}
  @override
  Stream<DownloadItem> get downloadUpdateStream =>
      const Stream<DownloadItem>.empty();
  @override
  Future<void> exportHistory(String path) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchPlaylist(String url) async => [];
  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
  }) async {
    return {};
  }

  @override
  List<DownloadItem> getCurrentDownloads() => [];
  @override
  Future<void> importHistory(String path) async {}
  @override
  Future<void> pauseDownload(String id) async {}
  @override
  Future<void> refreshLibrary() async {}
  @override
  Future<void> reorderDownloads(int oldIndex, int newIndex) async {}
  @override
  Future<void> resumeDownload(String id) async {}
  @override
  Future<String> startDownload(DownloadRequest request) async => 'mock-id';
}

// --- TEST ---

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');
  const protocolChannel = MethodChannel('protocol_handler');
  const dropChannel = MethodChannel('desktop_drop');

  setUpAll(() async {
    // 1. Mock MethodChannels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (MethodCall methodCall) async {
          return true;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(trayChannel, (MethodCall methodCall) async {
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(protocolChannel, (
          MethodCall methodCall,
        ) async {
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dropChannel, (MethodCall methodCall) async {
          return null;
        });

    // 2. Initialize SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings_util.initPrefs(prefs);
  });

  testWidgets('AppShell layout smoke test', (WidgetTester tester) async {
    // Set a fixed window size using modern API
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Setup basic GoRouter to host AppShell
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Center(child: Text('Content')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardServiceProvider.overrideWith(
            (ref) => MockClipboardService(ref),
          ),
          localServerServiceProvider.overrideWith(
            (ref) => MockLocalServerService(ref),
          ),
          downloaderRepositoryProvider.overrideWithValue(
            MockDownloaderRepository(),
          ),
          // Override mediaPlayerProvider with a simple StateProvider
          // to avoid instantiating the real MediaPlayerNotifier which
          // creates a native media_kit Player.
          mediaPlayerProvider.overrideWith(
            (ref) => MediaPlayerNotifier(testMode: true),
          ),
          dependencyBootstrapProvider.overrideWith(
            (ref) => DependencyBootstrapNotifier.ready(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Content'), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('AppShell uses a phone navigation bar on a compact viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Center(child: Text('Content')),
            ),
            GoRoute(
              path: '/stats',
              builder: (context, state) => const Center(child: Text('Stats')),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const Center(child: Text('Settings')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardServiceProvider.overrideWith(
            (ref) => MockClipboardService(ref),
          ),
          localServerServiceProvider.overrideWith(
            (ref) => MockLocalServerService(ref),
          ),
          downloaderRepositoryProvider.overrideWithValue(
            MockDownloaderRepository(),
          ),
          mediaPlayerProvider.overrideWith(
            (ref) => MediaPlayerNotifier(testMode: true),
          ),
          dependencyBootstrapProvider.overrideWith(
            (ref) => DependencyBootstrapNotifier.ready(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(AppTitleBar), findsNothing);
  });
}
