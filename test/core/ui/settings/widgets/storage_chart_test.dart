import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/folder_size_service.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/storage_chart.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FolderSizeSnapshot snap({
    String path = r'C:\dl',
    int totalBytes = 10,
    int fileCount = 1,
    List<FolderSizeEntry> topSubfolders = const [],
    int videoBytes = 10,
    int audioBytes = 0,
    int otherBytes = 0,
    DateTime? scannedAt,
  }) {
    return FolderSizeSnapshot(
      path: path,
      totalBytes: totalBytes,
      fileCount: fileCount,
      topSubfolders: topSubfolders,
      videoBytes: videoBytes,
      audioBytes: audioBytes,
      otherBytes: otherBytes,
      scannedAt: scannedAt ?? DateTime(2026, 8, 28, 14, 5),
    );
  }

  FolderSizeService serviceFor(FolderSizeSnapshot snapshot) {
    return FolderSizeService(scanner: (path) async => snapshot);
  }

  Future<DiskChartData> disk100(String path) async {
    return const DiskChartData(totalBytes: 100, freeBytes: 40);
  }

  Widget wrapChart(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.fromPalette(
        ThemePresets.midnight,
        Brightness.dark,
        useGoogleFonts: false,
      ),
      home: Scaffold(
        body: SizedBox(width: 900, height: 700, child: child),
      ),
    );
  }

  List<PieChartSectionData> sectionsOf(WidgetTester tester) {
    return tester.widget<PieChart>(find.byType(PieChart)).data.sections;
  }

  test('storage folder l10n keys are generated', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.storageFolder, 'Folder');
    expect(en.storageFileCount(0), '0 files');
  });

  testWidgets('draws 3 donut segments and legend percents for folder 10 / used 60 / free 40', (tester) async {
    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: serviceFor(snap(totalBytes: 10)),
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sections = sectionsOf(tester).where((s) => s.value > 0).toList();
    expect(sections, hasLength(3));
    expect(sections.map((s) => s.value).toList(), [10, 50, 40]);
    expect(sections.map((s) => s.title).toList(), ['10.0%', '50.0%', '40.0%']);

    // fl_chart paints donut titles on canvas (not Text widgets); legend is Text.
    expect(find.text('10.0%'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(find.text('10.0 B'), findsWidgets);
    expect(find.text('50.0 B'), findsOneWidget);
    expect(find.text('40.0 B'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Other used'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('places folder percent outside the ring when the slice is under 5%', (tester) async {
    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: serviceFor(snap(totalBytes: 2, videoBytes: 2)),
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sections = sectionsOf(tester);
    final folder = sections.firstWhere((s) => s.value == 2);
    expect(folder.titlePositionPercentageOffset, greaterThan(1));
    for (final section in sections.where((s) => s.value / 100 >= 0.05)) {
      expect(section.titlePositionPercentageOffset, lessThanOrEqualTo(1));
    }
  });
}
