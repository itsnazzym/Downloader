import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart'
    show qualityOptionLabels;
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'ios_glass.dart';
import 'ios_skin.dart';
import 'ios_theme.dart';

typedef IosSettingsSection = ({
  String path,
  String label,
  IconData icon,
  (Color, Color) tint,
});

/// The sections the chrome lists in Réglages, with the mockup's tints.
List<IosSettingsSection> iosSettingsSections(AppLocalizations l10n) => [
  (
    path: '/settings/general',
    label: l10n.settingsGeneral,
    icon: Icons.tune_rounded,
    tint: IosTints.gray,
  ),
  (
    path: '/settings/output',
    label: l10n.settingsOutput,
    icon: Icons.folder_rounded,
    tint: IosTints.blue,
  ),
  (
    path: '/settings/appearance',
    label: l10n.settingsAppearance,
    icon: Icons.palette_outlined,
    tint: IosTints.violet,
  ),
  (
    path: '/settings/performance',
    label: l10n.settingsPerformance,
    icon: Icons.bolt_rounded,
    tint: IosTints.orange,
  ),
  (
    path: '/settings/system',
    label: l10n.settingsSystem,
    icon: Icons.desktop_windows_rounded,
    tint: IosTints.graphite,
  ),
  (
    path: '/settings/plugins',
    label: l10n.settingsPlugins,
    icon: Icons.extension_rounded,
    tint: IosTints.green,
  ),
  (
    path: '/settings/advanced',
    label: l10n.settingsAdvanced,
    icon: Icons.more_horiz_rounded,
    tint: IosTints.dark,
  ),
  (
    path: '/settings/smart_organizer',
    label: l10n.smartOrganization,
    icon: Icons.auto_awesome_rounded,
    tint: IosTints.pink,
  ),
];

/// iOS's settings (mockup iOS-Reglages.dc.html): the chrome lists the
/// sections; « Général » is drawn from the mockup (downloads, output folder,
/// light / dark / auto and the tint). Every other section, Apparence
/// included, is today's view ([current]) on the glass, its tiles drawn by
/// the iOS skin.
class IosSettings extends StatelessWidget {
  const IosSettings({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final all = iosSettingsSections(l10n);
    final general = path == '/settings' || path == '/settings/general';
    final here = all.firstWhere((s) => s.path == path, orElse: () => all.first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosTitle(general ? l10n.settingsGeneral : here.label),
          const SizedBox(height: 20),
          Expanded(
            child: general
                ? const SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 28),
                    child: _General(),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: IosGlass(
                      radius: 28,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: IosFramed(child: current),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A grouped-list header (« Téléchargements »).
class _Group extends StatelessWidget {
  const _Group(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Text(
        text,
        style: iosText(t, size: 13, weight: FontWeight.w700, color: t.sub),
      ),
    );
  }
}

class _General extends StatelessWidget {
  const _General();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const main = _Downloads();
        const aside = _Look();
        if (box.maxWidth < 760) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, SizedBox(height: 20), aside],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            SizedBox(width: 20),
            SizedBox(width: 300, child: aside),
          ],
        );
      },
    );
  }
}

class _Downloads extends ConsumerWidget {
  const _Downloads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget toggle(
      String title,
      String sub,
      bool value,
      ValueChanged<bool> set,
      (Color, Color) tint,
      IconData icon,
    ) => IosSettingRow(
      card: false,
      tint: tint,
      icon: icon,
      title: title,
      subtitle: sub,
      onTap: () => set(!value),
      control: IosSwitch(value: value, label: title, onChanged: set),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(l10n.iosDownloadsGroup),
        IosGlass(
          radius: 26,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              toggle(
                l10n.autoStart,
                l10n.autoStartDesc,
                s.autoStart,
                n.setAutoStart,
                IosTints.green,
                Icons.play_arrow_rounded,
              ),
              toggle(
                l10n.audioOnly,
                l10n.audioOnlyDesc,
                s.audioOnly,
                n.setAudioOnly,
                IosTints.pink,
                Icons.music_note_rounded,
              ),
              // « Ne pas déranger », said the other way round.
              toggle(
                l10n.iosNotifications,
                l10n.iosNotificationsDesc,
                !s.doNotDisturb,
                (v) => n.setDoNotDisturb(!v),
                IosTints.orange,
                Icons.notifications_rounded,
              ),
              IosSettingRow(
                card: false,
                tint: IosTints.blue,
                icon: Icons.high_quality_rounded,
                title: l10n.preferredQuality,
                subtitle: l10n.iosQualityDesc,
                control: IosPillMenu<String>(
                  tooltip: l10n.preferredQuality,
                  value: s.preferredQuality,
                  options: qualityOptionLabels(l10n),
                  onSelected: n.setPreferredQuality,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Text(
            s.autoStart ? l10n.iosAutoStartOn : l10n.iosAutoStartOff,
            style: iosText(t, size: 12.5, color: t.sub),
          ),
        ),
        _Group(l10n.iosOutputGroup),
        KeyedSubtree(
          key: OnboardingTargets.outputFolder,
          child: IosGlass(
            radius: 26,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [IosTints.blue.$1, IosTints.blue.$2],
                    ),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadFolder,
                        style: iosText(t, size: 15, weight: FontWeight.w600),
                      ),
                      Text(
                        s.outputFolder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: iosText(t, size: 12.5, color: t.sub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                IosButton(
                  label: l10n.nocturneChange,
                  kind: IosButtonKind.pill,
                  height: 36,
                  onTap: () => pickOutputFolder(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Apparence: light / dark / auto, the tint, and the way to the designs.
class _Look extends ConsumerWidget {
  const _Look();

  /// The mockup's six tints; the first is iOS's own blue.
  static const _tints = [
    Color(0xFF0A84FF),
    Color(0xFF7B61FF),
    Color(0xFFFF4D8D),
    Color(0xFFFF8A1F),
    Color(0xFF2FD27A),
    Color(0xFF8E8E99),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final accent = s.customAccentColor;
    final names = [
      l10n.iosTintBlue,
      l10n.iosTintPurple,
      l10n.iosTintPink,
      l10n.iosTintOrange,
      l10n.iosTintGreen,
      l10n.iosTintGraphite,
    ];
    final modes = [
      (
        'light',
        l10n.iosLight,
        const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF1FF), Color(0xFFC9D6F2)],
          ),
        ),
      ),
      (
        'dark',
        l10n.iosDark,
        const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.6),
            radius: 1.1,
            colors: [Color(0xFF3A39A8), Color(0xFF0B0A18)],
          ),
        ),
      ),
      (
        'system',
        l10n.iosAuto,
        const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF1FF),
              Color(0xFFEAF1FF),
              Color(0xFF0B0A18),
              Color(0xFF0B0A18),
            ],
            stops: [0, 0.5, 0.5, 1],
          ),
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(l10n.settingsAppearance),
        IosGlass(
          radius: 26,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < modes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _ModeTile(
                        label: modes[i].$2,
                        preview: modes[i].$3,
                        selected: s.themeMode == modes[i].$1,
                        onTap: () => n.setThemeMode(modes[i].$1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.iosTint,
                style: iosText(
                  t,
                  size: 13,
                  weight: FontWeight.w600,
                  color: t.sub,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _tints.length; i++)
                    _Swatch(
                      color: _tints[i],
                      name: names[i],
                      selected: _tints[i].toARGB32() == accent,
                      onTap: () => n.setCustomAccentColor(_tints[i].toARGB32()),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IosTap(
          onTap: () => context.go('/settings/appearance'),
          radius: 22,
          semanticLabel: l10n.iosChangeDesign,
          builder: (context, hover) => IosGlass(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFF4D6D),
                        Color(0xFFFFC46B),
                        Color(0xFF5CF2B0),
                        Color(0xFF5AC8FF),
                        Color(0xFF9B8CF2),
                        Color(0xFFFF4D6D),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 3,
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
                        l10n.iosChangeDesign,
                        style: iosText(t, size: 15, weight: FontWeight.w700),
                      ),
                      Text(
                        l10n.iosDesignCount(ThemePresets.all.length),
                        style: iosText(t, size: 12.5, color: t.sub),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: hover ? t.text : t.sub,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final BoxDecoration preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IosTap(
      onTap: onTap,
      radius: 16,
      selected: selected,
      semanticLabel: label,
      builder: (context, hover) => AnimatedContainer(
        duration: iosMotion(context, 300),
        curve: iosEase,
        transform: Matrix4.translationValues(0, hover && !reduce ? -3 : 0, 0),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: t.blueFill.withValues(alpha: 0.6),
                            blurRadius: 22,
                          ),
                        ]
                      : null,
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? t.blueFill : t.edge,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(decoration: preview),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: iosText(
                t,
                size: 12.5,
                weight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? t.text : t.soft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IosTap(
      onTap: onTap,
      selected: selected,
      semanticLabel: name,
      tooltip: name,
      builder: (context, hover) => AnimatedContainer(
        duration: iosMotion(context, 200),
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)]
              : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
