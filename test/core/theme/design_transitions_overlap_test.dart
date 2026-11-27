import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/design_transitions.dart';

/// Switching page must never show the old and the new page at once: the old
/// page has left before the new one appears (pages have no backdrop of their
/// own, so any overlap reads as two pages drawn on top of each other).
void main() {
  double opacityOf(WidgetTester tester, String text) {
    // The first frame of a push builds the new page offstage, unpainted.
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return 0;
    var opacity = 1.0;
    for (final fade in tester.widgetList<FadeTransition>(
      find.ancestor(of: finder, matching: find.byType(FadeTransition)),
    )) {
      opacity *= fade.opacity.value;
    }
    return opacity;
  }

  for (final spec in DesignSpec.all) {
    testWidgets('${spec.id}: pages never overlap while switching', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Text('old page')),
              GoRoute(path: '/b', builder: (_, _) => const Text('new page')),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            pageTransitionsTheme: designPageTransitions(spec),
          ),
        ),
      );
      router.go('/b');
      for (var ms = 0; ms <= 600; ms += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final old = opacityOf(tester, 'old page');
        final fresh = opacityOf(tester, 'new page');
        expect(
          old > 0.02 && fresh > 0.02,
          isFalse,
          reason: 'at ${ms}ms old=$old new=$fresh',
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('old page'), findsNothing);
      expect(opacityOf(tester, 'new page'), 1);
    });
  }
}
