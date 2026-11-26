import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/core/setup/dependency_catalog.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/output_folder_picker.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart'
    show qualityOptionLabels;
import 'package:modern_downloader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'terminal_widgets.dart';

/// Terminal's settings (mockup Terminal-Reglages.dc.html): a section list
/// and « Général » drawn as an editable config.toml; the other sections are
/// today's views framed in the same file panel, so no setting is lost.
class TerminalSettings extends ConsumerWidget {
  const TerminalSettings({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final general = path == '/settings' || path == '/settings/general';
    final sections = [
      ('g', '/settings/general', l10n.settingsGeneral),
      ('o', '/settings/output', l10n.settingsOutput),
      ('p', '/settings/appearance', l10n.settingsAppearance),
      ('f', '/settings/performance', l10n.settingsPerformance),
      ('v', '/settings/advanced', l10n.settingsAdvanced),
      ('y', '/settings/system', l10n.settingsSystem),
      ('u', '/settings/plugins', l10n.settingsPlugins),
      ('m', '/settings/smart_organizer', l10n.smartOrganization),
    ];
    final title = sections
        .firstWhere((s) => s.$2 == path, orElse: () => sections.first)
        .$3
        .toLowerCase();
    final settings = ref.read(settingsProvider.notifier);
    final bindings = <String, VoidCallback>{
      for (final (k, p, _) in sections) k: () => context.go(p),
      if (general) ...{
        'c': () => pickOutputFolder(context, ref),
        'r': () => ref.read(dependencyBootstrapProvider.notifier).ensureReady(),
        '-': () => settings.setMaxConcurrent(
          (ref.read(settingsProvider).maxConcurrent - 1).clamp(1, 60),
        ),
        '+': () => settings.setMaxConcurrent(
          (ref.read(settingsProvider).maxConcurrent + 1).clamp(1, 60),
        ),
      },
    };
    final nav = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '## ${l10n.terminalSections}',
            style: tm(AppColors.of(context).textDisabled),
          ),
        ),
        for (final (k, p, label) in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: TKeyRow(
              keyHint: k,
              label: label.toLowerCase(),
              selected: p == path || (general && p == '/settings/general'),
              onTap: () => context.go(p),
            ),
          ),
      ],
    );
    final file = _FilePanel(
      title: title,
      child: general ? const _GeneralFile() : Expanded(child: current),
    );
    return TerminalPageKeys(
      bindings: bindings,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TPrompt('config', l10n.terminalFlagEdit),
                    const SizedBox(height: 12),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 170, child: nav),
                                const SizedBox(width: 18),
                                Expanded(child: file),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                nav,
                                const SizedBox(height: 18),
                                Expanded(child: file),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    THints([
                      ('g o p f v y u m', l10n.terminalSection),
                      if (general) ...[
                        ('c', l10n.terminalChangeFolder),
                        ('- +', l10n.terminalAdjust),
                        ('r', l10n.terminalCheckTools),
                      ],
                    ]),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// `config.toml [section]   utf-8 · toml` over the file's body.
class _FilePanel extends StatelessWidget {
  const _FilePanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final framed = child is Expanded;
    return TPanel(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: framed ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Text('config.toml', style: tm(colors.textSecondary)),
                const SizedBox(width: 10),
                Text('[$title]', style: tm(colors.primary)),
                const Spacer(),
                Text('utf-8 · toml', style: tm(colors.textDisabled)),
              ],
            ),
          ),
          if (framed)
            child
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralFile extends ConsumerWidget {
  const _GeneralFile();

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
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final tools = ref.watch(dependencyBootstrapProvider);
    final design = DesignSpec.of(context).id;
    final qualities = qualityOptionLabels(l10n);
    final packages = DependencyCatalog.windowsRequired;
    var no = 0;

    Widget line(Widget content, [Widget? control, bool header = false]) {
      no++;
      return _Line(no: no, header: header, control: control, child: content);
    }

    Widget blank() => line(const SizedBox.shrink());
    Widget header(String text, {bool on = false}) =>
        _Line(no: ++no, header: true, on: on, child: Text('[$text]'));
    Widget kv(String key, String value) => Text.rich(
      TextSpan(
        text: '$key = ',
        children: [TextSpan(text: value, style: tm(colors.warning))],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textPrimary),
    );
    Widget comment(String text) => Text(
      '# $text',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: tm(colors.textSecondary),
    );

    String toolState(DependencyPackage p) {
      if (tools.isReady || p.executableNames.every(tools.readyTools.contains)) {
        return l10n.terminalToolOk;
      }
      if (tools.isBusy) return l10n.terminalToolChecking;
      if (tools.hasFailed) return l10n.terminalToolMissing;
      return l10n.terminalToolUnchecked;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(comment(l10n.terminalConfigComment)),
        header(l10n.settingsGeneral.toLowerCase(), on: true),
        line(
          kv(l10n.terminalCfgAudioOnly, '${s.audioOnly}'),
          TSwitch(
            value: s.audioOnly,
            onChanged: n.setAudioOnly,
            label: l10n.audioOnly,
          ),
        ),
        line(
          kv(l10n.terminalCfgAutoStart, '${s.autoStart}'),
          TSwitch(
            value: s.autoStart,
            onChanged: n.setAutoStart,
            label: l10n.autoStart,
          ),
        ),
        line(
          Text('${l10n.terminalCfgQuality} =', style: tm(colors.textPrimary)),
          _Select(
            value: s.preferredQuality,
            options: qualities,
            label: l10n.preferredQuality,
            onChanged: n.setPreferredQuality,
          ),
        ),
        blank(),
        header(l10n.settingsOutput.toLowerCase()),
        line(
          kv(l10n.terminalCfgFolder, '"${s.outputFolder}"'),
          TButton(
            keyHint: 'c',
            label: l10n.terminalChange,
            height: 28,
            onTap: () => pickOutputFolder(context, ref),
          ),
        ),
        blank(),
        header(l10n.settingsAppearance.toLowerCase()),
        line(kv(l10n.terminalCfgDesign, '"$design"')),
        _Line(
          no: ++no,
          top: true,
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = ((c.maxWidth + 8) / 116).floor().clamp(1, 6);
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _designs)
                    SizedBox(
                      width: w,
                      child: _DesignThumb(
                        id: id,
                        selected: id == design,
                        onTap: () => n.setThemePreset(id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        blank(),
        header(l10n.settingsPerformance.toLowerCase()),
        line(
          kv(l10n.terminalCfgConcurrent, '${s.maxConcurrent}'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TButton(
                label: '-',
                square: true,
                height: 28,
                tooltip: l10n.simultaneousDownloads,
                onTap: s.maxConcurrent <= 1
                    ? null
                    : () => n.setMaxConcurrent(s.maxConcurrent - 1),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${s.maxConcurrent}',
                  textAlign: TextAlign.center,
                  style: tm(colors.textPrimary),
                ),
              ),
              TButton(
                label: '+',
                square: true,
                height: 28,
                tooltip: l10n.simultaneousDownloads,
                onTap: s.maxConcurrent >= 60
                    ? null
                    : () => n.setMaxConcurrent(s.maxConcurrent + 1),
              ),
            ],
          ),
        ),
        line(
          kv(l10n.terminalCfgReduceEffects, '${s.reduceEffects}'),
          TSwitch(
            value: s.reduceEffects,
            onChanged: n.setReduceEffects,
            label: l10n.terminalCfgReduceEffects,
          ),
        ),
        blank(),
        header(
          '${l10n.settingsSystem.toLowerCase()}.${l10n.settingsToolsSection.toLowerCase()}',
        ),
        line(
          comment(packages.map((p) => p.displayName.toLowerCase()).join(', ')),
          TButton(
            keyHint: 'r',
            label: l10n.previewSetup,
            height: 28,
            onTap: tools.isBusy
                ? null
                : () => ref
                      .read(dependencyBootstrapProvider.notifier)
                      .ensureReady(),
          ),
        ),
        line(
          Text.rich(
            TextSpan(
              children: [
                for (final (i, p) in packages.indexed) ...[
                  if (i > 0) const TextSpan(text: ' · '),
                  TextSpan(
                    text: p.displayName.toLowerCase(),
                    style: tm(colors.textPrimary, weight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' ${toolState(p)}',
                    style: tm(
                      toolState(p) == l10n.terminalToolOk
                          ? colors.primary
                          : toolState(p) == l10n.terminalToolMissing
                          ? colors.error
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            style: tm(colors.textPrimary),
          ),
        ),
        blank(),
        header(l10n.terminalHelp),
        line(
          comment(l10n.onboardingReplayDesc),
          TButton(
            label: l10n.onboardingReplay,
            height: 28,
            onTap: () {
              context.go('/');
              ref.read(onboardingControllerProvider.notifier).replay();
            },
          ),
        ),
      ],
    );
  }
}

/// `.cl`: line number, content, control on the right.
class _Line extends StatelessWidget {
  const _Line({
    required this.no,
    required this.child,
    this.control,
    this.header = false,
    this.on = false,
    this.top = false,
  });

  final int no;
  final Widget child;
  final Widget? control;
  final bool header;
  final bool on;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = header
        ? DefaultTextStyle.merge(
            style: tm(colors.primary, weight: FontWeight.w700),
            child: child,
          )
        : child;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: EdgeInsets.fromLTRB(0, top ? 4 : 1, 12, top ? 6 : 1),
      decoration: BoxDecoration(
        color: on ? colors.primary.withValues(alpha: 0.07) : null,
        border: Border(
          left: BorderSide(
            color: on ? colors.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: top
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$no',
              textAlign: TextAlign.right,
              style: tm(colors.textDisabled),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: content),
          if (control != null) ...[const SizedBox(width: 12), control!],
        ],
      ),
    );
  }
}

/// `.sel`: a square select.
class _Select extends StatelessWidget {
  const _Select({
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      tooltip: label,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final e in options.entries)
          PopupMenuItem<String>(
            value: e.key,
            height: 36,
            child: Text(
              e.value,
              style: tm(e.key == value ? colors.primary : colors.textPrimary),
            ),
          ),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options[value] ?? value,
              style: tm(colors.textPrimary, weight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: colors.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// `.th`: a mini page in the design's own colours, `[x] Name`.
class _DesignThumb extends StatefulWidget {
  const _DesignThumb({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesignThumb> createState() => _DesignThumbState();
}

class _DesignThumbState extends State<_DesignThumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = ThemePresets.getById(widget.id);
    final on = widget.selected;
    final fg = on || _hover ? colors.textPrimary : colors.textSecondary;
    Widget bar(double f, Color c) => FractionallySizedBox(
      widthFactor: f,
      alignment: AlignmentDirectional.centerStart,
      child: Container(height: 4, color: c),
    );
    return Semantics(
      selected: on,
      button: true,
      label: p.name,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        focusColor: colors.primary.withValues(alpha: 0.2),
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: tMotion(context),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(
              color: on
                  ? colors.primary
                  : (_hover ? colors.textSecondary : colors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.all(8),
                color: p.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(0.4, p.primary),
                    const SizedBox(height: 5),
                    bar(0.75, p.surfaceHighlight),
                    const SizedBox(height: 5),
                    bar(0.55, p.surfaceHighlight),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: on ? '[x]' : '[ ]',
                      style: tm(colors.primary, size: 12),
                    ),
                    TextSpan(text: ' ${p.name}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tm(fg, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
