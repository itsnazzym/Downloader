import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design_system/foundation/typography.dart';
import 'media_player_provider.dart';

/// iOS-style bottom chrome: capsule seek bar, remaining time, volume, speed.
class PlayerControls extends ConsumerStatefulWidget {
  final VoidCallback onInteraction;

  const PlayerControls({super.key, required this.onInteraction});

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  bool _dragging = false;
  double _dragValue = 0;
  bool _showSpeedMenu = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaPlayerProvider);
    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;
    final visualProgress = _dragging ? _dragValue : progress.clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SeekRow(
              progress: visualProgress,
              elapsed: _dragging
                  ? Duration(
                      milliseconds:
                          (visualProgress * state.duration.inMilliseconds)
                              .round(),
                    )
                  : state.position,
              remaining: _remaining(state.duration, visualProgress),
              onStart: (value) {
                widget.onInteraction();
                setState(() {
                  _dragging = true;
                  _dragValue = value;
                });
                ref.read(mediaPlayerProvider.notifier).startSeeking();
              },
              onUpdate: (value) {
                widget.onInteraction();
                setState(() => _dragValue = value);
                final preview = Duration(
                  milliseconds: (value * state.duration.inMilliseconds).round(),
                );
                ref.read(mediaPlayerProvider.notifier).seekPreview(preview);
              },
              onEnd: (value) {
                widget.onInteraction();
                setState(() {
                  _dragging = false;
                  _dragValue = value;
                });
                final position = Duration(
                  milliseconds: (value * state.duration.inMilliseconds).round(),
                );
                ref.read(mediaPlayerProvider.notifier).seek(position);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _VolumeControl(
                  volume: state.volume,
                  onChange: (volume) {
                    widget.onInteraction();
                    ref.read(mediaPlayerProvider.notifier).setVolume(volume);
                  },
                ),
                const Spacer(),
                _SpeedChip(
                  speed: state.playbackSpeed,
                  expanded: _showSpeedMenu,
                  onToggle: () {
                    widget.onInteraction();
                    setState(() => _showSpeedMenu = !_showSpeedMenu);
                  },
                  onSelect: (speed) {
                    widget.onInteraction();
                    ref
                        .read(mediaPlayerProvider.notifier)
                        .setPlaybackSpeed(speed);
                    setState(() => _showSpeedMenu = false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Duration _remaining(Duration duration, double progress) {
    final left = duration.inMilliseconds * (1.0 - progress);
    return Duration(
      milliseconds: left.round().clamp(0, duration.inMilliseconds),
    );
  }
}

class _SeekRow extends StatelessWidget {
  final double progress;
  final Duration elapsed;
  final Duration remaining;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  const _SeekRow({
    required this.progress,
    required this.elapsed,
    required this.remaining,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            _format(elapsed),
            style: AppTypography.mono.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IosSeekBar(
            progress: progress,
            onStart: onStart,
            onUpdate: onUpdate,
            onEnd: onEnd,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(
            '-${_format(remaining)}',
            textAlign: TextAlign.right,
            style: AppTypography.mono.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _IosSeekBar extends StatefulWidget {
  final double progress;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  const _IosSeekBar({
    required this.progress,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  State<_IosSeekBar> createState() => _IosSeekBarState();
}

class _IosSeekBarState extends State<_IosSeekBar> {
  bool _active = false;

  double _valueFromDx(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() => _active = true);
            widget.onStart(_valueFromDx(details.localPosition.dx, width));
          },
          onHorizontalDragUpdate: (details) {
            widget.onUpdate(_valueFromDx(details.localPosition.dx, width));
          },
          onHorizontalDragEnd: (details) {
            setState(() => _active = false);
            widget.onEnd(widget.progress);
          },
          onTapDown: (details) {
            setState(() => _active = true);
            widget.onStart(_valueFromDx(details.localPosition.dx, width));
          },
          onTapUp: (details) {
            final value = _valueFromDx(details.localPosition.dx, width);
            widget.onUpdate(value);
            widget.onEnd(value);
            setState(() => _active = false);
          },
          onTapCancel: () => setState(() => _active = false),
          child: SizedBox(
            height: 28,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: _active ? 8 : 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: widget.progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChange;

  const _VolumeControl({required this.volume, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          volume <= 0.001
              ? Icons.volume_off_rounded
              : volume < 0.4
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 18,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: _IosSeekBar(
            progress: volume.clamp(0.0, 1.0),
            onStart: onChange,
            onUpdate: onChange,
            onEnd: onChange,
          ),
        ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<double> onSelect;

  const _SpeedChip({
    required this.speed,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: expanded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _speeds.map((value) {
                    final active = value == speed;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => onSelect(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            value == 1.0 ? '1x' : '${value}x',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: active ? 1 : 0.55,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      speed == 1.0 ? '1x' : '${speed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

String _format(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
