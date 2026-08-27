import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Which vertical edge of the pane exposes resize handles (edge + both corners).
enum PaneResizeFrom { leading, trailing }

/// Fixed-width pane with grab handles on one edge and its two corners.
///
/// Resize tracks the pointer 1:1 (VS Code sash): the moving edge stays under
/// the grab point. Collapse snapping happens on pointer-up, not mid-drag.
class ResizableWidthPane extends StatefulWidget {
  final double width;
  final double minWidth;
  final double maxWidth;
  final PaneResizeFrom resizeFrom;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onToggleCollapse;
  final ValueChanged<bool>? onDragActive;
  final double? contentMinWidth;
  final Widget child;

  const ResizableWidthPane({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.resizeFrom,
    required this.onWidthChanged,
    this.onResizeEnd,
    this.onToggleCollapse,
    this.onDragActive,
    this.contentMinWidth,
    required this.child,
  });

  @override
  State<ResizableWidthPane> createState() => _ResizableWidthPaneState();
}

class _ResizableWidthPaneState extends State<ResizableWidthPane> {
  late double _liveWidth;
  bool _dragging = false;
  double _grabOffset = 0;

  @override
  void initState() {
    super.initState();
    _liveWidth = widget.width;
  }

  @override
  void didUpdateWidget(ResizableWidthPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.width != widget.width) {
      _liveWidth = widget.width;
    }
  }

  RenderBox? _paneBox() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box;
    return null;
  }

  void _onDragStart(Offset globalPosition) {
    _dragging = true;
    _liveWidth = widget.width;
    widget.onDragActive?.call(true);
    final box = _paneBox();
    if (box == null) {
      _grabOffset = 0;
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    if (widget.resizeFrom == PaneResizeFrom.trailing) {
      final edgeX = origin.dx + box.size.width;
      _grabOffset = globalPosition.dx - edgeX;
    } else {
      _grabOffset = globalPosition.dx - origin.dx;
    }
  }

  void _onDragUpdate(Offset globalPosition) {
    final box = _paneBox();
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final double next;
    if (widget.resizeFrom == PaneResizeFrom.trailing) {
      next = globalPosition.dx - origin.dx - _grabOffset;
    } else {
      final rightEdge = origin.dx + box.size.width;
      next = rightEdge - (globalPosition.dx - _grabOffset);
    }
    final clamped = next.clamp(widget.minWidth, widget.maxWidth);
    if (clamped == _liveWidth) return;
    _liveWidth = clamped;
    widget.onWidthChanged(_liveWidth);
  }

  void _onDragEnd() {
    _dragging = false;
    widget.onDragActive?.call(false);
    widget.onResizeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final minContent = widget.contentMinWidth;
    final useClipLayout = minContent != null && widget.width + 0.5 < minContent;
    final layoutWidth = useClipLayout ? minContent : widget.width;
    final clipAlignment = widget.resizeFrom == PaneResizeFrom.trailing
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Widget paneChild = useClipLayout
        ? OverflowBox(
            alignment: clipAlignment,
            minWidth: layoutWidth,
            maxWidth: layoutWidth,
            child: SizedBox(width: layoutWidth, child: widget.child),
          )
        : widget.child;
    return SizedBox(
      width: widget.width,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            paneChild,
            _PaneResizeOverlay(
              resizeFrom: widget.resizeFrom,
              onDragStart: _onDragStart,
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              onDoubleTap: widget.onToggleCollapse,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneResizeOverlay extends StatefulWidget {
  final PaneResizeFrom resizeFrom;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onDoubleTap;

  const _PaneResizeOverlay({
    required this.resizeFrom,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onDoubleTap,
  });

  @override
  State<_PaneResizeOverlay> createState() => _PaneResizeOverlayState();
}

class _PaneResizeOverlayState extends State<_PaneResizeOverlay> {
  bool _edgeHover = false;
  bool _topHover = false;
  bool _bottomHover = false;
  bool _dragging = false;

  bool get _active => _dragging || _edgeHover || _topHover || _bottomHover;

  bool get _isTrailing => widget.resizeFrom == PaneResizeFrom.trailing;

  void _setHover({bool? edge, bool? top, bool? bottom}) {
    setState(() {
      if (edge != null) _edgeHover = edge;
      if (top != null) _topHover = top;
      if (bottom != null) _bottomHover = bottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final handleColor = _active ? colors.primary : colors.border;
    final edgeCursor = SystemMouseCursors.resizeColumn;
    final topCursor = _isTrailing
        ? SystemMouseCursors.resizeUpRight
        : SystemMouseCursors.resizeUpLeft;
    final bottomCursor = _isTrailing
        ? SystemMouseCursors.resizeDownRight
        : SystemMouseCursors.resizeDownLeft;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          left: _isTrailing ? null : 0,
          right: _isTrailing ? 0 : null,
          width: 12,
          child: _DragHit(
            cursor: edgeCursor,
            onHover: (hover) => _setHover(edge: hover),
            onDragStart: (global) {
              setState(() => _dragging = true);
              widget.onDragStart(global);
            },
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: () {
              setState(() => _dragging = false);
              widget.onDragEnd();
            },
            onDoubleTap: widget.onDoubleTap,
            child: Align(
              alignment: _isTrailing
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                width: _active ? 2 : 1,
                color: handleColor,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: _isTrailing ? null : 0,
          right: _isTrailing ? 0 : null,
          width: 18,
          height: 18,
          child: _CornerHandle(
            resizeFrom: widget.resizeFrom,
            isTop: true,
            active: _active,
            color: handleColor,
            cursor: topCursor,
            onHover: (hover) => _setHover(top: hover),
            onDragStart: (global) {
              setState(() => _dragging = true);
              widget.onDragStart(global);
            },
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: () {
              setState(() => _dragging = false);
              widget.onDragEnd();
            },
          ),
        ),
        Positioned(
          bottom: 0,
          left: _isTrailing ? null : 0,
          right: _isTrailing ? 0 : null,
          width: 18,
          height: 18,
          child: _CornerHandle(
            resizeFrom: widget.resizeFrom,
            isTop: false,
            active: _active,
            color: handleColor,
            cursor: bottomCursor,
            onHover: (hover) => _setHover(bottom: hover),
            onDragStart: (global) {
              setState(() => _dragging = true);
              widget.onDragStart(global);
            },
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: () {
              setState(() => _dragging = false);
              widget.onDragEnd();
            },
          ),
        ),
      ],
    );
  }
}

class _CornerHandle extends StatelessWidget {
  final PaneResizeFrom resizeFrom;
  final bool isTop;
  final bool active;
  final Color color;
  final MouseCursor cursor;
  final ValueChanged<bool> onHover;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  const _CornerHandle({
    required this.resizeFrom,
    required this.isTop,
    required this.active,
    required this.color,
    required this.cursor,
    required this.onHover,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _DragHit(
      cursor: cursor,
      onHover: onHover,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      child: CustomPaint(
        painter: _CornerGripPainter(
          trailing: resizeFrom == PaneResizeFrom.trailing,
          top: isTop,
          color: color,
          emphasized: active,
        ),
      ),
    );
  }
}

class _DragHit extends StatelessWidget {
  final MouseCursor cursor;
  final ValueChanged<bool> onHover;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onDoubleTap;
  final Widget child;

  const _DragHit({
    required this.cursor,
    required this.onHover,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onDoubleTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) => onDragStart(details.globalPosition),
        onHorizontalDragUpdate: (details) =>
            onDragUpdate(details.globalPosition),
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: onDragEnd,
        onDoubleTap: onDoubleTap,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _CornerGripPainter extends CustomPainter {
  final bool trailing;
  final bool top;
  final Color color;
  final bool emphasized;

  _CornerGripPainter({
    required this.trailing,
    required this.top,
    required this.color,
    required this.emphasized,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = emphasized ? 2.4 : 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final inset = 3.0;
    final arm = emphasized ? 12.0 : 9.0;
    final x = trailing ? size.width - inset : inset;
    final y = top ? inset : size.height - inset;
    final dx = trailing ? -arm : arm;
    final dy = top ? arm : -arm;

    final path = Path()
      ..moveTo(x + dx, y)
      ..lineTo(x, y)
      ..lineTo(x, y + dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerGripPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.emphasized != emphasized ||
        oldDelegate.trailing != trailing ||
        oldDelegate.top != top;
  }
}
