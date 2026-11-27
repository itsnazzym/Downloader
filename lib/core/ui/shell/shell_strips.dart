import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// A row of pill tabs in the active design's shape. Shared by the strips
/// below so every chrome keeps the library filters and settings sub-pages.
class DesignPillTabs extends StatelessWidget {
  const DesignPillTabs({super.key, required this.items});

  final List<DesignPillItem> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _DesignPill(item: item),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class DesignPillItem {
  const DesignPillItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
}

class _DesignPill extends StatefulWidget {
  const _DesignPill({required this.item});

  final DesignPillItem item;

  @override
  State<_DesignPill> createState() => _DesignPillState();
}

class _DesignPillState extends State<_DesignPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final spec = DesignSpec.of(context);
    final item = widget.item;
    final radius = BorderRadius.circular(spec.controlRadius.clamp(0, 999));
    final fg = item.selected
        ? colors.background
        : (_hover ? colors.textPrimary : colors.textSecondary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: item.selected ? colors.textPrimary : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: item.selected
                    ? Colors.transparent
                    : colors.border.withValues(alpha: _hover ? 1 : 0.7),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: AppTypography.label.copyWith(color: fg),
                ),
                if (item.count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${item.count}',
                    style: AppTypography.mono.copyWith(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status and source filters for the library, for chromes without the
/// classic sidebar. Carries the onboarding "library" target.
class LibraryFilterStrip extends ConsumerWidget {
  const LibraryFilterStrip({super.key, this.showSources = true});

  final bool showSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final source = ref.watch(downloadSourceFilterProvider);
    final adult = ref.watch(
      settingsProvider.select((s) => s.adultSitesEnabled),
    );

    void setStatus(DownloadStatusFilter value) {
      ref.read(downloadStatusFilterProvider.notifier).state = value;
      ref.read(downloadSourceFilterProvider.notifier).state = null;
    }

    void setSource(String value) {
      ref.read(downloadSourceFilterProvider.notifier).state = value;
      ref.read(downloadStatusFilterProvider.notifier).state =
          DownloadStatusFilter.all;
    }

    final sources = libraryFilterSources(counts.sourceCounts, adult);
    return KeyedSubtree(
      key: OnboardingTargets.library,
      child: DesignPillTabs(
        items: [
          DesignPillItem(
            label: l10n.allDownloads,
            count: counts.total,
            selected: status == DownloadStatusFilter.all && source == null,
            onTap: () => setStatus(DownloadStatusFilter.all),
          ),
          DesignPillItem(
            label: l10n.sidebarActive,
            count: counts.active,
            selected: status == DownloadStatusFilter.active,
            onTap: () => setStatus(DownloadStatusFilter.active),
          ),
          DesignPillItem(
            label: l10n.sidebarCompleted,
            count: counts.completed,
            selected: status == DownloadStatusFilter.completed,
            onTap: () => setStatus(DownloadStatusFilter.completed),
          ),
          DesignPillItem(
            label: l10n.sidebarFailed,
            count: counts.failed,
            selected: status == DownloadStatusFilter.failed,
            onTap: () => setStatus(DownloadStatusFilter.failed),
          ),
          if (showSources)
            for (final s in sources)
              DesignPillItem(
                label: s,
                count: counts.sourceCounts[s],
                selected: source == s,
                onTap: () => setSource(s),
              ),
        ],
      ),
    );
  }
}

/// Sources that have downloads, adult sites hidden unless enabled — the same
/// rule the classic sidebar applies.
List<String> libraryFilterSources(Map<String, int> counts, bool adultEnabled) {
  const adult = {
    'Pornhub',
    'Xvideos',
    'Xhamster',
    'Youporn',
    'Xnxx',
    'Chaturbate',
    'Onlyfans',
  };
  return [
    for (final entry in counts.entries)
      if (entry.value > 0 &&
          entry.key != 'Other' &&
          (adultEnabled || !adult.contains(entry.key)))
        entry.key,
  ];
}

/// The settings sub-pages, for chromes without the classic sidebar.
class SettingsSectionStrip extends StatelessWidget {
  const SettingsSectionStrip({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = [
      ('/settings/general', l10n.settingsGeneral),
      ('/settings/output', l10n.settingsOutput),
      ('/settings/appearance', l10n.settingsAppearance),
      ('/settings/performance', l10n.settingsPerformance),
      ('/settings/advanced', l10n.settingsAdvanced),
      ('/settings/system', l10n.settingsSystem),
      ('/settings/plugins', l10n.settingsPlugins),
      ('/settings/smart_organizer', l10n.smartOrganization),
    ];
    return DesignPillTabs(
      items: [
        for (final (path, label) in sections)
          DesignPillItem(
            label: label,
            selected:
                location == path ||
                (path == '/settings/general' && location == '/settings'),
            onTap: () => context.go(path),
          ),
      ],
    );
  }
}

/// The strip a chrome shows above the page, if any.
Widget? shellStripFor(String location) {
  if (location == '/') return const LibraryFilterStrip();
  if (location.startsWith('/settings')) {
    return SettingsSectionStrip(location: location);
  }
  return null;
}
