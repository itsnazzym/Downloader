import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/components/app_skeleton.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'sidebar_nav_items.dart';

class SidebarSourcesSection extends StatelessWidget {
  final List<String> availableSources;
  final Map<String, int> sourceCounts;
  final String? activeSourceFilter;
  final bool listLoading;
  final ValueChanged<String> onSelectSource;
  final String Function(String source) sourceLabel;

  const SidebarSourcesSection({
    super.key,
    required this.availableSources,
    required this.sourceCounts,
    required this.activeSourceFilter,
    required this.listLoading,
    required this.onSelectSource,
    required this.sourceLabel,
  });

  static IconData iconForSource(String source) {
    switch (source) {
      case 'YouTube':
        return Icons.video_library_outlined;
      case 'Instagram':
        return Icons.photo_camera_outlined;
      case 'Twitter':
        return Icons.alternate_email;
      case 'Twitch':
        return Icons.videogame_asset_outlined;
      case 'Kick':
        return Icons.bolt;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SidebarNavSection(
      title: l10n.sourcesSection,
      children: listLoading
          ? List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 12, right: 12),
                child: AppSkeleton(
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
            )
          : availableSources.map((source) {
              return SidebarNavItem(
                icon: iconForSource(source),
                label: sourceLabel(source),
                count: sourceCounts[source] ?? 0,
                isSelected: activeSourceFilter == source,
                onTap: () => onSelectSource(source),
              );
            }).toList(),
    );
  }
}
