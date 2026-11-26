import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'signal_controls.dart';
import 'signal_library_row.dart';
import 'signal_settings.dart' show SignalSelect;
import 'signal_theme.dart';
import 'signal_widgets.dart';

/// How Signal draws the shared library rows and settings tiles (see
/// [DesignSkin]).
const signalSkin = DesignSkin(
  row: _row,
  sectionTitle: _sectionTitle,
  switchTile: _switchTile,
  sliderTile: _sliderTile,
  dropdownTile: _dropdownTile,
  actionTile: _actionTile,
  statusTile: _statusTile,
  panel: _panel,
  toggle: _toggle,
);

Widget _toggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => SignalSwitch(value: value, onChanged: onChanged);

Widget _row(BuildContext context, DesignRow row) => SignalLibraryRow(
  item: row.item,
  selected: row.isSelected,
  grid: row.grid,
  onTap: row.onTap,
  onRetry: row.onRetry,
  onDelete: row.onCancel,
);

BoxDecoration _panel(BuildContext context, BoxDecoration base) =>
    signalCardDecoration(AppColors.of(context));

Widget _sectionTitle(BuildContext context, SectionTitle tile) => Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 12),
  child: SignalEyebrow(tile.title),
);

Widget _switchTile(BuildContext context, SwitchTile tile) => _SkinTile(
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  trailing: ExcludeFocus(
    child: SignalSwitch(
      value: tile.value,
      onChanged: tile.onChanged,
      label: tile.title,
    ),
  ),
);

Widget _dropdownTile(BuildContext context, DropdownTile tile) => _SkinTile(
  icon: tile.icon,
  title: tile.title,
  trailing: SignalMaterial(
    child: SignalSelect(
      value: tile.value,
      options: tile.options,
      labels: tile.optionLabels ?? const {},
      tooltip: tile.title,
      onChanged: tile.onChanged,
    ),
  ),
);

Widget _actionTile(BuildContext context, ActionTile tile) => _SkinTile(
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  subtitleMaxLines: tile.subtitleMaxLines,
  onTap: tile.onTap,
  disabled: tile.onTap == null,
  trailing: tile.trailing == null
      ? Icon(
          Icons.arrow_forward_rounded,
          size: 17,
          color: AppColors.of(context).textSecondary,
        )
      : SignalMaterial(child: tile.trailing!),
);

Widget _sliderTile(BuildContext context, SliderTile tile) {
  final colors = AppColors.of(context);
  return _SkinTile(
    icon: tile.icon,
    title: tile.title,
    subtitle: tile.subtitle,
    trailing: SignalFigure(value: '${tile.value.round()}', size: 26),
    below: SliderTheme(
      data: signalSliderTheme(colors),
      child: Slider(
        value: tile.value.clamp(tile.min, tile.max),
        min: tile.min,
        max: tile.max,
        divisions: tile.divisions,
        label: '${tile.value.round()}',
        semanticFormatterCallback: (v) => '${tile.title} ${v.round()}',
        onChanged: tile.onChanged,
      ),
    ),
  );
}

Widget _statusTile(BuildContext context, StatusTile tile) {
  final colors = AppColors.of(context);
  final ok = tile.status.isInstalled;
  final tone = ok ? colors.primary : colors.error;
  return _SkinTile(
    leading: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: tone,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
    ),
    title: tile.name,
    mono: true,
    trailing: Flexible(
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.withValues(alpha: ok ? 0.35 : 0.5)),
        ),
        alignment: Alignment.center,
        child: Text(
          tile.status.version ?? context.l10n.settingsTilesNotFound,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.mono.copyWith(
            fontSize: 12.5,
            color: ok ? colors.textPrimary : colors.error,
          ),
        ),
      ),
    ),
  );
}

/// One shared settings tile as a Signal card: round icon well, label and
/// hint, control on the right; the whole card answers clicks and keys when
/// [onTap] is set.
class _SkinTile extends StatefulWidget {
  const _SkinTile({
    this.icon,
    this.leading,
    required this.title,
    this.subtitle = '',
    this.subtitleMaxLines = 2,
    this.trailing,
    this.below,
    this.onTap,
    this.disabled = false,
    this.mono = false,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final int subtitleMaxLines;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final bool disabled;
  final bool mono;

  @override
  State<_SkinTile> createState() => _SkinTileState();
}

class _SkinTileState extends State<_SkinTile> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tap = widget.disabled ? null : widget.onTap;
    final leading =
        widget.leading ??
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.inputBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(widget.icon, size: 16, color: colors.textSecondary),
        );
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style:
                        (widget.mono ? AppTypography.mono : AppTypography.body)
                            .copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: widget.subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        color: colors.textDisabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 16),
              widget.trailing!,
            ],
          ],
        ),
        if (widget.below != null) ...[
          const SizedBox(height: 10),
          widget.below!,
        ],
      ],
    );
    body = SignalCard(
      lift: tap != null,
      ring: _focus ? colors.primary : null,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: body,
    );
    if (widget.onTap != null) {
      body = Semantics(
        button: true,
        enabled: tap != null,
        child: FocusableActionDetector(
          enabled: tap != null,
          mouseCursor: tap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onShowFocusHighlight: (f) => setState(() => _focus = f),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                tap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: tap,
            child: Opacity(opacity: tap == null ? 0.55 : 1, child: body),
          ),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: body);
  }
}
