import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zinc palette mapped to shadcn semantic tokens (light / dark).
class ShadcnZinc {
  const ShadcnZinc({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.border,
    required this.ring,
    required this.veil,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color border;
  final Color ring;
  final Color veil;

  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color zinc500 = Color(0xFF71717A);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc950 = Color(0xFF09090B);

  static const double radius = 10;
  static const double radiusMd = 8;
  static const double radiusSm = 6;

  static const ShadcnZinc light = ShadcnZinc(
    background: zinc50,
    foreground: zinc950,
    card: zinc50,
    cardForeground: zinc950,
    primary: zinc900,
    primaryForeground: zinc50,
    secondary: zinc100,
    secondaryForeground: zinc900,
    muted: zinc100,
    mutedForeground: zinc500,
    accent: zinc100,
    accentForeground: zinc900,
    border: zinc200,
    ring: zinc400,
    veil: Color(0x8A09090B),
  );

  static const ShadcnZinc dark = ShadcnZinc(
    background: zinc950,
    foreground: zinc50,
    card: zinc900,
    cardForeground: zinc50,
    primary: zinc50,
    primaryForeground: zinc900,
    secondary: zinc800,
    secondaryForeground: zinc50,
    muted: zinc800,
    mutedForeground: zinc400,
    accent: zinc800,
    accentForeground: zinc50,
    border: zinc800,
    ring: zinc400,
    veil: Color(0x9909090B),
  );

  static ShadcnZinc of(BuildContext context) {
    try {
      return Theme.of(context).brightness == Brightness.dark ? dark : light;
    } catch (_) {
      return dark;
    }
  }
}

class ShadcnCard extends StatelessWidget {
  const ShadcnCard({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width ?? 300),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zinc.card,
          borderRadius: BorderRadius.circular(ShadcnZinc.radius),
          border: Border.all(color: zinc.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShadcnZinc.radius - 1),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

enum ShadcnBadgeVariant { outline, secondary }

class ShadcnBadge extends StatelessWidget {
  const ShadcnBadge({
    super.key,
    required this.label,
    this.variant = ShadcnBadgeVariant.outline,
  });

  final String label;
  final ShadcnBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    final filled = variant == ShadcnBadgeVariant.secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? zinc.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zinc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? zinc.secondaryForeground : zinc.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

enum ShadcnButtonVariant { primary, outline, ghost }

class ShadcnButton extends StatefulWidget {
  const ShadcnButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ShadcnButtonVariant.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final ShadcnButtonVariant variant;

  @override
  State<ShadcnButton> createState() => _ShadcnButtonState();
}

class _ShadcnButtonState extends State<ShadcnButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    final Color bg;
    final Color fg;
    final Color border;
    switch (widget.variant) {
      case ShadcnButtonVariant.primary:
        bg = _hover ? zinc.primary.withValues(alpha: 0.9) : zinc.primary;
        fg = zinc.primaryForeground;
        border = zinc.primary;
      case ShadcnButtonVariant.outline:
        bg = _hover ? zinc.accent : zinc.background;
        fg = _hover ? zinc.accentForeground : zinc.foreground;
        border = zinc.border;
      case ShadcnButtonVariant.ghost:
        bg = _hover ? zinc.accent : Colors.transparent;
        fg = _hover ? zinc.accentForeground : zinc.mutedForeground;
        border = Colors.transparent;
    }

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (hover) {
        if (mounted) setState(() => _hover = hover);
      },
      onShowFocusHighlight: (focused) {
        if (mounted) setState(() => _focused = focused);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        onTap: () {
          widget.onPressed();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Semantics(
          button: true,
          label: widget.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ShadcnZinc.radiusMd),
              border: Border.all(
                color: _focused ? zinc.ring.withValues(alpha: 0.4) : border,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShadcnProgress extends StatelessWidget {
  const ShadcnProgress({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final zinc = ShadcnZinc.of(context);
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: zinc.primary.withValues(alpha: 0.2)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: clamped,
              child: ColoredBox(color: zinc.primary),
            ),
          ],
        ),
      ),
    );
  }
}
