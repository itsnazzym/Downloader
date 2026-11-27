import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tapload/core/theme/app_theme.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/features/downloader/presentation/views/inspector/video_preview_widget.dart';

void main() {
  Widget wrapPreview(Widget child) {
    return MaterialApp(
      theme: AppTheme.fromPalette(
        ThemePresets.midnight,
        Brightness.dark,
        useGoogleFonts: false,
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets(
    'idle inspector preview shows thumbnail chrome without a player',
    (tester) async {
      await tester.pumpWidget(
        wrapPreview(
          const VideoPreviewWidget(filePath: r'C:\does\not\exist.mp4'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(Video), findsNothing);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      expect(find.text('Preview unavailable'), findsNothing);
    },
  );

  testWidgets('hover mounts a loading state then unmounts the player on exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPreview(const VideoPreviewWidget(filePath: r'C:\does\not\exist.mp4')),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(VideoPreviewWidget)));
    await tester.pump();

    expect(find.byType(Video), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final rect = tester.getRect(find.byType(VideoPreviewWidget));
    await gesture.moveTo(rect.bottomRight + const Offset(40, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(Video), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });
}
