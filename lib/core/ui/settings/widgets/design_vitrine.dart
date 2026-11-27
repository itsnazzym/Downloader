import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/core/theme/theme_presets.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'design_miniature.dart';

/// The desktop design picker (mockup Choix-Vitrine.dc.html): the designs on
/// the left, a miniature and a description of the selected one on the right.
/// Selecting only previews; « Utiliser » switches the design. Drawn in the
/// active design's colours, so it sits inside any design's settings.
class DesignVitrine extends ConsumerStatefulWidget {
  const DesignVitrine({super.key});

  @override
  ConsumerState<DesignVitrine> createState() => _DesignVitrineState();
}

/// What the mockup shows of a design: its ground and accent (list dot), four
/// colours and its typefaces. Fixed values: they describe the design, not
/// the active theme.
typedef _Facts = ({
  String id,
  Color ground,
  Color accent,
  List<Color> colors,
  String font,
});

const List<_Facts> _designs = [
  (
    id: 'signal',
    ground: Color(0xFF0F0F0D),
    accent: Color(0xFFD2F34C),
    colors: [
      Color(0xFF0F0F0D),
      Color(0xFF191916),
      Color(0xFFD2F34C),
      Color(0xFFF2F0E6),
    ],
    font: 'Bricolage Grotesque · Geist',
  ),
  (
    id: 'porcelaine',
    ground: Color(0xFFECEAE5),
    accent: Color(0xFF2747F5),
    colors: [
      Color(0xFFECEAE5),
      Color(0xFFFFFFFF),
      Color(0xFF2747F5),
      Color(0xFF16171A),
    ],
    font: 'Inter Tight · Inter',
  ),
  (
    id: 'pastille',
    ground: Color(0xFF191715),
    accent: Color(0xFFB9A8F5),
    colors: [
      Color(0xFF191715),
      Color(0xFFB9A8F5),
      Color(0xFFA8C686),
      Color(0xFFF4DA7A),
    ],
    font: 'Sora · DM Sans',
  ),
  (
    id: 'studio',
    ground: Color(0xFFF5F4F1),
    accent: Color(0xFFE5483B),
    colors: [
      Color(0xFFF5F4F1),
      Color(0xFFFFFFFF),
      Color(0xFF17171A),
      Color(0xFFE5483B),
    ],
    font: 'Inter Display · Inter',
  ),
  (
    id: 'terminal',
    ground: Color(0xFF0A0D0B),
    accent: Color(0xFF8BE9A0),
    colors: [
      Color(0xFF0A0D0B),
      Color(0xFF0F1411),
      Color(0xFF8BE9A0),
      Color(0xFFE8C468),
    ],
    font: 'JetBrains Mono',
  ),
  (
    id: 'nocturne',
    ground: Color(0xFF0A0F1E),
    accent: Color(0xFF8EA7FF),
    colors: [
      Color(0xFF0A0F1E),
      Color(0xFF111831),
      Color(0xFF8EA7FF),
      Color(0xFFEEF1FA),
    ],
    font: 'Manrope',
  ),
  (
    id: 'oled',
    ground: Color(0xFF000000),
    accent: Color(0xFF3CF2FF),
    colors: [
      Color(0xFF000000),
      Color(0xFF141414),
      Color(0xFF3CF2FF),
      Color(0xFFF2F2F2),
    ],
    font: 'Doto · Instrument Sans',
  ),
  (
    id: 'ios',
    ground: Color(0xFF04060C),
    accent: Color(0xFF0A6CFF),
    colors: [
      Color(0xFF04060C),
      Color(0xFF5AA8FF),
      Color(0xFF0A6CFF),
      Color(0xFF5CF2B0),
    ],
    font: 'Inter',
  ),
];

/// The localized copy of a design: short line, long description, the three
/// chips and its navigation.
({String short, String long, List<String> chips, String nav}) _copy(
  AppLocalizations l,
  String id,
) => switch (id) {
  'porcelaine' => (
    short: l.vitrinePorcelaineShort,
    long: l.vitrinePorcelaineLong,
    chips: [
      l.vitrineChipLight,
      l.vitrinePorcelaineChip2,
      l.vitrinePorcelaineChip3,
    ],
    nav: l.vitrinePorcelaineNav,
  ),
  'pastille' => (
    short: l.vitrinePastilleShort,
    long: l.vitrinePastilleLong,
    chips: [l.vitrineChipDark, l.vitrinePastilleChip2, l.vitrinePastilleChip3],
    nav: l.vitrinePastilleNav,
  ),
  'studio' => (
    short: l.vitrineStudioShort,
    long: l.vitrineStudioLong,
    chips: [l.vitrineChipLight, l.vitrineStudioChip2, l.vitrineStudioChip3],
    nav: l.vitrineStudioNav,
  ),
  'terminal' => (
    short: l.vitrineTerminalShort,
    long: l.vitrineTerminalLong,
    chips: [l.vitrineChipDark, l.vitrineTerminalChip2, l.vitrineTerminalChip3],
    nav: l.vitrineTerminalNav,
  ),
  'nocturne' => (
    short: l.vitrineNocturneShort,
    long: l.vitrineNocturneLong,
    chips: [l.vitrineChipDark, l.vitrineNocturneChip2, l.vitrineNocturneChip3],
    nav: l.vitrineNocturneNav,
  ),
  'oled' => (
    short: l.vitrineOledShort,
    long: l.vitrineOledLong,
    chips: [l.vitrineOledChip1, l.vitrineOledChip2, l.vitrineOledChip3],
    nav: l.vitrineOledNav,
  ),
  'ios' => (
    short: l.vitrineIosShort,
    long: l.vitrineIosLong,
    chips: [l.vitrineIosChip1, l.vitrineIosChip2, l.vitrineIosChip3],
    nav: l.vitrineIosNav,
  ),
  _ => (
    short: l.vitrineSignalShort,
    long: l.vitrineSignalLong,
    chips: [l.vitrineChipDark, l.vitrineSignalChip2, l.vitrineSignalChip3],
    nav: l.vitrineSignalNav,
  ),
};

class _DesignVitrineState extends ConsumerState<DesignVitrine> {
  /// The design being previewed; null shows the current one.
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final current = ThemePresets.migrateId(
      ref.watch(settingsProvider.select((s) => s.themePreset)),
    );
    final picked = _picked ?? current;
    final facts = _designs.firstWhere(
      (d) => d.id == picked,
      orElse: () => _designs.first,
    );
    final list = Semantics(
      container: true,
      label: context.l10n.vitrineListLabel,
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in _designs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _Item(
                  facts: d,
                  selected: d.id == facts.id,
                  current: d.id == current,
                  onTap: () => setState(() => _picked = d.id),
                ),
              ),
          ],
        ),
      ),
    );
    final preview = _Preview(
      facts: facts,
      isCurrent: facts.id == current,
      onApply: () =>
          ref.read(settingsProvider.notifier).setThemePreset(facts.id),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [list, const SizedBox(height: 16), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: box.maxWidth >= 960 ? 300 : 240, child: list),
            const SizedBox(width: 24),
            Expanded(child: preview),
          ],
        );
      },
    );
  }
}

/// Corner radius of the Vitrine's own pieces, following the design's
/// (Terminal stays square) without going rounder than the mockup.
double _radius(BuildContext context, double max) =>
    DesignSpec.of(context).cardRadius.clamp(0, max).toDouble();

class _Item extends StatelessWidget {
  const _Item({
    required this.facts,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final _Facts facts;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final radius = BorderRadius.circular(_radius(context, 14));
    final name = ThemePresets.getById(facts.id).name;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? c.surfaceHighlight : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? c.primary : Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: c.primary.withValues(alpha: 0.06),
          focusColor: c.primary.withValues(alpha: 0.16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: facts.ground,
                      borderRadius: BorderRadius.circular(_radius(context, 10)),
                      border: Border.all(color: c.border),
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: facts.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        _copy(l10n, facts.id).short,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (current) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.vitrineCurrentBadge,
                      style: AppTypography.body.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.facts,
    required this.isCurrent,
    required this.onApply,
  });

  final _Facts facts;
  final bool isCurrent;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final copy = _copy(l10n, facts.id);
    final name = ThemePresets.getById(facts.id).name;
    final label = AppTypography.body.copyWith(
      fontSize: 13,
      color: c.textSecondary,
    );
    final value = AppTypography.body.copyWith(
      fontSize: 13,
      color: c.textPrimary,
    );
    final motion = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);
    TableRow fact(String key, Widget v) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 18, bottom: 8),
          child: Text(key, style: label),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: v),
      ],
    );
    return Semantics(
      container: true,
      label: l10n.vitrinePreviewLabel,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_radius(context, 22)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_radius(context, 16)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: AnimatedSwitcher(
                  duration: motion,
                  // Expand: the switcher's Stack loosens the constraints.
                  child: SizedBox.expand(
                    key: ValueKey(facts.id),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: DesignMiniature(facts.id),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              style: AppTypography.display(28).copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              copy.long,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                height: 1.5,
                color: c.textPrimary.withValues(alpha: 0.86),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in copy.chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      chip,
                      style: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: c.textPrimary.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 24,
              runSpacing: 16,
              children: [
                Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    fact(
                      l10n.vitrineColors,
                      ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final color in facts.colors)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsetsDirectional.only(
                                  end: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: c.border),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    fact(l10n.vitrineFont, Text(facts.font, style: value)),
                    fact(l10n.vitrineNav, Text(copy.nav, style: value)),
                  ],
                ),
                // Disabled on the current design: nothing to apply.
                FilledButton(
                  onPressed: isCurrent ? null : onApply,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    disabledBackgroundColor: c.surfaceHighlight,
                    disabledForegroundColor: c.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignSpec.of(context).controlRadius,
                      ),
                    ),
                    textStyle: AppTypography.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    isCurrent
                        ? l10n.vitrineApplyCurrent
                        : l10n.vitrineApply(name),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
