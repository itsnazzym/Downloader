import 'package:flutter/widgets.dart';

/// Positions the coach card so it never covers the spotlight hole.
Offset placeOnboardingTooltip({
  required Rect hole,
  required Size viewport,
  required Size cardSize,
  double gap = OnboardingPlacement.gap,
  double margin = OnboardingPlacement.margin,
  double bottomReserved = 0,
}) {
  final safeHeight = (viewport.height - bottomReserved).clamp(0.0, viewport.height);

  bool inViewport(Rect card) {
    return card.left >= 0 &&
        card.top >= 0 &&
        card.right <= viewport.width + 0.5 &&
        card.bottom <= safeHeight + 0.5;
  }

  bool isValid(Offset origin) {
    final card = origin & cardSize;
    return inViewport(card) && !card.overlaps(hole.inflate(8));
  }

  Offset clampOrigin(Offset raw) {
    final maxX = viewport.width - cardSize.width;
    final maxY = safeHeight - cardSize.height;
    return Offset(
      raw.dx.clamp(0, maxX < 0 ? 0 : maxX),
      raw.dy.clamp(0, maxY < 0 ? 0 : maxY),
    );
  }

  final candidates = <Offset>[
    Offset(hole.right + gap, hole.top),
    Offset(hole.right + gap, hole.center.dy - cardSize.height / 2),
    Offset(hole.left - gap - cardSize.width, hole.top),
    Offset(hole.left, hole.bottom + gap),
    Offset(hole.center.dx - cardSize.width / 2, hole.bottom + gap),
    Offset(margin, hole.bottom + gap),
    Offset(viewport.width - cardSize.width - margin, hole.bottom + gap),
    Offset(hole.left, hole.top - gap - cardSize.height),
    Offset(margin, hole.top - gap - cardSize.height),
    Offset(margin, safeHeight - cardSize.height - margin),
    Offset(viewport.width - cardSize.width - margin, margin),
    Offset(margin, margin),
  ];

  for (final candidate in candidates) {
    if (isValid(candidate)) return candidate;
    final clamped = clampOrigin(candidate);
    if (isValid(clamped)) return clamped;
  }

  final below = Offset(margin, hole.bottom + gap);
  if (isValid(below)) return below;
  final above = Offset(margin, hole.top - gap - cardSize.height);
  if (isValid(above)) return above;

  return clampOrigin(Offset(margin, hole.bottom + gap));
}

class OnboardingPlacement {
  static const double gap = 16;
  static const double margin = 16;
  static const double bottomReserved = 80;
  static const double holeInset = 2;
}

/// Keeps the spotlight hole inside the content viewport so the rim
/// never crosses the title bar or window edge.
Rect? clampOnboardingHole(
  Rect hole,
  Size viewport, {
  double inset = OnboardingPlacement.holeInset,
}) {
  if (hole.isEmpty ||
      viewport.width <= inset * 2 ||
      viewport.height <= inset * 2) {
    return null;
  }
  final bounds = Rect.fromLTWH(
    inset,
    inset,
    viewport.width - inset * 2,
    viewport.height - inset * 2,
  );
  final left = hole.left.clamp(bounds.left, bounds.right);
  final top = hole.top.clamp(bounds.top, bounds.bottom);
  final right = hole.right.clamp(bounds.left, bounds.right);
  final bottom = hole.bottom.clamp(bounds.top, bounds.bottom);
  if (right - left < 8 || bottom - top < 8) return null;
  return Rect.fromLTRB(left, top, right, bottom);
}

class OnboardingTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  OnboardingTooltipLayoutDelegate({
    required this.hole,
    this.gap = OnboardingPlacement.gap,
    this.margin = OnboardingPlacement.margin,
    this.bottomReserved = OnboardingPlacement.bottomReserved,
  });

  final Rect? hole;
  final double gap;
  final double margin;
  final double bottomReserved;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = (constraints.maxWidth - margin * 2).clamp(
      0.0,
      constraints.maxWidth,
    );
    final maxH = (constraints.maxHeight - margin * 2).clamp(
      0.0,
      constraints.maxHeight,
    );
    return BoxConstraints(maxWidth: maxW, maxHeight: maxH);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (hole == null || hole!.isEmpty) {
      final safeH = (size.height - bottomReserved).clamp(0.0, size.height);
      final dx = ((size.width - childSize.width) / 2).clamp(
        0.0,
        (size.width - childSize.width).clamp(0.0, size.width),
      );
      final dy = ((safeH - childSize.height) / 2).clamp(
        0.0,
        (safeH - childSize.height).clamp(0.0, safeH),
      );
      return Offset(dx, dy);
    }
    return placeOnboardingTooltip(
      hole: hole!,
      viewport: size,
      cardSize: childSize,
      gap: gap,
      margin: margin,
      bottomReserved: bottomReserved,
    );
  }

  @override
  bool shouldRelayout(covariant OnboardingTooltipLayoutDelegate oldDelegate) {
    return hole != oldDelegate.hole ||
        gap != oldDelegate.gap ||
        margin != oldDelegate.margin ||
        bottomReserved != oldDelegate.bottomReserved;
  }
}
