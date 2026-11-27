import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../nocturne/nocturne_library.dart'
    show nocturneMetaOf, playDownload, revealDownload;
import '../shared/design_data.dart';
import '../signal/signal_widgets.dart' show SignalThumb;
import 'oled_theme.dart';
import 'oled_widgets.dart';

/// How OLED draws the shared library rows, settings tiles and toggles (see
/// [DesignSkin]): the `.o-row` of the home's library and the `.o-set` rows
/// of the settings, with the ion switch and the mono value pill.
const oledSkin = DesignSkin(
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

Widget _row(BuildContext context, DesignRow row) => OledDownloadRow(row: row);

bool _failed(DownloadItem i) =>
    i.status == DownloadStatus.failed || i.status == DownloadStatus.canceled;

/// A library row (`.o-row`): thumbnail, title, mono status line, « Réessayer »
/// when it failed, the format; play, folder and delete on hover or focus.
/// [DesignRow.grid] draws the detailed view's card instead.
class OledDownloadRow extends ConsumerStatefulWidget {
  const OledDownloadRow({super.key, required this.row});

  final DesignRow row;

  @override
  ConsumerState<OledDownloadRow> createState() => _OledDownloadRowState();
}

class _OledDownloadRowState extends ConsumerState<OledDownloadRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = widget.row;
    final item = row.item;
    final failed = _failed(item);
    final done = item.status == DownloadStatus.completed;
    final ageCheck =
        item.status == DownloadStatus.failed &&
        DownloadStatusGuard.isAgeVerificationFailure(
          error: item.error,
          url: item.request.url,
        );
    final meta = ageCheck
        ? '${l10n.ageCheckRequired} · ${l10n.ageCheckSeeSolutions}'
        : nocturneMetaOf(context, item);
    final metaText = Text(
      meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: oledMono(
        size: 11.5,
        color: ageCheck
            ? const Color(0xFFE9B44C)
            : (failed ? OledInk.err : OledInk.mute),
      ),
    );
    final show = _hover || _focus;
    final actions = IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: oledMotion(context, 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              _Icon(
                Icons.play_arrow_rounded,
                l10n.detailsPlayVideo,
                () => playDownload(ref, item),
              ),
              _Icon(
                Icons.folder_open_rounded,
                l10n.openFolder,
                () => revealDownload(item),
              ),
            ],
            if (done || failed)
              _Icon(Icons.delete_outline_rounded, l10n.remove, row.onCancel),
          ],
        ),
      ),
    );
    Widget thumbOf(double width) => SignalThumb(
      url: item.thumbnailUrl,
      filePath: item.filePath,
      width: width,
      height: row.grid ? 136 : 44,
      radius: 8,
    );
    final thumb = row.grid
        ? LayoutBuilder(builder: (context, box) => thumbOf(box.maxWidth))
        : thumbOf(72);
    final title = Text(
      titleOf(item),
      maxLines: row.grid ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: oledText(size: 14, weight: FontWeight.w500),
    );
    final retry = failed
        ? OledPill(
            label: l10n.retry,
            kind: OledPillKind.ghost,
            height: 36,
            padding: 14,
            fontSize: 12.5,
            onTap: row.onRetry,
          )
        : null;
    final format = Text(
      failed ? '—' : formatLabelOf(item),
      textAlign: TextAlign.end,
      style: oledMono(size: 11),
    );
    final Widget body = row.grid
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OledInk.edge),
                ),
                child: thumb,
              ),
              const SizedBox(height: 10),
              title,
              const SizedBox(height: 4),
              metaText,
              const Spacer(),
              Row(
                children: [
                  ?retry,
                  const Spacer(),
                  actions,
                  const SizedBox(width: 6),
                  format,
                ],
              ),
            ],
          )
        : Row(
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OledInk.edge),
                ),
                child: thumb,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, const SizedBox(height: 4), metaText],
                ),
              ),
              actions,
              if (retry != null) ...[const SizedBox(width: 10), retry],
              const SizedBox(width: 12),
              SizedBox(width: 44, child: format),
            ],
          );
    return Padding(
      padding: EdgeInsets.only(bottom: row.grid ? 0 : 10),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: ageCheck
              ? () => AgeVerificationHelpDialog.show(context, item)
              : row.onTap,
          onDoubleTap: () => playDownload(ref, item),
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _focus = v),
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: OledInk.ion.withValues(alpha: 0.05),
          child: OledHoverBox(
            selected: row.isSelected || _focus,
            padding: row.grid
                ? const EdgeInsets.all(10)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon(this.icon, this.tooltip, this.onTap);

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: onTap,
    color: OledInk.mute,
    hoverColor: OledInk.ink.withValues(alpha: 0.08),
    visualDensity: VisualDensity.compact,
  );
}

// ── Settings ────────────────────────────────────────────────────────────────

Widget _sectionTitle(BuildContext context, SectionTitle tile) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 26, 4, 6),
  child: Text(tile.title.toUpperCase(), style: oledEyebrow()),
);

/// One setting (`.o-set`): title and grey line, the control on the right,
/// a hairline under it; the row darkens a little on hover.
class OledSettingRow extends StatefulWidget {
  const OledSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.control,
    this.onTap,
    this.below,
    this.titleColor = OledInk.ink,
  });

  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final Widget? control;
  final VoidCallback? onTap;
  final Widget? below;
  final Color titleColor;

  @override
  State<OledSettingRow> createState() => _OledSettingRowState();
}

class _OledSettingRowState extends State<OledSettingRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    return Material(
      color: _hover ? const Color(0xFF050505) : OledInk.bg,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        hoverColor: Colors.transparent,
        focusColor: OledInk.ink.withValues(alpha: 0.05),
        highlightColor: Colors.transparent,
        splashColor: OledInk.ion.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF121212))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: oledText(size: 15, color: widget.titleColor),
                        ),
                        if (sub != null && sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            maxLines: widget.subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: oledText(size: 12.5, color: OledInk.mute),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.control != null) ...[
                    const SizedBox(width: 24),
                    widget.control!,
                  ],
                ],
              ),
              ?widget.below,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _switchTile(BuildContext context, SwitchTile tile) => OledSettingRow(
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  control: OledSwitch(
    value: tile.value,
    label: tile.title,
    onChanged: tile.onChanged,
  ),
);

Widget _sliderTile(BuildContext context, SliderTile tile) => OledSettingRow(
  title: tile.title,
  subtitle: tile.subtitle,
  control: Text('${tile.value.round()}', style: oledDoto(28)),
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

/// The mono value pill (« Meilleure ▾ ») opening the choices.
class OledValuePill extends StatelessWidget {
  const OledValuePill({
    super.key,
    required this.tooltip,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String tooltip;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value, style: oledText(size: 13.5)),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: OledInk.lineHover),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options[value] ?? value,
              maxLines: 1,
              style: oledMono(
                size: 13,
                color: OledInk.ink,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: OledInk.mute,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _dropdownTile(BuildContext context, DropdownTile tile) => OledSettingRow(
  title: tile.title,
  control: OledValuePill(
    tooltip: tile.title,
    value: tile.value,
    options: {for (final o in tile.options) o: tile.optionLabels?[o] ?? o},
    onSelected: tile.onChanged,
  ),
);

Widget _actionTile(BuildContext context, ActionTile tile) => OledSettingRow(
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
              color: OledInk.mute,
            )),
);

Widget _statusTile(BuildContext context, StatusTile tile) {
  final ok = tile.status.isInstalled;
  return OledSettingRow(
    title: tile.name,
    titleColor: ok ? OledInk.ink : OledInk.err,
    control: Flexible(
      child: Text(
        tile.status.version ?? context.l10n.settingsTilesNotFound,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: oledMono(size: 12.5, color: ok ? OledInk.ion : OledInk.err),
      ),
    ),
  );
}

BoxDecoration _panel(BuildContext context, BoxDecoration base) => BoxDecoration(
  color: OledInk.bg,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFF1A1A1A)),
);

Widget _toggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => OledSwitch(value: value, onChanged: onChanged);
