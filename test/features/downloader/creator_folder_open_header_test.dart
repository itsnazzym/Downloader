import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/creator_folder_grid.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  testWidgets('toggles list/detailed without closing the folder', (
    tester,
  ) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openedCreatorFolderKeyProvider.overrideWith((ref) => 'neo'),
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
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const CreatorFolderOpenHeader(
                  folder: CreatorFolder(
                    key: 'neo',
                    handle: 'neo',
                    itemIds: ['a', 'b'],
                    previewUrls: [null, null],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(openedCreatorFolderKeyProvider), 'neo');
    expect(
      container.read(folderContentsViewModeProvider),
      DownloadViewMode.list,
    );

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump();

    expect(container.read(openedCreatorFolderKeyProvider), 'neo');
    expect(
      container.read(folderContentsViewModeProvider),
      DownloadViewMode.detailed,
    );

    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pump();

    expect(container.read(openedCreatorFolderKeyProvider), 'neo');
    expect(
      container.read(folderContentsViewModeProvider),
      DownloadViewMode.list,
    );
  });
}
