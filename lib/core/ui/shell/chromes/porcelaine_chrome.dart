import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/designs/porcelaine/porcelaine_states.dart';
import 'package:modern_downloader/features/designs/porcelaine/porcelaine_widgets.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/designs/porcelaine/porcelaine_workspace_model.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';

/// Porcelaine: a floating capsule dock centred above the page (mark, one
/// pill per destination; on the Espace, its « Ajouter un widget » and
/// « Modifier » buttons). Pages draw their own titles and section tabs.
class PorcelaineChrome extends ConsumerWidget {
  const PorcelaineChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final destinations = desktopDestinations(context, ref, location);
    // Same rule as PorcelaineHome: a running search shows the library.
    final espace =
        location == '/' &&
        !ref.watch(porcelaineLibraryOpenProvider) &&
        !ref.watch(downloadSearchQueryProvider.select((q) => q.isNotEmpty));
    final editing =
        espace &&
        ref.watch(porcelaineWorkspaceProvider.select((s) => s.editing));
    final workspace = ref.read(porcelaineWorkspaceProvider.notifier);
    String label(DesktopDestination d) => switch (d.id) {
      'library' => l10n.porcelaineSpace,
      'archive' => l10n.designArchivesTab,
      'settings' => l10n.porcelaineSettingsTab,
      _ => d.label,
    };
    return Column(
      children: [
        // Padding inside the scroll view so the dock's shadow is not clipped;
        // narrow windows scroll the dock instead of overflowing.
        LayoutBuilder(
          builder: (context, box) {
            // Narrow windows: the mark and the Espace buttons keep only
            // their icons, so the whole dock still fits.
            final compact = box.maxWidth < 1000;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 32,
                    28,
                    compact ? 16 : 32,
                    18,
                  ),
                  child: Center(
                    child: _Dock(
                      children: [
                        _PorcelaineMark(compact: compact),
                        for (final d in destinations)
                          _DockPill(
                            label: label(d),
                            selected: d.selected,
                            compact: compact,
                            onTap: () {
                              // « Espace » also closes the full library.
                              if (d.id == 'library') pCloseLibrary(ref);
                              d.onTap();
                            },
                          ),
                        if (espace) ...[
                          const _DockDivider(),
                          if (editing)
                            PBtn(
                              label: l10n.porcelaineReset,
                              kind: PBtnKind.ghost,
                              height: 36,
                              onTap: workspace.reset,
                            ),
                          PBtn(
                            label: compact ? '' : l10n.porcelaineAddWidget,
                            tooltip: compact ? l10n.porcelaineAddWidget : null,
                            icon: Icons.add_rounded,
                            height: 36,
                            padding: compact ? 11 : 16,
                            onTap: () => ref
                                .read(porcelaineCatalogRequestProvider.notifier)
                                .state++,
                          ),
                          Semantics(
                            toggled: editing,
                            child: PBtn(
                              label: compact
                                  ? ''
                                  : (editing
                                        ? l10n.porcelaineDone
                                        : l10n.porcelaineEdit),
                              tooltip: compact
                                  ? (editing
                                        ? l10n.porcelaineDone
                                        : l10n.porcelaineEdit)
                                  : null,
                              icon: compact
                                  ? (editing
                                        ? Icons.check_rounded
                                        : Icons.edit_outlined)
                                  : null,
                              kind: editing ? PBtnKind.accent : PBtnKind.line,
                              height: 36,
                              padding: compact ? 11 : 16,
                              onTap: () => workspace.setEditing(!editing),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// `.dock`: the white capsule (the mockup's frosted glass, without blur).
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
          color: Color.alphaBlend(
            colors.surface.withValues(alpha: 0.72),
            colors.background,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.07),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.25),
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

class _DockDivider extends StatelessWidget {
  const _DockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.of(context).textPrimary.withValues(alpha: 0.1),
    );
  }
}

class _PorcelaineMark extends StatelessWidget {
  const _PorcelaineMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(8, 0, compact ? 6 : 12, 0),
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
          if (!compact) ...[
            const SizedBox(width: 8),
            Text('TapLoad', style: pBody(colors, weight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// One destination (`.btn-ghost`, ink when current) with hover, press and
/// a 2px accent ring on keyboard focus.
class _DockPill extends StatefulWidget {
  const _DockPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_DockPill> createState() => _DockPillState();
}

class _DockPillState extends State<_DockPill> {
  bool _hover = false;
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(999);
    final fill = widget.selected
        ? colors.textPrimary
        : (_hover
              ? colors.textPrimary.withValues(alpha: 0.06)
              : colors.textPrimary.withValues(alpha: 0));
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: pMotion(context, 160),
          child: AnimatedContainer(
            duration: pMotion(context, 180),
            curve: pEase,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(
                width: 2,
                color: _focused ? colors.primary : Colors.transparent,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _down = true),
                onTapCancel: () => setState(() => _down = false),
                onTapUp: (_) => setState(() => _down = false),
                onFocusChange: (v) => setState(() => _focused = v),
                borderRadius: radius,
                splashColor: Colors.transparent,
                child: SizedBox(
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 10 : 14,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: pBody(
                          colors,
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: widget.selected
                              ? colors.background
                              : colors.textPrimary,
                        ).copyWith(height: 1.2),
                      ),
                    ),
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
