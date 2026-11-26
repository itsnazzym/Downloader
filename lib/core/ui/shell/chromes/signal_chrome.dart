import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';

/// Signal: a top bar with a pill that slides under the active tab, then the
/// page on the full width (no sidebar). Settings draw their own section rail.
class SignalChrome extends ConsumerWidget {
  const SignalChrome({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final destinations = desktopDestinations(context, ref, location);
    final l10n = context.l10n;
    // Mockup labels: "Accueil" and "Archives" (short, the home holds the
    // library and the add-link field).
    final tabs = [
      for (final d in destinations)
        if (d.id != 'settings')
          DesktopDestination(
            id: d.id,
            label: d.id == 'library'
                ? l10n.mainPage
                : d.id == 'archive'
                ? l10n.designArchivesTab
                : d.label,
            icon: d.icon,
            selected: d.selected,
            onTap: d.id == 'archive' ? () => _openArchive(ref, d) : d.onTap,
          ),
    ];
    final settings = destinations.firstWhere((d) => d.id == 'settings');
    return Column(
      children: [
        Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              const _SignalMark(),
              const SizedBox(width: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SlidingTabs(tabs: tabs),
                ),
              ),
              const SizedBox(width: 16),
              const _SpeedPill(),
              const SizedBox(width: 12),
              _RoundIconButton(
                icon: Icons.settings_outlined,
                tooltip: settings.label,
                selected: settings.selected,
                onTap: settings.onTap,
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Signal's Archives page is the collections overview of its mockup; the
/// import hub stays one click away (« Synchroniser »), or shows when there
/// is nothing imported yet.
void _openArchive(WidgetRef ref, DesktopDestination d) {
  d.onTap();
  if (ref.read(tikTokArchiveProvider).hasCatalog) {
    ref
        .read(tikTokArchiveProvider.notifier)
        .setViewMode(TikTokViewMode.collections);
  }
}

class _SignalMark extends StatelessWidget {
  const _SignalMark();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.18),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(Icons.south_rounded, size: 18, color: colors.onPrimary),
        ),
        const SizedBox(width: 10),
        Text(
          'tapload',
          style: AppTypography.display(20).copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// Fixed-width tabs over a sunken track; one accent pill slides between them.
class _SlidingTabs extends StatelessWidget {
  const _SlidingTabs({required this.tabs});

  final List<DesktopDestination> tabs;

  static const double _tabWidth = 116;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final index = tabs.indexWhere((t) => t.selected);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Stack(
          children: [
            if (index >= 0)
              AnimatedPositioned(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 380),
                curve: const Cubic(0.3, 1.25, 0.4, 1),
                left: index * _tabWidth,
                top: 0,
                bottom: 0,
                width: _tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.16),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tab in tabs) _Tab(tab: tab, width: _tabWidth),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({required this.tab, required this.width});

  final DesktopDestination tab;
  final double width;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tab = widget.tab;
    final color = tab.selected
        ? colors.onPrimary
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return Semantics(
      selected: tab.selected,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: tab.onTap,
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: widget.width,
              height: 34,
              child: Center(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Total live speed with a pulsing dot while anything downloads.
class _SpeedPill extends ConsumerWidget {
  const _SpeedPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    // Progress ticks only reach the per-download runtime item.
    final active = liveActiveItems(
      items,
      (id) => ref.watch(downloadRuntimeItemProvider(id)),
    );
    if (active.isEmpty) return const SizedBox.shrink();
    final speed = formatSpeed(context.l10n, aggregateSpeed(active));
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulsingDot(),
          const SizedBox(width: 10),
          Text(
            '${speed.value} ${speed.unit}'.trim(),
            style: AppTypography.mono.copyWith(
              fontSize: 12.5,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dot in the accent colour with a ring that breathes out; still when
/// effects are reduced.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, this.size = 7});

  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).primary;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45 * (1 - t)),
                  spreadRadius: 7 * t,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? colors.surfaceHighlight : Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: selected ? colors.primary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
