import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/design_transitions.dart';

void main() {
  Future<Widget> build(
    WidgetTester tester,
    DesignNav nav, {
    bool reduce = false,
  }) async {
    late Widget built;
    const child = SizedBox(key: Key('page'));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            built = DesignPageTransitionsBuilder(nav).buildTransitions(
              MaterialPageRoute<void>(builder: (_) => child),
              context,
              const AlwaysStoppedAnimation(0.5),
              const AlwaysStoppedAnimation(0),
              child,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return built;
  }

  testWidgets('Terminal cuts, the other designs animate', (tester) async {
    final terminal = await build(tester, DesignNav.keySidebar);
    expect((terminal as FadeTransition).child, isA<SizedBox>());
    for (final nav in [
      DesignNav.topTabs,
      DesignNav.centerDock,
      DesignNav.bottomDock,
      DesignNav.textSidebar,
      DesignNav.iconRail,
    ]) {
      expect(await build(tester, nav), isA<FadeTransition>(), reason: '$nav');
    }
  });

  testWidgets('reduce effects shows every page without motion', (tester) async {
    for (final nav in DesignNav.values) {
      expect(
        await build(tester, nav, reduce: true),
        isA<SizedBox>(),
        reason: '$nav',
      );
    }
  });
}
