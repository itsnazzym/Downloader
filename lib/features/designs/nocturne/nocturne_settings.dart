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
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'nocturne_widgets.dart';

/// Nocturne's settings (mockup Nocturne-Reglages.dc.html): a section list on
/// the left. « Général » is drawn from the mockup; every other section shows
/// today's view ([current]) framed in a card, so no setting is lost.
class NocturneSettings extends StatelessWidget {
  const NocturneSettings({super.key, required this.current});

  final Widget current;

  static List<(String, String, IconData)> sections(AppLocalizations l10n) => [
    ('/settings/general', l10n.settingsGeneral, Icons.tune_rounded),
    ('/settings/output', l10n.settingsOutput, Icons.folder_outlined),
    (
      '/settings/appearance',
      l10n.settingsAppearance,
      Icons.pie_chart_outline_rounded,
    ),
    ('/settings/performance', l10n.settingsPerformance, Icons.bolt_outlined),
    ('/settings/system', l10n.settingsSystem, Icons.desktop_windows_outlined),
    ('/settings/plugins', l10n.settingsPlugins, Icons.power_outlined),
    ('/settings/advanced', l10n.settingsAdvanced, Icons.code_rounded),
    (
      '/settings/smart_organizer',
      l10n.smartOrganization,
      Icons.auto_awesome_motion_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final all = sections(l10n);
    final general = path == '/settings' || path == '/settings/general';
    final here = all.firstWhere(
      (s) => s.$1 == path,
      orElse: () => all.first,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final nav = _SectionNav(
          sections: all,
          current: general ? '/settings/general' : here.$1,
          vertical: wide,
        );
        final Widget body = general
            ? const SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 40),
                child: _GeneralCards(),
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: _Framed(child: current),
              );
        return Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 34, wide ? 40 : 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NocturneHeader(eyebrow: l10n.settings, title: here.$2),
              const SizedBox(height: 22),
              if (!wide) ...[nav, const SizedBox(height: 14)],
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 180,
                            child: SingleChildScrollView(child: nav),
                          ),
                          const SizedBox(width: 22),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({
    required this.sections,
    required this.current,
    required this.vertical,
  });

  final List<(String, String, IconData)> sections;
  final String current;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final (path, label, icon) in sections)
        _NavItem(
          label: label,
          icon: icon,
          selected: path == current,
          onTap: () => context.go(path),
        ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[item, const SizedBox(height: 4)],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[item, const SizedBox(width: 4)],
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final on = widget.selected;
    final radius = BorderRadius.circular(12);
    final fg = on || _hover ? c.textPrimary : c.textSecondary;
    return Semantics(
      selected: on,
      button: true,
      child: AnimatedContainer(
        duration: nocturneMotion(context, 200),
        decoration: BoxDecoration(
          color: on
              ? c.surfaceHighlight
              : (_hover
                    ? c.primary.withValues(alpha: 0.06)
                    : Colors.transparent),
          borderRadius: radius,
          border: _focus
              ? Border.all(
                  color: c.primary,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _focus = v),
            borderRadius: radius,
            hoverColor: Colors.transparent,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: on ? c.primary : fg,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nocturneText(
                        c,
                        weight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's section view inside a Nocturne card.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NocturneCard(
      lift: false,
      padding: EdgeInsets.zero,
      child: ClipRRect(borderRadius: BorderRadius.circular(17), child: child),
    );
  }
}

// ── « Général », as drawn ───────────────────────────────────────────────────

class _GeneralCards extends StatelessWidget {
  const _GeneralCards();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 14.0;
        final two = box.maxWidth >= 340 * 2 + gap;
        Widget pair(Widget a, Widget b) => two
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: gap),
                    Expanded(child: b),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [a, const SizedBox(height: gap), b],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pair(const _GeneralCard(), const _OutputCard()),
            const SizedBox(height: gap),
            const _AppearanceCard(),
            const SizedBox(height: gap),
            pair(const _PerformanceCard(), const _ToolsCard()),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
    this.subtitle,
    this.highlight = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NocturneCard(
      lift: false,
      highlight: highlight,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NocturneTitle(title),
          const SizedBox(height: 6),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: nocturneText(c, size: 12.5, color: c.textDisabled),
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: c.primary.withValues(alpha: 0.08)),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// `.row`: label and description on the left, a control on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.control, this.description});

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: nocturneText(c, weight: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    style: nocturneText(c, size: 12.5, color: c.textDisabled),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

class _GeneralCard extends ConsumerWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final labels = qualityOptionLabels(l10n);
    return _Card(
      title: l10n.settingsGeneral,
      highlight: true,
      children: [
        _Row(
          label: l10n.audioOnly,
          description: l10n.audioOnlyDesc,
          control: NocturneSwitch(
            value: s.audioOnly,
            label: l10n.audioOnly,
            onChanged: n.setAudioOnly,
          ),
        ),
        _Row(
          label: l10n.autoStart,
          description: l10n.autoStartDesc,
          control: NocturneSwitch(
            value: s.autoStart,
            label: l10n.autoStart,
            onChanged: n.setAutoStart,
          ),
        ),
        _Row(
          label: l10n.preferredQuality,
          control: PopupMenuButton<String>(
            tooltip: l10n.preferredQuality,
            color: c.surface,
            initialValue: s.preferredQuality,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: n.setPreferredQuality,
            itemBuilder: (context) => [
              for (final e in labels.entries)
                CheckedPopupMenuItem(
                  value: e.key,
                  checked: e.key == s.preferredQuality,
                  child: Text(e.value),
                ),
            ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 12, right: 12),
              decoration: BoxDecoration(
                color: c.surfaceHighlight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[s.preferredQuality] ?? s.preferredQuality,
                    style: nocturneText(c, size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.field`: a dark well with mono text.
class _Field extends StatelessWidget {
  const _Field(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.primary.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nocturneMono(c, size: 12.5),
      ),
    );
  }
}

class _OutputCard extends ConsumerWidget {
  const _OutputCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    // No file-name template setting: the folder layout the app really uses.
    final layout = [
      if (s.organizeBySite) '{${l10n.nocturneTokenSite}}',
      if (s.organizeByCreator) '{${l10n.nocturneTokenCreator}}',
      '{${l10n.nocturneTokenTitle}}',
    ].join(r'\');
    Widget block(String label, Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: nocturneText(c, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    return _Card(
      title: l10n.settingsOutput,
      children: [
        block(
          l10n.downloadFolder,
          Row(
            children: [
              Expanded(child: _Field(s.outputFolder)),
              const SizedBox(width: 8),
              NocturneButton(
                label: l10n.nocturneChange,
                height: 36,
                radius: 12,
                padding: 15,
                onTap: () => pickOutputFolder(context, ref),
              ),
            ],
          ),
        ),
        block(l10n.nocturneFileLayout, _Field(layout)),
      ],
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
    final l10n = context.l10n;
    final current = DesignSpec.of(context).id;
    return _Card(
      title: l10n.settingsAppearance,
      subtitle: l10n.nocturneAppearanceDesc,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: NocturneAutoGrid(
            minWidth: 118,
            gap: 8,
            children: [
              for (final id in _designs)
                _DesignTile(
                  preset: ThemePresets.getById(id),
                  selected: id == current,
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setThemePreset(id),
                ),
            ],
          ),
        ),
      ],
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
    final c = AppColors.of(context);
    final p = widget.preset;
    final on = widget.selected;
    return Semantics(
      selected: on,
      button: true,
      label: p.name,
      child: Material(
        color: on
            ? c.surfaceHighlight
            : (_hover ? c.primary.withValues(alpha: 0.06) : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.transparent,
          focusColor: c.primary.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on ? c.primary : c.primary.withValues(alpha: 0.1),
                      width: on ? 2 : 1,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 14,
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: 0.46,
                                  child: Container(
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: p.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p.surface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (on)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: c.background,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    p.name,
                    style: nocturneText(
                      c,
                      size: 13,
                      weight: FontWeight.w600,
                      color: on || _hover ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends ConsumerWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    // Same bounds as the Performance section's slider.
    final value = s.maxConcurrent.clamp(1, 60);
    return _Card(
      title: l10n.settingsPerformance,
      children: [
        _Row(
          label: l10n.simultaneousDownloads,
          description: l10n.simultaneousDownloadsDesc,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NocturneIconButton(
                icon: Icons.remove_rounded,
                tooltip: l10n.nocturneDecrease,
                size: 32,
                onTap: value <= 1 ? null : () => n.setMaxConcurrent(value - 1),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: nocturneMono(
                    c,
                    size: 16,
                    color: c.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              NocturneIconButton(
                icon: Icons.add_rounded,
                tooltip: l10n.nocturneIncrease,
                size: 32,
                onTap: value >= 60 ? null : () => n.setMaxConcurrent(value + 1),
              ),
            ],
          ),
        ),
        _Row(
          label: l10n.reduceEffects,
          description: l10n.reduceEffectsDesc,
          control: NocturneSwitch(
            value: s.reduceEffects,
            label: l10n.reduceEffects,
            onChanged: n.setReduceEffects,
          ),
        ),
      ],
    );
  }
}

class _ToolsCard extends ConsumerWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return _Card(
      title: l10n.settingsToolsSection,
      subtitle: l10n.nocturneToolsDesc,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in const ['yt-dlp', 'ffmpeg', 'aria2c'])
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.surfaceHighlight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(tool, style: nocturneMono(c)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                NocturneButton(
                  label: l10n.previewSetup,
                  icon: Icons.build_outlined,
                  height: 36,
                  padding: 15,
                  tooltip: l10n.previewSetupDesc,
                  onTap: () => ref
                      .read(dependencyBootstrapProvider.notifier)
                      .ensureReady(),
                ),
                NocturneButton(
                  label: l10n.onboardingReplay,
                  icon: Icons.replay_rounded,
                  kind: NocturneButtonKind.ghost,
                  height: 36,
                  padding: 12,
                  tooltip: l10n.onboardingReplayDesc,
                  onTap: () {
                    context.go('/');
                    ref.read(onboardingControllerProvider.notifier).replay();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }
}
