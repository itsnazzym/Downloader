import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/settings/widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'terminal_library.dart';
import 'terminal_widgets.dart';

/// How Terminal draws the shared library rows and settings tiles (see
/// [DesignSkin]): rows are table lines, tiles are `key = value` config lines.
const terminalSkin = DesignSkin(
  row: _row,
  sectionTitle: _section,
  switchTile: _switch,
  sliderTile: _slider,
  dropdownTile: _dropdown,
  actionTile: _action,
  statusTile: _status,
);

Widget _row(BuildContext context, DesignRow row) => TerminalRow(row: row);

Widget _section(BuildContext context, SectionTitle t) => Padding(
  padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
  child: Text(
    '[${t.title.toLowerCase()}]',
    style: tm(AppColors.of(context).primary, weight: FontWeight.w700),
  ),
);

Widget _switch(BuildContext context, SwitchTile t) => TConfLine(
  comment: t.subtitle,
  onTap: () => t.onChanged(!t.value),
  body: TKeyValue(t.title, '${t.value}'),
  control: TSwitch(value: t.value, onChanged: t.onChanged, label: t.title),
);

Widget _slider(BuildContext context, SliderTile t) {
  final step = t.divisions == null || t.divisions == 0
      ? 1.0
      : (t.max - t.min) / t.divisions!;
  void set(double v) => t.onChanged(v.clamp(t.min, t.max).toDouble());
  return TConfLine(
    comment: t.subtitle,
    body: TKeyValue(t.title, '${t.value.round()}'),
    control: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TButton(
          label: '-',
          square: true,
          height: 28,
          tooltip: t.title,
          onTap: t.value <= t.min ? null : () => set(t.value - step),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 140,
          child: TSegSlider(
            value: t.value,
            min: t.min,
            max: t.max,
            step: step,
            label: t.title,
            onChanged: set,
          ),
        ),
        const SizedBox(width: 6),
        TButton(
          label: '+',
          square: true,
          height: 28,
          tooltip: t.title,
          onTap: t.value >= t.max ? null : () => set(t.value + step),
        ),
      ],
    ),
  );
}

Widget _dropdown(BuildContext context, DropdownTile t) {
  final options = {for (final o in t.options) o: t.optionLabels?[o] ?? o};
  return TConfLine(
    body: Text(
      '${t.title} =',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(AppColors.of(context).textPrimary),
    ),
    control: TSelect(
      value: t.value,
      options: options,
      label: t.title,
      onChanged: t.onChanged,
    ),
  );
}

Widget _action(BuildContext context, ActionTile t) {
  final colors = AppColors.of(context);
  return TConfLine(
    comment: t.subtitle,
    commentMaxLines: t.subtitleMaxLines,
    onTap: t.onTap,
    body: Text(
      '› ${t.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textPrimary, weight: FontWeight.w600),
    ),
    control:
        t.trailing ??
        (t.onTap == null ? null : Text('→', style: tm(colors.primary))),
  );
}

Widget _status(BuildContext context, StatusTile t) {
  final colors = AppColors.of(context);
  final ok = t.status.isInstalled;
  return TConfLine(
    body: Text(
      t.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textPrimary, weight: FontWeight.w700),
    ),
    control: Text(
      '${ok ? '[ok]' : '[!!]'} ${t.status.version ?? context.l10n.settingsTilesNotFound}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(ok ? colors.primary : colors.error),
    ),
  );
}
