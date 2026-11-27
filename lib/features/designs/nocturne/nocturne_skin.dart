import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/settings/widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'nocturne_library.dart';
import 'nocturne_widgets.dart';

/// How Nocturne draws the shared library rows and settings tiles (see
/// [DesignSkin]): the `.row` of its settings cards, its switch and pill
/// menu, and its own library row.
const nocturneSkin = DesignSkin(
  row: _row,
  sectionTitle: _sectionTitle,
  switchTile: _switchTile,
  sliderTile: _sliderTile,
  dropdownTile: _dropdownTile,
  actionTile: _actionTile,
  statusTile: _statusTile,
);

Widget _row(BuildContext context, DesignRow row) => row.grid
    ? NocturneDownloadCard(
        item: row.item,
        selected: row.isSelected,
        onTap: row.onTap,
        onRetry: row.onRetry,
        onDelete: row.onCancel,
      )
    : NocturneDownloadRow(
        item: row.item,
        selected: row.isSelected,
        onTap: row.onTap,
        onRetry: row.onRetry,
        onDelete: row.onCancel,
      );

Widget _sectionTitle(BuildContext context, SectionTitle tile) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
  child: NocturneTitle(tile.title),
);

/// One setting as a Nocturne card: icon well, label and description, then
/// the control on the right.
class NocturneSettingCard extends StatefulWidget {
  const NocturneSettingCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.control,
    this.onTap,
    this.below,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final Widget? control;
  final VoidCallback? onTap;

  /// Under the row (a slider).
  final Widget? below;

  /// Icon colour (status tiles).
  final Color? tone;

  @override
  State<NocturneSettingCard> createState() => _NocturneSettingCardState();
}

class _NocturneSettingCardState extends State<NocturneSettingCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tappable = widget.onTap != null;
    final sub = widget.subtitle;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.surfaceHighlight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.icon,
                size: 17,
                color: widget.tone ?? (_hover ? c.primary : c.textSecondary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: nocturneText(c, weight: FontWeight.w600),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      maxLines: widget.subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: nocturneText(c, size: 12.5, color: c.textDisabled),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.control != null) ...[
              const SizedBox(width: 16),
              widget.control!,
            ],
          ],
        ),
        if (widget.below != null) widget.below!,
      ],
    );
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: nocturneMotion(context, 200),
        curve: nocturneEase,
        decoration: BoxDecoration(
          color: _hover && tappable
              ? Color.lerp(c.surface, c.primary, 0.03)
              : c.surface,
          borderRadius: radius,
          border: Border.all(
            color: c.primary.withValues(
              alpha: _hover && tappable ? 0.16 : 0.08,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            borderRadius: radius,
            hoverColor: Colors.transparent,
            focusColor: c.primary.withValues(alpha: 0.08),
            splashColor: c.primary.withValues(alpha: 0.06),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _switchTile(BuildContext context, SwitchTile tile) =>
    NocturneSettingCard(
      icon: tile.icon,
      title: tile.title,
      subtitle: tile.subtitle,
      onTap: () => tile.onChanged(!tile.value),
      control: NocturneSwitch(
        value: tile.value,
        label: tile.title,
        onChanged: tile.onChanged,
      ),
    );

Widget _sliderTile(BuildContext context, SliderTile tile) {
  final c = AppColors.of(context);
  return NocturneSettingCard(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    control: Container(
      height: 30,
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceHighlight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${tile.value.round()}',
        style: nocturneMono(c, size: 14, color: c.textPrimary),
      ),
    ),
    below: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Slider(
        value: tile.value.clamp(tile.min, tile.max),
        min: tile.min,
        max: tile.max,
        divisions: tile.divisions,
        label: '${tile.value.round()}',
        onChanged: tile.onChanged,
      ),
    ),
  );
}

Widget _dropdownTile(BuildContext context, DropdownTile tile) =>
    NocturneSettingCard(
      icon: tile.icon,
      title: tile.title,
      control: NocturnePillMenu<String>(
        tooltip: tile.title,
        value: tile.value,
        options: {for (final o in tile.options) o: tile.optionLabels?[o] ?? o},
        onSelected: tile.onChanged,
      ),
    );

Widget _actionTile(BuildContext context, ActionTile tile) {
  final c = AppColors.of(context);
  return NocturneSettingCard(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    subtitleMaxLines: tile.subtitleMaxLines,
    onTap: tile.onTap,
    control:
        tile.trailing ??
        (tile.onTap == null
            ? null
            : Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: c.textDisabled,
              )),
  );
}

Widget _statusTile(BuildContext context, StatusTile tile) {
  final c = AppColors.of(context);
  final ok = tile.status.isInstalled;
  return NocturneSettingCard(
    icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
    tone: ok ? c.primary : c.error,
    title: tile.name,
    control: Flexible(
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ok ? c.surfaceHighlight : c.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          tile.status.version ?? context.l10n.settingsTilesNotFound,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nocturneMono(c, color: ok ? c.textPrimary : c.error),
        ),
      ),
    ),
  );
}
