import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/components/status_badge.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'pastille_kit.dart';

/// Pieces Pastille draws for what it used to borrow: the status pill, the
/// dark panel, menus and the confirm dialog.

/// The tone of a download's state: lavender runs, sage is done, rose failed,
/// butter waits, cream paused or stopped.
Color pToneOf(BuildContext context, DownloadStatus status) {
  final t = PTones.of(context);
  return switch (status) {
    DownloadStatus.downloading ||
    DownloadStatus.extracting ||
    DownloadStatus.processing => t.lav,
    DownloadStatus.completed || DownloadStatus.duplicate => t.sage,
    DownloadStatus.failed => t.rose,
    DownloadStatus.queued => t.butter,
    DownloadStatus.paused || DownloadStatus.canceled => t.cream,
  };
}

/// A small solid pill in the state's tone, ink text.
class PStatusPill extends StatelessWidget {
  const PStatusPill({super.key, required this.status, this.tooltip});

  final DownloadStatus status;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pToneOf(context, status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        downloadStatusLabel(context, status),
        maxLines: 1,
        style: pBody(size: 12, weight: FontWeight.w700, color: pInk, height: 1),
      ),
    );
    final tip = tooltip;
    return tip == null || tip.isEmpty
        ? pill
        : Tooltip(message: tip, child: pill);
  }
}

/// The dark panel of the page (`.card`): espresso, 30 px corners, a faint
/// cream ring.
class PPanel extends StatelessWidget {
  const PPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 30,
    this.color = pCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: pCream.withValues(alpha: 0.07), spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

/// The round `…`-style trigger of a Pastille menu.
class PRoundIcon extends StatelessWidget {
  const PRoundIcon({super.key, required this.icon, this.size = 44, this.on});

  final IconData icon;
  final double size;

  /// A count or arrow shown beside the icon makes it a capsule.
  final Widget? on;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: on == null ? null : const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pInkDeep,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: pCream.withValues(alpha: 0.1), spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: pCream),
          if (on != null) ...[const SizedBox(width: 6), on!],
        ],
      ),
    );
  }
}

/// A Pastille popup menu: espresso sheet, 18 px corners, cream text.
class PMenu<T> extends StatelessWidget {
  const PMenu({
    super.key,
    required this.tooltip,
    required this.items,
    required this.child,
    this.onSelected,
  });

  final String tooltip;
  final List<PopupMenuEntry<T>> Function(BuildContext) items;
  final Widget child;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      color: pCard,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pCream.withValues(alpha: 0.08)),
      ),
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: items,
      child: child,
    );
  }
}

/// A small grey heading inside a [PMenu].
PopupMenuEntry<T> pMenuHeader<T>(String label) => PopupMenuItem<T>(
  enabled: false,
  height: 32,
  child: Text(
    label,
    style: pBody(size: 12, weight: FontWeight.w700, color: pFaint),
  ),
);

PopupMenuEntry<T> pMenuDivider<T>() => PopupMenuItem<T>(
  enabled: false,
  height: 9,
  child: Container(height: 1, color: pCream.withValues(alpha: 0.08)),
);

/// One row of a [PMenu]: icon, label, an optional mark on the right; a
/// round check when [checked] is given.
PopupMenuEntry<T> pMenuItem<T>({
  required T value,
  required String label,
  IconData? icon,
  bool enabled = true,
  bool? checked,
  bool danger = false,
  Color? tint,
  IconData? trailing,
  VoidCallback? onTap,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    onTap: onTap,
    height: 42,
    child: Builder(
      builder: (context) {
        final color = !enabled
            ? pFaint.withValues(alpha: 0.6)
            : danger
            ? PTones.of(context).rose
            : (tint ?? pCream);
        return Row(
          children: [
            if (checked != null) ...[
              AnimatedContainer(
                duration: pMotion(context, 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: checked ? PTones.of(context).butter : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked ? PTones.of(context).butter : pFaint,
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded, size: 11, color: pInk)
                    : null,
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pBody(size: 13.5, weight: FontWeight.w600, color: color),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Icon(trailing, size: 15, color: pMuted),
            ],
          ],
        );
      },
    ),
  );
}

/// Pastille's confirm dialog: Sora title, one sentence, a cream « cancel »
/// pill and a rose action pill. True when confirmed.
Future<bool> pConfirm(
  BuildContext context, {
  required String title,
  String? body,
  required String action,
  IconData icon = Icons.delete_outline_rounded,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: pCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: pNum(
                  24,
                  weight: FontWeight.w700,
                  color: pCream,
                ).copyWith(height: 1.15, letterSpacing: -0.7),
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(body, style: pBody(color: pMuted)),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PButton(
                    label: l10n.cancel,
                    kind: PButtonKind.ghost,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                  const SizedBox(width: 10),
                  PButton(
                    label: action,
                    icon: icon,
                    kind: PButtonKind.rose,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok == true;
}

/// A short toast in the app's snack bar.
void pNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
