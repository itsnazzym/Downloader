import 'package:flutter/material.dart';

import 'design_spec.dart';

/// How a design moves from one page to the next. Every variant returns the
/// page untouched when the OS or "Reduce effects" disables animations.
class DesignPageTransitionsBuilder extends PageTransitionsBuilder {
  const DesignPageTransitionsBuilder(this.nav);

  final DesignNav nav;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // The old page stays mounted under the new one until the transition
    // ends, and pages have no backdrop of their own: it leaves first, then
    // the new page enters, so the two are never drawn on top of each other.
    return FadeTransition(
      opacity: ReverseAnimation(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: nav == DesignNav.keySidebar
              ? const Threshold(0.001)
              : const Interval(0, _exitEnd, curve: Curves.easeOut),
        ),
      ),
      child: _enter(_delayed(animation), child),
    );
  }

  /// Share of the transition the old page takes to leave.
  static const _exitEnd = 0.35;

  /// [animation] held at 0 while the old page leaves.
  static Animation<double> _delayed(Animation<double> animation) =>
      CurvedAnimation(
        parent: animation,
        curve: const Interval(_exitEnd, 1),
      );

  Widget _enter(Animation<double> animation, Widget child) {
    switch (nav) {
      // Signal: the page rises a few pixels while it fades in.
      case DesignNav.topTabs:
        return _fadeSlide(animation, child, const Offset(0, 0.015));
      // Porcelaine: a soft fade with the page settling from 98 %.
      case DesignNav.centerDock:
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      // Pastille: tiles pop up from below with a little overshoot.
      case DesignNav.bottomDock:
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.2, 0.9, 0.3, 1.15),
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      // Studio: a quiet cross-fade, like turning a page of a magazine.
      case DesignNav.textSidebar:
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      // Terminal: a hard cut, like a new screen of output.
      case DesignNav.keySidebar:
        return child;
      // Nocturne: the page drifts in from the right as it fades in.
      case DesignNav.iconRail:
        return _fadeSlide(animation, child, const Offset(0.012, 0));
      // OLED: the page lights up from black, nothing moves.
      case DesignNav.textLinks:
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      case DesignNav.glassSidebar:
      case DesignNav.sidebar:
        return _fadeSlide(animation, child, const Offset(0, 0.015));
    }
  }

  static Widget _fadeSlide(
    Animation<double> animation,
    Widget child,
    Offset from,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: from, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Page transitions of a design, the same on every platform.
PageTransitionsTheme designPageTransitions(DesignSpec spec) {
  final builder = DesignPageTransitionsBuilder(spec.nav);
  return PageTransitionsTheme(
    builders: {for (final platform in TargetPlatform.values) platform: builder},
  );
}
