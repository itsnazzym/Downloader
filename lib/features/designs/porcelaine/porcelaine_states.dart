import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../shared/empty_art.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'porcelaine_widgets.dart';
import 'porcelaine_workspace_model.dart';
import '../shared/design_data.dart';

/// Porcelaine's situations: first launch, loading, a library that failed to
/// open, failed downloads, a search with no match, and the « download
/// finished » moment of the En cours widget.

// ── Data ───────────────────────────────────────────────────────────────────

/// Items that were active in [prev] and are completed in [next]; none on
/// the first load ([prev] null).
List<DownloadItem> pJustFinished(
  List<DownloadItem>? prev,
  List<DownloadItem> next,
) {
  if (prev == null) return const [];
  final wasActive = {
    for (final i in prev)
      if (isActiveDownload(i)) i.id,
  };
  if (wasActive.isEmpty) return const [];
  return [
    for (final i in next)
      if (i.status == DownloadStatus.completed && wasActive.contains(i.id)) i,
  ];
}

/// The download whose « finished » moment is playing (set and cleared by
/// the Espace).
final porcelaineFinishProvider = StateProvider<DownloadItem?>((ref) => null);

/// Clears the search and every library filter.
void pClearSearchAndFilters(WidgetRef ref) {
  ref.read(downloadSearchQueryProvider.notifier).state = '';
  ref.read(downloadStatusFilterProvider.notifier).state =
      DownloadStatusFilter.all;
  ref.read(downloadSourceFilterProvider.notifier).state = null;
}

/// Back to the Espace: closes the library and drops the search that kept it
/// open.
void pCloseLibrary(WidgetRef ref) {
  ref.read(porcelaineLibraryOpenProvider.notifier).state = false;
  ref.read(downloadSearchQueryProvider.notifier).state = '';
}

// ── Skeletons ──────────────────────────────────────────────────────────────

/// A soft light sweeping over the grey blocks below it; still when the
/// system asks for no animations.
class PShimmer extends StatefulWidget {
  const PShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<PShimmer> createState() => _PShimmerState();
}

class _PShimmerState extends State<PShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

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
    if (!_c.isAnimating) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final x = -1.5 + 3 * _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.6, -0.3),
              end: Alignment(x + 0.6, 0.3),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x8CFFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// A grey placeholder block.
class PSkel extends StatelessWidget {
  const PSkel({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).textPrimary.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A widget's body while the library loads, shaped like its real content.
class PTileSkeleton extends StatelessWidget {
  const PTileSkeleton({super.key, required this.type, required this.size});

  final PWidgetType type;
  final PWidgetSize size;

  @override
  Widget build(BuildContext context) {
    Widget lines(int n) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              const PSkel(width: 40, height: 28, radius: 9),
              const SizedBox(width: 12),
              Expanded(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: const [0.8, 0.6, 0.7, 0.5, 0.65, 0.55][i % 6],
                  child: const PSkel(height: 11),
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final Widget body;
    if (size == PWidgetSize.small) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type == PWidgetType.recent)
            const PSkel(height: 58, radius: 12)
          else
            const PSkel(width: 76, height: 40, radius: 10),
          const SizedBox(height: 12),
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: PSkel(height: 10),
          ),
        ],
      );
    } else if (type == PWidgetType.recent && size == PWidgetSize.medium) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PSkel(height: 54, radius: 12),
                  SizedBox(height: 10),
                  PSkel(height: 10),
                  SizedBox(height: 6),
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: PSkel(height: 8),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } else if (type == PWidgetType.active) {
      body = Column(
        mainAxisAlignment: size == PWidgetSize.large
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (size == PWidgetSize.large) ...[
                const PSkel(width: 120, height: 68, radius: 12),
                const SizedBox(width: 14),
              ],
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.8,
                      child: PSkel(height: 12),
                    ),
                    SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.45,
                      child: PSkel(height: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const PSkel(width: 84, height: 44, radius: 10),
            ],
          ),
          const SizedBox(height: 18),
          const PSkel(height: 8, radius: 8),
        ],
      );
    } else if (size == PWidgetSize.medium) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PSkel(width: 96, height: 36, radius: 10),
          const SizedBox(height: 14),
          const PSkel(height: 10, radius: 4),
        ],
      );
    } else {
      body = lines(5);
    }
    return ExcludeSemantics(child: PShimmer(child: body));
  }
}

/// The library's list while it loads: rows shaped like the real ones.
class PLibrarySkeleton extends StatelessWidget {
  const PLibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.porcelaineLoadingLibrary,
      liveRegion: true,
      child: ExcludeSemantics(
        child: PShimmer(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            itemCount: 10,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  const PSkel(width: 72, height: 42, radius: 10),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: const [
                            0.62,
                            0.48,
                            0.7,
                            0.4,
                            0.55,
                          ][i % 5],
                          child: const PSkel(height: 12),
                        ),
                        const SizedBox(height: 8),
                        const FractionallySizedBox(
                          widthFactor: 0.28,
                          child: PSkel(height: 9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const PSkel(width: 64, height: 22, radius: 999),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty slots ────────────────────────────────────────────────────────────

/// A dashed rounded outline (an empty widget slot).
class PDashedBox extends StatelessWidget {
  const PDashedBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.circle = false,
    this.child,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CustomPaint(
      painter: _DashPainter(
        color: colors.textPrimary.withValues(alpha: 0.18),
        fill: colors.textPrimary.withValues(alpha: 0.025),
        radius: radius,
        circle: circle,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.color,
    required this.fill,
    required this.radius,
    required this.circle,
  });

  final Color color;
  final Color fill;
  final double radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final path = circle
        ? (Path()..addOval(rect))
        : (Path()
            ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))));
    canvas.drawPath(path, Paint()..color = fill);
    _dash(canvas, path, color, 1.5);
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color ||
      old.fill != fill ||
      old.radius != radius ||
      old.circle != circle;
}

void _dash(Canvas canvas, Path path, Color color, double width) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  for (final PathMetric m in path.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 9) {
      canvas.drawPath(m.extractPath(d, d + 4.5), paint);
    }
  }
}

/// Empty dashed rows where a list will appear, over one line saying why.
class PEmptyRows extends StatelessWidget {
  const PEmptyRows({
    super.key,
    required this.text,
    this.rows = 3,
    this.numbered = false,
    this.thumb = false,
  });

  final String text;
  final int rows;
  final bool numbered;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  if (numbered) ...[
                    Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: pMono(
                        colors,
                        color: colors.textDisabled.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (thumb) ...[
                    const PDashedBox(width: 52, height: 32, radius: 10),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: const [0.72, 0.5, 0.62, 0.42][i % 4],
                      child: const PDashedBox(height: 12, radius: 6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(text, style: pBody(colors, color: colors.textSecondary)),
      ],
    );
  }
}

/// The first-launch picture: the Espace's grid with every slot still empty
/// except the quick-link card, cobalt, where everything starts.
class _SlotsPainter extends CustomPainter {
  _SlotsPainter({required this.ink, required this.card, required this.accent});

  final Color ink;
  final Color card;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 10.0;
    final cw = (size.width - 3 * gap) / 4;
    final ch = (size.height - gap) / 2;
    Rect cell(int c, int r, int w, int h) => Rect.fromLTWH(
      c * (cw + gap),
      r * (ch + gap),
      w * cw + (w - 1) * gap,
      h * ch + (h - 1) * gap,
    );
    final slots = [cell(0, 0, 2, 2), cell(2, 1, 1, 1), cell(3, 1, 1, 1)];
    for (final s in slots) {
      final rr = RRect.fromRectAndRadius(s, const Radius.circular(16));
      canvas.drawRRect(rr, Paint()..color = ink.withValues(alpha: 0.025));
      _dash(canvas, Path()..addRRect(rr), ink.withValues(alpha: 0.2), 1.4);
    }
    // A faint ring in the big slot: where the progress will be.
    final big = slots.first;
    _dash(
      canvas,
      Path()..addOval(
        Rect.fromCircle(center: big.center, radius: big.shortestSide * 0.26),
      ),
      ink.withValues(alpha: 0.14),
      1.4,
    );
    // The quick-link card, filled.
    final q = cell(2, 0, 2, 1);
    final qr = RRect.fromRectAndRadius(q, const Radius.circular(16));
    canvas.drawRRect(
      qr.shift(const Offset(0, 6)),
      Paint()
        ..color = ink.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(qr, Paint()..color = card);
    canvas.drawRRect(
      qr,
      Paint()
        ..color = ink.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke,
    );
    final field = RRect.fromRectAndRadius(
      Rect.fromLTWH(q.left + 12, q.center.dy - 13, q.width - 24, 26),
      const Radius.circular(9),
    );
    canvas.drawRRect(field, Paint()..color = ink.withValues(alpha: 0.05));
    final btn = RRect.fromRectAndRadius(
      Rect.fromLTWH(field.right - 40, field.top + 3, 37, 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(btn, Paint()..color = accent);
    // A down arrow on the button.
    final c = btn.center;
    final arrow = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(c.translate(0, -5), c.translate(0, 4), arrow);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy + 0.5)
        ..lineTo(c.dx, c.dy + 4.5)
        ..lineTo(c.dx + 4, c.dy + 0.5),
      arrow,
    );
    // A blinking-caret stroke in the field.
    canvas.drawLine(
      Offset(field.left + 12, field.center.dy - 6),
      Offset(field.left + 12, field.center.dy + 6),
      Paint()
        ..color = accent
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_SlotsPainter old) =>
      old.ink != ink || old.card != card || old.accent != accent;
}

/// First launch: nothing downloaded yet. The picture is
/// the Blender loop (`emptyArtAsset`) when it loads, else drawn here.
class PEmptyLibrary extends StatelessWidget {
  const PEmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final picture = ExcludeSemantics(
      child: SizedBox(
        width: 300,
        height: 172,
        child: Image.asset(
          emptyArtAsset(context, 'porcelaine'),
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => CustomPaint(
            painter: _SlotsPainter(
              ink: colors.textPrimary,
              card: colors.surface,
              accent: colors.primary,
            ),
          ),
        ),
      ),
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.porcelaineEmptyLibTitle,
            style: pDisp(30, color: colors.textPrimary).copyWith(height: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.porcelaineEmptyLibBody,
          style: pBody(colors, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        PBtn(
          label: l10n.newDownload,
          icon: Icons.add_rounded,
          kind: PBtnKind.accent,
          onTap: () => openNewDownload(context),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: pCardFill(colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: pCardShadow(colors),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [picture, const SizedBox(height: 24), text],
              )
            : Row(
                children: [
                  picture,
                  const SizedBox(width: 40),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: text,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Panels ─────────────────────────────────────────────────────────────────

/// A centred situation: a round mark, a title, a sentence, actions.
class PStatePanel extends StatelessWidget {
  const PStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = tint ?? colors.textSecondary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PDashedBox(
              width: 76,
              height: 76,
              circle: true,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    c.withValues(alpha: 0.12),
                    colors.surface,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: c),
              ),
            ),
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: pDisp(24, color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: pBody(colors, color: colors.textSecondary),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The library could not be read: say so and offer to read it again.
class PLoadError extends ConsumerWidget {
  const PLoadError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: PStatePanel(
        icon: Icons.cloud_off_rounded,
        tint: colors.error,
        title: l10n.porcelaineLoadErrorTitle,
        body: l10n.porcelaineLoadErrorBody,
        actions: [
          PBtn(
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            kind: PBtnKind.accent,
            onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
          ),
        ],
      ),
    );
  }
}

/// A search or filters that match nothing.
class PNoResults extends ConsumerWidget {
  const PNoResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(downloadSearchQueryProvider).trim();
    return PStatePanel(
      icon: Icons.search_off_rounded,
      title: l10n.porcelaineNoResultsTitle,
      body: query.isEmpty
          ? l10n.porcelaineNoResultsFilters
          : l10n.porcelaineNoResultsQuery(query),
      actions: [
        PBtn(
          label: l10n.clearSearchAndFilters,
          icon: Icons.close_rounded,
          kind: PBtnKind.accent,
          onTap: () => pClearSearchAndFilters(ref),
        ),
      ],
    );
  }
}

/// A widget whose data could not load.
class PTileError extends ConsumerWidget {
  const PTileError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_rounded, size: 20, color: colors.error),
        const SizedBox(height: 6),
        Text(
          l10n.porcelaineUnavailable,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: pBody(colors, size: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        PBtn(
          label: l10n.retry,
          height: 30,
          fontSize: 12.5,
          padding: 12,
          onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
        ),
      ],
    );
  }
}

/// Failed downloads above the Espace: how many, the latest reason, and one
/// button to retry them all.
class PFailureStrip extends ConsumerWidget {
  const PFailureStrip({super.key, required this.failed});

  final List<DownloadItem> failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(downloadListProvider.notifier);
    final reason = downloadErrorReason(failed.first.error);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 6, 6),
        decoration: BoxDecoration(
          color: pCardFill(colors),
          borderRadius: BorderRadius.circular(999),
          boxShadow: pCardShadow(colors),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.porcelaineFailedCount(failed.length),
              style: pBody(colors, size: 13.5, weight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pMono(colors, size: 12, color: colors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            PBtn(
              label: failed.length > 1
                  ? l10n.porcelaineRetryFailedCount(failed.length)
                  : l10n.retry,
              icon: Icons.refresh_rounded,
              kind: PBtnKind.accent,
              height: 34,
              fontSize: 13,
              onTap: failed.length > 1
                  ? notifier.retryAllFailed
                  : () => notifier.retryDownload(failed.first),
            ),
          ],
        ),
      ),
    );
  }
}

/// A once-only fade and rise for the [index]-th card when the page opens.
class PRise extends StatelessWidget {
  const PRise({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, 11);
    final curve = Interval(
      i * 0.05,
      (i * 0.05 + 0.45).clamp(0, 1),
      curve: pEase,
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = curve.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
