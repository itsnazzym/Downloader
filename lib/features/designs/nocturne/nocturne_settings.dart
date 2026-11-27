import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/design_vitrine.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/plugins/feature_catalog.dart';
import 'package:modern_downloader/core/plugins/plugin_manager.dart';
import 'package:modern_downloader/core/services/browser_extension_installer.dart';
import 'package:modern_downloader/core/ui/settings/widgets/extension_install_guide_dialog.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart'
    show languageOptionLabels, qualityOptionLabels, themeModeOptionLabels;
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
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
    final here = all.firstWhere((s) => s.$1 == path, orElse: () => all.first);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final nav = _SectionNav(
          sections: all,
          current: general ? '/settings/general' : here.$1,
          vertical: wide,
        );
        final drawn = switch (here.$1) {
          _ when general => const _GeneralCards(),
          '/settings/appearance' => const _AppearancePage(),
          '/settings/plugins' => _PluginsPage(
            pluginId: GoRouterState.of(context).uri.queryParameters['plugin'],
          ),
          _ => null,
        };
        final Widget body = drawn != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: drawn,
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
                  Icon(widget.icon, size: 16, color: on ? c.primary : fg),
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

/// Today's section view, its tiles drawn by Nocturne's skin: no extra
/// card around cards.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    // A night well: the view's own background, edged like Nocturne's fields.
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.of(context).primary.withValues(alpha: 0.08),
      ),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
  );
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
                children: [
                  a,
                  const SizedBox(height: gap),
                  b,
                ],
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
  const _Row({
    required this.label,
    required this.control,
    this.description,
    this.error,
  });

  final String label;
  final String? description;

  /// A problem shown under the description (a plugin that failed).
  final String? error;
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
                if (error != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    error!,
                    style: nocturneText(c, size: 12.5, color: c.error),
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

// ── « Apparence » and « Plugins », drawn ───────────────────────────────────

/// Appearance in Nocturne's cards: every design, light/dark where the design
/// follows it, the accent colours and the language.
class _AppearancePage extends ConsumerWidget {
  const _AppearancePage();

  // Same choices as today's accent picker.
  static const _accents = [
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final accent = Color(s.customAccentColor);
    final hex = accent
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    // Designs with their own brightness ignore light/dark: only iOS follows.
    final followsMode =
        DesignSpec.forId(ThemePresets.migrateId(s.themePreset)).brightness ==
        null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: l10n.theme,
          subtitle: l10n.nocturneAppearanceDesc,
          highlight: true,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: DesignVitrine(),
            ),
            if (followsMode)
              _Row(
                label: l10n.theme,
                control: NocturnePillMenu<String>(
                  tooltip: l10n.theme,
                  value: s.themeMode,
                  options: themeModeOptionLabels(l10n),
                  onSelected: n.setThemeMode,
                ),
              ),
          ],
        ),
        if (s.themePreset != 'oled') ...[
          const SizedBox(height: 14),
          _Card(
            title: l10n.accentColor,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.currentAccent,
                          style: nocturneText(c, weight: FontWeight.w600),
                        ),
                        Text('#$hex', style: nocturneMono(c)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in _accents)
                      _AccentSwatch(
                        color: color,
                        selected: color.toARGB32() == accent.toARGB32(),
                        onTap: () => n.setCustomAccentColor(color.toARGB32()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _Card(
          title: l10n.language,
          children: [
            _Row(
              label: l10n.language,
              control: NocturnePillMenu<String>(
                tooltip: l10n.language,
                value: s.locale,
                options: languageOptionLabels(l10n),
                onSelected: n.setLocale,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return Semantics(
      button: true,
      selected: selected,
      label: '#$hex',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: nocturneMotion(context, 180),
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

String _platform() => PlatformInfo.isAndroid ? 'android' : 'windows';

/// Plugins in Nocturne's cards: the app's features (switches, essential
/// ones locked), the download hooks, the install request from the web, and
/// the browser extensions with their token.
class _PluginsPage extends ConsumerWidget {
  const _PluginsPage({this.pluginId});

  final String? pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final lifecycle = ref.watch(pluginManagerProvider);
    final catalog = ref.watch(featureCatalogProvider);
    final activation = ref.watch(featureActivationProvider);
    if (!lifecycle.isLoaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: NocturneOrbit(size: 120, icon: Icons.power_outlined),
        ),
      );
    }
    final id = pluginId;
    final requested = id == null ? null : catalog.byId[id];
    final showcase = ref.watch(showcaseModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requested != null && requested.supportsPlatform(_platform())) ...[
          _InstallRequest(plugin: requested, locale: locale),
          const SizedBox(height: 14),
        ],
        _Card(
          title: l10n.pluginFeaturesTitle,
          subtitle: l10n.pluginFeaturesHint,
          children: [
            for (final p in catalog.modules)
              if (p.supportsPlatform(_platform()))
                _Row(
                  label: p.nameFor(locale),
                  description: p.descriptionFor(locale),
                  control: p.isCore
                      ? _Tag(
                          text: l10n.pluginRequired,
                          icon: Icons.lock_outline_rounded,
                        )
                      : NocturneSwitch(
                          value: activation.isEnabled(p),
                          label: p.nameFor(locale),
                          onChanged: (v) => ref
                              .read(featureActivationProvider.notifier)
                              .setEnabled(p.id, v),
                        ),
                ),
          ],
        ),
        const SizedBox(height: 14),
        _Card(
          title: l10n.pluginsSectionTitle,
          subtitle: l10n.pluginsSectionHint,
          children: [
            if (lifecycle.plugins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.noPluginsInstalled,
                  style: nocturneText(c, color: c.textSecondary),
                ),
              ),
            for (final entry in lifecycle.plugins)
              _Row(
                label:
                    catalog.byId[entry.plugin.id]?.nameFor(locale) ??
                    entry.plugin.name,
                description: [
                  catalog.byId[entry.plugin.id]?.descriptionFor(locale) ??
                      entry.plugin.description,
                  'v${entry.plugin.version}'
                      '${entry.plugin.isBuiltIn ? ' · ${l10n.builtIn}' : ''}',
                ].join('\n'),
                error: entry.error == null
                    ? null
                    : l10n.pluginError('${entry.error}'),
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.plugin.id == 'builtin_smart_organizer') ...[
                      NocturneIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: l10n.configurePlugin,
                        ghost: true,
                        onTap: () => context.push('/settings/smart_organizer'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    NocturneSwitch(
                      value: entry.isEnabled,
                      label: entry.plugin.name,
                      onChanged: (v) => ref
                          .read(pluginManagerProvider.notifier)
                          .togglePlugin(entry.plugin.id, v),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (!showcase) ...[
          const SizedBox(height: 14),
          KeyedSubtree(
            key: OnboardingTargets.extensions,
            child: const _ExtensionsCard(),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.surfaceHighlight,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: nocturneText(c, size: 12, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A plugin asked for from the website: activate, open or install it.
class _InstallRequest extends ConsumerWidget {
  const _InstallRequest({required this.plugin, required this.locale});

  final FeaturePluginDescriptor plugin;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activation = ref.watch(featureActivationProvider);
    final lifecycle = ref.watch(pluginManagerProvider);
    final enabled = plugin.isModule
        ? activation.isEnabled(plugin)
        : lifecycle.plugins
              .where((e) => e.plugin.id == plugin.id)
              .any((e) => e.isEnabled);
    VoidCallback? onTap;
    var label = l10n.pluginActivate;
    if (plugin.isModule) {
      if (enabled) {
        label = l10n.pluginOpen;
        onTap = () => context.go(plugin.route);
      } else {
        onTap = () async {
          await ref
              .read(featureActivationProvider.notifier)
              .setEnabled(plugin.id, true);
          if (context.mounted) context.go(plugin.route);
        };
      }
    } else if (plugin.isDownloadHook) {
      if (enabled) {
        label = l10n.configurePlugin;
        onTap = () => context.go('/settings/plugins');
      } else if (lifecycle.isLoaded) {
        onTap = () => ref
            .read(pluginManagerProvider.notifier)
            .togglePlugin(plugin.id, true);
      }
    } else if (plugin.isExternalExtension) {
      final chrome = plugin.id == 'chrome_extension';
      label = chrome ? l10n.installInChrome : l10n.installInFirefox;
      onTap = () => ExtensionInstallGuideDialog.show(
        context,
        chrome
            ? ExtensionInstallFlow.chromeInstall
            : ExtensionInstallFlow.firefoxInstall,
      );
    }
    return _Card(
      title: plugin.nameFor(locale),
      subtitle: plugin.isExternalExtension
          ? l10n.pluginExternalHint
          : l10n.pluginWebRequest,
      highlight: true,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: NocturneButton(
              label: label,
              kind: NocturneButtonKind.primary,
              icon: plugin.isExternalExtension
                  ? Icons.open_in_new_rounded
                  : (enabled ? Icons.arrow_forward_rounded : Icons.add_rounded),
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chrome and Firefox installs, and the token the extensions pair with.
class _ExtensionsCard extends ConsumerWidget {
  const _ExtensionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final token = ref.watch(settingsProvider.select((s) => s.apiToken));
    Widget browser(
      String title,
      String steps,
      String primary,
      ExtensionInstallFlow primaryFlow,
      String secondary,
      IconData secondaryIcon,
      ExtensionInstallFlow secondaryFlow,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: nocturneText(c, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            steps,
            style: nocturneText(c, size: 12.5, color: c.textDisabled),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NocturneButton(
                label: primary,
                icon: Icons.download_outlined,
                kind: NocturneButtonKind.primary,
                height: 36,
                onTap: () =>
                    ExtensionInstallGuideDialog.show(context, primaryFlow),
              ),
              NocturneButton(
                label: secondary,
                icon: secondaryIcon,
                height: 36,
                onTap: () =>
                    ExtensionInstallGuideDialog.show(context, secondaryFlow),
              ),
            ],
          ),
        ],
      ),
    );
    return _Card(
      title: l10n.browserExtensionsTitle,
      subtitle: l10n.browserExtensionsHint,
      children: [
        browser(
          l10n.chromeExtensionTitle,
          l10n.chromeExtensionSteps,
          l10n.installInChrome,
          ExtensionInstallFlow.chromeInstall,
          l10n.downloadExtensionZip,
          Icons.download_outlined,
          ExtensionInstallFlow.chromeZip,
        ),
        browser(
          l10n.firefoxExtensionTitle,
          l10n.firefoxExtensionSteps,
          l10n.installInFirefox,
          ExtensionInstallFlow.firefoxInstall,
          l10n.firefoxManualInstall,
          Icons.build_outlined,
          ExtensionInstallFlow.firefoxManual,
        ),
        _Row(
          label: l10n.extensionApiToken,
          description: token.isEmpty ? l10n.generatedOnFirstLaunch : token,
          control: NocturneButton(
            label: l10n.copyToken,
            icon: Icons.copy_rounded,
            height: 36,
            onTap: token.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    String message;
                    try {
                      await BrowserExtensionInstaller.copyPath(token);
                      message = l10n.tokenCopiedHint;
                    } catch (_) {
                      message = l10n.extensionInstallFailed;
                    }
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  },
          ),
        ),
      ],
    );
  }
}
