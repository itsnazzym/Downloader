import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/setup/dependency_bootstrap_provider.dart';
import '../../../core/ui/layout/pane_layout_provider.dart';
import '../../../core/ui/window_chrome.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../domain/onboarding_step.dart';
import 'onboarding_controller.dart';
import 'onboarding_spotlight.dart';
import 'onboarding_targets.dart';
import 'onboarding_tokens.dart';
import 'onboarding_tooltip.dart';
import 'onboarding_tooltip_placement.dart';
import 'shadcn_primitives.dart';

class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay> {
  Rect? _hole;
  double _advanceProgress = 0;
  int _armedStep = -1;
  int _measureGeneration = 0;
  Timer? _tick;
  Timer? _trackerTimer;
  bool _started = false;

  @override
  void dispose() {
    _tick?.cancel();
    _trackerTimer?.cancel();
    super.dispose();
  }

  void _maybeAutoStart() {
    if (!mounted || _started) return;
    if (!PlatformInfo.isDesktop) return;
    try {
      if (ref.read(dependencyBootstrapProvider).blocksUi) return;
      final started = ref
          .read(onboardingControllerProvider.notifier)
          .tryStart();
      _started = true;
      if (started) {
        unawaited(_syncStep());
      }
    } catch (_) {
      // Overlay must never crash the shell.
    }
  }

  Future<void> _syncStep() async {
    final generation = ++_measureGeneration;
    final tour = ref.read(onboardingControllerProvider);
    final step = tour.currentStep;
    if (!tour.active || step == null) {
      _tick?.cancel();
      _trackerTimer?.cancel();
      if (mounted) {
        setState(() {
          _hole = null;
          _advanceProgress = 0;
          _armedStep = -1;
        });
      }
      return;
    }

    try {
      if (step.route != null) {
        final current = GoRouterState.of(context).uri.path;
        if (current != step.route) {
          context.go(step.route!);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (!mounted || generation != _measureGeneration) return;

      if (step.needsSidebar) {
        final layout = ref.read(paneLayoutProvider);
        if (layout.sidebarCollapsed) {
          ref.read(paneLayoutProvider.notifier).expandSidebar();
          unawaited(ref.read(paneLayoutProvider.notifier).persist());
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      if (!mounted || generation != _measureGeneration) return;

      // When focusing top sidebar items, ensure sidebar scroll position is 0 so headers are never clipped
      if (step.id == OnboardingStepId.newDownload || step.id == OnboardingStepId.library) {
        final targetContext = OnboardingTargets.keyFor(step.target)?.currentContext;
        if (targetContext != null && targetContext.mounted) {
          final scrollable = Scrollable.maybeOf(targetContext);
          if (scrollable != null && scrollable.position.pixels > 0) {
            await scrollable.position.animateTo(
              0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        }
      }

      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted || generation != _measureGeneration) return;

      Rect? hole;
      if (step.hasHole) {
        final targetContext = OnboardingTargets.keyFor(
          step.target,
        )?.currentContext;
        if (targetContext != null && targetContext.mounted) {
          final renderBox = targetContext.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.attached && renderBox.hasSize) {
            final scrollable = Scrollable.maybeOf(targetContext);
            if (scrollable != null) {
              final viewport = RenderAbstractViewport.maybeOf(renderBox);
              if (viewport != null) {
                final offsetToRevealStart = viewport.getOffsetToReveal(renderBox, 0.0).offset;
                final offsetToRevealEnd = viewport.getOffsetToReveal(renderBox, 1.0).offset;
                final currentScroll = scrollable.position.pixels;
                final isFullyVisible = currentScroll <= offsetToRevealStart && currentScroll >= offsetToRevealEnd;
                // Only scroll if not already fully visible, and avoid scrolling sidebar top items
                if (!isFullyVisible &&
                    step.id != OnboardingStepId.library &&
                    step.id != OnboardingStepId.newDownload) {
                  try {
                    await Scrollable.ensureVisible(
                      targetContext,
                      alignment: 0.5,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                    await WidgetsBinding.instance.endOfFrame;
                  } catch (_) {}
                }
              }
            }
          }
        }
        hole = OnboardingTargets.measure(step.target);
        if (hole == null) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || generation != _measureGeneration) return;
          hole = OnboardingTargets.measure(step.target);
        }
      }

      if (!mounted || generation != _measureGeneration) return;
      setState(() {
        _hole = hole;
        _advanceProgress = 0;
        _armedStep = tour.stepIndex;
      });
      _armTimer(step, tour.stepIndex);
      _armTracker(step, tour.stepIndex);
    } catch (_) {
      if (!mounted || generation != _measureGeneration) return;
      setState(() {
        _hole = null;
        _advanceProgress = 0;
        _armedStep = tour.stepIndex;
      });
    }
  }

  void _armTracker(OnboardingStep step, int stepIndex) {
    _trackerTimer?.cancel();
    if (!step.hasHole) return;
    _trackerTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final tour = ref.read(onboardingControllerProvider);
      if (!tour.active || tour.stepIndex != stepIndex) {
        timer.cancel();
        return;
      }
      final updated = OnboardingTargets.measure(step.target);
      if (updated != null && updated != _hole) {
        setState(() => _hole = updated);
      }
    });
  }

  void _armTimer(OnboardingStep step, int stepIndex) {
    _tick?.cancel();
    if (!step.autoAdvance) return;
    final totalMs = step.duration.inMilliseconds.clamp(1000, 12000);
    const interval = Duration(milliseconds: 50);
    var elapsed = 0;
    _tick = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final tour = ref.read(onboardingControllerProvider);
      if (!tour.active || tour.stepIndex != stepIndex) {
        timer.cancel();
        return;
      }
      if (tour.timerPaused) return;
      elapsed += interval.inMilliseconds;
      final next = (elapsed / totalMs).clamp(0.0, 1.0);
      setState(() => _advanceProgress = next);
      if (next >= 1) {
        timer.cancel();
        ref.read(onboardingControllerProvider.notifier).next();
      }
    });
  }

  Future<void> _finishAndHome() async {
    _tick?.cancel();
    try {
      await ref.read(onboardingControllerProvider.notifier).complete();
    } catch (_) {}
    if (!mounted) return;
    try {
      context.go('/');
    } catch (_) {}
  }

  OnboardingCopy _copyFor(OnboardingStepId id) {
    final l10n = context.l10n;
    switch (id) {
      case OnboardingStepId.welcome:
        return OnboardingCopy(
          title: l10n.onboardingWelcomeTitle,
          body: l10n.onboardingWelcomeBody,
        );
      case OnboardingStepId.newDownload:
        return OnboardingCopy(
          title: l10n.onboardingNewDownloadTitle,
          body: l10n.onboardingNewDownloadBody,
        );
      case OnboardingStepId.library:
        return OnboardingCopy(
          title: l10n.onboardingLibraryTitle,
          body: l10n.onboardingLibraryBody,
        );
      case OnboardingStepId.topBar:
        return OnboardingCopy(
          title: l10n.onboardingTopBarTitle,
          body: l10n.onboardingTopBarBody,
        );
      case OnboardingStepId.creatorFolders:
        return OnboardingCopy(
          title: l10n.onboardingFoldersTitle,
          body: l10n.onboardingFoldersBody,
        );
      case OnboardingStepId.transfer:
        return OnboardingCopy(
          title: l10n.onboardingTransferTitle,
          body: l10n.onboardingTransferBody,
        );
      case OnboardingStepId.stats:
        return OnboardingCopy(
          title: l10n.onboardingStatsTitle,
          body: l10n.onboardingStatsBody,
        );
      case OnboardingStepId.outputFolder:
        return OnboardingCopy(
          title: l10n.onboardingOutputTitle,
          body: l10n.onboardingOutputBody,
        );
      case OnboardingStepId.extensions:
        return OnboardingCopy(
          title: l10n.onboardingExtensionTitle,
          body: l10n.onboardingExtensionBody,
        );
      case OnboardingStepId.ready:
        return OnboardingCopy(
          title: l10n.onboardingReadyTitle,
          body: l10n.onboardingReadyBody,
        );
    }
  }

  Rect? _holeInOverlay(Rect? hole, Size overlay) {
    if (hole == null || hole.isEmpty) return null;
    final shifted = hole.translate(0, -WindowChrome.titleBarHeight);
    return clampOnboardingHole(shifted, overlay);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) {
      return const SizedBox.shrink();
    }

    final blocksUi = ref.watch(
      dependencyBootstrapProvider.select((s) => s.blocksUi),
    );
    if (blocksUi) {
      return const SizedBox.shrink();
    }

    final tour = ref.watch(onboardingControllerProvider);
    ref.listen<int>(onboardingControllerProvider.select((s) => s.stepIndex), (
      previous,
      next,
    ) {
      if (ref.read(onboardingControllerProvider).active) {
        unawaited(_syncStep());
      }
    });
    ref.listen<bool>(onboardingControllerProvider.select((s) => s.active), (
      previous,
      next,
    ) {
      if (next == true) {
        unawaited(_syncStep());
      }
    });

    if (!tour.active) {
      if (!_started) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeAutoStart();
        });
      }
      return const SizedBox.shrink();
    }

    final step = tour.currentStep;
    if (step == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final zinc = ShadcnZinc.of(context);
    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      top: WindowChrome.titleBarHeight,
      bottom: 0,
      child: Theme(
        data: theme.copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final overlaySize = constraints.biggest;
              final targetHole = _armedStep == tour.stepIndex
                  ? _holeInOverlay(_hole, overlaySize)
                  : null;

              if (targetHole == null) {
                return _buildOverlayContent(
                  tour: tour,
                  step: step,
                  l10n: l10n,
                  zinc: zinc,
                  hole: null,
                  targetHole: null,
                );
              }

              return TweenAnimationBuilder<Rect?>(
                tween: RectTween(begin: targetHole, end: targetHole),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, animHole, _) {
                  return _buildOverlayContent(
                    tour: tour,
                    step: step,
                    l10n: l10n,
                    zinc: zinc,
                    hole: animHole,
                    targetHole: targetHole,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent({
    required OnboardingState tour,
    required OnboardingStep step,
    required AppLocalizations l10n,
    required ShadcnZinc zinc,
    required Rect? hole,
    required Rect? targetHole,
  }) {
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: SpotlightPainter(
                  hole: hole,
                  radius: OnboardingTokens.holeRadius,
                  veil: zinc.veil,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (hole != null) OnboardingSpotlightRim(hole: hole),
          CustomSingleChildLayout(
            delegate: OnboardingTooltipLayoutDelegate(
              hole: targetHole,
            ),
            child: MouseRegion(
              onEnter: (_) {
                ref
                    .read(onboardingControllerProvider.notifier)
                    .setTimerPaused(true);
              },
              onExit: (_) {
                ref
                    .read(onboardingControllerProvider.notifier)
                    .setTimerPaused(false);
              },
              child: OnboardingTooltipCard(
                copy: _copyFor(step.id),
                stepIndex: tour.stepIndex,
                stepCount: kOnboardingSteps.length,
                progress: _advanceProgress,
                isWelcome: tour.isWelcome,
                isReady: tour.isReady,
                onNext: () {
                  if (tour.isReady) {
                    unawaited(_finishAndHome());
                    return;
                  }
                  ref
                      .read(onboardingControllerProvider.notifier)
                      .next();
                },
                onSkipStep: () {
                  ref
                      .read(onboardingControllerProvider.notifier)
                      .skipStep();
                },
                onSkipAll: () => unawaited(_finishAndHome()),
                nextLabel: l10n.onboardingNext,
                skipStepLabel: l10n.onboardingSkipStep,
                skipAllLabel: l10n.onboardingSkipAll,
                startLabel: l10n.onboardingStart,
                doneLabel: l10n.onboardingDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
