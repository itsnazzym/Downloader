import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'nocturne_widgets.dart';

/// The home's situations other than a filled library: loading skeletons,
/// the empty library, no search results and a library that failed to load.

/// First line of a yt-dlp error without its `ERROR:` and `[extractor] id:`
/// prefixes; empty when there is nothing readable.
String nocturneErrorReason(String? raw) {
  final line = (raw ?? '')
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  return line
      .replaceFirst(
        RegExp(r'^(ERROR|WARNING)\s*[:\-]\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w\-]+:\s*)?'), '')
      // The row already says "Échec": keep only why.
      .replaceFirst(
        RegExp(r'^Unable to download( webpage)?\s*:\s*', caseSensitive: false),
        '',
      )
      .trim();
}

/// Lays out a state's art beside its text on wide cards, above it on narrow.
class _StateLayout extends StatelessWidget {
  const _StateLayout({required this.art, required this.text});

  final Widget art;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 560
          ? Row(
              children: [
                art,
                const SizedBox(width: 36),
                Expanded(child: text),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [art, const SizedBox(height: 20), text],
            ),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: nocturneText(
            c,
            size: 24,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: -0.5, height: 1.2),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            body,
            style: nocturneText(c, size: 14, color: c.textSecondary),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }
}

/// Nothing downloaded yet: the orbit (or the rendered illustration), a
/// headline, one sentence and the one action.
class NocturneEmptyLibrary extends StatelessWidget {
  const NocturneEmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: _StateLayout(
        art: const NocturneEmptyArt(size: 176),
        text: _StateText(
          title: l10n.nocturneEmptyTitle,
          body: l10n.nocturneEmptyBody,
          actions: [
            NocturneButton(
              label: l10n.newDownload,
              kind: NocturneButtonKind.primary,
              height: 42,
              radius: 14,
              fontSize: 13.5,
              padding: 20,
              onTap: () => openNewDownload(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A search or filter that matches nothing: says so, shows the query and
/// clears everything in one tap.
class NocturneNoResults extends ConsumerWidget {
  const NocturneNoResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final query = ref.watch(downloadSearchQueryProvider).trim();
    const art = NocturneOrbit(size: 72, icon: Icons.search_rounded, arc: 0);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.nocturneNoResultsTitle,
          style: nocturneText(c, size: 17, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          query.isEmpty
              ? l10n.nocturneNoResultsFilters
              : l10n.nocturneNoResultsQuery(query),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nocturneText(c, color: c.textSecondary),
        ),
      ],
    );
    final clear = NocturneButton(
      label: l10n.nocturneClearSearchFilters,
      icon: Icons.close_rounded,
      onTap: () {
        ref.read(downloadSearchQueryProvider.notifier).state = '';
        ref.read(downloadStatusFilterProvider.notifier).state =
            DownloadStatusFilter.all;
        ref.read(downloadSourceFilterProvider.notifier).state = null;
      },
    );
    // Compact, right under the search field it answers.
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 620
            ? Row(
                children: [
                  art,
                  const SizedBox(width: 20),
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  clear,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      art,
                      const SizedBox(width: 16),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: 14),
                  clear,
                ],
              ),
      ),
    );
  }
}

/// The library itself could not be read: the reason and « Réessayer ».
class NocturneLoadError extends ConsumerWidget {
  const NocturneLoadError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final reason = nocturneErrorReason(error.toString());
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: _StateLayout(
        art: NocturneOrbit(
          size: 140,
          icon: Icons.cloud_off_rounded,
          color: c.error,
          arc: 0.3,
        ),
        text: _StateText(
          title: l10n.nocturneLoadErrorTitle,
          body: reason.isEmpty
              ? l10n.nocturneLoadErrorBody
              : '${l10n.nocturneLoadErrorBody}\n$reason',
          actions: [
            NocturneButton(
              label: l10n.retry,
              kind: NocturneButtonKind.primary,
              icon: Icons.refresh_rounded,
              onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page title while the library loads.
class NocturneTitleSkeleton extends StatelessWidget {
  const NocturneTitleSkeleton({super.key, required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) => NocturneShimmer(
    animation: shimmer,
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: NocturneBone(width: 380, height: 33, radius: 10),
    ),
  );
}

/// The hero card while the library loads: the ring's track and its lines.
class NocturneHeroSkeleton extends StatelessWidget {
  const NocturneHeroSkeleton({super.key, required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      child: NocturneCard(
        lift: false,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: NocturneShimmer(
          animation: shimmer,
          child: const Row(
            children: [
              NocturneRing(value: 0, size: 112, stroke: 8, radius: 46),
              SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NocturneBone(width: 110, height: 11),
                    SizedBox(height: 12),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: NocturneBone(height: 20),
                    ),
                    SizedBox(height: 12),
                    NocturneBone(width: 190, height: 11),
                    SizedBox(height: 18),
                    Row(
                      children: [
                        NocturneBone(width: 76, height: 34, radius: 11),
                        SizedBox(width: 8),
                        NocturneBone(width: 76, height: 34, radius: 11),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Library rows while the library loads: thumbnail, title and meta bones,
/// in the real grid's columns and row height.
class NocturneRowsSkeleton extends StatelessWidget {
  const NocturneRowsSkeleton({
    super.key,
    required this.shimmer,
    required this.columns,
  });

  final Animation<double> shimmer;
  final int columns;

  @override
  Widget build(BuildContext context) {
    const row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          NocturneBone(width: 96, height: 56, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: NocturneBone(height: 13),
                ),
                SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.4,
                  child: NocturneBone(height: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return NocturneShimmer(
      animation: shimmer,
      child: Column(
        children: [
          for (var r = 0; r < 4; r++)
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    // Fainter further down, like rows fading into the night.
                    Expanded(
                      child: Opacity(opacity: 1 - r * 0.2, child: row),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
