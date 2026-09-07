import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/creator_folder_tile.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  testWidgets('shows handle, count, and opens on tap', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
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
          body: Center(
            child: SizedBox(
              width: 168,
              height: 220,
              child: CreatorFolderTile(
                folder: const CreatorFolder(
                  key: 'neo',
                  handle: 'neo',
                  itemIds: ['a', 'b'],
                  previewUrls: [null, null],
                ),
                onOpen: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('@neo'), findsOneWidget);
    expect(find.text('2 videos'), findsOneWidget);

    await tester.tap(find.byType(CreatorFolderTile));
    expect(opened, isTrue);
  });
}
