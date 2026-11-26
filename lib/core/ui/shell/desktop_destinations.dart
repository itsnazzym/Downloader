import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// One top-level place of the desktop app, shared by every design's chrome so
/// none of them can drop a page (plugin gating lives here, once).
class DesktopDestination {
  const DesktopDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.shortcut,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Key hint shown by keyboard-first designs (Terminal).
  final String? shortcut;
}

List<DesktopDestination> desktopDestinations(
  BuildContext context,
  WidgetRef ref,
  String location,
) {
  final l10n = context.l10n;
  final features = ref.watch(featureActivationProvider);
  final catalog = ref.watch(featureCatalogProvider);
  final locale = Localizations.localeOf(context).languageCode;
  return [
    DesktopDestination(
      id: 'library',
      label: l10n.librarySection,
      icon: Icons.inbox_rounded,
      selected: location == '/',
      onTap: () => context.go('/'),
      shortcut: '1',
    ),
    if (features.isEnabledById('tiktok_archives'))
      DesktopDestination(
        id: 'archive',
        label: catalog.byId['tiktok_archives']!.nameFor(locale),
        icon: Icons.inventory_2_rounded,
        selected: location == '/archive',
        onTap: () {
          ref
              .read(tikTokArchiveProvider.notifier)
              .setViewMode(TikTokViewMode.hub);
          context.go('/archive');
        },
        shortcut: 'a',
      ),
    if (features.isEnabledById('statistics'))
      DesktopDestination(
        id: 'stats',
        label: l10n.statistics,
        icon: Icons.bar_chart_rounded,
        selected: location == '/stats',
        onTap: () => context.go('/stats'),
        shortcut: 's',
      ),
    if (features.isEnabledById('device_transfer'))
      DesktopDestination(
        id: 'transfer',
        label: l10n.transferTitle,
        icon: Icons.ios_share_rounded,
        selected: location == '/transfer',
        onTap: () => context.go('/transfer'),
        shortcut: 't',
      ),
    DesktopDestination(
      id: 'settings',
      label: l10n.settings,
      icon: Icons.settings_outlined,
      selected: location.startsWith('/settings'),
      onTap: () => context.go('/settings/general'),
      shortcut: ',',
    ),
  ];
}

void openNewDownload(BuildContext context) {
  showDialog(context: context, builder: (context) => const AddDownloadDialog());
}
