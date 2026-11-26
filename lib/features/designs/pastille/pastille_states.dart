import 'package:flutter/material.dart';
import '../shared/empty_art.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'pastille_kit.dart';

/// The situations around Pastille's lists: nothing yet, nothing matching,
/// still loading, could not load, and the failure reason of one item.

/// The readable cause of a failed download: the first `ERROR:` line (or the
/// first line) of [error] without yt-dlp's `ERROR:` / `[extractor] id:` /
/// `Unable to download…:` prefixes.
String pFailReason(String? error) {
  final lines = [
    for (final l in (error ?? '').split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isEmpty) return '';
  final line = lines.firstWhere(
    (l) => l.startsWith('ERROR'),
    orElse: () => lines.first,
  );
  return line
      .replaceFirst(RegExp(r'^(ERROR|WARNING)\s*[:\-]\s*'), '')
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w-]+:\s+)?'), '')
      .replaceFirst(
        RegExp(r'^Unable to (download|extract)[\w ]*:\s*', caseSensitive: false),
        '',
      )
      .trim();
}

/// Whether a search, a status or a source filter narrows the library.
bool pFiltered(WidgetRef ref) =>
    ref.watch(downloadSearchQueryProvider).trim().isNotEmpty ||
    ref.watch(downloadStatusFilterProvider) != DownloadStatusFilter.all ||
    ref.watch(downloadSourceFilterProvider) != null;

void pClearFilters(WidgetRef ref) {
  ref.read(downloadSearchQueryProvider.notifier).state = '';
  ref.read(downloadStatusFilterProvider.notifier).state =
      DownloadStatusFilter.all;
  ref.read(downloadSourceFilterProvider.notifier).state = null;
}

/// How many downloads `retryAllFailed` would start again.
int pFailedCount(WidgetRef ref) => ref.watch(
  downloadListProvider.select(
    (v) =>
        v.valueOrNull?.where((i) => i.status == DownloadStatus.failed).length ??
        0,
  ),
);

/// « Relancer les échecs (n) »: a rose pill; callers show it when several
/// failed.
class PRetryFailedButton extends ConsumerWidget {
  const PRetryFailedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PButton(
      label: context.l10n.pastilleRetryFailed(pFailedCount(ref)),
      icon: Icons.refresh_rounded,
      iconSize: 17,
      kind: PButtonKind.rose,
      height: 46,
      padH: 20,
      fontSize: 14,
      onTap: () => ref.read(downloadListProvider.notifier).retryAllFailed(),
    );
  }
}

// ── Empty library ───────────────────────────────────────────────────────────

/// A down arrow drawn in the dot grid (9 × 7), ink dots on faint cells.
const _arrow = [
  '....#....',
  '....#....',
  '....#....',
  '.#..#..#.',
  '..#.#.#..',
  '...###...',
  '....#....',
];

/// The empty library: a lavender tile, the big Sora line, one sentence, the
/// new-download pill and the dot-grid arrow (or the Blender loop, `emptyArtAsset`).
class PastilleEmpty extends StatelessWidget {
  const PastilleEmpty({super.key, required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PTile(
      color: PTones.of(context).lav,
      semanticLabel: l10n.pastilleEmptyTitle,
      child: LayoutBuilder(
        builder: (context, c) {
          final art = SizedBox(
            width: 168,
            child: Image.asset(
              emptyArtAsset(context, 'pastille'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => PDots(
                count: 63,
                columns: 9,
                on: 0,
                gap: 7,
                levels: [
                  for (final row in _arrow)
                    for (final ch in row.split('')) ch == '#' ? 4 : 0,
                ],
              ),
            ),
          );
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PLabel(
                icon: Icons.inbox_rounded,
                text: l10n.librarySection,
              ),
              const Spacer(),
              Semantics(
                header: true,
                child: Text(
                  l10n.pastilleEmptyTitle,
                  style: pNum(
                    40,
                    weight: FontWeight.w800,
                    color: pInk,
                  ).copyWith(height: 1),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pastilleEmptyBody,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: pBody(size: 14.5, weight: FontWeight.w500, color: pInk),
              ),
              const SizedBox(height: 18),
              PButton(
                label: l10n.newDownload,
                icon: Icons.download_rounded,
                height: 44,
                padH: 20,
                fontSize: 14,
                onTap: onNew,
              ),
            ],
          );
          if (c.maxWidth < 440) return text;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              Center(child: art),
            ],
          );
        },
      ),
    );
  }
}

// ── No results ──────────────────────────────────────────────────────────────

/// The search or the filters match nothing: an ink capsule that names the
/// query and clears everything in one click.
class PastilleNoResults extends ConsumerWidget {
  const PastilleNoResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final query = ref.watch(downloadSearchQueryProvider).trim();
    final title = query.isEmpty
        ? l10n.pastilleNoResultsFilters
        : l10n.pastilleNoResultsTitle(query);
    final button = PButton(
      label: l10n.clearSearchAndFilters,
      icon: Icons.close_rounded,
      kind: PButtonKind.cream,
      height: 42,
      onTap: () => pClearFilters(ref),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: pBody(size: 16, weight: FontWeight.w700, color: pCream),
        ),
        Text(l10n.pastilleNoResultsBody, style: pBody(size: 13, color: pMuted)),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: pInkDeep,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: pCream.withValues(alpha: 0.08), spreadRadius: 1),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final badge = Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tones.butter,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 22,
                color: pInk,
              ),
            );
            if (c.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      badge,
                      const SizedBox(width: 14),
                      Expanded(child: words),
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ],
              );
            }
            return Row(
              children: [
                badge,
                const SizedBox(width: 16),
                Expanded(child: words),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Could not load ──────────────────────────────────────────────────────────

/// The library itself failed to load: a rose tile with « Réessayer ».
class PastilleLoadError extends ConsumerWidget {
  const PastilleLoadError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PTile(
      color: PTones.of(context).rose,
      semanticLabel: l10n.pastilleLoadErrorTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PLabel(icon: Icons.error_outline_rounded, text: l10n.error),
          const SizedBox(height: 28),
          Text(
            l10n.pastilleLoadErrorTitle,
            style: pNum(
              34,
              weight: FontWeight.w800,
              color: pInk,
            ).copyWith(height: 1.05),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.pastilleLoadErrorBody,
            style: pBody(size: 14.5, weight: FontWeight.w500, color: pInk),
          ),
          const SizedBox(height: 20),
          PButton(
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            height: 44,
            padH: 20,
            onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
          ),
        ],
      ),
    );
  }
}

// ── Loading ─────────────────────────────────────────────────────────────────

/// A soft light sweeping across [child] (skeletons); still when animations
/// are off.
class PShimmer extends StatefulWidget {
  const PShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<PShimmer> createState() => _PShimmerState();
}

class _PShimmerState extends State<PShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: context.l10n.pastilleLoading,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            child: widget.child,
            builder: (context, child) {
              if (still) return child!;
              final x = -1.5 + 3 * _c.value;
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(x - 0.6, -0.3),
                  end: Alignment(x + 0.6, 0.3),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0),
                  ],
                ).createShader(rect),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A placeholder bar.
class _Bar extends StatelessWidget {
  const _Bar({required this.w, this.h = 12, required this.color});

  final double w;
  final double h;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

/// One bento tile while loading: the tile's own tone, dimmed, with a label
/// bar, a big-number block and a caption bar.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.tone, this.dots = false});

  final Color tone;
  final bool dots;

  @override
  Widget build(BuildContext context) {
    final fill = Color.alphaBlend(tone.withValues(alpha: 0.16), pCard);
    final bar = Color.alphaBlend(tone.withValues(alpha: 0.22), fill);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bar(w: 96, color: bar),
          const Spacer(),
          _Bar(w: 84, h: 40, color: bar),
          const SizedBox(height: 10),
          _Bar(w: 130, color: bar),
          if (dots) ...[
            const SizedBox(height: 22),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 50; i++)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: bar,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// The home while the library loads: the bento's shapes, then four recent
/// cards, under one shimmer.
class PastilleHomeSkeleton extends StatelessWidget {
  const PastilleHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = PTones.of(context);
    return PShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PGrid(
            cells: [
              PCell(_SkeletonTile(tone: t.lav, dots: true), w: 2, h: 2),
              const PCell(_SkeletonTile(tone: pInkDeep), w: 2),
              PCell(_SkeletonTile(tone: t.sage)),
              PCell(_SkeletonTile(tone: t.sky)),
              PCell(_SkeletonTile(tone: t.rose), w: 2),
              PCell(_SkeletonTile(tone: t.butter)),
              PCell(_SkeletonTile(tone: t.cream)),
            ],
          ),
          const SizedBox(height: 26),
          const PastilleCardsSkeleton(),
        ],
      ),
    );
  }
}

/// Recent cards while loading (thumbnail block, title and caption bars).
class PastilleCardsSkeleton extends StatelessWidget {
  const PastilleCardsSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bar = pCream.withValues(alpha: 0.07);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + 14) / 234).floor().clamp(1, 8);
        final w = (c.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: w,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Bar(w: w * 0.7, color: bar),
                    const SizedBox(height: 8),
                    _Bar(w: w * 0.4, h: 10, color: bar),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The library list while loading: rows like the real ones (thumbnail, two
/// lines, a status pill).
class PastilleListSkeleton extends StatelessWidget {
  const PastilleListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bar = pCream.withValues(alpha: 0.07);
    return PShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        itemCount: 7,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Container(
          height: 76,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 92,
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.55 : 0.4,
                      child: _Bar(w: double.infinity, color: bar),
                    ),
                    const SizedBox(height: 10),
                    _Bar(w: 140, h: 10, color: bar),
                  ],
                ),
              ),
              _Bar(w: 72, h: 28, color: bar),
            ],
          ),
        ),
      ),
    );
  }
}
