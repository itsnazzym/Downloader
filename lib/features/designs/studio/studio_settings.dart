import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
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
        if (general) {
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
                    _GeneralPanel(stacked: constraints.maxWidth < 640),
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
            Expanded(child: current),
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
            KeyedSubtree(
              key: OnboardingTargets.outputFolder,
              child: _Item(
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
            _Thumbs(selected: theme, onSelect: set.setThemePreset),
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
            Expanded(
              child: labelWidget ?? Text(label!, style: studioText(c)),
            ),
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
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // The mockup's order; OLED and iOS are platform looks, not designs.
    const order = [
      'signal',
      'porcelaine',
      'studio',
      'pastille',
      'terminal',
      'nocturne',
    ];
    final presets = [for (final id in order) ThemePresets.getById(id)];
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
