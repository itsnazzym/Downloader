import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';

/// Porcelaine: a floating capsule dock centred above the content (mark, one
/// pill per destination, the accent "new download"), then the strip and page.
class PorcelaineChrome extends ConsumerWidget {
  const PorcelaineChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const double _maxWidth = 1220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = desktopDestinations(context, ref, location);
    final strip = shellStripFor(location);
    return Column(
      children: [
        // Padding inside the scroll view so the dock's shadow is not clipped;
        // narrow windows scroll the dock instead of overflowing.
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 14),
                child: Center(
                  child: _Dock(
                    children: [
                      const _PorcelaineMark(),
                      for (final d in destinations) _DockPill(destination: d),
                      const SizedBox(width: 4),
                      KeyedSubtree(
                        key: OnboardingTargets.newDownload,
                        child: _AccentButton(
                          label: context.l10n.newDownload,
                          onTap: () => openNewDownload(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (strip != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Align(alignment: Alignment.centerLeft, child: strip),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

/// The opaque white capsule (the mockup's frosted glass, without the blur).
class _Dock extends StatelessWidget {
  const _Dock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.16),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: children,
        ),
      ),
    );
  }
}

class _PorcelaineMark extends StatelessWidget {
  const _PorcelaineMark();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colors.textPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.download_rounded,
              size: 15,
              color: colors.background,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'tapload',
            style: AppTypography.label.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared hover / press / keyboard-focus state for the dock's buttons. The
/// fill sits outside the InkWell so it never hides the ink, and focus draws a
/// 2 px accent ring that reads on both the dark and the ghost pills.
mixin _DockButtonState<T extends StatefulWidget> on State<T> {
  bool hover = false;
  bool down = false;
  bool focused = false;

  Duration get quick => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);

  Widget interactive({
    required Color fill,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(999);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: down ? 0.97 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: quick,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(
              width: 2,
              color: focused ? colors.primary : Colors.transparent,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onTapDown: (_) => setState(() => down = true),
              onTapCancel: () => setState(() => down = false),
              onTapUp: (_) => setState(() => down = false),
              onFocusChange: (v) => setState(() => focused = v),
              borderRadius: radius,
              child: SizedBox(
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(widthFactor: 1, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination: filled in text colour when selected, ghost otherwise.
class _DockPill extends StatefulWidget {
  const _DockPill({required this.destination});

  final DesktopDestination destination;

  @override
  State<_DockPill> createState() => _DockPillState();
}

class _DockPillState extends State<_DockPill> with _DockButtonState {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final d = widget.destination;
    final fill = d.selected
        ? colors.textPrimary
        : (hover
              ? colors.surfaceHighlight
              : colors.surface.withValues(alpha: 0));
    return Semantics(
      button: true,
      selected: d.selected,
      child: interactive(
        fill: fill,
        onTap: d.onTap,
        child: AnimatedDefaultTextStyle(
          duration: quick,
          style: AppTypography.label.copyWith(
            color: d.selected ? colors.background : colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          child: Text(d.label, maxLines: 1),
        ),
      ),
    );
  }
}

class _AccentButton extends StatefulWidget {
  const _AccentButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_AccentButton> createState() => _AccentButtonState();
}

class _AccentButtonState extends State<_AccentButton> with _DockButtonState {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      // Static glow: only the fill reacts to hover.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: interactive(
        fill: hover ? colors.primaryVariant : colors.primary,
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: colors.onPrimary),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: AppTypography.label.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
