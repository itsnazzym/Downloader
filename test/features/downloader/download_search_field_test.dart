import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/downloader/data/downloader_data_providers.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

class _EmptyRepo implements IDownloaderRepository {
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
  Future<List<Map<String, dynamic>>> fetchPlaylist(
    String url, {
    bool? useTorProxy,
  }) async => [];
  @override
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookies,
    bool? useTorProxy,
  }) async => {};
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
  Future<String> startDownload(DownloadRequest request) async => 'id';
}

void main() {
  testWidgets('types a query, shows clear, then wipes the field', (
    tester,
  ) async {
    final queries = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(_EmptyRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.fromPalette(
            ThemePresets.midnight,
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
          home: Scaffold(body: DownloadSearchField(onChanged: queries.add)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filter titles or URLs'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lofi');
    await tester.pump();

    expect(queries, contains('lofi'));
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(queries.last, isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('keeps the controller aligned with the search provider', (
    tester,
  ) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloaderRepositoryProvider.overrideWithValue(_EmptyRepo()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              locale: const Locale('en'),
              theme: AppTheme.fromPalette(
                ThemePresets.midnight,
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
              home: Scaffold(
                body: DownloadSearchField(
                  onChanged: (value) {
                    ref.read(downloadSearchQueryProvider.notifier).state =
                        value;
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(downloadSearchQueryProvider.notifier).state = 'jazz';
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'jazz',
    );
  });
}
