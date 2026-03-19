import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/typography.dart';
import 'media_player_provider.dart';

/// Glassmorphism control bar for the media player
class PlayerControls extends StatefulWidget {
  final MediaPlayerState playerState;
  final String? currentFile;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekPreview;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChange;
  final ValueChanged<double> onSpeedChange;

  const PlayerControls({
    super.key,
    required this.playerState,
    this.currentFile,
    required this.onPlayPause,
    required this.onSeekStart,
    required this.onSeekPreview,
    required this.onSeek,
    required this.onVolumeChange,
    required this.onSpeedChange,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _showSpeedMenu = false;
  double _dragValue = 0.0;

  // Preview player — lazily created on first seek drag
  Player? _previewPlayer;
  VideoController? _previewController;
  bool _previewReady = false;
  String? _previewFile;

  // Overlay for the preview popup (renders above ClipRect)
  OverlayEntry? _previewOverlay;

  // Key to measure slider position and width
  final GlobalKey _sliderKey = GlobalKey();

  /// Create the preview player on demand
  void _ensurePreviewPlayerCreated() {
    if (_previewPlayer != null) return;
    _previewPlayer = Player();
    _previewPlayer!.setVolume(0);
    _previewController = VideoController(_previewPlayer!);
  }

  @override
  void dispose() {
    _removePreviewOverlay();
    try {
      _previewPlayer?.dispose();
    } catch (_) {
      // media_kit native cleanup can race during hot restart — safe to ignore
    }
    super.dispose();
  }

  /// Open the same file in preview player (lazy)
  Future<void> _ensurePreviewReady() async {
    final file = widget.currentFile;
    if (file == null) return;
    if (_previewFile == file && _previewReady) return;

    _ensurePreviewPlayerCreated();
    _previewFile = file;
    _previewReady = false;
    await _previewPlayer!.open(Media(file), play: false);
    await _previewPlayer!.setVolume(0);
    if (mounted) {
      _previewReady = true;
    }
  }

  /// Get the global position and size of the slider
  Rect? _getSliderRect() {
    final renderBox =
        _sliderKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final topLeft = renderBox.localToGlobal(Offset.zero);
    return topLeft & renderBox.size;
  }

  /// Calculate the global X position of the thumb
  double _getThumbGlobalX(Rect sliderRect) {
    // Flutter's Slider uses the overlay radius as horizontal padding
    const double overlayRadius = 14; // matches our SliderThemeData
    final trackLeft = sliderRect.left + overlayRadius;
    final trackRight = sliderRect.right - overlayRadius;
    final trackWidth = trackRight - trackLeft;
    return trackLeft + (_dragValue.clamp(0.0, 1.0) * trackWidth);
  }

  void _showPreviewOverlay() {
    _removePreviewOverlay();

    _previewOverlay = OverlayEntry(
      builder: (context) {
        final sliderRect = _getSliderRect();
        if (sliderRect == null) return const SizedBox.shrink();

        const previewWidth = 160.0;
        const previewHeight = 110.0; // 90 video + 4 gap + ~16 label
        final thumbX = _getThumbGlobalX(sliderRect);

        // Center preview horizontally on thumb, clamp to screen edges
        final screenWidth = MediaQuery.of(context).size.width;
        final left = (thumbX - previewWidth / 2).clamp(
          8.0,
          screenWidth - previewWidth - 8,
        );

        // Position above the slider
        final top = sliderRect.top - previewHeight - 12;

        return Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: _SeekPreviewPopup(
              controller: _previewController!,
              timeLabel: _formatPreviewTime(),
              isReady: _previewReady,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_previewOverlay!);
  }

  void _updatePreviewOverlay() {
    _previewOverlay?.markNeedsBuild();
  }

  void _removePreviewOverlay() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }

  void _onDragStart(double value) {
    _ensurePreviewReady();
    _dragValue = value;
    widget.onSeekStart();
    _showPreviewOverlay();
  }

  void _onDragUpdate(double value) {
    setState(() => _dragValue = value);

    final previewPos = Duration(
      milliseconds: (value * widget.playerState.duration.inMilliseconds)
          .round(),
    );
    widget.onSeekPreview(previewPos);

    // Seek the preview player to show the frame
    if (_previewReady) {
      _previewPlayer!.seek(previewPos);
    }

    _updatePreviewOverlay();
  }

  void _onDragEnd(double value) {
    _removePreviewOverlay();

    final newPosition = Duration(
      milliseconds: (value * widget.playerState.duration.inMilliseconds)
          .round(),
    );
    widget.onSeek(newPosition);
  }

  String _formatPreviewTime() {
    final ms = (_dragValue * widget.playerState.duration.inMilliseconds)
        .round();
    final d = Duration(milliseconds: ms);
    return _formatDuration(d);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.playerState;
    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seek bar
                SliderTheme(
                  key: _sliderKey,
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChangeStart: _onDragStart,
                    onChanged: _onDragUpdate,
                    onChangeEnd: _onDragEnd,
                  ),
                ),

                SizedBox(height: 4),

                // Controls row
                Row(
                  children: [
                    // Time display
                    Text(
                      '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
                      style: AppTypography.mono.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),

                    const Spacer(),

                    // Speed button
                    _ControlButton(
                      onTap: () =>
                          setState(() => _showSpeedMenu = !_showSpeedMenu),
                      child: Text(
                        '${state.playbackSpeed}x',
                        style: TextStyle(
                          color: state.playbackSpeed != 1.0
                              ? AppColors.info
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(width: 8),

                    // Volume
                    Icon(
                      state.volume == 0
                          ? Icons.volume_off
                          : state.volume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.2,
                          ),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: Slider(
                          value: state.volume.clamp(0.0, 1.0),
                          onChanged: widget.onVolumeChange,
                        ),
                      ),
                    ),

                    SizedBox(width: 16),

                    // Play/Pause
                    _ControlButton(
                      onTap: widget.onPlayPause,
                      child: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),

                // Speed menu
                if (_showSpeedMenu) ...[
                  SizedBox(height: 8),
                  _SpeedMenu(
                    currentSpeed: state.playbackSpeed,
                    onSelect: (speed) {
                      widget.onSpeedChange(speed);
                      setState(() => _showSpeedMenu = false);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// -------------------------------------------------------------------
// Seek Preview Popup — rendered via OverlayEntry above all widgets
// -------------------------------------------------------------------
class _SeekPreviewPopup extends StatelessWidget {
  final VideoController controller;
  final String timeLabel;
  final bool isReady;

  const _SeekPreviewPopup({
    required this.controller,
    required this.timeLabel,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video frame
        Container(
          width: 160,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isReady
              ? Video(
                  controller: controller,
                  controls: NoVideoControls,
                  fill: Colors.black,
                )
              : Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
        ),

        SizedBox(height: 4),

        // Time label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            timeLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// Control Button
// -------------------------------------------------------------------
class _ControlButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _ControlButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}

// -------------------------------------------------------------------
// Speed Menu
// -------------------------------------------------------------------
class _SpeedMenu extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSelect;

  const _SpeedMenu({required this.currentSpeed, required this.onSelect});

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _speeds.map((speed) {
          final isActive = speed == currentSpeed;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => onSelect(speed),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
