import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_theme.dart';
import 'package:modern_downloader/features/designs/nocturne/nocturne_widgets.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';

/// Nocturne (mockups Nocturne*.dc.html): a slim icon rail on the left (new
/// download on top, settings at the bottom), then the page under a faint
/// static glow.
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
    final l10n = context.l10n;
    final destinations = desktopDestinations(context, ref, location);
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    final reduce = MediaQuery.disableAnimationsOf(context);
    // The mockup rail has "En cours" under the library: the home with the
    // active filter (the page scrolls to its library when it changes).
    final activeOnly =
        ref.watch(downloadStatusFilterProvider) == DownloadStatusFilter.active;
    void setActive(bool active) {
      ref.read(downloadSourceFilterProvider.notifier).state = null;
      ref.read(downloadStatusFilterProvider.notifier).state = active
          ? DownloadStatusFilter.active
          : DownloadStatusFilter.all;
      context.go('/');
    }

    final pages = <DesktopDestination>[
      for (final d in destinations)
        if (d.id == 'library') ...[
          DesktopDestination(
            id: d.id,
            label: d.label,
            icon: d.icon,
            selected: d.selected && !activeOnly,
            onTap: activeOnly ? () => setActive(false) : d.onTap,
          ),
          DesktopDestination(
            id: 'active',
            label: l10n.designInProgress,
            icon: Icons.file_download_outlined,
            selected: d.selected && activeOnly,
            onTap: () => setActive(true),
          ),
        ] else if (d.id == 'archive')
          DesktopDestination(
            id: d.id,
            label: d.label,
            icon: d.icon,
            selected: d.selected,
            onTap: () {
              final archive = ref.read(tikTokArchiveProvider.notifier);
              if (!ref.read(tikTokArchiveProvider).hasCatalog) {
                d.onTap();
                return;
              }
              archive.setViewMode(TikTokViewMode.collections);
              context.go('/archive');
            },
          )
        else if (d.id != 'settings')
          d,
    ];
    final frame = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: colors.inputBackground,
            border: Border(
              right: BorderSide(color: colors.primary.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            children: [
              KeyedSubtree(
                key: OnboardingTargets.newDownload,
                child: _NewDownloadButton(
                  tooltip: l10n.newDownload,
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
                                colors.primary.withValues(alpha: 0.22),
                                colors.primary.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // The pages draw their own filters and settings sections.
                child,
              ],
            ),
          ),
        ),
      ],
    );
    // The shared dialogs, menus and fields opened from the rail or the pages
    // take Nocturne's look.
    return NocturneTheme(child: frame);
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
                color: colors.primary.withValues(alpha: _hover ? 0.45 : 0.35),
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
                child: Center(
                  child: NocturneIcon(
                    NocturneGlyph.add,
                    size: 18,
                    stroke: 2.6,
                    color: colors.background,
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

const _glyphs = {
  'library': NocturneGlyph.inbox,
  'active': NocturneGlyph.download,
  'archive': NocturneGlyph.archive,
  'stats': NocturneGlyph.stats,
  'transfer': NocturneGlyph.transfer,
  'settings': NocturneGlyph.settings,
};

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
                child: Center(
                  child: switch (_glyphs[d.id]) {
                    final glyph? => NocturneIcon(glyph, color: iconColor),
                    null => Icon(d.icon, size: 20, color: iconColor),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
