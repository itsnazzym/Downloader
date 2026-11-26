import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart'
    show qualityOptionLabels;
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'porcelaine_widgets.dart';

/// Porcelaine's settings (Porcelaine-Reglages.dc.html). « Général » is drawn
/// from the mockup; every other section keeps today's view ([current])
/// framed on a Porcelaine sheet under the same header and tabs.
class PorcelaineSettings extends StatelessWidget {
  const PorcelaineSettings({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final general = path == '/settings' || path == '/settings/general';
    final header = _Header(path: general ? '/settings/general' : path);
    if (general) {
      return PPage(
        children: [header, const SizedBox(height: 26), const _GeneralBento()],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 1284 ? (box.maxWidth - 1220) / 2 : 32.0;
        final colors = AppColors.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 26),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pCardFill(colors),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: pCardShadow(colors),
                  ),
                  child: current,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<(String, String)> _sections(BuildContext context) {
  final l10n = context.l10n;
  return [
    ('/settings/general', l10n.settingsGeneral),
    ('/settings/output', l10n.settingsOutput),
    ('/settings/appearance', l10n.settingsAppearance),
    ('/settings/performance', l10n.settingsPerformance),
    ('/settings/system', l10n.settingsSystem),
    ('/settings/plugins', l10n.settingsPlugins),
    ('/settings/advanced', l10n.settingsAdvanced),
    ('/settings/smart_organizer', l10n.smartOrganization),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final sections = _sections(context);
    final title = sections
        .firstWhere((s) => s.$1 == path, orElse: () => sections.first)
        .$2;
    return Column(
      children: [
        PPageTitle(
          eyebrow: l10n.porcelaineSettingsTab,
          title: title,
          subtitle: path == '/settings/general'
              ? l10n.porcelaineSettingsGeneralDesc
              : null,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.surface.withValues(alpha: 0.7),
              colors.background,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.07),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (p, label) in sections)
                _TabPill(
                  label: label,
                  selected: p == path,
                  onTap: () => context.go(p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: on ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: pBody(
                    colors,
                    size: 13,
                    weight: on ? FontWeight.w600 : FontWeight.w500,
                    color: on
                        ? colors.background
                        : (_hover ? colors.textPrimary : colors.textSecondary),
                  ).copyWith(height: 1.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── « Général » ────────────────────────────────────────────────────────────

class _GeneralBento extends StatelessWidget {
  const _GeneralBento();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final gap = wide ? 20.0 : 14.0;
        Widget row(List<(int, Widget)> cells) => wide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, (flex, w)) in cells.indexed) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(flex: flex, child: w),
                    ],
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (_, w)) in cells.indexed) ...[
                    if (i > 0) SizedBox(height: gap),
                    w,
                  ],
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row([
              (4, const _GeneralCard()),
              (4, const _OutputCard()),
              (4, const _PerformanceCard()),
            ]),
            SizedBox(height: gap),
            row([(8, const _AppearanceCard()), (4, const _ToolsCard())]),
            SizedBox(height: gap),
            const _MoreRow(),
          ],
        );
      },
    );
  }
}

/// `.row`: a 52px line with a hairline above (none on the first).
class _Line extends StatelessWidget {
  const _Line({required this.child, this.first = false, this.minHeight = 52});

  final Widget child;
  final bool first;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
            ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.first = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _Line(
      first: first,
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(child: Text(label, style: pBody(colors))),
            PSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The current section's card wears the accent ring.
class _Ring extends StatelessWidget {
  const _Ring({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The glow sits under the card, the 2px line over its edge.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            spreadRadius: 6,
          ),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.primary, width: 2),
        ),
        child: child,
      ),
    );
  }
}

class _GeneralCard extends ConsumerWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final labels = qualityOptionLabels(l10n);
    return _Ring(
      child: PCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PHead(
              icon: Icons.tune_rounded,
              label: l10n.settingsGeneral,
              tint: colors.primary,
              bottom: 12,
            ),
            _SwitchLine(
              first: true,
              label: l10n.porcelaineFormatAudio,
              value: s.audioOnly,
              onChanged: n.setAudioOnly,
            ),
            _SwitchLine(
              label: l10n.porcelaineAutoStart,
              value: s.autoStart,
              onChanged: n.setAutoStart,
            ),
            _Line(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.preferredQuality, style: pBody(colors)),
                    const SizedBox(height: 8),
                    _Select(
                      label: l10n.preferredQuality,
                      value: s.preferredQuality,
                      options: labels,
                      onChanged: n.setPreferredQuality,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.sel` + `.menu`: a 44px stone field opening a white menu.
class _Select extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      tooltip: label,
      color: colors.surface,
      elevation: 12,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final e in options.entries)
          PopupMenuItem<String>(
            value: e.key,
            height: 34,
            child: Row(
              children: [
                Expanded(child: Text(e.value, style: pBody(colors, size: 13))),
                if (e.key == value)
                  Icon(Icons.circle, size: 8, color: colors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                options[value] ?? value,
                style: pBody(colors, size: 13.5, weight: FontWeight.w500),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends ConsumerWidget {
  const _OutputCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget field(Widget child, {double end = 6}) => Container(
      height: 48,
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, end, 0),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
      ),
      child: child,
    );
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.folder_outlined,
            label: l10n.settingsOutput,
            bottom: 12,
          ),
          Text(
            l10n.downloadFolder,
            style: pBody(colors, size: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          field(
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.outputFolder.isEmpty ? l10n.selectFolder : s.outputFolder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pMono(colors, size: 13.5, color: colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                KeyedSubtree(
                  key: OnboardingTargets.outputFolder,
                  child: PBtn(
                    label: l10n.porcelaineChange,
                    height: 36,
                    padding: 14,
                    onTap: () => pickOutputFolder(context, ref),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // The mockup's « Modèle de nom » has no setting behind it: the
          // video format, which shapes every file name's extension, sits here.
          Text(
            l10n.formatLabel,
            style: pBody(colors, size: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          _Select(
            label: l10n.formatLabel,
            value: s.outputFormat,
            options: const {'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WebM'},
            onChanged: n.setOutputFormat,
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends ConsumerWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    // Same bounds as today's Performance page slider.
    const min = 1, max = 60;
    Widget step(IconData icon, String tip, VoidCallback? onTap) => PBtn(
      label: '',
      icon: icon,
      height: 36,
      padding: 10.5,
      tooltip: tip,
      onTap: onTap,
    );
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.speed_rounded,
            label: l10n.settingsPerformance,
            tint: pGreen,
            bottom: 12,
          ),
          _Line(
            first: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.porcelaineParallelDownloads,
                    style: pBody(colors),
                  ),
                ),
                step(
                  Icons.remove_rounded,
                  l10n.porcelaineOneLess,
                  s.maxConcurrent > min
                      ? () => n.setMaxConcurrent(s.maxConcurrent - 1)
                      : null,
                ),
                SizedBox(
                  width: 44,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${s.maxConcurrent}',
                      textAlign: TextAlign.center,
                      style: pDisp(26, color: colors.textPrimary),
                    ),
                  ),
                ),
                step(
                  Icons.add_rounded,
                  l10n.porcelaineOneMore,
                  s.maxConcurrent < max
                      ? () => n.setMaxConcurrent(s.maxConcurrent + 1)
                      : null,
                ),
              ],
            ),
          ),
          _SwitchLine(
            label: l10n.porcelaineReduceEffects,
            value: s.reduceEffects,
            onChanged: n.setReduceEffects,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.porcelaineReduceEffectsHint,
            style: pBody(colors, size: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  static const _designs = [
    'signal',
    'porcelaine',
    'studio',
    'pastille',
    'terminal',
    'nocturne',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final current = ThemePresets.migrateId(
      ref.watch(settingsProvider.select((s) => s.themePreset)),
    );
    final active = ThemePresets.getById(current);
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.contrast_rounded,
            label: l10n.settingsAppearance,
            tint: pPink,
            bottom: 12,
            trailing: Expanded(
              child: Text(
                l10n.porcelaineDesignActive(active.name),
                textAlign: TextAlign.end,
                style: pBody(
                  colors,
                  size: 13,
                  weight: FontWeight.w500,
                  color: colors.textDisabled,
                ),
              ),
            ),
          ),
          // A plain row: the card sits in an IntrinsicHeight, which a
          // LayoutBuilder cannot answer.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, id) in _designs.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _DesignTile(
                    preset: ThemePresets.getById(id),
                    selected: id == current,
                    onTap: () =>
                        ref.read(settingsProvider.notifier).setThemePreset(id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DesignTile extends StatefulWidget {
  const _DesignTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesignTile> createState() => _DesignTileState();
}

class _DesignTileState extends State<_DesignTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = widget.preset;
    final light = DesignSpec.forId(p.id).brightness == Brightness.light;
    final on = widget.selected;
    final up = _hover && !on;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      label: p.name,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: pMotion(context, 200),
          curve: pEase,
          transform: Matrix4.translationValues(0, up ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: on || up ? colors.surface : const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on
                  ? colors.primary
                  : colors.textPrimary.withValues(alpha: up ? 0.08 : 0.06),
              width: on ? 2 : 1,
            ),
            boxShadow: [
              if (on)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  spreadRadius: 4,
                ),
              if (up)
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  on ? 7 : 8,
                  on ? 7 : 8,
                  on ? 7 : 8,
                  on ? 9 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 70,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(
                                widthFactor: 0.7,
                                child: Container(
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: light
                                        ? p.surface
                                        : Color.lerp(
                                            p.background,
                                            p.textPrimary,
                                            0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              FractionallySizedBox(
                                widthFactor: 0.45,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: p.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (on)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pBody(colors, size: 13, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolsCard extends ConsumerWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final setup = ref.watch(dependencyBootstrapProvider);
    String status(String tool) {
      if (setup.readyTools.any((t) => t.toLowerCase().startsWith(tool))) {
        return l10n.porcelaineToolReady;
      }
      if (setup.isBusy &&
          setup.toolName.toLowerCase().contains(tool.split('-').first)) {
        return l10n.porcelaineToolChecking;
      }
      return l10n.porcelaineToolUnchecked;
    }

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.build_outlined,
            label: l10n.settingsToolsSection,
            tint: pSlate,
            bottom: 12,
          ),
          for (final (i, tool) in const ['yt-dlp', 'ffmpeg', 'aria2c'].indexed)
            _Line(
              first: i == 0,
              minHeight: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tool,
                      style: pMono(
                        colors,
                        size: 13.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    status(tool),
                    style: pBody(
                      colors,
                      size: 12.5,
                      color: status(tool) == l10n.porcelaineToolReady
                          ? colors.success
                          : colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          PBtn(
            label: l10n.previewSetup,
            height: 38,
            onTap: setup.isBusy
                ? null
                : () => ref
                      .read(dependencyBootstrapProvider.notifier)
                      .ensureReady(),
          ),
        ],
      ),
    );
  }
}

/// Today's General page also replays the tour and opens smart organisation.
class _MoreRow extends ConsumerWidget {
  const _MoreRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        PBtn(
          label: l10n.onboardingReplay,
          icon: Icons.replay_rounded,
          kind: PBtnKind.ghost,
          onTap: () {
            context.go('/');
            ref.read(onboardingControllerProvider.notifier).replay();
          },
        ),
        PBtn(
          label: l10n.smartOrganization,
          icon: Icons.auto_awesome_motion_rounded,
          kind: PBtnKind.ghost,
          onTap: () => context.go('/settings/smart_organizer'),
        ),
      ],
    );
  }
}
