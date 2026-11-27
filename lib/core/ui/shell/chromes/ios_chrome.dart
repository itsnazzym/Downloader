import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/ios/ios_ambient.dart';
import 'package:tapload/features/designs/ios/ios_glass.dart';
import 'package:tapload/features/designs/ios/ios_settings.dart'
    show iosSettingsSections;
import 'package:tapload/features/designs/ios/ios_theme.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';

/// iOS « Liquid Glass » (mockups iOS-*.dc.html): the page's coloured
/// ambient behind everything, a floating frosted sidebar (radius 28, 14px
/// off the window edges) and the page beside it. In Réglages the sidebar
/// turns into the list of sections, with a way back to the library.
class IosChrome extends ConsumerWidget {
  const IosChrome({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = location.startsWith('/settings');
    // Narrow windows keep a rail of icons.
    final compact = MediaQuery.sizeOf(context).width < 900;
    final width = compact ? 68.0 : (settings ? 252.0 : 232.0);
    return IosGlassTheme(
      child: Stack(
        fit: StackFit.expand,
        children: [
          IosAmbient(location: location),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 0, 14),
                child: SizedBox(
                  width: width,
                  child: IosGlass(
                    radius: compact ? 24 : 28,
                    padding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: compact ? 8 : 10,
                    ),
                    child: settings
                        ? _SettingsBar(location: location, compact: compact)
                        : _MainBar(location: location, compact: compact),
                  ),
                ),
              ),
              // The pages draw their own titles, filters and sections.
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainBar extends ConsumerWidget {
  const _MainBar({required this.location, required this.compact});

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final counts = ref.watch(downloadLibraryCountsProvider);
    final status = ref.watch(downloadStatusFilterProvider);
    final destinations = desktopDestinations(context, ref, location);
    final home = location == '/';
    void setStatus(DownloadStatusFilter s) {
      ref.read(downloadSourceFilterProvider.notifier).state = null;
      ref.read(downloadStatusFilterProvider.notifier).state = s;
      context.go('/');
    }

    Widget item(
      String label,
      IconData icon, {
      required bool selected,
      required VoidCallback onTap,
      Color? iconColor,
      Widget? trailing,
      bool dot = false,
    }) => _NavItem(
      label: label,
      icon: icon,
      iconColor: iconColor ?? (selected ? t.blue : t.sub),
      selected: selected,
      onTap: onTap,
      compact: compact,
      trailing: trailing,
      dot: dot,
    );

    final tools = <Widget>[];
    DesktopDestination? settings;
    for (final d in destinations) {
      switch (d.id) {
        case 'library':
          continue;
        case 'settings':
          settings = d;
          continue;
        case 'archive':
          tools.add(
            item(
              d.label,
              Icons.inventory_2_outlined,
              selected: d.selected,
              onTap: () {
                if (!ref.read(tikTokArchiveProvider).hasCatalog) {
                  d.onTap();
                  return;
                }
                ref
                    .read(tikTokArchiveProvider.notifier)
                    .setViewMode(TikTokViewMode.collections);
                context.go('/archive');
              },
            ),
          );
        case 'stats':
          tools.add(
            item(
              d.label,
              Icons.bar_chart_rounded,
              selected: d.selected,
              onTap: d.onTap,
            ),
          );
        case 'transfer':
          tools.add(
            item(
              d.label,
              Icons.swap_horiz_rounded,
              selected: d.selected,
              onTap: d.onTap,
            ),
          );
        default:
          tools.add(
            item(d.label, d.icon, selected: d.selected, onTap: d.onTap),
          );
      }
    }
    final count = iosText(t, size: 12, weight: FontWeight.w500, color: t.sub);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 0 : 10, 4, 0, 16),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(t.blueFill, Colors.white, 0.3)!,
                      Color.lerp(t.blueFill, Colors.black, 0.2)!,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: iosText(
                      t,
                      size: 17,
                      weight: FontWeight.w800,
                      spacing: -0.34,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          // Scrolls only when the window gets very short.
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(
                  l10n.librarySection,
                  Icons.smart_display_outlined,
                  selected:
                      home &&
                      status != DownloadStatusFilter.active &&
                      status != DownloadStatusFilter.failed,
                  onTap: () => setStatus(DownloadStatusFilter.all),
                  trailing: Text('${counts.total}', style: count),
                ),
                item(
                  l10n.designInProgress,
                  Icons.schedule_rounded,
                  selected: home && status == DownloadStatusFilter.active,
                  onTap: () => setStatus(DownloadStatusFilter.active),
                  dot: counts.active > 0,
                  trailing: counts.active > 0
                      ? Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.blueFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${counts.active}',
                            style: iosText(
                              t,
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                item(
                  l10n.iosFailures,
                  Icons.error_outline_rounded,
                  iconColor: t.red,
                  selected: home && status == DownloadStatusFilter.failed,
                  onTap: () => setStatus(DownloadStatusFilter.failed),
                  trailing: counts.failed > 0
                      ? Text(
                          '${counts.failed}',
                          style: iosText(
                            t,
                            size: 12,
                            weight: FontWeight.w600,
                            color: t.red,
                          ),
                        )
                      : null,
                ),
                if (tools.isNotEmpty) ...[
                  if (compact)
                    const SizedBox(height: 14)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        l10n.iosTools,
                        style: iosText(
                          t,
                          size: 12,
                          weight: FontWeight.w600,
                          color: t.sub,
                        ),
                      ),
                    ),
                  ...tools,
                ],
              ],
            ),
          ),
        ),
        if (settings != null)
          item(
            settings.label,
            Icons.settings_outlined,
            selected: settings.selected,
            onTap: settings.onTap,
          ),
      ],
    );
  }
}

/// Réglages: « ‹ Bibliothèque », then the sections as tinted rows.
class _SettingsBar extends StatelessWidget {
  const _SettingsBar({required this.location, required this.compact});

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final current = location == '/settings' ? '/settings/general' : location;
    final back = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosTap(
          onTap: () => context.go('/'),
          radius: 12,
          tooltip: compact ? l10n.librarySection : null,
          semanticLabel: l10n.librarySection,
          builder: (context, hover) => Padding(
            padding: EdgeInsets.fromLTRB(compact ? 0 : 8, 4, 8, 14),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(back, size: 20, color: t.blue),
                if (!compact)
                  Flexible(
                    child: Text(
                      l10n.librarySection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: iosText(
                        t,
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: hover ? t.text : t.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in iosSettingsSections(l10n))
                  _NavItem(
                    label: s.label,
                    selected: s.path == current,
                    onTap: () => context.go(s.path),
                    compact: compact,
                    leading: IosTintDot(colors: s.tint, icon: s.icon, size: 30),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One sidebar row: a capsule, the selected one a brighter pill.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.dot = false,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final Widget? trailing;

  /// A count the compact rail cannot spell out.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final lead = leading ?? Icon(icon, size: 19, color: iconColor ?? t.sub);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IosTap(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        tooltip: compact ? label : null,
        builder: (context, hover) => AnimatedContainer(
          duration: iosMotion(context, 200),
          curve: iosEase,
          height: leading != null ? 44 : 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? t.pillGradient : null,
            color: selected ? null : (hover ? t.hover : Colors.transparent),
            boxShadow: selected ? t.pillShadow : null,
          ),
          child: compact
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    lead,
                    if (dot)
                      PositionedDirectional(
                        top: 8,
                        end: 12,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: t.blueFill,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    lead,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: iosText(
                          t,
                          size: 14.5,
                          weight: selected
                              ? (leading != null
                                    ? FontWeight.w700
                                    : FontWeight.w600)
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
