import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'oled_theme.dart';
import 'oled_widgets.dart';

/// OLED's settings (mockup OLED-Reglages.dc.html): the sections as text
/// links (a glowing dot before the open one), the section's name in Doto
/// and one grey line, then today's view of the section ([current]) whose
/// rows, switches and value pills OLED's skin draws: no setting is lost.
class OledSettings extends StatelessWidget {
  const OledSettings({super.key, required this.current});

  final Widget current;

  static List<(String, String, String)> sections(AppLocalizations l10n) => [
    ('/settings/general', l10n.settingsGeneral, l10n.oledLeadGeneral),
    ('/settings/output', l10n.settingsOutput, l10n.oledLeadOutput),
    ('/settings/appearance', l10n.settingsAppearance, l10n.oledLeadAppearance),
    (
      '/settings/performance',
      l10n.settingsPerformance,
      l10n.oledLeadPerformance,
    ),
    ('/settings/system', l10n.settingsSystem, l10n.oledLeadSystem),
    ('/settings/plugins', l10n.settingsPlugins, l10n.oledLeadPlugins),
    ('/settings/advanced', l10n.settingsAdvanced, l10n.oledLeadAdvanced),
    (
      '/settings/smart_organizer',
      l10n.smartOrganization,
      l10n.oledLeadOrganizer,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final all = sections(l10n);
    final here = all.firstWhere((s) => s.$1 == path, orElse: () => all.first);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final links = [
          for (final (route, label, _) in all)
            _SectionLink(
              label: label,
              selected: route == here.$1,
              onTap: () => context.go(route),
            ),
        ];
        final nav = Semantics(
          container: true,
          label: l10n.oledSettingsSections,
          child: wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final link in links) ...[
                      link,
                      const SizedBox(height: 10),
                    ],
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final link in links) ...[
                        link,
                        const SizedBox(width: 18),
                      ],
                    ],
                  ),
                ),
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(here.$2, style: oledDoto(56, height: 0.95)),
            ),
            const SizedBox(height: 6),
            Text(here.$3, style: oledText(size: 14, color: OledInk.mute)),
            const SizedBox(height: 18),
            Expanded(child: current),
          ],
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 34, wide ? 40 : 20, 0),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 240,
                      child: SingleChildScrollView(child: nav),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: body,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nav,
                    const SizedBox(height: 22),
                    Expanded(child: body),
                  ],
                ),
        );
      },
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          child: selected
              ? const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OledLiveDot(size: 6),
                )
              : null,
        ),
        OledTextLink(
          label: label,
          selected: selected,
          selectedWeight: FontWeight.w400,
          onTap: onTap,
        ),
      ],
    );
  }
}
