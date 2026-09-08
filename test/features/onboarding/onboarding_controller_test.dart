import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/features/onboarding/data/onboarding_store.dart';
import 'package:modern_downloader/features/onboarding/domain/onboarding_step.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';

void main() {
  test('does not start on non-desktop', () {
    final store = MemoryOnboardingStore();
    final controller = OnboardingController(store: store, isDesktop: false);
    addTearDown(controller.dispose);

    expect(controller.tryStart(), isFalse);
    expect(controller.state.active, isFalse);
  });

  test('does not start when already completed', () {
    final store = MemoryOnboardingStore(completed: true);
    final controller = OnboardingController(store: store, isDesktop: true);
    addTearDown(controller.dispose);

    expect(controller.tryStart(), isFalse);
    expect(controller.state.active, isFalse);
    expect(controller.state.completed, isTrue);
  });

  test('starts on desktop then next and skipStep advance', () {
    final store = MemoryOnboardingStore();
    final controller = OnboardingController(store: store, isDesktop: true);
    addTearDown(controller.dispose);

    expect(controller.tryStart(), isTrue);
    expect(controller.state.active, isTrue);
    expect(controller.state.currentStep?.id, OnboardingStepId.welcome);

    controller.next();
    expect(controller.state.currentStep?.id, OnboardingStepId.newDownload);

    controller.skipStep();
    expect(controller.state.currentStep?.id, OnboardingStepId.library);
  });

  test('skipAll persists and dismisses', () async {
    final store = MemoryOnboardingStore();
    final controller = OnboardingController(store: store, isDesktop: true);
    addTearDown(controller.dispose);

    controller.tryStart();
    await controller.skipAll();

    expect(controller.state.active, isFalse);
    expect(controller.state.completed, isTrue);
    expect(store.completed, isTrue);
  });

  test('replay resets store and restarts at welcome', () async {
    final store = MemoryOnboardingStore(completed: true);
    final controller = OnboardingController(store: store, isDesktop: true);
    addTearDown(controller.dispose);

    controller.replay();
    expect(controller.state.active, isTrue);
    expect(controller.state.stepIndex, 0);
    expect(controller.state.currentStep?.id, OnboardingStepId.welcome);

    await Future<void>.delayed(Duration.zero);
    expect(store.completed, isFalse);
  });

  test('next on last step completes the tour', () async {
    final store = MemoryOnboardingStore();
    final controller = OnboardingController(store: store, isDesktop: true);
    addTearDown(controller.dispose);

    controller.tryStart();
    for (var i = 0; i < kOnboardingSteps.length - 1; i++) {
      controller.next();
    }
    expect(controller.state.isReady, isTrue);
    controller.next();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.active, isFalse);
    expect(store.completed, isTrue);
  });

  test('pause flag does not change step', () {
    final controller = OnboardingController(
      store: MemoryOnboardingStore(),
      isDesktop: true,
    );
    addTearDown(controller.dispose);
    controller.tryStart();
    controller.setTimerPaused(true);
    expect(controller.state.timerPaused, isTrue);
    expect(controller.state.stepIndex, 0);
  });
}
