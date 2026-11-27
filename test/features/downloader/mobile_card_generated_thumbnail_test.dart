import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/entities/download_request.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/video_thumbnail_provider.dart';
import 'package:tapload/features/downloader/presentation/widgets/mobile_download_card.dart';
import 'package:tapload/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'a row with no stored preview shows the one taken from the file',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('md_thumb_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final video = File('${dir.path}/clip [abc].mp4')
        ..writeAsBytesSync([1, 2, 3]);
      final thumb = File('${dir.path}/t.jpg')..writeAsBytesSync([1, 2, 3]);

      final item = DownloadItem(
        id: 'a',
        request: const DownloadRequest(url: 'https://unknown.invalid/imported'),
        status: DownloadStatus.completed,
        progress: 1,
        title: 'clip',
        filePath: video.path,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoThumbnailProvider.overrideWith(
              (ref, path) async => thumb.path,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MobileDownloadCard(
                item: item,
                onTap: () {},
                onRetry: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        images.any((i) => i.image is ResizeImage || i.image is FileImage),
        isTrue,
      );
    },
  );
}
