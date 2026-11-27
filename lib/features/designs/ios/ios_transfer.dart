import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'ios_glass.dart';
import 'ios_theme.dart';

/// iOS's transfer (mockup iOS-Transfert.dc.html): this PC in the middle of
/// radar waves with the devices around it (tap one to send it the
/// selection), what will be sent, the pairing code and « Choisir des
/// fichiers… ».
///
/// Today's view ([current]) stays mounted behind it: it starts the transfer
/// service and asks about incoming transfers and device PINs. « Toutes les
/// options » brings it to the front for the rest (receive, direct IP,
/// trusted devices, creators one by one, diagnostics).
class IosTransfer extends StatefulWidget {
  const IosTransfer({super.key, required this.current});

  final Widget current;

  @override
  State<IosTransfer> createState() => _IosTransferState();
}

class _IosTransferState extends State<IosTransfer> {
  bool _detailed = false;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IosTitle(l10n.transferTitle),
                    const SizedBox(height: 2),
                    Text(
                      l10n.iosTransferHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: iosText(t, color: t.sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IosButton(
                label: _detailed
                    ? l10n.nocturneSimpleView
                    : l10n.nocturneAllOptions,
                icon: _detailed ? Icons.radar_rounded : Icons.tune_rounded,
                onTap: () => setState(() => _detailed = !_detailed),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _detailed ? 1 : 0,
            sizing: StackFit.expand,
            children: [
              const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 28),
                child: _Board(),
              ),
              // Mounted for its listeners; no animation while hidden.
              TickerMode(
                enabled: _detailed,
                child: IosFramed(child: widget.current),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Files(),
            SizedBox(height: 14),
            _Pairing(),
            SizedBox(height: 14),
            _ChooseFiles(),
          ],
        );
        if (box.maxWidth < 860) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 460, child: _Radar()),
              SizedBox(height: 20),
              side,
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 125, child: SizedBox(height: 560, child: _Radar())),
            SizedBox(width: 20),
            Expanded(flex: 100, child: side),
          ],
        );
      },
    );
  }
}

// ── Radar ───────────────────────────────────────────────────────────────────

class _Radar extends ConsumerStatefulWidget {
  const _Radar();

  @override
  ConsumerState<_Radar> createState() => _RadarState();
}

class _RadarState extends ConsumerState<_Radar>
    with SingleTickerProviderStateMixin {
  /// Two waves 1.5s apart on one 3s loop; still when motion is reduced.
  late final AnimationController _waves;

  @override
  void initState() {
    super.initState();
    _waves = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _waves.stop();
    } else if (!_waves.isAnimating) {
      _waves.repeat();
    }
  }

  @override
  void dispose() {
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          peers: s.peers,
          target: s.activeTargetFingerprint,
          progress: s.progress,
          scanning: s.isScanningSubnet,
          payload:
              s.selectedFilesCount > 0 ||
              s.selectedCreatorKeys.isNotEmpty ||
              s.extraFolders.isNotEmpty ||
              s.extraFiles.isNotEmpty,
        ),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final still = MediaQuery.disableAnimationsOf(context);
    final waveColor = Color.lerp(
      t.blueFill,
      Colors.white,
      t.dark ? 0.55 : 0.1,
    )!;
    Widget wave(double shift) => AnimatedBuilder(
      animation: _waves,
      builder: (context, _) {
        final p = still ? 1.0 : (_waves.value + shift) % 1;
        return Opacity(
          opacity: still ? 0.18 : 0.8 * (1 - p),
          child: Transform.scale(
            scale: still ? 1 : 0.45 + 0.75 * p,
            child: Container(
              width: 440,
              height: 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: waveColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
    final sending =
        s.progress != null &&
        s.progress!.phase != TransferPhase.idle &&
        s.progress!.phase != TransferPhase.done &&
        s.progress!.phase != TransferPhase.failed;
    // Today's view, mounted behind, carries the onboarding's transfer target.
    return IosGlass(
      radius: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: LayoutBuilder(
          builder: (context, box) {
            final centre = box.biggest.center(Offset.zero);
            final orbit = math.min(box.maxWidth, box.maxHeight) * 0.36;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Painted on their own layer: the page never repaints.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [wave(0), wave(0.5)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Disc(
                          size: 92,
                          tint: (
                            Color.lerp(t.blueFill, Colors.white, 0.3)!,
                            Color.lerp(t.blueFill, Colors.black, 0.2)!,
                          ),
                          icon: Icons.desktop_windows_outlined,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.iosThisPc,
                          style: iosText(t, size: 15, weight: FontWeight.w700),
                        ),
                        if (s.peers.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            s.scanning
                                ? l10n.transferScanningSubnet
                                : l10n.transferNoDevices,
                            textAlign: TextAlign.center,
                            style: iosText(t, size: 13, color: t.sub),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < s.peers.length; i++)
                  _placed(
                    centre: centre,
                    orbit: orbit,
                    index: i,
                    child: _Device(
                      peer: s.peers[i],
                      index: i,
                      target: s.peers[i].fingerprint == s.target,
                      progress: s.peers[i].fingerprint == s.target && sending
                          ? s.progress!.fraction
                          : null,
                      onTap: () {
                        notifier.setActiveTargetFingerprint(
                          s.peers[i].fingerprint,
                        );
                        if (s.payload && !sending) {
                          notifier.sendTo(s.peers[i]);
                        }
                      },
                    ),
                  ),
                PositionedDirectional(
                  bottom: 16,
                  end: 16,
                  child: Row(
                    children: [
                      IosRoundButton(
                        icon: Icons.refresh_rounded,
                        tooltip: l10n.nocturneRefreshDevices,
                        size: 40,
                        onTap: notifier.triggerDiscoveryPulse,
                      ),
                      const SizedBox(width: 8),
                      IosRoundButton(
                        icon: Icons.travel_explore_rounded,
                        tooltip: s.scanning
                            ? l10n.transferScanningSubnet
                            : l10n.transferScanSubnet,
                        size: 40,
                        onTap: s.scanning ? null : notifier.scanSubnet,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Devices around this PC: first top-right, then bottom-left, then the
  /// gaps between.
  static Widget _placed({
    required Offset centre,
    required double orbit,
    required int index,
    required Widget child,
  }) {
    const angles = [-40.0, 140.0, 40.0, -140.0, -90.0, 90.0, 0.0, 180.0];
    final a = angles[index % angles.length] * math.pi / 180;
    final ring = orbit * (1 + 0.18 * (index ~/ angles.length));
    final at = centre + Offset(math.cos(a) * ring, math.sin(a) * ring * 0.9);
    return Positioned(
      left: at.dx - 70,
      top: at.dy - 50,
      width: 140,
      child: child,
    );
  }
}

/// A tinted disc with a white glyph and the inner top highlight.
class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.tint, required this.icon});

  final double size;
  final (Color, Color) tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tint.$1, tint.$2],
      ),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
      ),
      boxShadow: [
        BoxShadow(
          color: tint.$2.withValues(alpha: 0.35),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Icon(icon, size: size * 0.4, color: Colors.white),
  );
}

IconData _deviceIcon(TransferDeviceType type) => switch (type) {
  TransferDeviceType.mobile => Icons.smartphone_rounded,
  TransferDeviceType.desktop => Icons.laptop_rounded,
  _ => Icons.devices_other_rounded,
};

class _Device extends StatelessWidget {
  const _Device({
    required this.peer,
    required this.index,
    required this.target,
    required this.progress,
    required this.onTap,
  });

  final TransferPeer peer;
  final int index;
  final bool target;

  /// The send in progress to this device, else null.
  final double? progress;
  final VoidCallback onTap;

  static const _tints = [
    (Color(0xFF3FDA95), Color(0xFF128A5A)),
    (Color(0xFFFFB25B), Color(0xFFD9670F)),
    (Color(0xFFA59BFF), Color(0xFF5E5CE6)),
    (Color(0xFFFF8DB3), Color(0xFFD6336C)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final p = progress;
    final status = p != null
        ? l10n.iosSending((p * 100).round())
        : (target ? l10n.iosSelected : l10n.iosAvailable);
    return IosTap(
      onTap: onTap,
      radius: 20,
      selected: target,
      semanticLabel: '${peer.alias}, $status',
      builder: (context, hover) => AnimatedScale(
        duration: iosMotion(context, 300),
        curve: iosEase,
        scale: hover && !reduce ? 1.06 : 1,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 74,
                child: CustomPaint(
                  painter: _ArcPainter(
                    value: p ?? (target ? 1 : 0),
                    color: const Color(0xFF5CF2B0),
                    track: t.track,
                  ),
                  child: Center(
                    child: _Disc(
                      size: 64,
                      tint: _tints[index % _tints.length],
                      icon: _deviceIcon(peer.deviceType),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                peer.alias,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: iosText(t, size: 13.5, weight: FontWeight.w700),
              ),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: iosText(
                  t,
                  size: 12.5,
                  weight: p != null ? FontWeight.w600 : FontWeight.w400,
                  color: p != null || target ? t.green : t.soft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The conic progress around a device (`conic-gradient(#5CF2B0 0 41%, …)`).
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (value <= 0) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(c, r, paint..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

// ── What to send ────────────────────────────────────────────────────────────

class _Files extends ConsumerWidget {
  const _Files();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          creators: s.selectedCreatorKeys,
          folders: s.extraFolders,
          files: s.extraFiles,
          count: s.selectedFilesCount,
          bytes: s.selectedTotalBytes,
          progress: s.progress,
          error: s.lastError,
          onlyNew: s.onlyNewVideos,
          zip: s.compressZip,
        ),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final folders = ref.watch(creatorFoldersProvider).folders;
    final all = folders.isNotEmpty && s.creators.length >= folders.length;
    final p = s.progress;
    final rows = <Widget>[
      if (p != null && p.phase != TransferPhase.idle)
        _Row(
          seed: 6,
          title: p.currentName.isEmpty ? l10n.transferTitle : p.currentName,
          bar: p.phase == TransferPhase.done ? 1 : p.fraction,
          barColor: p.phase == TransferPhase.done
              ? const Color(0xFF3FDA95)
              : null,
          state: switch (p.phase) {
            TransferPhase.done => l10n.iosSent,
            TransferPhase.failed => l10n.designFailed,
            _ => '${(p.fraction * 100).round()} %',
          },
          stateColor: switch (p.phase) {
            TransferPhase.done => t.green,
            TransferPhase.failed => t.red,
            _ => t.blue,
          },
          action: switch (p.phase) {
            TransferPhase.done => null,
            TransferPhase.failed => (
              Icons.refresh_rounded,
              l10n.retry,
              notifier.retryLastTransfer,
            ),
            _ => (Icons.close_rounded, l10n.cancel, notifier.cancelTransfer),
          },
        ),
      for (final f in folders)
        if (s.creators.contains(f.key))
          _Row(
            seed: f.key.hashCode,
            title: f.isUnknown ? l10n.folderUnknownCreator : '@${f.handle}',
            state: l10n.archiveMobileVideoCount(f.count),
            action: (
              Icons.close_rounded,
              l10n.iosRemove,
              () => notifier.toggleCreator(f.key),
            ),
          ),
      for (final path in s.folders)
        _Row(
          seed: path.hashCode,
          icon: Icons.folder_rounded,
          title: path,
          action: (
            Icons.close_rounded,
            l10n.iosRemove,
            () => notifier.removeExtraFolder(path),
          ),
        ),
      for (final path in s.files)
        _Row(
          seed: path.hashCode,
          icon: Icons.insert_drive_file_rounded,
          title: path,
          action: (
            Icons.close_rounded,
            l10n.iosRemove,
            () => notifier.removeExtraFile(path),
          ),
        ),
    ];
    return IosGlass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.transferMobileFileCount(s.count)} · '
                    '${localBytes(l10n, s.bytes)}',
                    style: iosText(
                      t,
                      size: 13,
                      weight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ),
                IosButton(
                  label: l10n.transferEntireLibrary,
                  icon: all ? Icons.check_rounded : null,
                  kind: all ? IosButtonKind.pill : IosButtonKind.glass,
                  height: 30,
                  fontSize: 12.5,
                  onTap: folders.isEmpty
                      ? null
                      : all
                      ? notifier.clearCreators
                      : () => notifier.replaceCreators({
                          for (final f in folders) f.key,
                        }),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                l10n.transferNeedPayload,
                style: iosText(t, size: 13.5, color: t.sub),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(shrinkWrap: true, children: rows),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Option(
                  label: l10n.transferOnlyNewToggle,
                  value: s.onlyNew,
                  onChanged: notifier.setOnlyNewVideos,
                ),
                _Option(
                  label: l10n.nocturneZip,
                  value: s.zip,
                  onChanged: notifier.setCompressZip,
                ),
              ],
            ),
          ),
          if (s.error != null && p?.phase == TransferPhase.failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Text(
                s.error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: iosText(t, size: 12.5, color: t.red),
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: IosSwitch(value: value, label: label, onChanged: onChanged),
        ),
        const SizedBox(width: 4),
        Text(label, style: iosText(t, size: 13, color: t.soft)),
      ],
    );
  }
}

/// A row of the files card: a picture, the name, its bar and its state.
class _Row extends StatelessWidget {
  const _Row({
    required this.seed,
    required this.title,
    this.icon,
    this.bar,
    this.barColor,
    this.state,
    this.stateColor,
    this.action,
  });

  final int seed;
  final IconData? icon;
  final String title;
  final double? bar;
  final Color? barColor;
  final String? state;
  final Color? stateColor;
  final (IconData, String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final t = IosTokens.of(context);
    final a = action;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 40,
              child: IosArt(seed: seed, icon: icon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: iosText(t, size: 14.5, weight: FontWeight.w700),
                ),
                if (bar != null) ...[
                  const SizedBox(height: 6),
                  IosBar(value: bar!, color: barColor),
                ],
              ],
            ),
          ),
          if (state != null) ...[
            const SizedBox(width: 12),
            Text(
              state!,
              style: iosText(
                t,
                size: 13,
                weight: FontWeight.w700,
                color: stateColor ?? t.sub,
              ),
            ),
          ],
          if (a != null) ...[
            const SizedBox(width: 6),
            IosTap(
              onTap: a.$3,
              tooltip: a.$2,
              semanticLabel: a.$2,
              builder: (context, hover) => Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(a.$1, size: 17, color: hover ? t.text : t.sub),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pairing extends ConsumerWidget {
  const _Pairing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = IosTokens.of(context);
    final l10n = context.l10n;
    final pin = ref.watch(transferControllerProvider.select((s) => s.pin));
    final shown = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : pin;
    return IosGlass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.iosPairingCode,
                  style: iosText(
                    t,
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: t.sub,
                  ),
                ),
                Text(
                  shown.isEmpty ? '—' : shown,
                  style: iosText(
                    t,
                    size: 32,
                    weight: FontWeight.w900,
                    spacing: 1.9,
                  ),
                ),
              ],
            ),
          ),
          IosButton(
            label: l10n.iosCopy,
            kind: IosButtonKind.pill,
            onTap: pin.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: pin));
                    ScaffoldMessenger.maybeOf(context)
                      ?..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(l10n.iosCopied),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  },
          ),
        ],
      ),
    );
  }
}

class _ChooseFiles extends ConsumerWidget {
  const _ChooseFiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(transferControllerProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: IosButton(
            label: l10n.iosChooseFiles,
            kind: IosButtonKind.primary,
            height: 54,
            fontSize: 16,
            expand: true,
            onTap: notifier.addExtraFiles,
          ),
        ),
        const SizedBox(width: 10),
        IosRoundButton(
          icon: Icons.create_new_folder_outlined,
          tooltip: l10n.nocturneAddFolder,
          size: 54,
          onTap: notifier.addExtraFolder,
        ),
      ],
    );
  }
}
