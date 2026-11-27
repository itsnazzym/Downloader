import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/features/designs/pastille/pastille_kit.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';

/// Pastille's pages draw their own header ("tapload · …", big title,
/// actions); the chrome only floats the dock of coloured dots at the bottom
/// centre, over the page. Routes Pastille does not draw (the X browser) keep
/// a compact header with the new-download button.
class PastilleChrome extends ConsumerWidget {
  const PastilleChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static bool _drawn(String location) =>
      location == '/' ||
      location == '/archive' ||
      location == '/stats' ||
      location == '/transfer' ||
      location.startsWith('/settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = PTones.of(context);
    final drawn = _drawn(location);
    final libraryView =
        GoRouterState.of(context).uri.queryParameters['view'] == 'library';
    final destinations = desktopDestinations(context, ref, location);
    return Stack(
      children: [
        if (drawn)
          Positioned.fill(child: child)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
                child: Row(
                  children: [
                    const _Mark(),
                    const Spacer(),
                    KeyedSubtree(
                      key: OnboardingTargets.newDownload,
                      child: PButton(
                        label: context.l10n.newDownload,
                        icon: Icons.download_rounded,
                        kind: PButtonKind.butter,
                        height: 42,
                        onTap: () => openNewDownload(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (shellStripFor(location) case final strip?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
                  child: Align(alignment: Alignment.centerLeft, child: strip),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 92),
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
            child: _Dock(
              items: _dockItems(context, destinations, tones, libraryView),
            ),
          ),
        ),
      ],
    );
  }

  /// The mockup's six stops: Accueil, Bibliothèque, Archives, Statistiques,
  /// Transfert, Réglages. Home and library share the `/` route; the library
  /// is `/?view=library`.
  List<_DockItem> _dockItems(
    BuildContext context,
    List<DesktopDestination> destinations,
    PTones tones,
    bool libraryView,
  ) {
    final l10n = context.l10n;
    final items = <_DockItem>[];
    for (final d in destinations) {
      switch (d.id) {
        case 'library':
          items
            ..add(
              _DockItem(
                label: l10n.mainPage,
                dot: tones.butter,
                selected: d.selected && !libraryView,
                onTap: () => context.go('/'),
              ),
            )
            ..add(
              _DockItem(
                label: l10n.librarySection,
                dot: tones.sky,
                selected: d.selected && libraryView,
                onTap: () => context.go('/?view=library'),
              ),
            );
        default:
          items.add(
            _DockItem(
              label: d.label,
              dot: switch (d.id) {
                'archive' => tones.rose,
                'stats' => tones.sage,
                'transfer' => tones.lav,
                _ => pMuted,
              },
              selected: d.selected,
              onTap: d.onTap,
            ),
          );
      }
    }
    return items;
  }
}

class _DockItem {
  const _DockItem({
    required this.label,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dot;
  final bool selected;
  final VoidCallback onTap;
}

/// Four small tone dots and the brand, for routes without a Pastille page.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tones = PTones.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in [tones.lav, tones.sage, tones.rose, tones.butter])
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

/// `.dock`: the floating ink capsule, one button per stop.
class _Dock extends StatelessWidget {
  const _Dock({required this.items});

  final List<_DockItem> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: pInkDeep.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: pCream.withValues(alpha: 0.1), spreadRadius: 1),
            const BoxShadow(
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
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _DockButton(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  const _DockButton({required this.item});

  final _DockItem item;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.item;
    final tones = PTones.of(context);
    final open = d.selected || _hover || _focus;
    final fg = d.selected ? pInk : (_hover ? pCream : pMuted);
    final bg = d.selected
        ? tones.cream
        : (_hover ? pCream.withValues(alpha: 0.07) : Colors.transparent);
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
          duration: pMotion(context, 200),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: _focus ? Border.all(color: tones.butter, width: 3) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: d.onTap,
              onFocusChange: (f) => setState(() => _focus = f),
              borderRadius: BorderRadius.circular(999),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Container(
                height: _focus ? 38 : 44,
                padding: EdgeInsets.symmetric(horizontal: _focus ? 11 : 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: d.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClipRect(
                      child: AnimatedAlign(
                        alignment: Alignment.centerLeft,
                        widthFactor: open ? 1 : 0,
                        duration: pMotion(context, 300),
                        curve: pEase,
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Text(
                            d.label,
                            maxLines: 1,
                            softWrap: false,
                            style: pBody(
                              size: 13,
                              weight: FontWeight.w600,
                              color: fg,
                              height: 1.2,
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
