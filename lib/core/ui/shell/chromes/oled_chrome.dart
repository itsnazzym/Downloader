import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/designs/oled/oled_theme.dart';
import 'package:tapload/features/designs/oled/oled_widgets.dart';
import 'package:tapload/features/designs/shared/design_data.dart';
import 'package:tapload/features/designs/signal/signal_home.dart'
    show designFreeSpaceProvider;
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../desktop_destinations.dart';

/// OLED (mockups Main, OLED-*.dc.html): a black top bar with the breathing
/// logo dot, the pages as text links (a glowing dot under the active one)
/// and the live speed and free space, then the page on pure black.
class OledChrome extends ConsumerWidget {
  const OledChrome({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final destinations = desktopDestinations(context, ref, location);
    final links = [
      for (final d in destinations)
        switch (d.id) {
          'library' => DesktopDestination(
            id: d.id,
            label: l10n.oledNavHome,
            icon: d.icon,
            selected: d.selected,
            onTap: d.onTap,
          ),
          // The archive opens on its videos once there is a catalog.
          'archive' => DesktopDestination(
            id: d.id,
            label: d.label,
            icon: d.icon,
            selected: d.selected,
            onTap: () {
              if (!ref.read(tikTokArchiveProvider).hasCatalog) {
                d.onTap();
                return;
              }
              ref
                  .read(tikTokArchiveProvider.notifier)
                  .setViewMode(TikTokViewMode.list);
              context.go('/archive');
            },
          ),
          _ => d,
        },
    ];
    return OledTheme(
      child: ColoredBox(
        color: OledInk.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OledInk.line)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OledLiveDot(breathe: true),
                      const SizedBox(width: 10),
                      Text('tapload', style: oledDoto(24, height: 1)),
                    ],
                  ),
                  Semantics(
                    container: true,
                    label: l10n.oledMainNavigation,
                    child: Wrap(
                      spacing: 28,
                      runSpacing: 8,
                      children: [
                        for (final d in links) _NavLink(destination: d),
                      ],
                    ),
                  ),
                  const _LiveFigures(),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// A page link; the active one is white with its glowing dot under it.
class _NavLink extends StatelessWidget {
  const _NavLink({required this.destination});

  final DesktopDestination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OledTextLink(
          label: d.label,
          selected: d.selected,
          selectedWeight: FontWeight.w500,
          onTap: d.onTap,
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 4,
          child: d.selected ? const OledLiveDot(size: 4) : null,
        ),
      ],
    );
  }
}

/// "6,2 Mo/s · 412 Go libres": the only part of the bar that follows the
/// progress ticks.
class _LiveFigures extends ConsumerWidget {
  const _LiveFigures();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // A finished download takes room on the disk: read it again.
    ref.listen(
      downloadLibraryCountsProvider.select((c) => c.completed),
      (_, _) => ref.invalidate(designFreeSpaceProvider),
    );
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final speed = aggregateSpeed(
      liveActiveItems(
        items,
        (id) => ref.watch(downloadRuntimeItemProvider(id)),
      ),
    );
    final free = ref.watch(designFreeSpaceProvider).valueOrNull;
    final rate = formatSpeed(l10n, speed);
    final value = oledMono(color: OledInk.ink);
    final unit = oledMono();
    return Wrap(
      spacing: 18,
      children: [
        if (speed != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: rate.value, style: value),
                TextSpan(text: ' ${rate.unit}', style: unit),
              ],
            ),
          ),
        if (free != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: localBytes(l10n, free), style: value),
                TextSpan(text: ' ${l10n.oledFreeWord}', style: unit),
              ],
            ),
          ),
      ],
    );
  }
}
