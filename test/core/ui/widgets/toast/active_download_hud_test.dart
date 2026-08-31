import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart'
    as settings_util;
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/widgets/toast/custom_toast.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BatchRepo implements IDownloaderRepository {
  _BatchRepo(this._items);

  final List<DownloadItem> _items;

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
  List<DownloadItem> getCurrentDownloads() => _items;

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

List<DownloadItem> _activeBatch(int count) {
  return List<DownloadItem>.generate(count, (index) {
    return DownloadItem(
      id: 'dl-$index',
      request: DownloadRequest(url: 'https://example.com/video/$index'),
      status: DownloadStatus.downloading,
      title: 'Video $index',
      progress: 0.25,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings_util.initPrefs(prefs);
  });

  testWidgets('download HUD stays compact with a large active batch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(
            _BatchRepo(_activeBatch(40)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.fromPalette(
            ThemePresets.sunset,
            Brightness.dark,
            useGoogleFonts: false,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Stack(children: [SizedBox.expand(), ToastOverlay()]),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('40 vidéos se téléchargent'), findsOneWidget);

    final hudSize = tester.getSize(
      find.byKey(const Key('active-download-hud')),
    );
    expect(hudSize.width, lessThanOrEqualTo(ToastOverlay.overlayWidth));
    expect(hudSize.height, lessThan(120));
    expect(hudSize.height, greaterThan(24));
  });
}
