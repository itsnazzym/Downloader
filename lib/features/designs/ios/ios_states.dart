import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/ui/shell/desktop_destinations.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'ios_glass.dart';

/// A state as one glass card: the frosted rings, a headline, one sentence
/// and its action. Side by side when there is room.
class IosStateCard extends StatelessWidget {
  const IosStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.danger = false,
    this.artSize = 150,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final bool danger;
  final double artSize;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final art = IosStateArt(icon: icon, size: artSize, danger: danger);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: iosText(t, size: 24, weight: FontWeight.w800, spacing: -0.6),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(body, style: iosText(t, size: 14.5, color: t.sub)),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );
    return IosGlass(
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 560
            ? Row(
                children: [
                  art,
                  const SizedBox(width: 34),
                  Expanded(child: text),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [art, const SizedBox(height: 20), text],
              ),
      ),
    );
  }
}

/// Nothing downloaded yet.
class IosEmptyLibrary extends StatelessWidget {
  const IosEmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosStateCard(
      icon: Icons.download_rounded,
      title: l10n.iosEmptyTitle,
      body: l10n.iosEmptyBody,
      actions: [
        IosButton(
          label: l10n.newDownload,
          icon: Icons.add_rounded,
          kind: IosButtonKind.primary,
          height: 44,
          onTap: () => openNewDownload(context),
        ),
      ],
    );
  }
}

/// A search or a filter that matches nothing, and the way out.
class IosNoResults extends ConsumerWidget {
  const IosNoResults({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(downloadSearchQueryProvider).trim();
    return IosStateCard(
      icon: Icons.search_rounded,
      artSize: 96,
      title: l10n.iosNoResultsTitle,
      body: query.isEmpty
          ? l10n.iosNoResultsFilters
          : l10n.iosNoResultsQuery(query),
      actions: [
        IosButton(
          label: l10n.iosClearFilters,
          icon: Icons.close_rounded,
          onTap: onClear,
        ),
      ],
    );
  }
}

/// The library could not be read: the reason and « Réessayer ».
class IosLoadError extends ConsumerWidget {
  const IosLoadError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reason = downloadErrorReason(error.toString());
    return IosStateCard(
      icon: Icons.cloud_off_rounded,
      danger: true,
      title: l10n.iosLoadErrorTitle,
      body: reason.isEmpty
          ? l10n.iosLoadErrorBody
          : '${l10n.iosLoadErrorBody}\n$reason',
      actions: [
        IosButton(
          label: l10n.retry,
          icon: Icons.refresh_rounded,
          kind: IosButtonKind.primary,
          onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
        ),
      ],
    );
  }
}
