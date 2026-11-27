import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/widgets/download_search_field.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/core/ui/shell/desktop_destinations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

import 'porcelaine_library.dart';
import 'porcelaine_states.dart';
import 'porcelaine_tiles.dart';
import 'porcelaine_widgets.dart';
import 'porcelaine_workspace_model.dart';

/// Porcelaine's home: the Espace, a grid of widgets the user arranges
/// (Espace.dc.html), or the whole library when « Toute la bibliothèque » is
/// open.
class PorcelaineHome extends ConsumerWidget {
  const PorcelaineHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A search left running (Ctrl+F, the chrome) shows its results.
    final open =
        ref.watch(porcelaineLibraryOpenProvider) ||
        ref.watch(downloadSearchQueryProvider.select((q) => q.isNotEmpty));
    return open ? const _Library() : const _Espace();
  }
}

// ── The Espace ─────────────────────────────────────────────────────────────

const _rowHeight = 180.0;

class _Espace extends ConsumerStatefulWidget {
  const _Espace();

  @override
  ConsumerState<_Espace> createState() => _EspaceState();
}

class _EspaceState extends ConsumerState<_Espace>
    with TickerProviderStateMixin {
  late final AnimationController _wiggle;
  // The cards' once-only entrance.
  late final AnimationController _enter;
  // The En cours card's « finished » glow.
  late final AnimationController _finish;
  bool _entered = false;
  String? _dragId;
  String? _removingId;
  String? _freshId;
  String? _resizingId;
  (PWidget, int)? _toast;
  Timer? _toastTimer;
  Timer? _freshTimer;
  late final PWorkspaceNotifier _notifier;
  late final StateController<DownloadItem?> _finished;

  // Resize drag: start size and the pointer travel since.
  Offset _rzDelta = Offset.zero;
  PWidgetSize _rzFrom = PWidgetSize.small;

  @override
  void initState() {
    super.initState();
    _finish = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener(_onFinishStatus);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _notifier = ref.read(porcelaineWorkspaceProvider.notifier);
    _finished = ref.read(porcelaineFinishProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  void _onFinishStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _finished.mounted) {
      _finished.state = null;
    }
  }

  void _onList(
    AsyncValue<List<DownloadItem>>? prev,
    AsyncValue<List<DownloadItem>> next,
  ) {
    final items = next.valueOrNull;
    if (items == null || MediaQuery.disableAnimationsOf(context)) return;
    final done = pJustFinished(prev?.valueOrNull, items);
    if (done.isEmpty) return;
    _finished.state = done.last;
    _finish.forward(from: 0);
  }

  @override
  void dispose() {
    _wiggle.dispose();
    _enter.dispose();
    _finish.dispose();
    _toastTimer?.cancel();
    _freshTimer?.cancel();
    final notifier = _notifier;
    final finish = _finished;
    // Leaving the page ends edit mode (the dock's buttons belong to it) and
    // any « finished » moment.
    Future.microtask(() {
      if (notifier.mounted) notifier.setEditing(false);
      if (finish.mounted) finish.state = null;
    });
    super.dispose();
  }

  void _syncWiggle(bool editing) {
    final run = editing && !MediaQuery.disableAnimationsOf(context);
    if (run && !_wiggle.isAnimating) _wiggle.repeat(reverse: true);
    if (!run && _wiggle.isAnimating) _wiggle.stop();
  }

  void _remove(String id) {
    setState(() => _removingId = id);
    final delay = MediaQuery.disableAnimationsOf(context) ? 0 : 220;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      final removed = _notifier.remove(id);
      _toastTimer?.cancel();
      setState(() {
        _removingId = null;
        _toast = removed;
      });
      _toastTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _toast = null);
      });
    });
  }

  void _undo() {
    final t = _toast;
    if (t == null) return;
    _toastTimer?.cancel();
    _notifier.restore(t.$1, t.$2);
    setState(() => _toast = null);
  }

  void _markFresh(String id) {
    _freshTimer?.cancel();
    setState(() => _freshId = id);
    _freshTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _freshId = null);
    });
  }

  Future<void> _openCatalog() async {
    final id = await showPorcelaineCatalog(context);
    if (id != null && mounted) _markFresh(id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(porcelaineWorkspaceProvider);
    final editing = state.editing;
    _syncWiggle(editing);
    ref.listen(porcelaineCatalogRequestProvider, (_, _) => _openCatalog());
    ref.listen(downloadListProvider, _onList);
    // -1 loading, -2 unreadable, else how many items.
    final phase = ref.watch(
      downloadListProvider.select(
        (v) => v.hasValue ? v.value!.length : (v.hasError ? -2 : -1),
      ),
    );
    final failed = ref.watch(
      downloadListProvider.select(
        (v) => _FailedIds([
          for (final i in v.valueOrNull ?? const <DownloadItem>[])
            if (i.status == DownloadStatus.failed) i,
        ]),
      ),
    );
    // A context menu's « details » selects an item: the inspector lives with
    // the full library.
    ref.listen(selectedDownloadIdProvider, (_, next) {
      if (next != null) {
        ref.read(porcelaineLibraryOpenProvider.notifier).state = true;
      }
    });
    void search() {
      ref.read(porcelaineLibraryOpenProvider.notifier).state = true;
      // The library's search field exists once the next frame is built.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => DownloadSearchFocus.request(),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (editing) _notifier.setEditing(false);
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): search,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): search,
      },
      child: Stack(
        children: [
          // `.page::before`: the dotted board shown while editing.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: editing ? 1 : 0,
                duration: pMotion(context, 350),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DotsPainter(
                      colors.textPrimary.withValues(alpha: 0.13),
                    ),
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 900;
              final side = box.maxWidth > 1284
                  ? (box.maxWidth - 1220) / 2
                  : 32.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, 0, side, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    _Greeting(editing: editing),
                    const SizedBox(height: 30),
                    if (phase == -2) ...[
                      PRise(
                        animation: _enter,
                        index: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pCardFill(colors),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: pCardShadow(colors),
                          ),
                          child: const PLoadError(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (phase == 0 && !editing) ...[
                      PRise(
                        animation: _enter,
                        index: 0,
                        child: const PEmptyLibrary(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // One failure is told by the Récents widget; several get the strip.
                    if (failed.items.length > 1 && !editing) ...[
                      PFailureStrip(failed: failed.items),
                      const SizedBox(height: 20),
                    ],
                    _Grid(
                      enter: _enter,
                      finish: _finish,
                      widgets: state.widgets,
                      editing: editing,
                      cols: wide ? 4 : 2,
                      gap: wide ? 20 : 14,
                      width: box.maxWidth - side * 2,
                      wiggle: _wiggle,
                      dragId: _dragId,
                      removingId: _removingId,
                      freshId: _freshId,
                      resizingId: _resizingId,
                      onDragStart: (id) => setState(() => _dragId = id),
                      onDragEnd: () {
                        setState(() => _dragId = null);
                        _notifier.save();
                      },
                      onHover: (dragged, index) =>
                          _notifier.move(dragged, index, persist: false),
                      onRemove: _remove,
                      onAdd: _openCatalog,
                      onResizeStart: (w) {
                        _rzDelta = Offset.zero;
                        _rzFrom = w.size;
                        setState(() => _resizingId = w.id);
                      },
                      onResizeUpdate: (w, delta, unit) {
                        _rzDelta += delta;
                        final cols = (_rzFrom.cols + _rzDelta.dx / unit.width)
                            .round()
                            .clamp(1, 2);
                        final rows = (_rzFrom.rows + _rzDelta.dy / unit.height)
                            .round()
                            .clamp(1, 2);
                        _notifier.setSize(
                          w.id,
                          PWidgetSize.fromSpan(cols, rows),
                          persist: false,
                        );
                      },
                      onResizeEnd: () {
                        setState(() => _resizingId = null);
                        _notifier.save();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: _Toast(
                  text: l10n.porcelaineRemoved(
                    pWidgetName(l10n, _toast!.$1.type),
                  ),
                  action: l10n.cancel,
                  onAction: _undo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final now = DateTime.now();
    final String subtitle;
    final loading = ref.watch(
      downloadListProvider.select((v) => !v.hasValue && !v.hasError),
    );
    if (editing) {
      subtitle = l10n.porcelaineEditHint;
    } else if (loading) {
      subtitle = l10n.porcelaineLoadingLibrary;
    } else {
      final count = ref.watch(
        downloadListProvider.select(
          (v) => (v.valueOrNull ?? const <DownloadItem>[])
              .where(isActiveDownload)
              .length,
        ),
      );
      final speed = ref.watch(porcelaineSpeedProvider.select((h) => h.now));
      final (n, u) = pSpeedParts(l10n, speed);
      final date = DateFormat('EEEE d MMMM', l10n.localeName).format(now);
      final day = date.isEmpty
          ? date
          : date[0].toUpperCase() + date.substring(1);
      subtitle = count == 0
          ? '$day · ${l10n.porcelaineIdle}'
          : '$day · ${l10n.porcelaineActiveNow(count, '$n $u')}';
    }
    return Column(
      children: [
        Text(
          now.hour >= 18 || now.hour < 5
              ? l10n.porcelaineGoodEvening
              : l10n.porcelaineGoodMorning,
          style: pDisp(40, color: colors.textPrimary).copyWith(height: 1.05),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: pBody(colors, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 11.0; y < size.height; y += 22) {
      for (var x = 11.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

// ── The grid ───────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  const _Grid({
    required this.enter,
    required this.finish,
    required this.widgets,
    required this.editing,
    required this.cols,
    required this.gap,
    required this.width,
    required this.wiggle,
    required this.dragId,
    required this.removingId,
    required this.freshId,
    required this.resizingId,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onHover,
    required this.onRemove,
    required this.onAdd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final Animation<double> enter;
  final Animation<double> finish;
  final List<PWidget> widgets;
  final bool editing;
  final int cols;
  final double gap;
  final double width;
  final Animation<double> wiggle;
  final String? dragId;
  final String? removingId;
  final String? freshId;
  final String? resizingId;
  final ValueChanged<String> onDragStart;
  final VoidCallback onDragEnd;
  final void Function(String dragged, int index) onHover;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<PWidget> onResizeStart;
  final void Function(PWidget w, Offset delta, Size unit) onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final cell = (width - gap * (cols - 1)) / cols;
    final unit = Size(cell + gap, _rowHeight + gap);
    final cells = packWorkspace(
      [for (final w in widgets) w.size],
      cols,
      extraSmall: editing ? 1 : 0,
    );
    var rows = 0;
    for (var i = 0; i < cells.length; i++) {
      final h = i < widgets.length ? widgets[i].size.rows : 1;
      if (cells[i].$2 + h > rows) rows = cells[i].$2 + h;
    }
    if (widgets.isEmpty) rows = 2;
    final height = rows * _rowHeight + (rows - 1) * gap;
    Rect rectOf(int i, int w, int h) {
      final (c, r) = cells[i];
      final span = w.clamp(1, cols);
      return Rect.fromLTWH(
        c * unit.width,
        r * unit.height,
        span * cell + (span - 1) * gap,
        h * _rowHeight + (h - 1) * gap,
      );
    }

    final duration = pMotion(context, 340);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widgets.isEmpty)
            Positioned.fill(child: _EmptyBoard(onAdd: onAdd)),
          for (var i = 0; i < widgets.length; i++)
            () {
              final w = widgets[i];
              final r = rectOf(i, w.size.cols, w.size.rows);
              return AnimatedPositioned.fromRect(
                key: ValueKey(w.id),
                rect: r,
                duration: duration,
                curve: pEase,
                child: PRise(
                  animation: enter,
                  index: i,
                  child: _Cell(
                    finish: w.type == PWidgetType.active ? finish : null,
                    widget: w,
                    index: i,
                    count: widgets.length,
                    size: r.size,
                    unit: unit,
                    editing: editing,
                    wiggle: wiggle,
                    ghost: dragId == w.id,
                    removing: removingId == w.id,
                    fresh: freshId == w.id,
                    lifting: resizingId == w.id,
                    onDragStart: () => onDragStart(w.id),
                    onDragEnd: onDragEnd,
                    onHover: (dragged) => onHover(dragged, i),
                    onRemove: () => onRemove(w.id),
                    onResizeStart: () => onResizeStart(w),
                    onResizeUpdate: (d) => onResizeUpdate(w, d, unit),
                    onResizeEnd: onResizeEnd,
                  ),
                ),
              );
            }(),
          if (editing && widgets.isNotEmpty)
            () {
              final r = rectOf(widgets.length, 1, 1);
              return AnimatedPositioned.fromRect(
                key: const ValueKey('add-tile'),
                rect: r,
                duration: duration,
                curve: pEase,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (d) {
                    onHover(d.data, widgets.length - 1);
                    return true;
                  },
                  builder: (context, _, _) => _AddTile(onTap: onAdd),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _Cell extends ConsumerStatefulWidget {
  const _Cell({
    this.finish,
    required this.widget,
    required this.index,
    required this.count,
    required this.size,
    required this.unit,
    required this.editing,
    required this.wiggle,
    required this.ghost,
    required this.removing,
    required this.fresh,
    required this.lifting,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onHover,
    required this.onRemove,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  /// The « finished » moment, on the En cours card only.
  final Animation<double>? finish;
  final PWidget widget;
  final int index;
  final int count;
  final Size size;
  final Size unit;
  final bool editing;
  final Animation<double> wiggle;
  final bool ghost;
  final bool removing;
  final bool fresh;
  final bool lifting;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onHover;
  final VoidCallback onRemove;
  final VoidCallback onResizeStart;
  final ValueChanged<Offset> onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  ConsumerState<_Cell> createState() => _CellState();
}

class _CellState extends ConsumerState<_Cell> {
  bool _hover = false;
  bool _focused = false;
  bool _menuOpen = false;

  PWorkspaceNotifier get _notifier =>
      ref.read(porcelaineWorkspaceProvider.notifier);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.editing || event is KeyUpEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final back = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    final fwd = rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    if (event.logicalKey == back) {
      _notifier.move(widget.widget.id, widget.index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == fwd) {
      _notifier.move(widget.widget.id, widget.index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      widget.onRemove();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final w = widget.widget;
    final name = pWidgetName(l10n, w.type);
    final editing = widget.editing;
    final up = !editing && (_hover || _menuOpen);
    final List<BoxShadow> shadow;
    if (widget.ghost) {
      shadow = [
        BoxShadow(
          color: colors.primary.withValues(alpha: 0.1),
          spreadRadius: 6,
        ),
      ];
    } else if (widget.fresh) {
      shadow = [
        BoxShadow(
          color: colors.primary.withValues(alpha: 0.18),
          spreadRadius: 7,
        ),
        ...pCardShadow(colors, up: true),
      ];
    } else if (widget.lifting) {
      shadow = [
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.1),
          spreadRadius: 1,
        ),
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.35),
          blurRadius: 70,
          spreadRadius: -14,
          offset: const Offset(0, 36),
        ),
      ];
    } else {
      shadow = pCardShadow(colors, up: up);
    }
    final border = widget.ghost
        ? Border.all(color: colors.primary.withValues(alpha: 0.55), width: 2)
        : (widget.fresh || (_focused && editing))
        ? Border.all(color: colors.primary, width: 2)
        : null;
    final card = AnimatedContainer(
      duration: pMotion(context, 300),
      curve: pEase,
      width: widget.size.width,
      height: widget.size.height,
      transform: Matrix4.translationValues(
        0,
        up ? -3 : (widget.lifting ? -6 : 0),
        0,
      ),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.ghost
            ? Color.alphaBlend(
                colors.primary.withValues(alpha: 0.05),
                colors.background,
              )
            : pCardFill(colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: shadow,
        border: border,
      ),
      child: AnimatedOpacity(
        opacity: widget.ghost ? 0.25 : 1,
        duration: pMotion(context, 200),
        child: IgnorePointer(
          ignoring: editing,
          child: pTileFor(w.type, w.size),
        ),
      ),
    );

    final controls = <Widget>[
      if (!editing)
        Positioned(
          top: 16,
          right: 16,
          child: AnimatedOpacity(
            opacity: _hover || _menuOpen || _focused ? 1 : 0,
            duration: pMotion(context, 180),
            child: _MoreMenu(
              widget: w,
              name: name,
              onOpen: (v) => setState(() => _menuOpen = v),
              onRemove: widget.onRemove,
              onFocus: (v) => setState(() => _focused = v),
            ),
          ),
        ),
      if (editing) ...[
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _RoundButton(
            icon: Icons.remove_rounded,
            tooltip: l10n.porcelaineRemoveWidget(name),
            onTap: widget.onRemove,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: _EditBar(
              widget: w,
              isFirst: widget.index == 0,
              isLast: widget.index == widget.count - 1,
              onBack: () => _notifier.move(w.id, widget.index - 1),
              onForward: () => _notifier.move(w.id, widget.index + 1),
              onSize: (s) => _notifier.setSize(w.id, s),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: _ResizeHandle(
            tooltip: l10n.porcelaineResizeHint,
            onStart: widget.onResizeStart,
            onUpdate: widget.onResizeUpdate,
            onEnd: widget.onResizeEnd,
          ),
        ),
      ],
    ];

    // One tree in and out of edit mode, so the tiles keep their state.
    final body = Draggable<String>(
      data: w.id,
      maxSimultaneousDrags: editing && !widget.lifting ? 1 : 0,
      onDragStarted: widget.onDragStart,
      onDragEnd: (_) => widget.onDragEnd(),
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            width: widget.size.width,
            height: widget.size.height,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: pCardFill(colors),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.1),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.35),
                  blurRadius: 70,
                  spreadRadius: -14,
                  offset: const Offset(0, 36),
                ),
              ],
            ),
            child: IgnorePointer(child: pTileFor(w.type, w.size, keyed: false)),
          ),
        ),
      ),
      childWhenDragging: card,
      child: MouseRegion(
        cursor: editing ? SystemMouseCursors.grab : MouseCursor.defer,
        child: card,
      ),
    );

    final finish = widget.finish;
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        // The halo behind the card, the ring over it.
        if (finish != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _FinishGlow(animation: finish, halo: true),
            ),
          ),
        body,
        if (finish != null)
          Positioned.fill(
            child: IgnorePointer(child: _FinishGlow(animation: finish)),
          ),
        ...controls,
      ],
    );
    final tilt = widget.index.isEven ? 1.0 : -1.0;
    final cell = RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.wiggle,
        builder: (context, child) => Transform.rotate(
          // ±0.4° like `@keyframes wig`, every other card in phase opposition.
          angle: !editing || widget.ghost || widget.lifting
              ? 0
              : tilt * (widget.wiggle.value * 2 - 1) * 0.007,
          child: child,
        ),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (d) {
            if (!editing || d.data == w.id) return false;
            widget.onHover(d.data);
            return true;
          },
          builder: (context, _, _) => stack,
        ),
      ),
    );

    return Semantics(
      container: true,
      label: '$name, ${pSizeName(l10n, w.size).toLowerCase()}',
      child: Focus(
        canRequestFocus: editing,
        onKeyEvent: _onKey,
        onFocusChange: (v) => setState(() => _focused = v),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedScale(
            scale: widget.removing ? 0.86 : 1,
            duration: pMotion(context, 220),
            curve: Curves.easeIn,
            child: AnimatedOpacity(
              opacity: widget.removing ? 0 : 1,
              duration: pMotion(context, 220),
              child: cell,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.more` + `.menu`: sizes, the widget's own shortcuts, remove.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({
    required this.widget,
    required this.name,
    required this.onOpen,
    required this.onRemove,
    required this.onFocus,
  });

  final PWidget widget;
  final String name;
  final ValueChanged<bool> onOpen;
  final VoidCallback onRemove;
  final ValueChanged<bool> onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(porcelaineWorkspaceProvider.notifier);
    final item = pBody(colors, size: 13);
    PopupMenuItem<VoidCallback> entry(
      VoidCallback action,
      Widget child, {
      bool danger = false,
    }) => PopupMenuItem<VoidCallback>(
      value: action,
      height: 34,
      child: DefaultTextStyle(
        style: item.copyWith(color: danger ? colors.error : colors.textPrimary),
        child: child,
      ),
    );
    final extras = <(String, VoidCallback)>[
      if (widget.type == PWidgetType.paste)
        (l10n.porcelaineMoreOptions, () => openNewDownload(context)),
      if (widget.type == PWidgetType.recent ||
          widget.type == PWidgetType.storage)
        (
          l10n.porcelaineWholeLibrary,
          () => ref.read(porcelaineLibraryOpenProvider.notifier).state = true,
        ),
      if (widget.type == PWidgetType.queue || widget.type == PWidgetType.active)
        (
          l10n.designSeeAll,
          () {
            ref.read(downloadSourceFilterProvider.notifier).state = null;
            ref.read(downloadStatusFilterProvider.notifier).state =
                DownloadStatusFilter.active;
            ref.read(porcelaineLibraryOpenProvider.notifier).state = true;
          },
        ),
    ];
    return Focus(
      onFocusChange: onFocus,
      skipTraversal: true,
      child: PopupMenuButton<VoidCallback>(
        tooltip: l10n.porcelaineWidgetOptions(name),
        color: colors.surface,
        elevation: 12,
        offset: const Offset(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        constraints: const BoxConstraints(minWidth: 200),
        onOpened: () => onOpen(true),
        onCanceled: () => onOpen(false),
        onSelected: (action) {
          onOpen(false);
          action();
        },
        itemBuilder: (context) => [
          for (final s in PWidgetSize.values)
            entry(
              () => notifier.setSize(widget.id, s),
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${s.cols}×${s.rows}',
                      style: pMono(
                        colors,
                        size: 11,
                        color: colors.textDisabled,
                      ),
                    ),
                  ),
                  Text(pSizeName(l10n, s)),
                  const Spacer(),
                  if (widget.size == s)
                    Icon(Icons.circle, size: 8, color: colors.primary),
                ],
              ),
            ),
          if (extras.isNotEmpty) const PopupMenuDivider(height: 9),
          for (final (label, action) in extras) entry(action, Text(label)),
          const PopupMenuDivider(height: 9),
          entry(
            onRemove,
            Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: colors.error,
                ),
                const SizedBox(width: 10),
                Text(l10n.delete),
              ],
            ),
            danger: true,
          ),
        ],
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.textPrimary.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// `.del`: the white round « − ».
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedScale(
          scale: _hover ? 1.08 : 1,
          duration: pMotion(context, 150),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _hover ? colors.error : colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withValues(alpha: 0.12),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: colors.textPrimary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 14,
                  color: _hover ? Colors.white : colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ebar`: ← P M G → under the card.
class _EditBar extends StatelessWidget {
  const _EditBar({
    required this.widget,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onForward,
    required this.onSize,
  });

  final PWidget widget;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<PWidgetSize> onSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.1),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EbarButton(
            label: rtl ? '→' : '←',
            tooltip: l10n.porcelaineMoveBack,
            onTap: isFirst ? null : onBack,
          ),
          for (final s in PWidgetSize.values)
            _EbarButton(
              label: pSizeShort(l10n, s),
              tooltip: l10n.porcelaineSizeLabel(pSizeName(l10n, s)),
              on: widget.size == s,
              onTap: () => onSize(s),
            ),
          _EbarButton(
            label: rtl ? '←' : '→',
            tooltip: l10n.porcelaineMoveForward,
            onTap: isLast ? null : onForward,
          ),
        ],
      ),
    );
  }
}

class _EbarButton extends StatefulWidget {
  const _EbarButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.on = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool on;

  @override
  State<_EbarButton> createState() => _EbarButtonState();
}

class _EbarButtonState extends State<_EbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        selected: widget.on,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Opacity(
            opacity: enabled ? 1 : 0.35,
            child: Material(
              color: widget.on
                  ? colors.textPrimary
                  : (_hover && enabled
                        ? colors.textPrimary.withValues(alpha: 0.06)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: widget.onTap,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  child: Text(
                    widget.label,
                    style: pBody(
                      colors,
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: widget.on
                          ? colors.background
                          : (_hover
                                ? colors.textPrimary
                                : colors.textSecondary),
                    ).copyWith(height: 1.1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.rz`: the corner handle; dragging it snaps the card to 1×1, 2×1, 2×2.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.tooltip,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final String tooltip;
  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => widget.onStart(),
          onPanUpdate: (d) => widget.onUpdate(d.delta),
          onPanEnd: (_) => widget.onEnd(),
          onPanCancel: widget.onEnd,
          child: Container(
            width: 26,
            height: 26,
            padding: const EdgeInsets.all(6),
            alignment: Alignment.bottomRight,
            decoration: BoxDecoration(
              color: _hover
                  ? colors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CornerPainter(
                _hover
                    ? colors.primary
                    : colors.textPrimary.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 12;
    canvas.drawPath(
      Path()
        ..moveTo(11 * s, 3 * s)
        ..lineTo(11 * s, 11 * s)
        ..lineTo(3 * s, 11 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

/// `.addtile`: the dashed « + Ajouter un widget » cell at the end.
class _AddTile extends StatefulWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddTile> createState() => _AddTileState();
}

class _AddTileState extends State<_AddTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = _hover ? colors.primary : colors.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: colors.surface.withValues(alpha: _hover ? 0.6 : 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            width: 1.5,
            color: _hover
                ? colors.primary.withValues(alpha: 0.4)
                : colors.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 22, color: c),
              const SizedBox(height: 8),
              Text(
                context.l10n.porcelaineAddWidget,
                style: pBody(
                  colors,
                  size: 13,
                  weight: FontWeight.w600,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          width: 1.5,
          color: colors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.porcelaineEmptyTitle,
            style: pDisp(24, color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              l10n.porcelaineEmptyBody,
              textAlign: TextAlign.center,
              style: pBody(colors, color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          PBtn(
            label: l10n.porcelaineAddWidget,
            kind: PBtnKind.accent,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

/// The failed items, equal when the same ids failed for the same reasons
/// (so progress ticks do not rebuild the Espace).
class _FailedIds {
  const _FailedIds(this.items);

  final List<DownloadItem> items;

  @override
  bool operator ==(Object other) {
    if (other is! _FailedIds || other.items.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (other.items[i].id != items[i].id ||
          other.items[i].error != items[i].error) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([for (final i in items) i.id]);
}

/// Porcelaine's « finished » moment: a cobalt ring rises around the card in
/// a third of the time, then settles back into the porcelain.
class _FinishGlow extends StatelessWidget {
  const _FinishGlow({required this.animation, this.halo = false});

  final Animation<double> animation;

  /// The soft cobalt light around the card (painted under it); otherwise
  /// the 2px ring on its edge.
  final bool halo;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final v = animation.value;
          final g = v <= 0 || v >= 1
              ? 0.0
              : (v < 0.3
                    ? Curves.easeOut.transform(v / 0.3)
                    : 1 - Curves.easeInOut.transform((v - 0.3) / 0.7));
          if (g == 0) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: halo
                  ? null
                  : Border.all(
                      color: colors.primary.withValues(alpha: g),
                      width: 2,
                    ),
              boxShadow: !halo
                  ? null
                  : [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.2 * g),
                        spreadRadius: 8 * g,
                      ),
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.22 * g),
                        blurRadius: 48,
                        offset: const Offset(0, 16),
                      ),
                    ],
            ),
          );
        },
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        height: 46,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 8, 0),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: pBody(
                colors,
                size: 13.5,
                weight: FontWeight.w500,
                color: colors.background,
              ),
            ),
            const SizedBox(width: 14),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onAction,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(
                    action,
                    style: pBody(colors, size: 13, weight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── « Ajouter un widget » ──────────────────────────────────────────────────

/// Opens the catalog sheet; returns the id of the widget added, if any.
Future<String?> showPorcelaineCatalog(BuildContext context) {
  final colors = AppColors.of(context);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.close,
    barrierColor: colors.background.withValues(alpha: 0.7),
    transitionDuration: pMotion(context, 320),
    pageBuilder: (context, _, _) => const _CatalogSheet(),
    transitionBuilder: (context, anim, _, child) {
      final t = pEase.transform(anim.value);
      return Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
        ),
      );
    },
  );
}

class _CatalogSheet extends ConsumerWidget {
  const _CatalogSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final present = {
      for (final w in ref.watch(porcelaineWorkspaceProvider).widgets) w.type,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.25),
                    blurRadius: 90,
                    offset: const Offset(0, 40),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  l10n.porcelaineAddWidget,
                                  style: pDisp(24, color: colors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.porcelaineCatalogHint,
                                style: pBody(
                                  colors,
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PBtn(
                          label: '',
                          icon: Icons.close_rounded,
                          kind: PBtnKind.ghost,
                          padding: 12,
                          tooltip: l10n.close,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, box) {
                        final cols = (box.maxWidth / 222).floor().clamp(1, 3);
                        final w = (box.maxWidth - (cols - 1) * 12) / cols;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final t in PWidgetType.values)
                              SizedBox(
                                width: w,
                                child: _CatalogCard(
                                  type: t,
                                  present: present.contains(t),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends ConsumerStatefulWidget {
  const _CatalogCard({required this.type, required this.present});

  final PWidgetType type;
  final bool present;

  @override
  ConsumerState<_CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends ConsumerState<_CatalogCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final t = widget.type;
    final name = pWidgetName(l10n, t);
    final up = _hover && !widget.present;
    return Opacity(
      opacity: widget.present ? 0.5 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: pMotion(context, 200),
          curve: pEase,
          transform: Matrix4.translationValues(0, up ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: up ? colors.surface : const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: up ? 0.08 : 0.06),
                spreadRadius: 1,
              ),
              if (up)
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: -12,
                  offset: const Offset(0, 16),
                ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: widget.present
                  ? null
                  : () {
                      final id = ref
                          .read(porcelaineWorkspaceProvider.notifier)
                          .add(t);
                      Navigator.of(context).pop(id);
                    },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 92,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colors.textPrimary.withValues(alpha: 0.06),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: colors.textPrimary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: -8,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: pBody(
                              colors,
                              size: 11,
                              color: colors.textDisabled,
                            ),
                          ),
                          Text(
                            pCatalogPreview(ref, l10n, t),
                            maxLines: 1,
                            style: pDisp(
                              30,
                              color: colors.textPrimary,
                            ).copyWith(height: 0.9),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: pBody(colors, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      pWidgetDesc(l10n, t),
                      style: pBody(
                        colors,
                        size: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.present
                          ? l10n.porcelaineAlreadyThere
                          : l10n.porcelaineAddAt(
                              pSizeName(l10n, kPRecommendedSize[t]!),
                            ),
                      style: pMono(
                        colors,
                        size: 11.5,
                        color: widget.present
                            ? colors.textDisabled
                            : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── The whole library ──────────────────────────────────────────────────────

/// « Toute la bibliothèque »: today's library (filters, search, sort, list
/// or creator folders, inspector, context menu, queue controls) on a
/// Porcelaine sheet, with the way back to the Espace.
class _Library extends ConsumerWidget {
  const _Library();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final count = ref.watch(
      filteredDownloadsProvider.select((v) => v.valueOrNull?.length ?? 0),
    );
    // -1 loading, -2 unreadable, else how many items in all.
    final phase = ref.watch(
      downloadListProvider.select(
        (v) => v.hasValue ? v.value!.length : (v.hasError ? -2 : -1),
      ),
    );
    final failed = ref.watch(
      downloadListProvider.select(
        (v) => (v.valueOrNull ?? const <DownloadItem>[])
            .where((i) => i.status == DownloadStatus.failed)
            .length,
      ),
    );
    void back() => pCloseLibrary(ref);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final Widget? content = switch (phase) {
      -1 => const PLibrarySkeleton(),
      -2 => const PLoadError(),
      0 => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SingleChildScrollView(child: PEmptyLibrary())),
      ),
      _ => null,
    };
    return CallbackShortcuts(
      bindings: {
        // Esc closes the inspector first, like today's library.
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (ref.read(selectedDownloadIdProvider) != null) {
            ref.read(selectedDownloadIdProvider.notifier).state = null;
          } else {
            back();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            DownloadSearchFocus.request,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            DownloadSearchFocus.request,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = box.maxWidth > 1284 ? (box.maxWidth - 1220) / 2 : 32.0;
            final compact = box.maxWidth < 900;
            // The sheet rises once when the library opens.
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: pMotion(context, 420),
              curve: pEase,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - t)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(side, 4, side, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PBtn(
                          label: compact ? '' : l10n.porcelaineSpace,
                          tooltip: compact ? l10n.porcelaineSpace : null,
                          icon: rtl
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          kind: PBtnKind.line,
                          height: 36,
                          padding: compact ? 11 : 16,
                          onTap: back,
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            l10n.librarySection,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pDisp(
                              compact ? 24 : 28,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (phase > 0)
                          Text('$count', style: pMono(colors, size: 14)),
                        const Spacer(),
                        if (failed > 0) ...[
                          PBtn(
                            label: compact
                                ? '$failed'
                                : l10n.porcelaineRetryFailedCount(failed),
                            tooltip: compact
                                ? l10n.porcelaineRetryFailedCount(failed)
                                : l10n.retryAllFailedTooltip(failed),
                            icon: Icons.refresh_rounded,
                            height: 36,
                            onTap: () async {
                              await ref
                                  .read(downloadListProvider.notifier)
                                  .retryAllFailed();
                              if (context.mounted) {
                                pNotice(context, l10n.retryingFailed(failed));
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Today's « Nouveau téléchargement » (also Ctrl+N and
                        // the Lien rapide widget's menu).
                        PBtn(
                          label: compact ? '' : l10n.newDownload,
                          tooltip: compact ? l10n.newDownload : null,
                          icon: Icons.add_rounded,
                          kind: PBtnKind.accent,
                          height: 36,
                          padding: compact ? 11 : 16,
                          onTap: () => openNewDownload(context),
                        ),
                      ],
                    ),
                    if (phase > 0) ...[
                      const SizedBox(height: 16),
                      PLibraryToolbar(key: OnboardingTargets.topBar),
                      const SizedBox(height: 12),
                      const PLibraryFilters(),
                    ],
                    const SizedBox(height: 14),
                    Expanded(
                      child: content == null
                          ? PLibraryBody(noResults: count == 0)
                          : Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: pCardFill(colors),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: pCardShadow(colors),
                              ),
                              child: AnimatedSwitcher(
                                duration: pMotion(context, 220),
                                child: KeyedSubtree(
                                  key: ValueKey(phase),
                                  child: content,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
