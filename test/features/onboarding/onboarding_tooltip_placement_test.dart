import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_tooltip_placement.dart';

void main() {
  const viewport = Size(1280, 800);
  const card = Size(320, 220);

  test('prefers the right of a left-side hole and never overlaps', () {
    const hole = Rect.fromLTWH(40, 120, 180, 64);
    final origin = placeOnboardingTooltip(
      hole: hole,
      viewport: viewport,
      cardSize: card,
    );
    final cardRect = origin & card;
    expect(cardRect.overlaps(hole.inflate(8)), isFalse);
    expect(origin.dx, greaterThan(hole.right));
    expect(cardRect.right, lessThanOrEqualTo(viewport.width));
    expect(cardRect.bottom, lessThanOrEqualTo(viewport.height));
  });

  test('falls below when the hole occupies the left column', () {
    const hole = Rect.fromLTWH(20, 40, 1200, 520);
    final origin = placeOnboardingTooltip(
      hole: hole,
      viewport: viewport,
      cardSize: card,
    );
    final cardRect = origin & card;
    expect(cardRect.overlaps(hole.inflate(8)), isFalse);
    expect(cardRect.top, greaterThanOrEqualTo(hole.bottom - 0.5));
  });

  test('stays inside a compact viewport without covering the hole', () {
    const compact = Size(900, 640);
    const hole = Rect.fromLTWH(500, 80, 360, 80);
    final origin = placeOnboardingTooltip(
      hole: hole,
      viewport: compact,
      cardSize: card,
    );
    final cardRect = origin & card;
    expect(cardRect.overlaps(hole.inflate(8)), isFalse);
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(compact.width));
    expect(cardRect.bottom, lessThanOrEqualTo(compact.height));
  });

  test('stays inside a short content viewport below the title bar', () {
    const content = Size(1280, 400);
    const compactCard = Size(300, 180);
    const hole = Rect.fromLTWH(40, 12, 180, 48);
    final origin = placeOnboardingTooltip(
      hole: hole,
      viewport: content,
      cardSize: compactCard,
    );
    final cardRect = origin & compactCard;
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.bottom, lessThanOrEqualTo(content.height));
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(content.width));
    expect(cardRect.overlaps(hole.inflate(8)), isFalse);
  });

  test('clamps a hole that crosses the title bar and window edge', () {
    const overlay = Size(1000, 688);
    const overflowing = Rect.fromLTWH(-12, -20, 240, 80);
    final clamped = clampOnboardingHole(overflowing, overlay);
    expect(clamped, isNotNull);
    expect(clamped!.left, greaterThanOrEqualTo(OnboardingPlacement.holeInset));
    expect(clamped.top, greaterThanOrEqualTo(OnboardingPlacement.holeInset));
    expect(
      clamped.right,
      lessThanOrEqualTo(overlay.width - OnboardingPlacement.holeInset),
    );
    expect(
      clamped.bottom,
      lessThanOrEqualTo(overlay.height - OnboardingPlacement.holeInset),
    );
  });

  test('drops a hole that collapses after clamping', () {
    const overlay = Size(400, 300);
    const sliver = Rect.fromLTWH(398, 10, 40, 20);
    expect(clampOnboardingHole(sliver, overlay), isNull);
  });
}
