import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/providers/settings_provider.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_step.dart';

class OnboardingState {
  const OnboardingState({
    required this.completed,
    required this.active,
    required this.stepIndex,
    this.timerPaused = false,
  });

  final bool completed;
  final bool active;
  final int stepIndex;
  final bool timerPaused;

  OnboardingStep? get currentStep {
    if (!active) return null;
    if (stepIndex < 0 || stepIndex >= kOnboardingSteps.length) return null;
    return kOnboardingSteps[stepIndex];
  }

  bool get isLastStep => stepIndex >= kOnboardingSteps.length - 1;
  bool get isWelcome => active && currentStep?.id == OnboardingStepId.welcome;
  bool get isReady => active && currentStep?.id == OnboardingStepId.ready;

  OnboardingState copyWith({
    bool? completed,
    bool? active,
    int? stepIndex,
    bool? timerPaused,
  }) {
    return OnboardingState(
      completed: completed ?? this.completed,
      active: active ?? this.active,
      stepIndex: stepIndex ?? this.stepIndex,
      timerPaused: timerPaused ?? this.timerPaused,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController({
    required OnboardingPersistence store,
    required bool isDesktop,
  }) : _store = store,
       _isDesktop = isDesktop,
       super(
         OnboardingState(
           completed: store.completed,
           active: false,
           stepIndex: 0,
         ),
       );

  final OnboardingPersistence _store;
  final bool _isDesktop;

  bool get isDesktop => _isDesktop;

  bool tryStart({bool replay = false}) {
    if (!_isDesktop) return false;
    if (!replay && _store.completed) return false;
    if (replay) {
      try {
        _store.setCompleted(false);
      } catch (_) {}
    }
    state = OnboardingState(
      completed: false,
      active: true,
      stepIndex: 0,
      timerPaused: false,
    );
    return true;
  }

  void replay() {
    tryStart(replay: true);
  }

  void next() {
    if (!state.active) return;
    if (state.isLastStep) {
      complete();
      return;
    }
    state = state.copyWith(stepIndex: state.stepIndex + 1, timerPaused: false);
  }

  void skipStep() {
    next();
  }

  Future<void> skipAll() async {
    await complete();
  }

  Future<void> complete() async {
    try {
      await _store.setCompleted(true);
    } catch (_) {}
    state = OnboardingState(completed: true, active: false, stepIndex: 0);
  }

  void setTimerPaused(bool paused) {
    if (!state.active || state.timerPaused == paused) return;
    state = state.copyWith(timerPaused: paused);
  }
}

final onboardingStoreProvider = Provider<OnboardingPersistence>((ref) {
  return OnboardingStore(prefs);
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
      return OnboardingController(
        store: ref.watch(onboardingStoreProvider),
        isDesktop: PlatformInfo.isDesktop,
      );
    });
