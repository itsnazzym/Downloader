import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player_win/video_player_win.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:glass/glass.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String filePath;
  final String? thumbnailUrl;

  const VideoPreviewWidget({
    super.key,
    required this.filePath,
    this.thumbnailUrl,
    this.onFullscreen,
  });

  final VoidCallback? onFullscreen;

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  WinVideoPlayerController? _controller;
  bool _isHovering = false;
  bool _isMuted = true;
  bool _isInitialized = false;
  bool _hasError = false;
  DateTime? _lastSeekTime;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    final file = File(widget.filePath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
      return;
    }

    try {
      _controller = WinVideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      await _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing win_video_player: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _isInitialized = false;
      _hasError = false;
      _controller?.dispose();
      _controller = null;
      _initializeController();
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  Widget _buildThumbnailBackground(BuildContext context) {
    final url = widget.thumbnailUrl;
    if (url == null) return const SizedBox();

    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      );
    }

    String decodedPath = url;
    try {
      decodedPath = Uri.decodeFull(url);
    } catch (_) {}
    final file = File(decodedPath);
    if (!file.existsSync()) return const SizedBox();
    return Image.file(
      file,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0.4, child: _buildThumbnailBackground(context)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.movie_creation_outlined,
                  size: 48,
                  color: AppColors.of(context).textSecondary,
                ),
                const Gap(8),
                Text(
                  'Preview unavailable',
                  style: TextStyle(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (widget.onFullscreen != null) ...[
                  const Gap(12),
                  TextButton.icon(
                    onPressed: widget.onFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                    label: const Text('Open fullscreen'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.thumbnailUrl != null)
              Opacity(opacity: 0.3, child: _buildThumbnailBackground(context)),
            Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.of(context).primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        if (_controller != null && _isInitialized) {
          _controller!.setVolume(_isMuted ? 0.0 : 1.0);
          _controller!.play();
        }
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _controller?.pause();
      },
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.of(context).primary.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail / Background when not playing
            if (widget.thumbnailUrl != null && !_isHovering)
              Positioned.fill(child: _buildThumbnailBackground(context)),

            // Native Windows Player — excluded from semantics to avoid AXTree errors
            ExcludeSemantics(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: WinVideoPlayer(_controller!),
                  ),
                ),
              ),
            ),

            // Glassmorphism Overlay (Bottom Scrubber & Mute)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: 300.ms,
                opacity: _isHovering ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ultra-thin scrubber
                      ValueListenableBuilder(
                        valueListenable: _controller!,
                        builder: (context, value, child) {
                          final duration = value.duration.inMilliseconds
                              .toDouble();
                          final position = value.position.inMilliseconds
                              .toDouble();
                          final progress = duration > 0
                              ? position / duration
                              : 0.0;

                          return GestureDetector(
                            onPanStart: (_) {
                              setState(() => _isDragging = true);
                              _controller?.pause();
                            },
                            onPanEnd: (_) {
                              setState(() => _isDragging = false);
                              if (_isHovering) _controller?.play();
                            },
                            onTapDown: (details) =>
                                _handleSeek(details.localPosition.dx, context),
                            onPanUpdate: (details) =>
                                _handleSeek(details.localPosition.dx, context),
                            child: Container(
                              height: 20,
                              width: double.infinity,
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Container(
                                height: _isDragging ? 6 : 3,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.of(context).primary,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.of(context).primary
                                              .withValues(
                                                alpha: _isDragging ? 0.8 : 0.5,
                                              ),
                                          blurRadius: _isDragging ? 8 : 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          // Time info
                          ValueListenableBuilder(
                            valueListenable: _controller!,
                            builder: (context, value, child) {
                              return Text(
                                _formatDuration(value.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          // Mute Toggle (Glass)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleMute,
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      _isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ).asGlass(
                                    blurX: 10,
                                    blurY: 10,
                                    clipBorderRadius: BorderRadius.circular(8),
                                  ),
                            ),
                          ),
                          const Gap(8),
                          // Fullscreen Button
                          if (widget.onFullscreen != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onFullscreen,
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ).asGlass(
                                      blurX: 10,
                                      blurY: 10,
                                      clipBorderRadius: BorderRadius.circular(
                                        8,
                                      ),
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Center Play Icon if not hovering
            if (!_isHovering)
              IgnorePointer(
                child:
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 54,
                    ).animate().scale(
                      delay: 100.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleSeek(double localX, BuildContext context) {
    if (_controller == null || !_isInitialized) return;

    // Throttle seeks to 15fps max to avoid overloading the engine
    final now = DateTime.now();
    if (_lastSeekTime != null &&
        now.difference(_lastSeekTime!) < const Duration(milliseconds: 60)) {
      return;
    }
    _lastSeekTime = now;

    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    if (width <= 0) return;

    final double relative = localX / width;
    final double targetMs =
        _controller!.value.duration.inMilliseconds.toDouble() *
        relative.clamp(0.0, 1.0);
    _controller!.seekTo(Duration(milliseconds: targetMs.toInt()));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
