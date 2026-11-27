import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'porcelaine_library.dart';
import 'porcelaine_widgets.dart';

/// How Porcelaine draws the shared library rows and settings tiles (see
/// [DesignSkin]): the rows as Porcelaine cards, the tiles as white `.wg`
/// cards with the tinted icon tile, [PSwitch] and [PSelect].
const porcelaineSkin = DesignSkin(
  row: porcelaineRow,
  sectionTitle: _sectionTitle,
  switchTile: _switchTile,
  sliderTile: _sliderTile,
  dropdownTile: _dropdownTile,
  actionTile: _actionTile,
  statusTile: _statusTile,
  toggle: _toggle,
);

Widget _toggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => PSwitch(value: value, onChanged: onChanged);

Widget _sectionTitle(BuildContext context, SectionTitle tile) {
  final colors = AppColors.of(context);
  return Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(6, 14, 0, 12),
    child: Text(
      tile.title,
      style: pBody(
        colors,
        size: 13,
        weight: FontWeight.w600,
        color: colors.textDisabled,
      ),
    ),
  );
}

Widget _switchTile(BuildContext context, SwitchTile tile) => _TileCard(
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  trailing: PSwitch(value: tile.value, onChanged: tile.onChanged),
);

Widget _sliderTile(BuildContext context, SliderTile tile) {
  final colors = AppColors.of(context);
  return _TileCard(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    trailing: Container(
      constraints: const BoxConstraints(minWidth: 44),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${tile.value.toInt()}',
        style: pDisp(18, color: colors.textPrimary),
      ),
    ),
    bottom: PSlider(
      value: tile.value,
      min: tile.min,
      max: tile.max,
      divisions: tile.divisions,
      onChanged: tile.onChanged,
    ),
  );
}

Widget _dropdownTile(BuildContext context, DropdownTile tile) => _TileCard(
  icon: tile.icon,
  title: tile.title,
  trailing: ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 140, maxWidth: 240),
    child: PSelect(
      label: tile.title,
      value: tile.value,
      options: {for (final o in tile.options) o: tile.optionLabels?[o] ?? o},
      onChanged: tile.onChanged,
    ),
  ),
);

Widget _actionTile(BuildContext context, ActionTile tile) {
  final colors = AppColors.of(context);
  return _TileCard(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    subtitleMaxLines: tile.subtitleMaxLines,
    onTap: tile.onTap,
    trailing:
        tile.trailing ??
        Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          size: 20,
          color: colors.textDisabled,
        ),
  );
}

Widget _statusTile(BuildContext context, StatusTile tile) {
  final colors = AppColors.of(context);
  final ok = tile.status.isInstalled;
  final tint = ok ? pGreen : colors.error;
  return _TileCard(
    icon: ok ? Icons.check_rounded : Icons.priority_high_rounded,
    tint: tint,
    title: tile.name,
    mono: true,
    trailing: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.1), colors.surface),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tile.status.version ?? context.l10n.settingsTilesNotFound,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: pMono(colors, size: 12, color: tint),
      ),
    ),
  );
}

/// A settings tile as a white `.wg` card: the tinted icon tile, the title
/// and its hint, the control on the end; the whole card is the button when
/// it has an action.
class _TileCard extends StatefulWidget {
  const _TileCard({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.subtitleMaxLines = 2,
    this.trailing,
    this.bottom,
    this.onTap,
    this.tint,
    this.mono = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int subtitleMaxLines;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onTap;
  final Color? tint;
  final bool mono;

  @override
  State<_TileCard> createState() => _TileCardState();
}

class _TileCardState extends State<_TileCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tint = widget.tint ?? colors.primary;
    final up = _hover && widget.onTap != null;
    final row = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color.alphaBlend(tint.withValues(alpha: 0.12), Colors.white),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(widget.icon, size: 18, color: tint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: widget.mono
                    ? pMono(colors, size: 13.5, color: colors.textPrimary)
                    : pBody(colors, weight: FontWeight.w600),
              ),
              if (widget.subtitle.isNotEmpty)
                Text(
                  widget.subtitle,
                  maxLines: widget.subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(colors, size: 12.5, color: colors.textSecondary),
                ),
            ],
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 12),
          widget.trailing!,
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: pMotion(context, 300),
          curve: pEase,
          transform: Matrix4.translationValues(0, up ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              if (_focus) BoxShadow(color: colors.primary, spreadRadius: 2),
              ...pCardShadow(colors, up: up),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (v) => setState(() => _focus = v),
              borderRadius: BorderRadius.circular(22),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashColor: colors.primary.withValues(alpha: 0.06),
              highlightColor: colors.textPrimary.withValues(alpha: 0.03),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  16,
                  widget.bottom == null ? 14 : 6,
                ),
                child: widget.bottom == null
                    ? row
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [row, widget.bottom!],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
