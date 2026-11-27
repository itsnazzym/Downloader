import 'package:flutter/material.dart';
import 'package:modern_downloader/core/design_system/design_skin.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'pastille_kit.dart';
import 'pastille_parts.dart';

/// How Pastille draws the shared library rows and settings tiles (see
/// [DesignSkin]): dark cards with a pastel status pill for the rows, pastel
/// tiles with ink controls for the settings.
const pastilleSkin = DesignSkin(
  row: _row,
  sectionTitle: _sectionTitle,
  switchTile: _switchTile,
  sliderTile: _sliderTile,
  dropdownTile: _dropdownTile,
  actionTile: _actionTile,
  statusTile: _statusTile,
);

Widget _row(BuildContext context, DesignRow row) => _PastilleRow(row: row);

// ── Library row ─────────────────────────────────────────────────────────────

bool _finished(DownloadStatus s) =>
    s == DownloadStatus.failed ||
    s == DownloadStatus.canceled ||
    s == DownloadStatus.completed;

bool _ageBlocked(DownloadItem i) =>
    i.status == DownloadStatus.failed &&
    DownloadStatusGuard.isAgeVerificationFailure(
      error: i.error,
      url: i.request.url,
    );

/// "YouTube · MP4 · 54,1 Mo" or, while it runs, "6,2 Mo/s · reste 5 s".
String _meta(BuildContext context, DownloadItem item) {
  final l10n = context.l10n;
  final size = bytesOf(item);
  final parts = <String>[
    if (item.source.isNotEmpty) item.source,
    formatLabelOf(item),
    if (size > 0) localBytes(l10n, size),
  ];
  if (isActiveDownload(item)) {
    final speed = parseSpeed(item.speed);
    final phase = livePhase(item, speed);
    if (phase != null) {
      parts.add(livePhaseLabel(l10n, phase));
    } else if (speed != null) {
      final s = formatSpeed(l10n, speed);
      parts.add('${s.value} ${s.unit}');
    }
    if (item.eta.isNotEmpty) {
      parts.add(l10n.designRemaining(etaLabel(l10n, item.eta)));
    }
  }
  return parts.join(' · ');
}

Color _thumbTone(DownloadItem item) => item.status == DownloadStatus.failed
    ? const Color(0xFFCFCFD1)
    : switch (mediaKindOf(item)) {
        MediaKind.video => const Color(0xFFD8CFBD),
        MediaKind.audio => const Color(0xFFCDCAD8),
        MediaKind.image => const Color(0xFFD5CEC4),
      };

class _PastilleRow extends StatefulWidget {
  const _PastilleRow({required this.row});

  final DesignRow row;

  @override
  State<_PastilleRow> createState() => _PastilleRowState();
}

class _PastilleRowState extends State<_PastilleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final item = row.item;
    final tones = PTones.of(context);
    final radius = BorderRadius.circular(row.grid ? 26 : 24);
    final body = row.grid ? _grid(context) : _list(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: pMotion(context, 250),
        curve: pEase,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _hover || row.isSelected ? const Color(0xFF2A2723) : pCard,
          borderRadius: radius,
          boxShadow: [
            if (row.isSelected) ...[
              BoxShadow(color: pToneOf(context, item.status), spreadRadius: 2),
            ] else
              BoxShadow(color: pCream.withValues(alpha: 0.07), spreadRadius: 1),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            hoverColor: Colors.transparent,
            focusColor: tones.butter.withValues(alpha: 0.2),
            onTap: row.onTap,
            child: Semantics(
              selected: row.isSelected,
              label: titleOf(item),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(int lines) => Text(
    titleOf(widget.row.item),
    maxLines: lines,
    overflow: TextOverflow.ellipsis,
    style: pBody(
      size: 14.5,
      weight: FontWeight.w700,
      color: pCream,
      height: 1.3,
    ),
  );

  /// The second line: why it failed, the age check, the progress or the meta.
  Widget _detail(BuildContext context, {required bool grid}) {
    final l10n = context.l10n;
    final item = widget.row.item;
    final tones = PTones.of(context);
    if (_ageBlocked(item)) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: PButton(
          label: '${l10n.ageCheckRequired} · ${l10n.ageCheckSeeSolutions}',
          icon: Icons.shield_outlined,
          kind: PButtonKind.butter,
          height: 28,
          padH: 12,
          fontSize: 12,
          iconSize: 13,
          onTap: () => AgeVerificationHelpDialog.show(context, item),
        ),
      );
    }
    if (item.status == DownloadStatus.failed) {
      final reason = downloadErrorReason(item.error);
      return Tooltip(
        message: item.error ?? '',
        child: Text(
          reason.isEmpty ? l10n.designFailed : reason,
          maxLines: grid ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: pBody(size: 12.5, weight: FontWeight.w500, color: tones.rose),
        ),
      );
    }
    final meta = Text(
      _meta(context, item),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: pBody(size: 12.5, weight: FontWeight.w500, color: pMuted),
    );
    if (!isActiveDownload(item) && item.status != DownloadStatus.paused) {
      return meta;
    }
    final pct = (item.progress * 100).clamp(0, 100).floor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: PDots(
                count: 40,
                columns: 40,
                gap: 3,
                on: (pct * 40 / 100).floor(),
                live: true,
                paused: item.status == DownloadStatus.paused,
                cascade: false,
                maxWidth: 420,
                semanticLabel: '$pct %',
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$pct %',
              style: pMono(size: 12, weight: FontWeight.w500, color: pCream),
            ),
          ],
        ),
        const SizedBox(height: 4),
        meta,
      ],
    );
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = context.l10n;
    final row = widget.row;
    if (!_finished(row.item.status)) return const [];
    return [
      PButton(
        icon: Icons.refresh_rounded,
        tooltip: l10n.retryDownload,
        kind: PButtonKind.ghost,
        height: 34,
        iconSize: 16,
        onTap: row.onRetry,
      ),
      const SizedBox(width: 6),
      PButton(
        icon: Icons.delete_outline_rounded,
        tooltip: l10n.remove,
        kind: PButtonKind.ghost,
        height: 34,
        iconSize: 16,
        onTap: row.onCancel,
      ),
    ];
  }

  Widget _list(BuildContext context) {
    final item = widget.row.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 58,
            child: PThumb(
              url: item.thumbnailUrl,
              filePath: item.filePath,
              tone: _thumbTone(item),
              radius: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _title(1),
                const SizedBox(height: 5),
                _detail(context, grid: false),
              ],
            ),
          ),
          const SizedBox(width: 14),
          PStatusPill(status: item.status, tooltip: item.error),
          if (_finished(item.status)) const SizedBox(width: 10),
          ..._actions(context),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final item = widget.row.item;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PThumb(
                  url: item.thumbnailUrl,
                  filePath: item.filePath,
                  tone: _thumbTone(item),
                  radius: 18,
                ),
                PositionedDirectional(
                  top: 10,
                  start: 10,
                  child: PStatusPill(status: item.status, tooltip: item.error),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(1),
                const SizedBox(height: 4),
                SizedBox(height: 40, child: _detail(context, grid: true)),
                SizedBox(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _actions(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings tiles ──────────────────────────────────────────────────────────

Widget _sectionTitle(BuildContext context, SectionTitle tile) {
  final tones = PTones.of(context);
  // One Text (dots as spans): some pages put the title in a Row that does
  // not bound its width.
  return Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 12, left: 4),
    child: Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            for (final c in [tones.lav, tones.sage, tones.rose])
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ),
            const WidgetSpan(child: SizedBox(width: 8)),
            TextSpan(text: tile.title),
          ],
        ),
        style: pNum(
          22,
          weight: FontWeight.w700,
          color: pCream,
        ).copyWith(letterSpacing: -0.6, height: 1.1),
      ),
    ),
  );
}

/// One setting as a pastel tile: icon, title and description in ink, the
/// control on the right (or under it).
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.subtitleLines = 2,
    this.trailing,
    this.below,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final int subtitleLines;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PTile(
        color: color,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
        semanticLabel: title,
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: pInk.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: pInk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: pBody(
                            size: 14.5,
                            weight: FontWeight.w700,
                            color: pInk,
                            height: 1.3,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: subtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: pSub(context),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 14),
                    // A view's own trailing (copy icon, text button) reads
                    // in ink on the pastel tile.
                    Theme(
                      data: Theme.of(context).copyWith(
                        iconButtonTheme: const IconButtonThemeData(
                          style: ButtonStyle(
                            foregroundColor: WidgetStatePropertyAll(pInk),
                          ),
                        ),
                        textButtonTheme: const TextButtonThemeData(
                          style: ButtonStyle(
                            foregroundColor: WidgetStatePropertyAll(pInk),
                          ),
                        ),
                      ),
                      child: IconTheme.merge(
                        data: const IconThemeData(color: pInk),
                        child: trailing!,
                      ),
                    ),
                  ],
                ],
              ),
              if (below != null) ...[const SizedBox(height: 10), below!],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _switchTile(BuildContext context, SwitchTile tile) => _SettingTile(
  color: PTones.of(context).sage,
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  trailing: PSwitch(
    value: tile.value,
    onChanged: tile.onChanged,
    label: tile.title,
  ),
);

Widget _sliderTile(BuildContext context, SliderTile tile) => _SettingTile(
  color: PTones.of(context).lav,
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  trailing: Semantics(
    liveRegion: true,
    child: Text(tile.value.toInt().toString(), style: pNum(34, color: pInk)),
  ),
  below: SliderTheme(
    data: SliderThemeData(
      trackHeight: 8,
      activeTrackColor: pInk,
      inactiveTrackColor: pInk.withValues(alpha: 0.14),
      thumbColor: pInk,
      overlayColor: pInk.withValues(alpha: 0.1),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      activeTickMarkColor: pCream.withValues(alpha: 0.6),
      inactiveTickMarkColor: pInk.withValues(alpha: 0.3),
      valueIndicatorColor: pInk,
      valueIndicatorTextStyle: pMono(size: 12, color: pCream),
    ),
    child: Slider(
      value: tile.value,
      min: tile.min,
      max: tile.max,
      divisions: tile.divisions,
      label: tile.value.toInt().toString(),
      onChanged: tile.onChanged,
    ),
  ),
);

Widget _dropdownTile(BuildContext context, DropdownTile tile) {
  String label(String o) => tile.optionLabels?[o] ?? o;
  return _SettingTile(
    color: PTones.of(context).sky,
    icon: tile.icon,
    title: tile.title,
    trailing: PMenu<String>(
      tooltip: tile.title,
      onSelected: tile.onChanged,
      items: (context) => [
        for (final o in tile.options)
          pMenuItem(value: o, label: label(o), checked: o == tile.value),
      ],
      child: Container(
        height: 38,
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        decoration: BoxDecoration(
          color: pInk,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label(tile.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pBody(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: pCream,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: pCream,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _actionTile(BuildContext context, ActionTile tile) => _SettingTile(
  color: PTones.of(context).cream,
  icon: tile.icon,
  title: tile.title,
  subtitle: tile.subtitle,
  subtitleLines: tile.subtitleMaxLines,
  onTap: tile.onTap,
  trailing:
      tile.trailing ??
      Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(color: pInk, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_forward_rounded, size: 16, color: pCream),
      ),
);

Widget _statusTile(BuildContext context, StatusTile tile) {
  final ok = tile.status.isInstalled;
  final tones = PTones.of(context);
  return _SettingTile(
    color: ok ? tones.sage : tones.rose,
    icon: ok ? Icons.check_rounded : Icons.priority_high_rounded,
    title: tile.name,
    trailing: Container(
      height: 30,
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pInk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tile.status.version ?? context.l10n.settingsTilesNotFound,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: pMono(size: 12, weight: FontWeight.w500, color: pCream),
      ),
    ),
  );
}
