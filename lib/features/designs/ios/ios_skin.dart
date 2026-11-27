import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import 'package:tapload/core/ui/settings/widgets/settings_tiles.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'ios_glass.dart';

/// How iOS draws the shared settings tiles and cards (see [DesignSkin]):
/// grouped-list headers, each setting a glass row with a tinted dot, the
/// springy switch and the pill menu. The library has its own posters, so no
/// row skin.
const iosSkin = DesignSkin(
  sectionTitle: _sectionTitle,
  switchTile: _switchTile,
  sliderTile: _sliderTile,
  dropdownTile: _dropdownTile,
  actionTile: _actionTile,
  statusTile: _statusTile,
  panel: _panel,
  toggle: _toggle,
);

Widget _sectionTitle(BuildContext context, SectionTitle tile) => Padding(
  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
  child: Text(
    tile.title,
    style: iosText(
      IosTokens.of(context),
      size: 13,
      weight: FontWeight.w700,
      color: IosTokens.of(context).sub,
    ),
  ),
);

BoxDecoration _panel(BuildContext context, BoxDecoration base) {
  final t = IosTokens.of(context);
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [t.glassTop, t.glassBottom],
    ),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: t.edge),
  );
}

Widget _toggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => IosSwitch(value: value, onChanged: onChanged, label: '');

const _tints = [
  IosTints.blue,
  IosTints.green,
  IosTints.orange,
  IosTints.violet,
  IosTints.pink,
  IosTints.graphite,
];

/// One setting as a glass row: tinted dot, title and description, control.
class IosSettingRow extends StatelessWidget {
  const IosSettingRow({
    super.key,
    required this.title,
    this.icon,
    this.tint,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.control,
    this.onTap,
    this.below,
    this.card = true,
  });

  final IconData? icon;
  final (Color, Color)? tint;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final Widget? control;
  final VoidCallback? onTap;

  /// Under the row (a slider).
  final Widget? below;

  /// Its own glass card (shared views); false inside a drawn card.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final sub = subtitle;
    final i = icon;
    final row = IosTap(
      onTap: onTap,
      radius: 20,
      semanticLabel: title,
      builder: (context, hover) => AnimatedContainer(
        duration: iosMotion(context, 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: hover ? t.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IosTintDot(
                  colors:
                      tint ??
                      _tints[(i?.codePoint ?? title.hashCode) % _tints.length],
                  icon: i,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: iosText(t, size: 15, weight: FontWeight.w600),
                      ),
                      if (sub != null && sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: iosText(t, size: 12.5, color: t.sub),
                        ),
                    ],
                  ),
                ),
                if (control != null) ...[const SizedBox(width: 14), control!],
              ],
            ),
            if (below != null) below!,
          ],
        ),
      ),
    );
    if (!card) return row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IosGlass(
        radius: 26,
        shadow: false,
        padding: const EdgeInsets.all(6),
        child: row,
      ),
    );
  }
}

/// The value pill (« Meilleure ⌄ ») that opens a menu of [options].
class IosPillMenu<T> extends StatelessWidget {
  const IosPillMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.tooltip,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: SizedBox(
        height: 32,
        child: IosGlass(
          radius: 16,
          pill: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  options[value] ?? '$value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: iosText(t, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: t.text),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _switchTile(BuildContext context, SwitchTile tile) => IosSettingRow(
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  control: IosSwitch(
    value: tile.value,
    label: tile.title,
    onChanged: tile.onChanged,
  ),
);

Widget _sliderTile(BuildContext context, SliderTile tile) {
  final t = IosTokens.of(context);
  return IosSettingRow(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    control: SizedBox(
      height: 32,
      child: IosGlass(
        radius: 16,
        pill: true,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          widthFactor: 1,
          child: Text(
            '${tile.value.round()}',
            style: iosText(t, weight: FontWeight.w700),
          ),
        ),
      ),
    ),
    below: Padding(
      padding: const EdgeInsets.only(top: 6),
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

Widget _dropdownTile(BuildContext context, DropdownTile tile) => IosSettingRow(
  icon: tile.icon,
  title: tile.title,
  control: IosPillMenu<String>(
    tooltip: tile.title,
    value: tile.value,
    options: {for (final o in tile.options) o: tile.optionLabels?[o] ?? o},
    onSelected: tile.onChanged,
  ),
);

Widget _actionTile(BuildContext context, ActionTile tile) {
  final t = IosTokens.of(context);
  return IosSettingRow(
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
                color: t.sub,
              )),
  );
}

Widget _statusTile(BuildContext context, StatusTile tile) {
  final t = IosTokens.of(context);
  final ok = tile.status.isInstalled;
  return IosSettingRow(
    icon: ok ? Icons.check_rounded : Icons.error_outline_rounded,
    tint: ok ? IosTints.green : (t.redFill, const Color(0xFF8E1A13)),
    title: tile.name,
    control: Flexible(
      child: SizedBox(
        height: 28,
        child: IosGlass(
          radius: 14,
          pill: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              tile.status.version ?? context.l10n.settingsTilesNotFound,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: iosText(
                t,
                size: 12.5,
                weight: FontWeight.w600,
                color: ok ? t.text : t.red,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
