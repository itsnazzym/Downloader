import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';

/// Studio's building blocks, measured on the Studio*.dc.html mockups: ink on
/// paper, hairline rings instead of borders, one recording red for what runs.

Duration studioMotion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

const Curve studioEase = Cubic(0.2, 0.8, 0.2, 1);

/// Row hover tint (#FAF9F7): halfway between the panel and the paper.
Color studioHover(AppColors c) => Color.lerp(c.surface, c.background, 0.5)!;

/// The big Inter Tight page title (34px, -0.035em).
TextStyle studioTitle(AppColors c, [double size = 34]) => AppTypography.display(
  size,
  weight: FontWeight.w600,
).copyWith(color: c.textPrimary, letterSpacing: -0.035 * size, height: 1.15);

TextStyle studioMono(AppColors c, {double size = 13, Color? color}) =>
    AppTypography.mono.copyWith(
      fontSize: size,
      color: color ?? c.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle studioText(AppColors c, {double size = 13, Color? color}) =>
    AppTypography.bodySmall.copyWith(
      fontSize: size,
      color: color ?? c.textPrimary,
    );

/// Small uppercase caption (`.cap`): 11px, 600, +0.06em.
class StudioCap extends StatelessWidget {
  const StudioCap(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.66,
        color: c.textDisabled,
      ),
    );
  }
}

/// White panel: 12px corners, a hairline ring and a soft two-layer shadow.
class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: studioPanelDecoration(c),
      child: child,
    );
  }
}

BoxDecoration studioPanelDecoration(AppColors c, {double radius = 12}) =>
    BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.border),
      boxShadow: [
        BoxShadow(
          color: c.primary.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: c.primary.withValues(alpha: 0.06),
          blurRadius: 32,
          // Pulled in so the halo stays soft (and hidden where blur is off).
          spreadRadius: -12,
          offset: const Offset(0, 12),
        ),
      ],
    );

/// A 1px hairline (#ECEAE5) between table rows.
class StudioRule extends StatelessWidget {
  const StudioRule({super.key, this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(height: 1, color: strong ? c.border : c.borderSubtle);
  }
}

/// The recording light: a red dot that dims and returns every 1.6 s; still
/// when effects are reduced.
class StudioRecDot extends StatefulWidget {
  const StudioRecDot({super.key, this.live = true});

  final bool live;

  @override
  State<StudioRecDot> createState() => _StudioRecDotState();
}

class _StudioRecDotState extends State<StudioRecDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.25,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  void _sync() {
    final run = widget.live && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StudioRecDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.of(context).accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The thin ink progress line (`.line`): 2px on a #ECEAE5 track.
class StudioLine extends StatelessWidget {
  const StudioLine({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 2,
        color: c.borderSubtle,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: c.primary),
        ),
      ),
    );
  }
}

/// Text whose ink underline grows from the start when [hover] is true.
class StudioUnderline extends StatelessWidget {
  const StudioUnderline({
    super.key,
    required this.text,
    required this.hover,
    required this.style,
  });

  final String text;
  final bool hover;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      children: [
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: studioMotion(context, 300),
              curve: studioEase,
              widthFactor: hover ? 1 : 0,
              child: Container(height: 1, color: c.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

enum StudioButtonKind { ink, light, danger }

/// `.btnk` (ink, lifts 1px on hover, sinks on press), `.btnl` (white with a
/// hairline ring; ink when [on]) and `.btnd` (red).
class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = StudioButtonKind.ink,
    this.icon,
    this.height = 36,
    this.on = false,
  });

  final String label;
  final VoidCallback? onTap;
  final StudioButtonKind kind;
  final IconData? icon;
  final double height;
  final bool on;

  @override
  State<StudioButton> createState() => _StudioButtonState();
}

class _StudioButtonState extends State<StudioButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(8);
    final light = widget.kind == StudioButtonKind.light && !widget.on;
    final lifts = !light;
    final dy = !lifts ? 0.0 : (_down ? 1.0 : (_hover ? -1.0 : 0.0));
    final Color bg = switch (widget.kind) {
      StudioButtonKind.danger => c.error,
      StudioButtonKind.ink => c.primary,
      StudioButtonKind.light =>
        widget.on ? c.primary : (_hover ? studioHover(c) : c.surface),
    };
    final fg = light ? c.textPrimary : c.background;
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AnimatedContainer(
        duration: studioMotion(context, 160),
        transform: Matrix4.translationValues(0, dy, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: light ? Border.all(color: c.border) : null,
          boxShadow: switch (widget.kind) {
            StudioButtonKind.ink => [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: c.primary.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
            ],
            StudioButtonKind.light when !widget.on => [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
            _ => null,
          },
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onHighlightChanged: (v) => setState(() => _down = v),
            borderRadius: radius,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: fg.withValues(alpha: 0.12),
            child: Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(
                horizontal: widget.kind == StudioButtonKind.ink ? 16 : 14,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 14, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: fg,
                        fontWeight: light ? FontWeight.w500 : FontWeight.w600,
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
}

/// Underlined tabs (`.tabs`): 36px high, 24px apart, a 1.5px ink line under
/// the selected one, an optional mono count.
class StudioTabs extends StatelessWidget {
  const StudioTabs({super.key, required this.tabs});

  final List<StudioTab> tabs;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              _StudioTabButton(tab: tabs[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class StudioTab {
  const StudioTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? count;
}

class _StudioTabButton extends StatefulWidget {
  const _StudioTabButton({required this.tab});

  final StudioTab tab;

  @override
  State<_StudioTabButton> createState() => _StudioTabButtonState();
}

class _StudioTabButtonState extends State<_StudioTabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tab = widget.tab;
    return Semantics(
      selected: tab.selected,
      button: true,
      child: InkWell(
        onTap: tab.onTap,
        onHover: (v) => setState(() => _hover = v),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: studioMotion(context, 160),
          height: 36,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 1.5,
                color: tab.selected ? c.textPrimary : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tab.label,
                style:
                    studioText(
                      c,
                      color: tab.selected || _hover
                          ? c.textPrimary
                          : c.textSecondary,
                    ).copyWith(
                      fontWeight: tab.selected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
              ),
              if (tab.count != null) ...[
                const SizedBox(width: 8),
                Text(
                  tab.count!,
                  style: studioMono(c, size: 11, color: c.textDisabled),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A square icon button with a tooltip, 36px target, hairline ring.
class StudioIconButton extends StatefulWidget {
  const StudioIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<StudioIconButton> createState() => _StudioIconButtonState();
}

class _StudioIconButtonState extends State<StudioIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: studioMotion(context, 160),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? studioHover(c) : c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(widget.icon, size: 16, color: c.textSecondary),
        ),
      ),
    );
  }
}

/// Grey info line under a block (`ⓘ text`).
class StudioNote extends StatelessWidget {
  const StudioNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 13, color: c.textDisabled),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: studioText(c, size: 12, color: c.textDisabled),
          ),
        ),
      ],
    );
  }
}

/// `.sw`: 34×20, ink when on with a white knob, a ringed grey track when off.
class StudioSwitch extends StatelessWidget {
  const StudioSwitch({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;

  /// Null greys it out.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = studioMotion(context, 200);
    final onChanged = this.onChanged;
    return Semantics(
      toggled: value,
      label: label,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        // A 36px target around the 20px track.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
          child: AnimatedContainer(
            duration: motion,
            width: 34,
            height: 20,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? c.primary : c.borderSubtle,
              borderRadius: BorderRadius.circular(10),
              border: value
                  ? null
                  : Border.all(color: const Color(0xFF8F8C86), width: 1.5),
            ),
            child: AnimatedAlign(
              duration: motion,
              curve: studioEase,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                width: value ? 14 : 11,
                height: value ? 14 : 11,
                decoration: BoxDecoration(
                  color: value ? c.surface : c.textDisabled,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white 36px search box with a hairline ring that turns ink on focus, a
/// magnifier, and a clear button once something is typed (Esc clears too).
class StudioSearchBox extends StatefulWidget {
  const StudioSearchBox({
    super.key,
    required this.hint,
    required this.clearTooltip,
    required this.onChanged,
    this.initial = '',
  });

  final String hint;
  final String clearTooltip;
  final ValueChanged<String> onChanged;
  final String initial;

  @override
  State<StudioSearchBox> createState() => _StudioSearchBoxState();
}

class _StudioSearchBoxState extends State<StudioSearchBox> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _focus = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _controller.text.isEmpty ? _focus.unfocus() : _clear(),
      },
      child: AnimatedContainer(
        duration: studioMotion(context, 160),
        height: 36,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focus.hasFocus ? c.textPrimary : c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 15, color: c.textDisabled),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() {});
                },
                cursorColor: c.textPrimary,
                cursorHeight: 16,
                style: studioText(c),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: studioText(c, color: c.textDisabled),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: widget.clearTooltip,
                onPressed: _clear,
                iconSize: 15,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: c.textDisabled),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Studio's Material component themes, for the shared views a Studio page
/// still hosts (settings sub-pages, the archive import hub): 8px ink and
/// ringed buttons, hairline fields and cards, ink switches and checkboxes.
/// Dialogs and menus opened below it inherit it.
class StudioThemed extends StatelessWidget {
  const StudioThemed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context);
    final radius = BorderRadius.circular(8);
    const offRing = Color(0xFF8F8C86);
    final label = AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500);
    final shape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: radius),
    );
    final hover = WidgetStateProperty.resolveWith<Color?>(
      (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed)
          ? c.textPrimary.withValues(alpha: 0.06)
          : null,
    );
    OutlineInputBorder ring(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );
    return Theme(
      data: t.copyWith(
        splashFactory: NoSplash.splashFactory,
        dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1),
        cardTheme: CardThemeData(
          color: c.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.border),
          ),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: c.textSecondary,
          textColor: c.textPrimary,
          titleTextStyle: studioText(c).copyWith(fontWeight: FontWeight.w500),
          subtitleTextStyle: studioText(c, size: 12, color: c.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.surface : c.textDisabled,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.primary : c.borderSubtle,
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? Colors.transparent : offRing,
          ),
          trackOutlineWidth: const WidgetStatePropertyAll(1.5),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          thumbIcon: const WidgetStatePropertyAll(null),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
          ),
          checkColor: WidgetStatePropertyAll(c.surface),
          side: const BorderSide(color: offRing, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : offRing,
          ),
        ),
        sliderTheme: studioSliderTheme(c),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: c.primary,
          linearTrackColor: c.borderSubtle,
          circularTrackColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            textStyle: WidgetStatePropertyAll(
              label.copyWith(fontWeight: FontWeight.w600),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.disabled) ? c.borderSubtle : c.primary,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? c.textDisabled
                  : c.background,
            ),
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            textStyle: WidgetStatePropertyAll(label),
            backgroundColor: WidgetStatePropertyAll(c.primary),
            foregroundColor: WidgetStatePropertyAll(c.background),
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            textStyle: WidgetStatePropertyAll(label),
            backgroundColor: WidgetStatePropertyAll(c.surface),
            foregroundColor: WidgetStatePropertyAll(c.textPrimary),
            overlayColor: hover,
            side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            textStyle: WidgetStatePropertyAll(label),
            foregroundColor: WidgetStatePropertyAll(c.textPrimary),
            overlayColor: hover,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            foregroundColor: WidgetStatePropertyAll(c.textSecondary),
            overlayColor: hover,
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: shape,
            textStyle: WidgetStatePropertyAll(label),
            side: WidgetStatePropertyAll(BorderSide(color: c.border)),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? c.background
                  : c.textPrimary,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: c.surface,
          selectedColor: c.primary,
          checkmarkColor: c.background,
          labelStyle: studioText(c, size: 12),
          secondaryLabelStyle: studioText(c, size: 12, color: c.background),
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surface,
          isDense: true,
          hintStyle: studioText(c, color: c.textDisabled),
          labelStyle: studioText(c, color: c.textSecondary),
          border: ring(c.border),
          enabledBorder: ring(c.border),
          focusedBorder: ring(c.textPrimary),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: c.surface,
          surfaceTintColor: Colors.transparent,
          textStyle: studioText(c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: c.border),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: studioTitle(c, 20),
          contentTextStyle: studioText(c, color: c.textSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.border),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// A 2px ink line with a small ink knob, no halo and no ticks.
SliderThemeData studioSliderTheme(AppColors c) => SliderThemeData(
  trackHeight: 2,
  activeTrackColor: c.primary,
  inactiveTrackColor: c.borderSubtle,
  thumbColor: c.primary,
  overlayColor: Colors.transparent,
  thumbShape: const RoundSliderThumbShape(
    enabledThumbRadius: 6,
    elevation: 0,
    pressedElevation: 0,
  ),
  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
  tickMarkShape: SliderTickMarkShape.noTickMark,
  showValueIndicator: ShowValueIndicator.never,
);

/// [DesignSkin.toggle]: the shared views' fixed-colour switches as `.sw`.
Widget studioToggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => Opacity(
  opacity: onChanged == null ? 0.5 : 1,
  child: StudioSwitch(value: value, label: '', onChanged: onChanged),
);

/// `.cb`: a 16px box, ink with a white tick when checked, ringed when not.
class StudioCheckbox extends StatelessWidget {
  const StudioCheckbox({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: studioMotion(context, 160),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: value ? c.primary : c.surface,
        borderRadius: BorderRadius.circular(4),
        border: value
            ? null
            : Border.all(color: const Color(0xFF8F8C86), width: 1.5),
      ),
      child: value
          ? Icon(Icons.check_rounded, size: 12, color: c.surface)
          : null,
    );
  }
}
