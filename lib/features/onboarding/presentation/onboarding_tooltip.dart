import 'package:flutter/material.dart';

import 'onboarding_tokens.dart';
import 'shadcn_primitives.dart';

class OnboardingCopy {
  const OnboardingCopy({required this.title, required this.body});

  final String title;
  final String body;
}

class OnboardingTooltipCard extends StatelessWidget {
  const OnboardingTooltipCard({
    super.key,
    required this.copy,
    required this.stepIndex,
    required this.stepCount,
    required this.progress,
    required this.isWelcome,
    required this.isReady,
    required this.onNext,
    required this.onSkipStep,
    required this.onSkipAll,
    required this.nextLabel,
    required this.skipStepLabel,
    required this.skipAllLabel,
    required this.startLabel,
    required this.doneLabel,
  });

  final OnboardingCopy copy;
  final int stepIndex;
  final int stepCount;
  final double progress;
  final bool isWelcome;
  final bool isReady;
  final VoidCallback onNext;
  final VoidCallback onSkipStep;
  final VoidCallback onSkipAll;
  final String nextLabel;
  final String skipStepLabel;
  final String skipAllLabel;
  final String startLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    final primaryLabel = isWelcome
        ? startLabel
        : isReady
        ? doneLabel
        : nextLabel;

    return ShadcnCard(
      width: OnboardingTokens.cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShadcnBadge(label: '${stepIndex + 1} / $stepCount'),
              const Spacer(),
              ShadcnButton(
                label: skipAllLabel,
                variant: ShadcnButtonVariant.ghost,
                onPressed: onSkipAll,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            copy.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: zinc.cardForeground,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: zinc.mutedForeground,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          ShadcnProgress(
            value: isWelcome || isReady
                ? (stepIndex + 1) / stepCount
                : ((stepIndex + progress) / stepCount).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isWelcome && !isReady)
                ShadcnButton(
                  label: skipStepLabel,
                  variant: ShadcnButtonVariant.outline,
                  onPressed: onSkipStep,
                ),
              const Spacer(),
              ShadcnButton(label: primaryLabel, onPressed: onNext),
            ],
          ),
        ],
      ),
    );
  }
}
