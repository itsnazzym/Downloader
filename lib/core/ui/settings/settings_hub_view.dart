import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../../android/android_engine_bridge.dart';
import '../../design_system/components/app_toast.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../platform/platform_info.dart';
import '../../providers/settings_provider.dart';
import 'general_settings_view.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isMobile) return const _OledSettingsHub();
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final isMobile = PlatformInfo.isMobile;
    final entries = <_HubEntry>[
      _HubEntry(
        title: l10n.settingsGeneral,
        icon: Icons.tune_rounded,
        path: '/settings/general',
      ),
      _HubEntry(
        title: l10n.settingsOutput,
        icon: Icons.folder_outlined,
        path: '/settings/output',
      ),
      _HubEntry(
        title: l10n.settingsAppearance,
        icon: Icons.palette_outlined,
        path: '/settings/appearance',
      ),
      _HubEntry(
        title: l10n.settingsPerformance,
        icon: Icons.speed_rounded,
        path: '/settings/performance',
      ),
      _HubEntry(
        title: l10n.settingsAdvanced,
        icon: Icons.settings_suggest_outlined,
        path: '/settings/advanced',
      ),
      if (isMobile)
        _HubEntry(
          title: l10n.statistics,
          icon: Icons.bar_chart_outlined,
          path: '/stats',
        )
      else ...[
        _HubEntry(
          title: l10n.settingsSystem,
          icon: Icons.memory_outlined,
          path: '/settings/system',
        ),
        _HubEntry(
          title: l10n.settingsPlugins,
          icon: Icons.extension_outlined,
          path: '/settings/plugins',
        ),
        _HubEntry(
          title: l10n.smartOrganization,
          icon: Icons.auto_awesome_motion,
          path: '/settings/smart_organizer',
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        title: Text(
          l10n.settings,
          style: AppTypography.h3.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              leading: Icon(entry.icon, color: colors.textPrimary),
              title: Text(entry.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(entry.path),
            ),
          );
        },
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({
    required this.title,
    required this.icon,
    required this.path,
  });

  final String title;
  final IconData icon;
  final String path;
}

/// Desktop keeps the general page on `/settings`; phones get the hub.
class AdaptiveSettingsHome extends StatelessWidget {
  const AdaptiveSettingsHome({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.useMobileLayout(context)) {
      return const SettingsHubView();
    }
    return const GeneralSettingsView();
  }
}

/// Android hub in the OLED language: engine card, parallel downloads,
/// storage meter and hairline navigation rows.
class _OledSettingsHub extends ConsumerStatefulWidget {
  const _OledSettingsHub();

  @override
  ConsumerState<_OledSettingsHub> createState() => _OledSettingsHubState();
}

class _OledSettingsHubState extends ConsumerState<_OledSettingsHub> {
  String? _ytDlpVersion;
  bool _updating = false;
  int? _totalBytes;
  int? _freeBytes;

  @override
  void initState() {
    super.initState();
    if (PlatformInfo.isAndroid) _loadVersion();
    _loadDisk();
  }

  Future<void> _loadVersion() async {
    try {
      await AndroidEngineBridge.instance.ensureInitialized();
      final version = await AndroidEngineBridge.instance.getYtDlpVersion();
      if (!mounted) return;
      setState(() => _ytDlpVersion = version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ytDlpVersion = 'unknown');
    }
  }

  Future<void> _checkUpdates() async {
    if (_updating) return;
    final l10n = context.l10n;
    final channel = ref.read(settingsProvider).ytDlpChannel;
    setState(() => _updating = true);
    try {
      final res = await AndroidEngineBridge.instance.updateYtDlp(
        channel: channel,
      );
      if (!mounted) return;
      if (res == 'Update check failed') {
        AppToast.showError(context, l10n.settingsHubUpdateFailed);
      } else {
        AppToast.showSuccess(
          context,
          res.toUpperCase().contains('ALREADY')
              ? l10n.settingsHubUpToDate
              : l10n.settingsHubUpdated,
        );
      }
      await _loadVersion();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, l10n.settingsHubUpdateError('$e'));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _loadDisk() async {
    final folder = ref.read(settingsProvider).outputFolder;
    if (PlatformInfo.isAndroid) {
      final space = await AndroidEngineBridge.instance.diskSpace();
      if (!mounted || space == null) return;
      setState(() {
        _totalBytes = space.total;
        _freeBytes = space.free;
      });
      return;
    }
    try {
      final diskSpace = DiskSpace();
      await diskSpace.scan();
      final disks = diskSpace.disks;
      if (disks.isEmpty) return;
      Disk? match;
      for (final d in disks) {
        if (folder.startsWith(d.devicePath) || folder.startsWith(d.mountPath)) {
          match = d;
          break;
        }
      }
      final disk = match ?? disks.first;
      if (!mounted || disk.totalSize <= 0) return;
      setState(() {
        _totalBytes = disk.totalSize;
        _freeBytes = disk.availableSpace;
      });
    } catch (_) {
      // The storage meter stays hidden when disk data is unavailable.
    }
  }

  String _gigabytes(BuildContext context, int bytes) {
    final l10n = context.l10n;
    final gb = bytes / (1024 * 1024 * 1024);
    final text = NumberFormat(
      gb >= 100 ? '0' : '0.0',
      l10n.localeName,
    ).format(gb);
    return '$text ${l10n.sizeUnitGb}';
  }

  Widget _engineCard(BuildContext context, OledTokens t) {
    final version = _ytDlpVersion;
    final known = version != null && version != 'unknown' && version.isNotEmpty;
    return OledCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settingsHubEngine,
            style: OledText.ui(context, size: 13, color: t.ink2),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: known
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      // Doto draws "." as a tiny "+", so dots use the UI face.
                      child: Text.rich(
                        TextSpan(
                          children: [
                            for (final ch in version.split(''))
                              TextSpan(
                                text: ch,
                                style: ch == '.'
                                    ? OledText.ui(
                                        context,
                                        size: 34,
                                        weight: FontWeight.w700,
                                      )
                                    : OledText.dot(context, size: 34),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      version == null
                          ? '…'
                          : context.l10n.settingsHubUnavailable,
                      style: OledText.ui(context, size: 15, color: t.ink3),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          OledButton(
            label: _updating
                ? context.l10n.settingsHubChecking
                : context.l10n.settingsHubCheckUpdates,
            filled: false,
            height: 48,
            onPressed: _updating ? null : _checkUpdates,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.settingsHubAutoUpdate,
                  style: OledText.ui(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              OledToggle(
                value: ref.watch(settingsProvider).autoUpdateYtDlp,
                onChanged: ref
                    .read(settingsProvider.notifier)
                    .setAutoUpdateYtDlp,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.settingsHubChannel,
            style: OledText.ui(context, size: 13, color: t.ink2),
          ),
          const SizedBox(height: 8),
          OledSegmented<String>(
            options: {
              'nightly': context.l10n.settingsHubChannelNightly,
              'stable': context.l10n.settingsHubChannelStable,
            },
            value: ref.watch(settingsProvider).ytDlpChannel,
            onChanged: ref.read(settingsProvider.notifier).setYtDlpChannel,
          ),
        ],
      ),
    );
  }

  Widget _parallelRow(BuildContext context, OledTokens t) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final stepperMax = settings.maxConcurrent > 16
        ? settings.maxConcurrent
        : 16;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.settingsHubParallel,
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.settingsHubParallelHint,
                    style: OledText.ui(
                      context,
                      size: 12,
                      weight: FontWeight.w400,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
            ),
            OledStepper(
              value: settings.maxConcurrent,
              min: 1,
              max: stepperMax,
              onChanged: notifier.setMaxConcurrent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wifiOnlyRow(BuildContext context, OledTokens t) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsHubWifiOnly,
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.settingsHubWifiOnlyHint,
                    style: OledText.ui(
                      context,
                      size: 12,
                      weight: FontWeight.w400,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OledToggle(
              value: settings.wifiOnly,
              onChanged: ref.read(settingsProvider.notifier).setWifiOnly,
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageCard(BuildContext context, OledTokens t) {
    final total = _totalBytes;
    final free = _freeBytes;
    if (total == null || free == null) return const SizedBox.shrink();
    final fraction = (free / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OledCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    context.l10n.settingsHubStorage,
                    style: OledText.ui(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  context.l10n.settingsHubStorageFree(
                    _gigabytes(context, free),
                    _gigabytes(context, total),
                  ),
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w400,
                    color: t.ink2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: t.line,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  heightFactor: 1,
                  child: ColoredBox(color: t.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text(l10n.settings, style: OledText.title(context)),
          if (PlatformInfo.isAndroid) ...[
            const SizedBox(height: 16),
            _engineCard(context, t),
          ],
          const SizedBox(height: 12),
          _HubGroup(
            children: [
              _parallelRow(context, t),
              if (PlatformInfo.isAndroid) _wifiOnlyRow(context, t),
            ],
          ),
          _storageCard(context, t),
          const SizedBox(height: 12),
          _HubGroup(
            children: [
              _HubRow(label: l10n.settingsGeneral, path: '/settings/general'),
              _HubRow(label: l10n.settingsOutput, path: '/settings/output'),
              _HubRow(label: l10n.settingsPlugins, path: '/settings/plugins'),
              _HubRow(
                label: l10n.settingsAppearance,
                path: '/settings/appearance',
              ),
              _HubRow(
                label: l10n.settingsPerformance,
                path: '/settings/performance',
              ),
              _HubRow(
                label: l10n.smartOrganization,
                path: '/settings/smart_organizer',
              ),
              _HubRow(label: l10n.settingsAdvanced, path: '/settings/advanced'),
              _HubRow(label: l10n.settingsSystem, path: '/settings/system'),
              _HubRow(label: l10n.statistics, path: '/stats'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hairline-framed group of rows separated by hairlines.
class _HubGroup extends StatelessWidget {
  const _HubGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: t.ink.withValues(alpha: 0.08),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(path);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        child: Row(
          children: [
            Expanded(child: Text(label, style: OledText.ui(context, size: 15))),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3),
          ],
        ),
      ),
    );
  }
}
