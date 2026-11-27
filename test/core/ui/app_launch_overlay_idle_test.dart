import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/core/bootstrap/app_warmup_provider.dart';
import 'package:tapload/core/setup/dependency_bootstrap_provider.dart';
import 'package:tapload/core/ui/setup/app_launch_overlay.dart';

void main() {
  testWidgets('the launch overlay stops scheduling frames once dismissed', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appWarmupProvider.overrideWith(
          (ref) => AppWarmupNotifier(ref, autoStart: false),
        ),
        dependencyBootstrapProvider.overrideWith(
          (ref) => DependencyBootstrapNotifier.ready(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppLaunchOverlay(libraryReady: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    container.read(appWarmupProvider.notifier).continueAnyway();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // fade-out
    await tester.pump();

    // An idle window must not keep the raster thread busy.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
