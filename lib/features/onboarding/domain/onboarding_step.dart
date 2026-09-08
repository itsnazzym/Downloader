enum OnboardingTargetId {
  none,
  newDownload,
  library,
  topBar,
  creatorList,
  transfer,
  stats,
  outputFolder,
  extensions,
}

enum OnboardingStepId {
  welcome,
  newDownload,
  library,
  topBar,
  creatorFolders,
  transfer,
  stats,
  outputFolder,
  extensions,
  ready,
}

class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.target,
    this.route,
    this.duration = const Duration(seconds: 5),
    this.autoAdvance = true,
    this.needsSidebar = false,
  });

  final OnboardingStepId id;
  final OnboardingTargetId target;
  final String? route;
  final Duration duration;
  final bool autoAdvance;
  final bool needsSidebar;

  bool get hasHole => target != OnboardingTargetId.none;
}

const List<OnboardingStep> kOnboardingSteps = [
  OnboardingStep(
    id: OnboardingStepId.welcome,
    target: OnboardingTargetId.none,
    route: '/',
    autoAdvance: false,
  ),
  OnboardingStep(
    id: OnboardingStepId.newDownload,
    target: OnboardingTargetId.newDownload,
    route: '/',
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.library,
    target: OnboardingTargetId.library,
    route: '/',
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.topBar,
    target: OnboardingTargetId.topBar,
    route: '/',
  ),
  OnboardingStep(
    id: OnboardingStepId.creatorFolders,
    target: OnboardingTargetId.creatorList,
    route: '/',
  ),
  OnboardingStep(
    id: OnboardingStepId.transfer,
    target: OnboardingTargetId.transfer,
    route: '/transfer',
    duration: Duration(seconds: 6),
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.stats,
    target: OnboardingTargetId.stats,
    route: '/stats',
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.outputFolder,
    target: OnboardingTargetId.outputFolder,
    route: '/settings/output',
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.extensions,
    target: OnboardingTargetId.extensions,
    route: '/settings/plugins',
    duration: Duration(seconds: 6),
    needsSidebar: true,
  ),
  OnboardingStep(
    id: OnboardingStepId.ready,
    target: OnboardingTargetId.none,
    route: '/',
    duration: Duration(seconds: 5),
  ),
];
