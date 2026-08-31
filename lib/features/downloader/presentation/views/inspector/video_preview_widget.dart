import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player_win/video_player_win.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:glass/glass.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

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
  int _initToken = 0;

  Future<void> _initializeController() async {
    final token = ++_initToken;
    final file = File(widget.filePath);
    try {
      if (!await file.exists()) {
        if (!mounted || token != _initToken || !_isHovering) return;
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Error checking video file: $e");
      if (!mounted || token != _initToken || !_isHovering) return;
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    WinVideoPlayerController? controller;
    try {
      controller = WinVideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted || token != _initToken || !_isHovering) {
        await _disposeController(controller);
        return;
      }
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.setLooping(true);
      if (!mounted || token != _initToken || !_isHovering) {
        await _disposeController(controller);
        return;
      }
      _controller = controller;
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      try {
        await controller.play();
      } catch (e) {
        debugPrint("Error playing win_video_player: $e");
      }
    } catch (e) {
      debugPrint("Error initializing win_video_player: $e");
      await _disposeController(controller);
      if (!mounted || token != _initToken || !_isHovering) return;
      setState(() {
        _hasError = true;
        _isInitialized = false;
        _controller = null;
      });
    }
  }

  Future<void> _disposeController(WinVideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint("Error disposing win_video_player: $e");
    }
  }

  void _unmountPlayer({bool notify = true}) {
    _initToken++;
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    _isDragging = false;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_disposeController(controller));
      });
    }
    if (notify && mounted) setState(() {});
  }

  void _onHoverEnter() {
    if (_isHovering) return;
    setState(() {
      _isHovering = true;
      _hasError = false;
    });
    if (_controller != null && _isInitialized) {
      try {
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
        _controller!.play();
      } catch (e) {
        debugPrint("Error playing win_video_player: $e");
      }
      return;
    }
    unawaited(_initializeController());
  }

  void _onHoverExit() {
    if (!_isHovering && _controller == null) return;
    _isHovering = false;
    _hasError = false;
    _unmountPlayer();
  }

  @override
  void dispose() {
    _initToken++;
    final controller = _controller;
    _controller = null;
    unawaited(_disposeController(controller));
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _hasError = false;
      _unmountPlayer(notify: false);
      if (_isHovering) {
        unawaited(_initializeController());
      }
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

  Widget _buildErrorPreview(BuildContext context) {
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
                context.l10n.previewUnavailable,
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
                  label: Text(context.l10n.openFullscreen),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: _isHovering && _hasError
          ? _buildErrorPreview(context)
          : _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final controller = _controller;
    final showPlayer = _isHovering && _isInitialized && controller != null;

    return Container(
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
          if (widget.thumbnailUrl != null && !showPlayer)
            Positioned.fill(child: _buildThumbnailBackground(context)),

          // Native Windows Player — excluded from semantics to avoid AXTree errors
          if (showPlayer)
            ExcludeSemantics(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: WinVideoPlayer(controller),
                  ),
                ),
              ),
            ),

          // Glassmorphism Overlay (Bottom Scrubber & Mute)
          if (showPlayer)
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
                        valueListenable: controller,
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
                            valueListenable: controller,
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

          if (_isHovering && !_isInitialized)
            Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.of(context).primary,
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
