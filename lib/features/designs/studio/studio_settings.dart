import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'studio_widgets.dart';

/// Studio's settings (mockup Studio-Reglages.dc.html): « Paramètres » caption,
/// the section as a big title, underlined section tabs, then « Général » drawn
/// as the mockup's sectioned panel. Every other section frames today's view.
class StudioSettings extends StatelessWidget {
  const StudioSettings({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = AppColors.of(context);
    final path = GoRouterState.of(context).uri.path;
    final sections = [
      ('/settings/general', l10n.settingsGeneral),
      ('/settings/output', l10n.settingsOutput),
      ('/settings/appearance', l10n.settingsAppearance),
      ('/settings/performance', l10n.settingsPerformance),
      ('/settings/advanced', l10n.settingsAdvanced),
      ('/settings/system', l10n.settingsSystem),
      ('/settings/plugins', l10n.settingsPlugins),
      ('/settings/smart_organizer', l10n.smartOrganization),
    ];
    final general = path == '/settings' || path == '/settings/general';
    final appearance = path.startsWith('/settings/appearance');
    final title = general
        ? l10n.settingsGeneral
        : sections
              .firstWhere(
                (s) => path.startsWith(s.$1),
                orElse: () => (path, l10n.settings),
              )
              .$2;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioCap(l10n.settings),
        const SizedBox(height: 6),
        Text(title, style: studioTitle(c)),
        const SizedBox(height: 18),
        StudioTabs(
          tabs: [
            for (final (route, label) in sections)
              StudioTab(
                label: label,
                selected: route == '/settings/general'
                    ? general
                    : path.startsWith(route),
                onTap: () => context.go(route),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
        final pad = EdgeInsets.fromLTRB(side, 30, side, 0);
        if (general || appearance) {
          return SingleChildScrollView(
            padding: pad.copyWith(bottom: 40),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (general)
                      _GeneralPanel(stacked: constraints.maxWidth < 640)
                    else
                      _AppearancePanel(stacked: constraints.maxWidth < 640),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: pad,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: header,
                ),
              ),
            ),
            // Today's sub-page in Studio's components, its 700px column
            // lined up under the header instead of centred.
            Expanded(
              child: StudioThemed(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: (side - 24).clamp(0, 40).toDouble(),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700 + 48),
                      child: current,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GeneralPanel extends ConsumerWidget {
  const _GeneralPanel({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = AppColors.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final busy = ref.watch(dependencyBootstrapProvider.select((v) => v.isBusy));
    final qualities = qualityOptionLabels(l10n);
    final theme = ThemePresets.migrateId(s.themePreset);
    Widget block(String label, List<Widget> rows, {bool active = false}) =>
        _Block(label: label, active: active, stacked: stacked, rows: rows);
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block(l10n.settingsGeneral, active: true, [
            _Item(
              label: l10n.addSheetModeAudioOnly,
              trailing: StudioSwitch(
                value: s.audioOnly,
                label: l10n.addSheetModeAudioOnly,
                onChanged: set.setAudioOnly,
              ),
            ),
            _Item(
              label: l10n.studioAutoStart,
              trailing: StudioSwitch(
                value: s.autoStart,
                label: l10n.studioAutoStart,
                onChanged: set.setAutoStart,
              ),
            ),
            _Item(
              label: l10n.preferredQuality,
              trailing: _Select(
                value: s.preferredQuality,
                labels: qualities,
                onChanged: set.setPreferredQuality,
              ),
            ),
          ]),
          block(l10n.settingsOutput, [
            _Item(
              label: l10n.storageFolder,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.outputFolder.isNotEmpty)
                    Flexible(child: _Code(s.outputFolder)),
                  const SizedBox(width: 10),
                  StudioButton(
                    label: l10n.studioChange,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: () => pickOutputFolder(context, ref),
                  ),
                ],
              ),
            ),
            // No file-name template setting exists: the video format instead.
            _Item(
              label: l10n.formatLabel,
              trailing: _Select(
                value: s.outputFormat,
                labels: const {'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WEBM'},
                onChanged: set.setOutputFormat,
                mono: true,
              ),
            ),
          ]),
          block(l10n.settingsAppearance, [
            _Thumbs(
              ids: _designOrder,
              selected: theme,
              onSelect: set.setThemePreset,
            ),
          ]),
          block(l10n.settingsPerformance, [
            _Item(
              label: l10n.simultaneousDownloads,
              trailing: _Stepper(
                value: s.maxConcurrent.clamp(1, 60),
                min: 1,
                max: 60,
                onChanged: set.setMaxConcurrent,
              ),
            ),
            _Item(
              label: l10n.reduceEffects,
              trailing: StudioSwitch(
                value: s.reduceEffects,
                label: l10n.reduceEffects,
                onChanged: set.setReduceEffects,
              ),
            ),
          ]),
          block(l10n.settingsSystem, [
            _Item(
              labelWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.studioTools, style: studioText(c)),
                  const SizedBox(height: 3),
                  Text(
                    'yt-dlp · ffmpeg · aria2c',
                    style: studioMono(c, size: 11, color: c.textDisabled),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const StudioRecDot(),
                    const SizedBox(width: 6),
                    Text(
                      l10n.studioChecking,
                      style: studioText(c, size: 12, color: c.textSecondary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: StudioButton(
                      label: l10n.previewSetup,
                      icon: Icons.build_outlined,
                      kind: StudioButtonKind.light,
                      height: 32,
                      onTap: busy
                          ? null
                          : () => ref
                                .read(dependencyBootstrapProvider.notifier)
                                .ensureReady(),
                    ),
                  ),
                ],
              ),
            ),
            _Item(
              label: l10n.onboardingReplayDesc,
              trailing: StudioButton(
                label: l10n.studioReplay,
                kind: StudioButtonKind.light,
                height: 32,
                onTap: () {
                  context.go('/');
                  ref.read(onboardingControllerProvider.notifier).replay();
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// One section of the panel: its caption on the left (a dot when it is the
/// page's own section), its rows on the right.
class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.rows,
    required this.active,
    required this.stacked,
  });

  final String label;
  final List<Widget> rows;
  final bool active;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final caption = Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: active ? c.textPrimary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: studioText(
              c,
              size: 11,
              color: active ? c.textPrimary : c.textDisabled,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.66),
          ),
        ),
      ],
    );
    final items = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const StudioRule(),
          rows[i],
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: active ? studioHover(c) : null,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: caption,
                ),
                items,
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: caption,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: items),
              ],
            ),
    );
  }
}

/// A setting row: 48px at least, label left, control right.
class _Item extends StatelessWidget {
  const _Item({this.label, this.labelWidget, required this.trailing});

  final String? label;
  final Widget? labelWidget;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: labelWidget ?? Text(label!, style: studioText(c))),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.sel`: a white 32px box with a chevron, opening a menu.
class _Select extends StatelessWidget {
  const _Select({
    required this.value,
    required this.labels,
    required this.onChanged,
    this.mono = false,
  });

  final String value;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = mono ? studioMono(c, color: c.textPrimary) : studioText(c);
    return PopupMenuButton<String>(
      tooltip: '',
      initialValue: value,
      onSelected: onChanged,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (context) => [
        for (final e in labels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            height: 36,
            child: Text(e.value, style: style),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labels[value] ?? value, style: style),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.code`: a mono chip on the paper colour with an inner hairline.
class _Code extends StatelessWidget {
  const _Code(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: studioMono(c, size: 12, color: c.textPrimary),
      ),
    );
  }
}

/// `.step`: − value + in a ringed box.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    Widget button(IconData icon, String tip, int? next) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: next == null ? null : () => onChanged(next),
        borderRadius: BorderRadius.circular(8),
        hoverColor: studioHover(c),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 13,
            color: next == null ? const Color(0xFFB8B5AE) : c.textPrimary,
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Icons.remove_rounded,
            l10n.studioDecrease,
            value > min ? value - 1 : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: studioMono(
                c,
                color: c.textPrimary,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          button(
            Icons.add_rounded,
            l10n.studioIncrease,
            value < max ? value + 1 : null,
          ),
        ],
      ),
    );
  }
}

/// The six designs as small swatches; the chosen one wears an ink ring and a
/// tick. OLED and iOS stay in the full Appearance section.
/// The mockup's order; OLED and iOS are platform looks, not designs.
const _designOrder = [
  'signal',
  'porcelaine',
  'studio',
  'pastille',
  'terminal',
  'nocturne',
];

class _Thumbs extends StatelessWidget {
  const _Thumbs({
    required this.ids,
    required this.selected,
    required this.onSelect,
  });

  final List<String> ids;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final presets = [for (final id in ids) ThemePresets.getById(id)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = ((constraints.maxWidth + 12) / (112 + 12))
              .floor()
              .clamp(1, presets.length);
          final width = (constraints.maxWidth - 12 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in presets)
                SizedBox(
                  width: width,
                  child: _Thumb(
                    preset: p,
                    on: p.id == selected,
                    onTap: () => onSelect(p.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.preset, required this.on, required this.onTap});

  final ThemePreset preset;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = widget.preset;
    Widget bar(double f, Color color) => FractionallySizedBox(
      widthFactor: f,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return Semantics(
      selected: widget.on,
      button: true,
      label: p.name,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: studioMotion(context, 180),
              transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
              height: 62,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.on ? c.textPrimary : c.border,
                  width: widget.on ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The design's signature colour: its accent when the
                      // primary is just its ink (Studio).
                      bar(
                        0.6,
                        (p.primary == p.textPrimary ? p.accent : p.primary)
                            .withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 5),
                      bar(0.85, p.textPrimary.withValues(alpha: 0.35)),
                      const SizedBox(height: 5),
                      bar(0.7, p.textPrimary.withValues(alpha: 0.35)),
                    ],
                  ),
                  if (widget.on)
                    PositionedDirectional(
                      end: -4,
                      bottom: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: c.surface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              p.name,
              style: studioText(
                c,
                size: 12,
                color: widget.on || _hover ? c.textPrimary : c.textSecondary,
              ).copyWith(fontWeight: widget.on ? FontWeight.w500 : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Apparence » drawn like « Général »: every look (OLED and iOS too), the
/// light/dark choice for the designs that follow it, the accent colour and
/// the language, as today's Appearance section offers.
class _AppearancePanel extends ConsumerWidget {
  const _AppearancePanel({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final theme = ThemePresets.migrateId(s.themePreset);
    Widget block(String label, List<Widget> rows, {bool active = false}) =>
        _Block(label: label, active: active, stacked: stacked, rows: rows);
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block(l10n.theme, active: true, [
            // Only the looks without a brightness of their own (iOS) follow it.
            if (DesignSpec.forId(theme).brightness == null)
              _Item(
                label: l10n.theme,
                trailing: _Select(
                  value: s.themeMode,
                  labels: themeModeOptionLabels(l10n),
                  onChanged: set.setThemeMode,
                ),
              ),
            _Thumbs(
              ids: [for (final p in ThemePresets.all) p.id],
              selected: theme,
              onSelect: set.setThemePreset,
            ),
          ]),
          if (s.themePreset != 'oled')
            block(l10n.accentColor, [
              _Accents(
                current: Color(s.customAccentColor),
                onChanged: (color) =>
                    set.setCustomAccentColor(color.toARGB32()),
              ),
            ]),
          block(l10n.language, [
            _Item(
              label: l10n.language,
              trailing: _Select(
                value: s.locale,
                labels: languageOptionLabels(l10n),
                onChanged: set.setLocale,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The current accent (swatch and hex) over the twelve choices, as small
/// squares with an ink ring and tick on the chosen one.
class _Accents extends StatelessWidget {
  const _Accents({required this.current, required this.onChanged});

  final Color current;
  final ValueChanged<Color> onChanged;

  // Today's Appearance section offers the same twelve.
  static const _colors = [
    Color(0xFF0D9488),
    Color(0xFF0A84FF),
    Color(0xFF0EA5E9),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFFC026D3),
    Color(0xFF6366F1),
    Color(0xFFEAB308),
    Color(0xFFF43F5E),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hex = current
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: c.border),
                ),
              ),
              const SizedBox(width: 10),
              Text(context.l10n.currentAccent, style: studioText(c)),
              const SizedBox(width: 10),
              _Code('#$hex'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _colors)
                _Swatch(
                  color: color,
                  on: color.toARGB32() == current.toARGB32(),
                  onTap: () => onChanged(color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({required this.color, required this.on, required this.onTap});

  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: widget.on,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: studioMotion(context, 160),
          curve: studioEase,
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.on ? c.textPrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(5),
            ),
            child: widget.on
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

// ── Shared settings tiles, drawn by Studio (see studioSkin) ────────────────

/// A shared tile as a Studio row on the paper: label and note on the left,
/// the control on the right, an optional line under them, a hairline below.
class _TileRow extends StatefulWidget {
  const _TileRow({
    required this.title,
    this.subtitle = '',
    this.subtitleMaxLines,
    this.trailing,
    this.onTap,
    this.below,
  });

  final String title;
  final String subtitle;
  final int? subtitleMaxLines;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? below;

  @override
  State<_TileRow> createState() => _TileRowState();
}

class _TileRowState extends State<_TileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tappable = widget.onTap != null;
    final title = studioText(c, size: 14).copyWith(fontWeight: FontWeight.w500);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onHover: tappable ? (v) => setState(() => _hover = v) : null,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: studioMotion(context, 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? c.surface.withValues(alpha: 0.6) : null,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          tappable
                              ? StudioUnderline(
                                  text: widget.title,
                                  hover: _hover,
                                  style: title,
                                )
                              : Text(widget.title, style: title),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              maxLines: widget.subtitleMaxLines,
                              overflow: widget.subtitleMaxLines == null
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: studioText(
                                c,
                                size: 12,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 16),
                      // Sized by its content, so the note keeps the width.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: widget.trailing,
                      ),
                    ],
                  ],
                ),
              ),
              ?widget.below,
            ],
          ),
        ),
      ),
    );
  }
}

Widget studioSectionTitle(BuildContext context, SectionTitle tile) => Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 4),
  child: StudioCap(tile.title),
);

Widget studioSwitchTile(BuildContext context, SwitchTile tile) => _TileRow(
  title: tile.title,
  subtitle: tile.subtitle,
  onTap: () => tile.onChanged(!tile.value),
  trailing: StudioSwitch(
    value: tile.value,
    label: tile.title,
    onChanged: tile.onChanged,
  ),
);

/// The value in the ringed − n + stepper, and a thin ink slider under it for
/// big jumps.
Widget studioSliderTile(BuildContext context, SliderTile tile) {
  final c = AppColors.of(context);
  final divisions = tile.divisions;
  final step = divisions == null || divisions == 0
      ? 1.0
      : (tile.max - tile.min) / divisions;
  double clamp(double v) => v.clamp(tile.min, tile.max).toDouble();
  return _TileRow(
    title: tile.title,
    subtitle: tile.subtitle,
    trailing: _Stepper(
      value: tile.value.round(),
      min: tile.min.round(),
      max: tile.max.round(),
      onChanged: (v) => tile.onChanged(
        clamp(v > tile.value.round() ? tile.value + step : tile.value - step),
      ),
    ),
    below: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SliderTheme(
        data: studioSliderTheme(c),
        child: Slider(
          value: clamp(tile.value),
          min: tile.min,
          max: tile.max,
          divisions: divisions,
          onChanged: tile.onChanged,
        ),
      ),
    ),
  );
}

Widget studioDropdownTile(BuildContext context, DropdownTile tile) => _TileRow(
  title: tile.title,
  trailing: _Select(
    value: tile.value,
    labels: {for (final o in tile.options) o: tile.optionLabels?[o] ?? o},
    onChanged: tile.onChanged,
  ),
);

Widget studioActionTile(BuildContext context, ActionTile tile) {
  final c = AppColors.of(context);
  return _TileRow(
    title: tile.title,
    subtitle: tile.subtitle,
    subtitleMaxLines: tile.subtitleMaxLines,
    onTap: tile.onTap,
    trailing:
        tile.trailing ??
        (tile.onTap == null
            ? null
            : Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: c.textSecondary,
              )),
  );
}

/// A tool's name, then its version in mono beside an ink tick, or « not
/// found » in red beside a red dot.
Widget studioStatusTile(BuildContext context, StatusTile tile) {
  final c = AppColors.of(context);
  final ok = tile.status.isInstalled;
  return _TileRow(
    title: tile.name,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ok
            ? Icon(Icons.check_rounded, size: 14, color: c.textPrimary)
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.error,
                  shape: BoxShape.circle,
                ),
              ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            tile.status.version ?? context.l10n.settingsTilesNotFound,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: studioMono(c, size: 12, color: ok ? c.textPrimary : c.error),
          ),
        ),
      ],
    ),
  );
}
