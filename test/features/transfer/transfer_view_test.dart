import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_view.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

class _FakeTransferController extends TransferController {
  _FakeTransferController(super.ref, [TransferUiState? initialState])
    : _initialState = initialState;

  final TransferUiState? _initialState;

  @override
  Future<void> start() async {
    state =
        _initialState ??
        const TransferUiState(
          started: true,
          pin: '123456',
          port: 53317,
          lanIp: '192.168.1.8',
          alias: 'PC-Test',
        );
  }

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('shows PIN and QR url without leaving folder chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorFoldersProvider.overrideWithValue(const CreatorFolderList([])),
          transferControllerProvider.overrideWith(
            (ref) => _FakeTransferController(ref),
          ),
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
          home: const Scaffold(body: TransferView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('123456'), findsOneWidget);
    expect(find.textContaining('192.168.1.8:53317'), findsWidgets);
  });

  testWidgets('payload search adds a creator without listing the library', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorFoldersProvider.overrideWithValue(
            const CreatorFolderList([
              CreatorFolder(
                key: 'neo',
                handle: 'neo',
                itemIds: ['a'],
                previewUrls: [null],
              ),
              CreatorFolder(
                key: 'zeta',
                handle: 'zeta',
                itemIds: ['b', 'c'],
                previewUrls: [null],
              ),
            ]),
          ),
          transferControllerProvider.overrideWith(
            (ref) => _FakeTransferController(ref),
          ),
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
          home: const Scaffold(body: TransferView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('@zeta'), findsNothing);

    await tester.enterText(find.byType(TextField), 'neo');
    await tester.pump();

    expect(find.text('@neo'), findsWidgets);
    expect(find.text('@zeta'), findsNothing);

    await tester.tap(find.text('@neo').last);
    await tester.pump();

    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('handles 250 extra folders without RenderFlex overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeFolders = List.generate(
      250,
      (i) => 'E:\\Videos\\TikTok\\folder_$i',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorFoldersProvider.overrideWithValue(const CreatorFolderList([])),
          transferControllerProvider.overrideWith(
            (ref) => _FakeTransferController(
              ref,
              TransferUiState(
                started: true,
                pin: '123456',
                port: 53317,
                lanIp: '192.168.1.8',
                alias: 'PC-Test',
                extraFolders: fakeFolders,
                selectedFilesCount: 889,
                selectedTotalBytes: 1600000000,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
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
          home: const Scaffold(body: TransferView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Verify no RenderFlex overflow
    expect(tester.takeException(), isNull);
    expect(find.textContaining('250 dossiers'), findsOneWidget);
    expect(find.text('folder_0'), findsOneWidget);

    // Verify clear button clears all folders
    final clearButton = find.widgetWithText(TextButton, 'Retirer');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pump();

    expect(find.text('folder_0'), findsNothing);
  });

  testWidgets('a progress tick only rebuilds the progress banner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _FakeTransferController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorFoldersProvider.overrideWithValue(const CreatorFolderList([])),
          transferControllerProvider.overrideWith((ref) {
            return controller = _FakeTransferController(ref);
          }),
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
          home: const Scaffold(body: TransferView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    TransferProgress tick(int done) => TransferProgress(
      phase: TransferPhase.transferring,
      bytesDone: done,
      bytesTotal: 1000,
      currentName: 'clip.mp4',
    );
    // ignore: invalid_use_of_protected_member
    controller.state = controller.state.copyWith(progress: tick(1));
    await tester.pump();

    var rebuilds = 0;
    widgets.debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
    addTearDown(() => widgets.debugOnRebuildDirtyWidget = null);
    for (var i = 2; i <= 6; i++) {
      // ignore: invalid_use_of_protected_member
      controller.state = controller.state.copyWith(progress: tick(i * 100));
      await tester.pump();
    }
    widgets.debugOnRebuildDirtyWidget = null;

    // ignore: avoid_print
    print('[transfer] widgets rebuilt per progress tick: ${rebuilds ~/ 5}');
    // The whole page (header, payload, devices) rebuilt on every tick, ~7x/s:
    // 372 widgets. The progress banner alone is about 40.
    expect(rebuilds ~/ 5, lessThan(80));
  });
}
