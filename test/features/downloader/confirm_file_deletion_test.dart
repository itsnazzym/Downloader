import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_request.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/widgets/confirm_file_deletion.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

const _done = DownloadItem(
  id: 'a',
  request: DownloadRequest(url: 'https://example.com/a'),
  title: 'Holiday clip',
  status: DownloadStatus.completed,
  progress: 1,
);

Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('a finished file asks first, and Cancel keeps it', (
    tester,
  ) async {
    final context = await _host(tester);
    final answer = confirmFileDeletion(context, _done, actionLabel: 'Delete');
    await tester.pumpAndSettle();

    expect(find.textContaining('Holiday clip'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('confirming returns true', (tester) async {
    final context = await _host(tester);
    final answer = confirmFileDeletion(context, _done, actionLabel: 'Delete');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('a failed row has no finished file and does not ask', (
    tester,
  ) async {
    final context = await _host(tester);
    final failed = _done.copyWith(status: DownloadStatus.failed);

    expect(
      await confirmFileDeletion(context, failed, actionLabel: 'Delete'),
      isTrue,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });
}
