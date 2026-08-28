import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/widgets/mesh_gradient_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapMesh({
    required bool reduceMotion,
    required bool tickersEnabled,
    Widget? child,
  }) {
    return MaterialApp(
      theme: AppTheme.fromPalette(
        ThemePresets.ios,
        Brightness.dark,
        useGoogleFonts: false,
      ),
      builder: (context, appChild) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickersEnabled,
            child: appChild ?? const SizedBox.shrink(),
          ),
        );
      },
      home: MeshGradientBackground(
        child: child ?? const SizedBox.expand(),
      ),
    );
  }

  MeshGradientBackgroundState meshState(WidgetTester tester) {
    return tester.state<MeshGradientBackgroundState>(
      find.byType(MeshGradientBackground),
    );
  }

  Finder meshOrbs() {
    return find.descendant(
      of: find.byType(MeshGradientBackground),
      matching: find.byType(AnimatedBuilder),
    );
  }

  testWidgets('mesh does not tick when reduce-motion is on', (tester) async {
    await tester.pumpWidget(wrapMesh(reduceMotion: true, tickersEnabled: true));
    await tester.pump();

    expect(meshState(tester).isAnimating, isFalse);
    expect(meshOrbs(), findsNothing);
  });

  testWidgets('mesh ticks then freezes after idle without pointer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapMesh(reduceMotion: false, tickersEnabled: true),
    );
    await tester.pump();

    expect(meshState(tester).isAnimating, isTrue);
    expect(meshOrbs(), findsNWidgets(3));

    await tester.pump(MeshGradientBackgroundState.idleTimeout);

    expect(meshState(tester).isAnimating, isFalse);
    expect(meshOrbs(), findsNWidgets(3));
  });

  testWidgets('mesh resumes ticking after pointer activity', (tester) async {
    await tester.pumpWidget(
      wrapMesh(reduceMotion: false, tickersEnabled: true),
    );
    await tester.pump();
    await tester.pump(MeshGradientBackgroundState.idleTimeout);
    expect(meshState(tester).isAnimating, isFalse);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();

    expect(meshState(tester).isAnimating, isTrue);
  });

  testWidgets('TickerMode off does not schedule mesh frames', (tester) async {
    await tester.pumpWidget(
      wrapMesh(reduceMotion: false, tickersEnabled: false),
    );
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
    expect(meshOrbs(), findsNWidgets(3));
  });
}
