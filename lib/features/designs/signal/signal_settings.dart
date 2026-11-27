import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart'
    show languageOptionLabels, qualityOptionLabels, themeModeOptionLabels;
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'signal_controls.dart';
import 'signal_theme.dart';
import 'signal_widgets.dart';

/// Signal's settings (mockup Signal-Reglages.dc.html): a section rail on the
/// left; « Général » is the mockup's overview, every other section frames
/// today's view ([current]) so no setting is lost.
class SignalSettings extends StatelessWidget {
  const SignalSettings({super.key, required this.current});

  final Widget current;

  static List<(String, String)> sections(AppLocalizations l10n) => [
    ('/settings/general', l10n.settingsGeneral),
    ('/settings/output', l10n.settingsOutput),
    ('/settings/appearance', l10n.settingsAppearance),
    ('/settings/performance', l10n.settingsPerformance),
    ('/settings/advanced', l10n.settingsAdvanced),
    ('/settings/system', l10n.settingsSystem),
    ('/settings/plugins', l10n.settingsPlugins),
    ('/settings/smart_organizer', l10n.smartOrganization),
  ];

  @override
  Widget build(BuildContext context) {
    var path = GoRouterState.of(context).uri.path;
    if (path == '/settings') path = '/settings/general';
    final general = path == '/settings/general';
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = signalPagePadding(constraints.maxWidth, top: 28);
        final l10n = context.l10n;
        final title = sections(
          l10n,
        ).firstWhere((s) => s.$1 == path, orElse: () => sections(l10n)[0]).$2;
        final body = general
            ? SingleChildScrollView(
                padding: EdgeInsets.only(bottom: pad.bottom),
                child: _General(wide: wide),
              )
            // The framed view has no title bar of its own: say where we are,
            // as « Général » does.
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SignalEyebrow(l10n.settings),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: AppTypography.display(32, weight: FontWeight.w600)
                        .copyWith(
                          color: AppColors.of(context).textPrimary,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    // Appearance is Signal's own page; every other section
                    // keeps today's view, in Signal's controls.
                    child: path == '/settings/appearance'
                        ? SingleChildScrollView(
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom: pad.bottom,
                            ),
                            child: const _Appearance(),
                          )
                        : SignalMaterial(child: current),
                  ),
                ],
              );
        if (!wide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionChips(path: path),
                const SizedBox(height: 16),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: _SectionRail(path: path)),
              const SizedBox(width: 24),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

// ── Section navigation ──────────────────────────────────────────────────────

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return SignalCard(
      padding: const EdgeInsets.all(10),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (route, label) in SignalSettings.sections(context.l10n))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _RailItem(
                  label: label,
                  selected: route == path,
                  onTap: () => context.go(route),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        borderRadius: BorderRadius.circular(999),
        focusColor: colors.primary.withValues(alpha: 0.25),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: signalMotion(context, 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: on
                ? colors.textPrimary
                : (_hover ? colors.surfaceHighlight : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: on
                  ? colors.background
                  : (_hover ? colors.textPrimary : colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Below 900px the rail becomes a row of chips.
class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (route, label) in SignalSettings.sections(context.l10n))
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: SignalChip(
                label: label,
                selected: route == path,
                onTap: () => context.go(route),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Général: the overview of the mockup ─────────────────────────────────────

class _General extends ConsumerWidget {
  const _General({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalEyebrow(l10n.settings),
                  const SizedBox(height: 2),
                  Text(
                    l10n.settingsGeneral,
                    style: AppTypography.display(
                      32,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.signalSettingsGeneralHint,
                    style: AppTypography.body.copyWith(
                      fontSize: 13.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Today's « Relancer le tour » stays on this page.
            SignalButton(
              label: l10n.onboardingReplay,
              icon: Icons.replay_rounded,
              accent: false,
              height: 36,
              fontSize: 12.5,
              onTap: () {
                context.go('/');
                ref.read(onboardingControllerProvider.notifier).replay();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        signalRow(
          wide: wide,
          flexes: const [1, 1],
          children: const [_GeneralCard(), _OutputCard()],
        ),
        const SizedBox(height: 16),
        const _DesignCard(),
        const SizedBox(height: 16),
        signalRow(
          wide: wide,
          flexes: const [1, 1],
          children: const [_PerformanceCard(), _ToolsCard()],
        ),
      ],
    );
  }
}

/// One settings line: label and hint on the left, control on the right; a
/// hairline above every line but the first.
class SignalSettingRow extends StatelessWidget {
  const SignalSettingRow({
    super.key,
    required this.title,
    this.hint,
    required this.trailing,
    this.first = false,
  });

  final String title;
  final String? hint;
  final Widget trailing;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : 14, bottom: 14),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(
                  color: colors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 2,
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
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SignalEyebrow(text),
  );
}

const _cardPadding = EdgeInsets.fromLTRB(24, 20, 24, 20);

class _GeneralCard extends ConsumerWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final labels = qualityOptionLabels(l10n);
    return SignalCard(
      focus: true,
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l10n.settingsGeneral),
          SignalSettingRow(
            first: true,
            title: l10n.audioOnly,
            hint: l10n.audioOnlyDesc,
            trailing: SignalSwitch(
              value: s.audioOnly,
              onChanged: n.setAudioOnly,
              label: l10n.audioOnly,
            ),
          ),
          SignalSettingRow(
            title: l10n.autoStart,
            hint: l10n.autoStartDesc,
            trailing: SignalSwitch(
              value: s.autoStart,
              onChanged: n.setAutoStart,
              label: l10n.autoStart,
            ),
          ),
          SignalSettingRow(
            title: l10n.preferredQuality,
            trailing: SignalSelect(
              value: s.preferredQuality,
              options: const ['best', 'manual', 'manual+'],
              labels: labels,
              tooltip: l10n.preferredQuality,
              onChanged: n.setPreferredQuality,
            ),
          ),
        ],
      ),
    );
  }
}

class SignalSelect extends StatelessWidget {
  const SignalSelect({
    super.key,
    required this.value,
    required this.options,
    required this.labels,
    required this.tooltip,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final Map<String, String> labels;
  final String tooltip;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: value,
      onSelected: onChanged,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.borderSubtle),
      ),
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Text(
              labels[o] ?? o,
              style: AppTypography.body.copyWith(
                fontSize: 13.5,
                color: colors.textPrimary,
              ),
            ),
          ),
      ],
      child: SignalInset(
        ring: 0.1,
        padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labels[value] ?? value,
              style: AppTypography.body.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colors.textSecondary,
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
    final folder = ref.watch(settingsProvider.select((s) => s.outputFolder));
    final byCreator = ref.watch(
      settingsProvider.select((s) => s.organizeByCreator),
    );
    final n = ref.read(settingsProvider.notifier);
    return SignalCard(
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l10n.settingsOutput),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.downloadFolder,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SignalInset(
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folder.isEmpty ? l10n.selectFolder : folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.mono.copyWith(
                            fontSize: 13,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      SignalButton(
                        label: l10n.signalSettingsChange,
                        accent: false,
                        height: 32,
                        fontSize: 12.5,
                        onTap: () => pickOutputFolder(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // The mockup's file-name template has no setting: how files are
          // filed (one folder per creator) is the closest real choice.
          SignalSettingRow(
            title: l10n.organizeByCreator,
            hint: l10n.organizeByCreatorDesc,
            trailing: SignalSwitch(
              value: byCreator,
              onChanged: n.setOrganizeByCreator,
              label: l10n.organizeByCreator,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignCard extends ConsumerWidget {
  const _DesignCard({this.every = false});

  /// Every look, OLED and iOS too (the Appearance page).
  final bool every;

  static const _ids = [
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
    final selected = ThemePresets.migrateId(
      ref.watch(settingsProvider.select((s) => s.themePreset)),
    );
    final current = ThemePresets.getById(selected);
    return SignalCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SignalEyebrow(l10n.signalSettingsDesignTitle)),
              Text(
                l10n.signalSettingsCurrentDesign(current.name),
                style: AppTypography.body.copyWith(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cols = ((c.maxWidth + 12) / 140).floor().clamp(1, 6);
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final id
                      in every
                          ? [for (final p in ThemePresets.all) p.id]
                          : _ids)
                    SizedBox(
                      width: w,
                      child: _Vignette(
                        preset: ThemePresets.getById(id),
                        selected: id == selected,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setThemePreset(id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Vignette extends StatefulWidget {
  const _Vignette({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Vignette> createState() => _VignetteState();
}

class _VignetteState extends State<_Vignette> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = widget.preset;
    final on = widget.selected;
    return Semantics(
      selected: on,
      button: true,
      label: p.name,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        borderRadius: BorderRadius.circular(16),
        focusColor: colors.primary.withValues(alpha: 0.2),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: signalMotion(context, 200),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on
                  ? colors.textPrimary
                  : colors.textPrimary.withValues(alpha: _hover ? 0.22 : 0.08),
              width: on ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x40808080)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 26,
                      height: 10,
                      child: _Pill(p.textSecondary.withValues(alpha: 0.85), 5),
                    ),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomLeft,
                        widthFactor: 0.52,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 32, 0, 10),
                          child: _Pill(p.surface, 7),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      width: 26,
                      height: 22,
                      child: _Pill(p.primary, 999),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: signalMotion(context, 200),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: colors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: colors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _PerformanceCard extends ConsumerWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final max = ref.watch(settingsProvider.select((s) => s.maxConcurrent));
    final calm = ref.watch(settingsProvider.select((s) => s.reduceEffects));
    final n = ref.read(settingsProvider.notifier);
    // Same bounds as today's Performance slider.
    const lo = 1, hi = 60;
    return SignalCard(
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l10n.settingsPerformance),
          SignalSettingRow(
            first: true,
            title: l10n.simultaneousDownloads,
            hint: l10n.simultaneousDownloadsDesc,
            trailing: SignalInset(
              height: null,
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SignalIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: l10n.signalSettingsLess,
                    size: 34,
                    iconSize: 15,
                    onTap: max > lo ? () => n.setMaxConcurrent(max - 1) : null,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$max',
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                        20,
                        weight: FontWeight.w600,
                      ).copyWith(color: colors.textPrimary),
                    ),
                  ),
                  SignalIconButton(
                    icon: Icons.add_rounded,
                    tooltip: l10n.signalSettingsMore,
                    size: 34,
                    iconSize: 15,
                    onTap: max < hi ? () => n.setMaxConcurrent(max + 1) : null,
                  ),
                ],
              ),
            ),
          ),
          SignalSettingRow(
            title: l10n.reduceEffects,
            hint: l10n.reduceEffectsDesc,
            trailing: SignalSwitch(
              value: calm,
              onChanged: n.setReduceEffects,
              label: l10n.reduceEffects,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsCard extends ConsumerWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final busy = ref.watch(dependencyBootstrapProvider.select((s) => s.isBusy));
    return SignalCard(
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignalEyebrow(l10n.signalSettingsToolsTitle),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SignalTag('yt-dlp'),
              SignalTag('ffmpeg'),
              SignalTag('aria2c'),
            ],
          ),
          const SizedBox(height: 14),
          SignalButton(
            label: l10n.previewSetup,
            icon: Icons.build_outlined,
            accent: false,
            height: 40,
            fontSize: 13,
            onTap: busy
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

// ── Apparence ───────────────────────────────────────────────────────────────

/// Today's Appearance settings in Signal's cards: every look (OLED and iOS
/// too), light/dark for the looks that follow it, the language, and the
/// accent colour (not on OLED).
class _Appearance extends ConsumerWidget {
  const _Appearance();

  // shortcut: the same palette as the shared Appearance view; keep both in
  // step if that list changes.
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final followsMode =
        DesignSpec.forId(ThemePresets.migrateId(s.themePreset)).brightness ==
        null;
    final accent = Color(s.customAccentColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DesignCard(every: true),
        const SizedBox(height: 16),
        SignalCard(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (followsMode)
                SignalSettingRow(
                  first: true,
                  title: l10n.theme,
                  trailing: SignalMaterial(
                    child: SignalSelect(
                      value: s.themeMode,
                      options: const ['system', 'dark', 'light'],
                      labels: themeModeOptionLabels(l10n),
                      tooltip: l10n.theme,
                      onChanged: n.setThemeMode,
                    ),
                  ),
                ),
              SignalSettingRow(
                first: !followsMode,
                title: l10n.language,
                trailing: SignalMaterial(
                  child: SignalSelect(
                    value: s.locale,
                    options: const ['en', 'fr', 'ar'],
                    labels: languageOptionLabels(l10n),
                    tooltip: l10n.language,
                    onChanged: n.setLocale,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (s.themePreset != 'oled') ...[
          const SizedBox(height: 16),
          SignalCard(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: SignalEyebrow(l10n.accentColor)),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.currentAccent} ${_hex(accent)}',
                      style: AppTypography.mono.copyWith(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _accents)
                      _Swatch(
                        color: c,
                        selected: c.toARGB32() == accent.toARGB32(),
                        onTap: () => n.setCustomAccentColor(c.toARGB32()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// A round accent swatch: a cream ring and a check when chosen.
class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    final ring = on || _focus;
    return Semantics(
      selected: on,
      button: true,
      label: _hex(widget.color),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover && !on ? 1.08 : 1,
            duration: signalMotion(context, 160),
            curve: signalEase,
            child: AnimatedContainer(
              duration: signalMotion(context, 200),
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ring
                      ? colors.textPrimary
                      : colors.textPrimary.withValues(alpha: 0.08),
                  width: ring ? 2 : 1,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: on
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
