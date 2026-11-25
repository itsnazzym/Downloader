import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';

/// Nocturne: a slim icon rail on the left (new download on top, settings at
/// the bottom), then the page under a faint static glow.
class NocturneChrome extends ConsumerWidget {
  const NocturneChrome({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final destinations = desktopDestinations(context, ref, location);
    final pages = destinations.where((d) => d.id != 'settings').toList();
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    final strip = shellStripFor(location);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Color.lerp(colors.background, Colors.black, 0.22),
            border: Border(right: BorderSide(color: colors.borderSubtle)),
          ),
          child: Column(
            children: [
              KeyedSubtree(
                key: OnboardingTargets.newDownload,
                child: _NewDownloadButton(
                  tooltip: context.l10n.newDownload,
                  onTap: () => openNewDownload(context),
                ),
              ),
              const SizedBox(height: 22),
              // Scrolls only if the window gets very short.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final page in pages) ...[
                        _RailButton(destination: page),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              _RailButton(destination: settings),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!reduce)
                  Positioned(
                    left: -120,
                    top: -260,
                    width: 520,
                    height: 520,
                    child: IgnorePointer(
                      // Static: painted once, isolated from page repaints.
                      child: RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.12),
                                colors.primary.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (strip != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: strip,
                        ),
                      ),
                    Expanded(child: child),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The primary square at the top of the rail that opens the add dialog.
class _NewDownloadButton extends StatefulWidget {
  const _NewDownloadButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_NewDownloadButton> createState() => _NewDownloadButtonState();
}

class _NewDownloadButtonState extends State<_NewDownloadButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _focus ? colors.textPrimary : Colors.transparent,
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: _hover ? 0.42 : 0.3),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: colors.primary,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (v) => setState(() => _hover = v),
              onFocusChange: (v) => setState(() => _focus = v),
              borderRadius: radius,
              mouseCursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.download_rounded,
                  size: 20,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One 44px rounded icon button for a destination; lifts 1px on hover.
class _RailButton extends StatefulWidget {
  const _RailButton({required this.destination});

  final DesktopDestination destination;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final d = widget.destination;
    final radius = BorderRadius.circular(14);
    final iconColor = d.selected
        ? colors.primary
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return Tooltip(
      message: d.label,
      preferBelow: false,
      child: Semantics(
        button: true,
        selected: d.selected,
        label: d.label,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          decoration: BoxDecoration(
            color: d.selected
                ? colors.surfaceHighlight
                : (_hover
                      ? colors.primary.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: radius,
            border: Border.all(
              color: _focus ? colors.primary : Colors.transparent,
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: d.selected
                ? const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: d.onTap,
              onHover: (v) => setState(() => _hover = v),
              onFocusChange: (v) => setState(() => _focus = v),
              borderRadius: radius,
              mouseCursor: SystemMouseCursors.click,
              hoverColor: Colors.transparent,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(d.icon, size: 20, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
