import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

class FloatingNavDock extends StatelessWidget {
  final String currentLocation;
  const FloatingNavDock({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final reduce = MediaQuery.of(context).disableAnimations;

    final dock = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: AppRadius.fullBorder,
            border: Border.all(color: colors.glassBorder),
            boxShadow: colors.tintedShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DockItem(
                  icon: Icons.download_rounded,
                  label: l10n.mainPage,
                  selected: currentLocation == '/',
                  onTap: () => context.go('/'),
                ),
                const SizedBox(width: 6),
                _DockItem(
                  icon: Icons.add_rounded,
                  label: l10n.newDownload,
                  selected: false,
                  emphasized: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddDownloadDialog(),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _DockItem(
                  icon: Icons.bar_chart_rounded,
                  label: l10n.statistics,
                  selected: currentLocation == '/stats',
                  onTap: () => context.go('/stats'),
                ),
                const SizedBox(width: 6),
                _DockItem(
                  icon: Icons.settings_rounded,
                  label: l10n.settings,
                  selected: currentLocation.startsWith('/settings'),
                  onTap: () => context.go('/settings/general'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reduce) return dock;
    return dock.animate().fadeIn(duration: 280.ms).slideY(begin: 0.16, end: 0);
  }
}

class _DockItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    final bg = widget.emphasized
        ? colors.primary
        : (widget.selected
              ? colors.primary.withValues(alpha: 0.22)
              : (_hovering
                    ? colors.surfaceHighlight.withValues(alpha: 0.6)
                    : Colors.transparent));
    final iconColor = widget.emphasized
        ? colors.onPrimary
        : (widget.selected ? colors.primary : colors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: reduce ? 1 : (_pressed ? 0.96 : (_hovering ? 1.06 : 1)),
          duration: const Duration(milliseconds: 140),
          child: Tooltip(
            message: widget.label,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
