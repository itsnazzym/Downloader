import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/mobile_download_card.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget(DownloadItem item) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProviderScope(
          child: MobileDownloadCard(
            item: item,
            onTap: () {},
            onRetry: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('MobileDownloadCard renders failed download without crashing', (tester) async {
    final item = DownloadItem(
      id: 'test_1',
      request: const DownloadRequest(url: 'https://xhamster.com/videos/test-123'),
      status: DownloadStatus.failed,
      error: 'yt-dlp exited with code 1: No video formats found!',
      title: 'Ep7t8d4tldfnKXVO9',
    );

    await tester.pumpWidget(buildTestWidget(item));
    await tester.pumpAndSettle();
    expect(find.byType(MobileDownloadCard), findsOneWidget);
  });

  testWidgets('MobileDownloadCard renders completed download without crashing', (tester) async {
    final item = const DownloadItem(
      id: 'test_2',
      request: DownloadRequest(url: 'https://youtube.com/watch?v=123'),
      status: DownloadStatus.completed,
      totalSize: '24.5 MB',
      title: 'My Video',
    );

    await tester.pumpWidget(buildTestWidget(item));
    await tester.pumpAndSettle();
    expect(find.byType(MobileDownloadCard), findsOneWidget);
  });

  testWidgets('MobileDownloadCard renders downloading state without crashing', (tester) async {
    final item = const DownloadItem(
      id: 'test_3',
      request: DownloadRequest(url: 'https://youtube.com/watch?v=123'),
      status: DownloadStatus.downloading,
      progress: 0.45,
      speed: '2.1 MB/s',
      eta: '00:15',
      downloadedSize: '10 MB',
      totalSize: '24.5 MB',
      title: 'Downloading Clip',
    );

    await tester.pumpWidget(buildTestWidget(item));
    await tester.pumpAndSettle();
    expect(find.byType(MobileDownloadCard), findsOneWidget);
  });
}
