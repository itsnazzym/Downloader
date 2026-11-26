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
import '../shell_strips.dart' show libraryFilterSources;

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
    // The mockup's order: Statistiques, Transfert, Archives TikTok.
    const order = ['stats', 'transfer', 'archive'];
    final pages =
        destinations
            .where((d) => d.id != 'library' && d.id != 'settings')
            .toList()
          ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
    final onLibrary = location == '/';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 220,
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
          decoration: BoxDecoration(
            border: BorderDirectional(end: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Wordmark(),
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
        // Settings draws its own section tabs under its title.
        Expanded(child: child),
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      child: Row(
        children: [
          Icon(Icons.download_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'TapLoad',
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
      margin: const EdgeInsets.fromLTRB(10, 14, 10, 16),
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
          (DownloadStatusFilter.all, l10n.sidebarAll, total),
          (DownloadStatusFilter.active, l10n.designInProgress, active),
          (DownloadStatusFilter.completed, l10n.sidebarCompleted, completed),
          (DownloadStatusFilter.failed, l10n.libraryHeaderFailed, failed),
        ])
          _StudioRow(
            label: label,
            trailing: _Count(
              count,
              color: filter == DownloadStatusFilter.failed && count > 0
                  ? colors.error
                  : null,
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
    // 6px: the mockup's row corners.
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
        // 30px rows as drawn, 2px apart; shortcut: below the 36px target rule.
        height: 30,
        margin: const EdgeInsets.only(bottom: 2),
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

