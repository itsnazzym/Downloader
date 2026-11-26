import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'pastille_kit.dart';

/// Pastille's settings (mockup Pastille-Reglages.dc.html). « Général » is the
/// mockup's overview of tiles; every other section shows today's view framed
/// under the same header and section tabs, so no setting is lost.
class PastilleSettings extends StatelessWidget {
  const PastilleSettings({super.key, required this.section});

  final Widget section;

  static List<(String, String)> _sections(AppLocalizations l10n) => [
    ('/settings/general', l10n.settingsGeneral),
    ('/settings/output', l10n.settingsOutput),
    ('/settings/appearance', l10n.settingsAppearance),
    ('/settings/performance', l10n.settingsPerformance),
    ('/settings/system', l10n.settingsSystem),
    ('/settings/plugins', l10n.settingsPlugins),
  ];

  static List<(String, String)> _more(AppLocalizations l10n) => [
    ('/settings/advanced', l10n.settingsAdvanced),
    ('/settings/smart_organizer', l10n.smartOrganization),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    var path = GoRouterState.of(context).uri.path;
    if (path == '/settings') path = '/settings/general';
    final all = [..._sections(l10n), ..._more(l10n)];
    final title = all
        .firstWhere((s) => s.$1 == path, orElse: () => all.first)
        .$2;
    final header = PastilleHeader(
      eyebrow: l10n.pastilleSettingsEyebrow,
      title: title,
      actions: [_SectionTabs(path: path)],
    );
    if (path == '/settings/general') {
      return PastillePage(gap: 22, children: [header, const _Overview()]);
    }
    return ColoredBox(
      color: pBackground,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth > 1264 ? (c.maxWidth - 1200) / 2 : 32.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(side, 30, side, 92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 22),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: pBackground,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: pCream.withValues(alpha: 0.08),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: section,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final more = PastilleSettings._more(l10n);
    final hidden = more.where((s) => s.$1 == path).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // One line always: scrolls sideways when the header stacks (narrow).
        LayoutBuilder(
          builder: (context, c) {
            final seg = PSeg(
              page: true,
              items: [
                for (final (p, label) in [
                  ...PastilleSettings._sections(l10n),
                  ...hidden,
                ])
                  PSegItem(label, p == path, () => context.go(p)),
              ],
            );
            if (!c.maxWidth.isFinite) return seg;
            return SizedBox(
              width: (c.maxWidth - 52).clamp(0.0, double.infinity),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: seg,
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          tooltip: l10n.pastilleMoreSettings,
          color: pCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (p) => context.go(p),
          itemBuilder: (context) => [
            for (final (p, label) in more)
              CheckedPopupMenuItem(
                value: p,
                checked: p == path,
                child: Text(label, style: pBody(color: pCream)),
              ),
          ],
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pInkDeep,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: pCream.withValues(alpha: 0.1),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: pMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return const PGrid(
      rowHeight: 150,
      rowHeights: {0: 205},
      cells: [
        PCell(_GeneralTile(), w: 2),
        PCell(_OutputTile(), w: 2),
        PCell(_AppearanceTile(), w: 2, h: 2),
        PCell(_PerformanceTile(), h: 2),
        PCell(_SystemTile(), h: 2),
      ],
    );
  }
}

/// `.setr`: one setting row, a hairline above all but the first.
class _Row extends StatelessWidget {
  const _Row({required this.child, this.first = false, this.padV = 0});

  final Widget child;
  final bool first;
  final double padV;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: EdgeInsets.symmetric(vertical: padV),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(
                  color: pInk.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

TextStyle _rowLabel() => pBody(weight: FontWeight.w600, color: pInk);

class _GeneralTile extends ConsumerWidget {
  const _GeneralTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final labels = qualityOptionLabels(l10n);
    return PTile(
      color: PTones.of(context).sage,
      picked: true,
      semanticLabel: l10n.settingsGeneral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PLabel(icon: Icons.tune_rounded, text: l10n.settingsGeneral),
          const SizedBox(height: 6),
          _Row(
            first: true,
            child: Row(
              children: [
                Expanded(child: Text(l10n.audioOnly, style: _rowLabel())),
                PSwitch(
                  value: s.audioOnly,
                  onChanged: n.setAudioOnly,
                  label: l10n.audioOnly,
                ),
              ],
            ),
          ),
          _Row(
            child: Row(
              children: [
                Expanded(child: Text(l10n.autoStart, style: _rowLabel())),
                PSwitch(
                  value: s.autoStart,
                  onChanged: n.setAutoStart,
                  label: l10n.autoStart,
                ),
              ],
            ),
          ),
          _Row(
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.preferredQuality, style: _rowLabel()),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.preferredQuality,
                  color: pCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onSelected: n.setPreferredQuality,
                  itemBuilder: (context) => [
                    for (final e in labels.entries)
                      CheckedPopupMenuItem(
                        value: e.key,
                        checked: e.key == s.preferredQuality,
                        child: Text(e.value, style: pBody(color: pCream)),
                      ),
                  ],
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
                    decoration: BoxDecoration(
                      color: pInk,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[s.preferredQuality] ?? s.preferredQuality,
                          style: pBody(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: pCream,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: pCream,
                        ),
                      ],
                    ),
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

class _OutputTile extends ConsumerWidget {
  const _OutputTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    Widget value(BuildContext context, String sub, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sub, style: pSub(context)),
        const SizedBox(height: 2),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pMono(size: 15, weight: FontWeight.w500, color: pInk),
        ),
      ],
    );
    return PTile(
      color: PTones.of(context).sky,
      delay: 60,
      semanticLabel: l10n.settingsOutput,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.folder_outlined, text: l10n.settingsOutput),
            const SizedBox(height: 6),
            _Row(
              first: true,
              padV: 6,
              child: Row(
                children: [
                  Expanded(
                    child: value(
                      context,
                      l10n.downloadFolder,
                      s.outputFolder.isEmpty
                          ? l10n.outputFolderNotConfigured
                          : s.outputFolder,
                    ),
                  ),
                  const SizedBox(width: 14),
                  KeyedSubtree(
                    key: OnboardingTargets.outputFolder,
                    child: PButton(
                      label: l10n.pastilleChange,
                      height: 38,
                      onTap: () => pickOutputFolder(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            // The mockup's name template has no setting; the output format is
            // the closest real value of this tile.
            _Row(
              padV: 6,
              child: value(
                context,
                l10n.formatLabel,
                s.outputFormat.toUpperCase(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The six desktop designs with their own swatches (bg, two accents).
const _designs = [
  ('signal', Color(0xFF0F0F0D), Color(0xFFF2F0E6), Color(0xFF8A887E)),
  ('porcelaine', Color(0xFFECEAE5), Color(0xFF2747F5), Color(0xFF16171A)),
  ('studio', Color(0xFFF5F4F1), Color(0xFF17171A), Color(0xFFE2E0DB)),
  ('pastille', Color(0xFF191715), Color(0xFFB9A8F5), Color(0xFFF4DA7A)),
  ('terminal', Color(0xFF0A0D0B), Color(0xFF8BE9A0), Color(0xFF1C241E)),
  ('nocturne', Color(0xFF0A0F1E), Color(0xFF8EA7FF), Color(0xFFEEF1FA)),
];

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = DesignSpec.of(context).id;
    final n = ref.read(settingsProvider.notifier);
    return PTile(
      color: PTones.of(context).cream,
      delay: 120,
      semanticLabel: l10n.settingsAppearance,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.contrast_rounded,
              text: l10n.settingsAppearance,
              trailing: Text(l10n.pastilleAppDesign, style: pSub(context)),
            ),
            const Spacer(),
            LayoutBuilder(
              builder: (context, c) {
                // Two rows of three fit the tile; three rows of two overflowed
                // it in a 1000 px window.
                final cols = c.maxWidth < 300 ? 2 : 3;
                final w = (c.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (id, bg, a, b) in _designs)
                      SizedBox(
                        width: w,
                        child: _DesignChoice(
                          label: ThemePresets.getById(id).name,
                          bg: bg,
                          a: a,
                          b: b,
                          selected: id == current,
                          onTap: () => n.setThemePreset(id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignChoice extends StatefulWidget {
  const _DesignChoice({
    required this.label,
    required this.bg,
    required this.a,
    required this.b,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color a;
  final Color b;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesignChoice> createState() => _DesignChoiceState();
}

class _DesignChoiceState extends State<_DesignChoice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            focusColor: pInk.withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: AnimatedContainer(
              duration: pMotion(context, 200),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              decoration: BoxDecoration(
                color: pInk.withValues(alpha: _hover ? 0.11 : 0.06),
                borderRadius: BorderRadius.circular(22),
              ),
              foregroundDecoration: widget.selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: pInk, width: 2.5),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.bottomLeft,
                    decoration: BoxDecoration(
                      color: widget.bg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: pInk.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        for (final c in [widget.a, widget.b]) ...[
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pBody(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: pInk,
                            ),
                          ),
                        ),
                        PCheck(on: widget.selected, size: 24),
                      ],
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

class _PerformanceTile extends ConsumerWidget {
  const _PerformanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final conc = s.maxConcurrent.clamp(1, 60);
    return PTile(
      color: PTones.of(context).lav,
      delay: 180,
      semanticLabel: l10n.settingsPerformance,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.bolt_rounded, text: l10n.settingsPerformance),
            const SizedBox(height: 14),
            Text(l10n.simultaneousDownloads, style: pSub(context)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text('$conc', style: pNum(72, color: pInk)),
                  ),
                ),
                PButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.pastilleConcurrentLess,
                  iconSize: 14,
                  onTap: conc <= 1 ? null : () => n.setMaxConcurrent(conc - 1),
                ),
                const SizedBox(width: 8),
                PButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.pastilleConcurrentMore,
                  iconSize: 14,
                  onTap: conc >= 60 ? null : () => n.setMaxConcurrent(conc + 1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PDots(
              count: 6,
              columns: 6,
              on: conc.clamp(0, 6),
              gap: 8,
              maxWidth: 220,
              semanticLabel: '$conc',
            ),
            const Spacer(),
            Container(
              constraints: const BoxConstraints(minHeight: 46),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: pInk.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.pastilleReduceEffects, style: _rowLabel()),
                  ),
                  PSwitch(
                    value: s.reduceEffects,
                    onChanged: n.setReduceEffects,
                    label: l10n.reduceEffects,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemTile extends ConsumerWidget {
  const _SystemTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final boot = ref.watch(dependencyBootstrapProvider);
    String state(String tool) {
      if (boot.readyTools.any((t) => t.toLowerCase().startsWith(tool))) {
        return l10n.pastilleToolReady;
      }
      if (boot.isBusy) return l10n.pastilleToolChecking;
      return l10n.pastilleToolUnchecked;
    }

    Widget link(IconData icon, String label, VoidCallback onTap) => Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              Icon(icon, size: 15, color: pMuted),
              const SizedBox(width: 6),
              Expanded(
                // Two lines fit the 36 px: half-width links stay readable
                // ("Replay t…" in a 1000 px window).
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pBody(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: pMuted,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PTile(
      color: pInkDeep,
      delay: 240,
      semanticLabel: l10n.settingsSystem,
      // A narrow tile (1000 px window) drops the heading, which the button
      // repeats, to stack its links instead of cutting their words.
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 240;
          final replay = link(Icons.replay_rounded, l10n.onboardingReplay, () {
            context.go('/');
            ref.read(onboardingControllerProvider.notifier).replay();
          });
          final organize = link(
            Icons.auto_awesome_motion_rounded,
            l10n.smartOrganization,
            () => context.push('/settings/smart_organizer'),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PLabel(
                icon: Icons.build_outlined,
                iconColor: tones.butter,
                text: l10n.pastilleSystemTools,
              ),
              const SizedBox(height: 14),
              if (!narrow) ...[
                Text(
                  l10n.previewSetup,
                  style: pBody(
                    size: 15,
                    weight: FontWeight.w700,
                    color: pCream,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              for (final tool in const ['yt-dlp', 'ffmpeg', 'aria2c']) ...[
                if (tool != 'yt-dlp') const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tool,
                          style: pMono(size: 13, color: pCream),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: state(tool) == l10n.pastilleToolReady
                              ? tones.sage
                              : pFaint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        state(tool),
                        style: pBody(
                          size: 12.5,
                          color: state(tool) == l10n.pastilleToolReady
                              ? pCream
                              : pMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Today's « Outils » actions of the General page.
              if (narrow) ...[
                replay,
                organize,
              ] else
                Row(
                  children: [
                    Expanded(child: replay),
                    const SizedBox(width: 8),
                    Expanded(child: organize),
                  ],
                ),
              const SizedBox(height: 8),
              PButton(
                label: boot.isBusy
                    ? l10n.pastilleToolChecking
                    : l10n.pastilleRepair,
                icon: Icons.sync_rounded,
                iconSize: 15,
                kind: PButtonKind.butter,
                height: 44,
                padH: narrow ? 12 : 18,
                expand: true,
                onTap: boot.isBusy
                    ? null
                    : () => ref
                          .read(dependencyBootstrapProvider.notifier)
                          .ensureReady(),
              ),
            ],
          );
        },
      ),
    );
  }
}
