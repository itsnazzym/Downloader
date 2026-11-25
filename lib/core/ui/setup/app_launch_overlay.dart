import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:window_manager/window_manager.dart';

import '../../bootstrap/app_warmup_models.dart';
import '../../bootstrap/app_warmup_provider.dart';
import '../../config/app_config.dart';
import '../../platform/platform_info.dart';
import 'oled_launch_screen.dart';
import '../../design_system/foundation/typography.dart';
import '../../setup/dependency_bootstrap_provider.dart';

/// Ultra-sleek Black Minimalist Launcher Screen (Shadcn UI inspired).
/// Orchestrates the real application warmup pipeline to eliminate startup lag
/// and presents an animated progress bar with continuous interior shimmer.
class AppLaunchOverlay extends ConsumerStatefulWidget {
  const AppLaunchOverlay({super.key, required this.libraryReady});

  final bool libraryReady;

  @override
  ConsumerState<AppLaunchOverlay> createState() => _AppLaunchOverlayState();
}

class _AppLaunchOverlayState extends ConsumerState<AppLaunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _dismissed = false;

  /// Phones keep the intro on screen long enough to be seen, even when the
  /// warm-up finishes instantly.
  bool _introPlayed = !PlatformInfo.isMobile;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    if (!_introPlayed) {
      _introTimer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() => _introPlayed = true);
      });
    }
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warmup = ref.watch(appWarmupProvider);
    final depState = ref.watch(dependencyBootstrapProvider);

    // If warmup is finished and animation has faded out, remove from layout
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final isCompleted =
        warmup.isCompleted && widget.libraryReady && _introPlayed;

    return IgnorePointer(
      ignoring: isCompleted,
      child: AnimatedOpacity(
        opacity: isCompleted ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        onEnd: () {
          if (isCompleted && mounted) {
            // The overlay stays mounted; a repeating ticker would schedule a
            // frame every vsync for the rest of the session.
            _shimmerController.stop();
            setState(() => _dismissed = true);
          }
        },
        child: Material(
          color: const Color(0xFF000000),
          child: SizedBox.expand(
            child: PlatformInfo.isMobile
                ? OledLaunchScreen(
                    progress: !widget.libraryReady && warmup.isCompleted
                        ? 0.92
                        : warmup.progress,
                    finishing: isCompleted || warmup.isCompleted,
                    showContinue: warmup.canContinueAnyway,
                    onContinue: () =>
                        ref.read(appWarmupProvider.notifier).continueAnyway(),
                  )
                : DragToMoveArea(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Subtle Radial Background Glow
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.0, -0.15),
                                radius: 0.9,
                                colors: [
                                  const Color(
                                    0xFF18181C,
                                  ).withValues(alpha: 0.45),
                                  const Color(0xFF09090B),
                                  const Color(0xFF000000),
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Center Content (Shadcn Card)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C0C0E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.8,
                                      ),
                                      blurRadius: 40,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(26),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. Header (Glyph + App Title + Status Badge)
                                    _buildCardHeader(warmup),

                                    const Gap(22),

                                    // 2. Animated Progress Bar with Interior Shimmer
                                    _buildProgressBarSection(warmup, depState),

                                    const Gap(24),

                                    // 3. System Modules Checklist (Shadcn UI style)
                                    _buildStagesChecklist(warmup),

                                    // Optional Error / Fallback Button
                                    if (warmup.canContinueAnyway) ...[
                                      const Gap(18),
                                      OutlinedButton(
                                        onPressed: () => ref
                                            .read(appWarmupProvider.notifier)
                                            .continueAnyway(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFFAFAFA,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Continuer vers l\'application',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Footer subtle version tag
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'TapLoad • Architecture v${AppConfig.version}',
                              style: AppTypography.caption.copyWith(
                                color: const Color(0xFF52525B),
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(AppWarmupState warmup) {
    return Row(
      children: [
        // App Glyph in Obsidian square with fine border
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.download_rounded,
            color: Color(0xFFFAFAFA),
            size: 20,
          ),
        ),
        const Gap(14),
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAPLOAD',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFFFAFAFA),
                ),
              ),
              const Gap(2),
              Text(
                'Initialisation & préchauffage système',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFFA1A1AA),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Shadcn UI Status Badge with glowing green indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: warmup.isCompleted
                      ? const Color(0xFF10B981)
                      : const Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (warmup.isCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF38BDF8))
                              .withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const Gap(6),
              Text(
                warmup.isCompleted ? 'READY' : 'WARMUP',
                style: AppTypography.mono.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFFFAFAFA),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBarSection(
    AppWarmupState warmup,
    DependencyBootstrapState depState,
  ) {
    // If downloading a binary tool, reflect download progress
    final isDownloading = depState.fraction != null;
    final effectiveFraction = isDownloading
        ? depState.fraction!.clamp(0.0, 1.0)
        : (!widget.libraryReady && warmup.isCompleted
              ? 0.92
              : warmup.progress.clamp(0.0, 1.0));
    final percent = (effectiveFraction * 100).round();

    final statusText = isDownloading && depState.toolName.isNotEmpty
        ? 'Téléchargement de ${depState.toolName} ($percent%)...'
        : (!widget.libraryReady && warmup.isCompleted
              ? 'Chargement de la bibliothèque...'
              : warmup.statusMessage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label + Percent Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  statusText,
                  key: ValueKey(statusText),
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFFA1A1AA),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Gap(10),
            Text(
              '$percent%',
              style: AppTypography.mono.copyWith(
                color: const Color(0xFFFAFAFA),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Gap(8),

        // Animated Track with Interior Shimmer Wave
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 0.8,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: effectiveFraction),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  final fillWidth = maxWidth * animValue;

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) {
                          final offset = _shimmerController.value;
                          // Interior continuous gleaming shimmer wave
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.8 + (3.6 * offset), 0.0),
                                  end: Alignment(-0.8 + (3.6 * offset), 0.0),
                                  colors: [
                                    const Color(0xFFD4D4D8),
                                    Colors.white,
                                    const Color(0xFFD4D4D8),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStagesChecklist(AppWarmupState warmup) {
    return Column(
      children: warmup.stages.map((stage) {
        final waitingForLibrary =
            stage.id == WarmupStageId.storageCatalog && !widget.libraryReady;
        final status = waitingForLibrary
            ? WarmupStageStatus.running
            : stage.status;
        final description = waitingForLibrary
            ? 'Chargement de la bibliothèque sauvegardée...'
            : stage.description;
        final isDone = status == WarmupStageStatus.completed;
        final isRunning = status == WarmupStageStatus.running;
        final isFailed = status == WarmupStageStatus.failed;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isRunning
                ? const Color(0xFF18181B).withValues(alpha: 0.7)
                : const Color(0xFF111113),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRunning
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Status Indicator Icon
              if (isDone)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                )
              else if (isRunning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFAFAFA),
                  ),
                )
              else if (isFailed)
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: Color(0xFFEF4444),
                )
              else
                const Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: Color(0xFF3F3F46),
                ),

              const Gap(12),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDone || isRunning
                            ? const Color(0xFFFAFAFA)
                            : const Color(0xFF71717A),
                      ),
                    ),
                    const Gap(2),
                    Text(
                      description,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF52525B),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const Gap(8),

              // Mini Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : (isRunning
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDone
                      ? 'PRÊT'
                      : (isRunning
                            ? 'EN COURS'
                            : (isFailed ? 'ERREUR' : 'EN ATTENTE')),
                  style: AppTypography.mono.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDone
                        ? const Color(0xFF10B981)
                        : (isRunning
                              ? const Color(0xFFFAFAFA)
                              : const Color(0xFF52525B)),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
