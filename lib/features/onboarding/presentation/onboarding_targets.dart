import 'package:flutter/widgets.dart';

import '../domain/onboarding_step.dart';
import 'onboarding_tokens.dart';

class OnboardingTargets {
  OnboardingTargets._();

  static const double holePadding = OnboardingTokens.holePadding;

  static final GlobalKey newDownload = GlobalKey(
    debugLabel: 'onboarding_newDownload',
  );
  static final GlobalKey library = GlobalKey(debugLabel: 'onboarding_library');
  static final GlobalKey topBar = GlobalKey(debugLabel: 'onboarding_topBar');
  static final GlobalKey creatorList = GlobalKey(
    debugLabel: 'onboarding_creatorList',
  );
  static final GlobalKey transfer = GlobalKey(
    debugLabel: 'onboarding_transfer',
  );
  static final GlobalKey stats = GlobalKey(debugLabel: 'onboarding_stats');
  static final GlobalKey outputFolder = GlobalKey(
    debugLabel: 'onboarding_outputFolder',
  );
  static final GlobalKey extensions = GlobalKey(
    debugLabel: 'onboarding_extensions',
  );

  static GlobalKey? keyFor(OnboardingTargetId id) {
    switch (id) {
      case OnboardingTargetId.none:
        return null;
      case OnboardingTargetId.newDownload:
        return newDownload;
      case OnboardingTargetId.library:
        return library;
      case OnboardingTargetId.topBar:
        return topBar;
      case OnboardingTargetId.creatorList:
        return creatorList;
      case OnboardingTargetId.transfer:
        return transfer;
      case OnboardingTargetId.stats:
        return stats;
      case OnboardingTargetId.outputFolder:
        return outputFolder;
      case OnboardingTargetId.extensions:
        return extensions;
    }
  }

  static Rect? measure(
    OnboardingTargetId id, {
    double padding = holePadding,
    RenderBox? ancestor,
  }) {
    final key = keyFor(id);
    if (key == null) return null;
    try {
      final context = key.currentContext;
      if (context == null) return null;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return null;
      }
      if (!renderObject.attached) return null;
      final origin = ancestor != null && ancestor.attached
          ? renderObject.localToGlobal(Offset.zero, ancestor: ancestor)
          : renderObject.localToGlobal(Offset.zero);
      final rect = origin & renderObject.size;
      if (rect.width < 4 || rect.height < 4) return null;
      return rect.inflate(padding);
    } catch (_) {
      return null;
    }
  }
}
