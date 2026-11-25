import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';
import '../shell_strips.dart';

/// Studio: ink on paper. A text-only left sidebar (library filters, pages,
/// sources, settings) separated by hairlines; the page fills the rest. The
/// only colour is the recording red for what is live.
class StudioChrome extends ConsumerWidget {
  const StudioChrome({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final destinations = desktopDestinations(context, ref, location);
    final library = destinations.firstWhere((d) => d.id == 'library');
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    final pages = destinations
        .where((d) => d.id != 'library' && d.id != 'settings')
        .toList();
    final onLibrary = location == '/';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 248,
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Wordmark(),
              KeyedSubtree(
                key: OnboardingTargets.newDownload,
                child: _InkButton(
                  label: context.l10n.newDownload,
                  onTap: () => openNewDownload(context),
                ),
              ),
              const SizedBox(height: 18),
              // The flexible gap: sections scroll when sources overflow,
              // settings stays pinned at the bottom.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: OnboardingTargets.library,
                        child: _StatusFilters(
                          onLibrary: onLibrary,
                          goLibrary: library.onTap,
                        ),
                      ),
                      if (pages.isNotEmpty) ...[
                        const _Hairline(),
                        for (final page in pages)
                          _StudioRow(
                            label: page.label,
                            selected: page.selected,
                            onTap: page.onTap,
                          ),
                      ],
                      _SourceRows(
                        onLibrary: onLibrary,
                        goLibrary: library.onTap,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _StudioRow(
                label: settings.label,
                selected: settings.selected,
                onTap: settings.onTap,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (location.startsWith('/settings'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SettingsSectionStrip(location: location),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
      child: Row(
        children: [
          Icon(Icons.download_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'tapload',
            style: AppTypography.display(
              15,
              weight: FontWeight.w600,
            ).copyWith(color: color, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      color: AppColors.of(context).border,
    );
  }
}

/// Tous / En cours / Terminés / Échecs with their counts. Each count is
/// watched as an int so download progress never rebuilds the sidebar.
class _StatusFilters extends ConsumerWidget {
  const _StatusFilters({required this.onLibrary, required this.goLibrary});

  final bool onLibrary;
  final VoidCallback goLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    // A record compares by value, so this only fires when a count changes.
    final (total, active, completed, failed) = ref.watch(
      downloadLibraryCountsProvider.select(
        (c) => (c.total, c.active, c.completed, c.failed),
      ),
    );
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);

    void select(DownloadStatusFilter value) {
      ref.read(downloadStatusFilterProvider.notifier).state = value;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
      if (!onLibrary) goLibrary();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (filter, label, count) in [
          (DownloadStatusFilter.all, l10n.allDownloads, total),
          (DownloadStatusFilter.active, l10n.sidebarActive, active),
          (DownloadStatusFilter.completed, l10n.sidebarCompleted, completed),
          (DownloadStatusFilter.failed, l10n.sidebarFailed, failed),
        ])
          _StudioRow(
            label: label,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (filter == DownloadStatusFilter.active && count > 0) ...[
                  const _RecDot(),
                  const SizedBox(width: 6),
                ],
                _Count(
                  count,
                  color: filter == DownloadStatusFilter.failed && count > 0
                      ? colors.error
                      : null,
                ),
              ],
            ),
            selected: onLibrary && source == null && status == filter,
            onTap: () => select(filter),
          ),
      ],
    );
  }
}

/// One row per source that has downloads, after a hairline; nothing if none.
class _SourceRows extends ConsumerWidget {
  const _SourceRows({required this.onLibrary, required this.goLibrary});

  final bool onLibrary;
  final VoidCallback goLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The counts provider only emits on status/source changes, so this map
    // is stable across progress ticks.
    final counts = ref.watch(
      downloadLibraryCountsProvider.select((c) => c.sourceCounts),
    );
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );
    final selected = ref.watch(downloadSourceFilterProvider);
    final sources = libraryFilterSources(counts, adult);
    if (sources.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hairline(),
        for (final s in sources)
          _StudioRow(
            label: s,
            trailing: _Count(counts[s] ?? 0),
            selected: onLibrary && selected == s,
            onTap: () {
              ref.read(downloadSourceFilterProvider.notifier).state = s;
              ref.read(downloadStatusFilterProvider.notifier).state =
                  DownloadStatusFilter.all;
              if (!onLibrary) goLibrary();
            },
          ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, {this.color});

  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value',
      style: AppTypography.mono.copyWith(
        fontSize: 11,
        color: color ?? AppColors.of(context).textSecondary,
      ),
    );
  }
}

/// A text row; the selected one is a white card with a hairline border and
/// a faint shadow, hover is a warm tint, focus an ink outline.
class _StudioRow extends StatefulWidget {
  const _StudioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_StudioRow> createState() => _StudioRowState();
}

class _StudioRowState extends State<_StudioRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(
      DesignSpec.of(context).controlRadius.clamp(0, 8) - 2,
    );
    final selected = widget.selected;
    final borderColor = _focus
        ? colors.textPrimary
        : (selected ? colors.border : Colors.transparent);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? colors.surface
              : (_hover ? colors.surfaceHighlight : Colors.transparent),
          borderRadius: radius,
          border: Border.all(color: borderColor),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: radius,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: selected || _hover
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The recording light: a red dot that slowly dims and returns; still when
/// effects are reduced.
class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.25,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.of(context).accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The ink button: near-black, lifts a pixel on hover and sinks on press.
class _InkButton extends StatefulWidget {
  const _InkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<_InkButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(
      DesignSpec.of(context).controlRadius.clamp(0, 8),
    );
    final dy = _down ? 1.0 : (_hover ? -1.0 : 0.0);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(0, dy, 0),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: colors.primary,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          onHighlightChanged: (v) => setState(() => _down = v),
          borderRadius: radius,
          focusColor: colors.onPrimary.withValues(alpha: 0.18),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: colors.onPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
