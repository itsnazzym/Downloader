import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';

/// Text on pastel tiles is always this dark ink (Pastille's contrast rule).
const _ink = Color(0xFF1A1714);

/// The dock capsule, a shade darker than the espresso background.
const _dockInk = Color(0xFF0F0E0D);

/// Room kept under the page so its last row never hides behind the dock.
const double _dockClearance = 92;

/// Pastille: a compact header, the page, and a floating dock of coloured dots
/// pinned at the bottom centre whose labels open on hover or selection.
class PastilleChrome extends ConsumerWidget {
  const PastilleChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final spec = DesignSpec.of(context);
    // Another design's spec has no tiles; fall back to its own accents.
    final tiles = spec.tiles.length >= 6
        ? spec.tiles
        : [
            colors.primary,
            colors.accent,
            colors.info,
            colors.success,
            colors.warning,
            colors.textPrimary,
          ];
    final destinations = desktopDestinations(context, ref, location);
    final strip = shellStripFor(location);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
              child: Row(
                children: [
                  _Mark(tiles: tiles),
                  const Spacer(),
                  KeyedSubtree(
                    key: OnboardingTargets.newDownload,
                    child: _ButterButton(
                      label: context.l10n.newDownload,
                      color: tiles[4],
                      onTap: () => openNewDownload(context),
                    ),
                  ),
                ],
              ),
            ),
            if (strip != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
                child: Align(alignment: Alignment.centerLeft, child: strip),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _dockClearance),
                child: child,
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Center(
            child: _Dock(destinations: destinations, tiles: tiles),
          ),
        ),
      ],
    );
  }
}

/// Four small tile-coloured dots and the brand, as in the mockup's header.
class _Mark extends StatelessWidget {
  const _Mark({required this.tiles});

  final List<Color> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in [tiles[0], tiles[1], tiles[2], tiles[4]])
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          'tapload',
          style: AppTypography.display(
            18,
          ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// The primary action: a solid butter pill with ink text that lifts on hover.
class _ButterButton extends StatefulWidget {
  const _ButterButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ButterButton> createState() => _ButterButtonState();
}

class _ButterButtonState extends State<_ButterButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 160);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedSlide(
          offset: Offset(0, _down ? 0.02 : (_hover ? -0.025 : 0)),
          duration: duration,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: duration,
            child: Material(
              color: widget.color,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(999),
                focusColor: _ink.withValues(alpha: 0.12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, size: 18, color: _ink),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: AppTypography.label.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating ink capsule holding one button per destination.
class _Dock extends StatelessWidget {
  const _Dock({required this.destinations, required this.tiles});

  final List<DesktopDestination> destinations;
  final List<Color> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _dockInk,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              offset: Offset(0, 20),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < destinations.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _DockButton(
                  destination: destinations[i],
                  dot: tiles[i % 5],
                  selectedFill: tiles[5],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  const _DockButton({
    required this.destination,
    required this.dot,
    required this.selectedFill,
  });

  final DesktopDestination destination;
  final Color dot;
  final Color selectedFill;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final d = widget.destination;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final open = d.selected || _hover || _focus;
    final fg = d.selected
        ? _ink
        : (_hover ? colors.textPrimary : colors.textSecondary);
    final bg = d.selected
        ? widget.selectedFill
        : (_hover
              ? colors.textPrimary.withValues(alpha: 0.07)
              : Colors.transparent);
    return Semantics(
      selected: d.selected,
      button: true,
      label: d.label,
      excludeSemantics: true,
      // No tooltip: hovering or focusing already unfolds the label.
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: d.onTap,
              onFocusChange: (f) => setState(() => _focus = f),
              borderRadius: BorderRadius.circular(999),
              focusColor: widget.dot.withValues(alpha: 0.28),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    ClipRect(
                      child: AnimatedAlign(
                        alignment: Alignment.centerLeft,
                        widthFactor: open ? 1 : 0,
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        curve: const Cubic(0.2, 0.8, 0.2, 1),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            d.label,
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.label.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
