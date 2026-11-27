import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../shared/design_data.dart';
import 'oled_theme.dart';
import 'oled_widgets.dart';

/// OLED's transfer (mockup OLED-Transfert.dc.html): the devices on the Wi-Fi
/// around this PC on a radar with one expanding ion ring, the pairing code
/// in Doto, what goes to the chosen device, then send / choose files.
///
/// Today's view ([current]) stays mounted behind it: it starts the transfer
/// service and asks about incoming transfers and device PINs. « Toutes les
/// options » brings it to the front for the rest (receive, direct IP,
/// trusted devices, folders, diagnostics).
class OledTransfer extends StatefulWidget {
  const OledTransfer({super.key, required this.current});

  final Widget current;

  @override
  State<OledTransfer> createState() => _OledTransferState();
}

class _OledTransferState extends State<OledTransfer> {
  bool _detailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final side = wide ? 40.0 : 20.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 18, side, 0),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OledTextLink(
                  label: _detailed ? l10n.oledSimpleView : l10n.oledAllOptions,
                  size: 13,
                  onTap: () => setState(() => _detailed = !_detailed),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _detailed ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(side, 12, side, 36),
                    child: wide
                        ? const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: _Radar()),
                              SizedBox(width: 40),
                              Expanded(flex: 5, child: _Send(divider: true)),
                            ],
                          )
                        : const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Radar(),
                              SizedBox(height: 24),
                              _Send(divider: false),
                            ],
                          ),
                  ),
                  // Mounted for its listeners; no animation while hidden.
                  TickerMode(enabled: _detailed, child: widget.current),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where the devices sit on the radar, as angles from this PC.
const _angles = [-40.0, 140.0, 35.0, 215.0, -95.0, 85.0, 260.0, -10.0];

class _Radar extends ConsumerStatefulWidget {
  const _Radar();

  @override
  ConsumerState<_Radar> createState() => _RadarState();
}

class _RadarState extends ConsumerState<_Radar>
    with SingleTickerProviderStateMixin {
  /// The expanding ring (`ring` 3.2 s): still at 25 % with reduced motion.
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.repeat();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (peers, target, ip, scanning) = ref.watch(
      transferControllerProvider.select(
        (s) =>
            (s.peers, s.activeTargetFingerprint, s.lanIp, s.isScanningSubnet),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final chosen =
        peers.where((p) => p.fingerprint == target).firstOrNull ??
        peers.firstOrNull;
    final still = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final size = math.min(box.maxWidth, 520.0);
            Widget circle(double d, Color color) => Container(
              width: size * d,
              height: size * d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
            );
            return SizedBox(
              height: math.max(size, 400),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  circle(1, const Color(0xFF1A1A1A)),
                  circle(360 / 520, const Color(0xFF1A1A1A)),
                  circle(200 / 520, const Color(0xFF222222)),
                  ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _ring,
                      builder: (context, child) {
                        final t = still
                            ? 1.0
                            : Curves.easeOut.transform(_ring.value);
                        return Opacity(
                          opacity: still ? 0.25 : 0.9 * (1 - t),
                          child: Transform.scale(
                            scale: still ? 1 : 0.4 + 0.6 * t,
                            child: child,
                          ),
                        );
                      },
                      child: circle(1, OledInk.ion),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.oledThisPc, style: oledDoto(22, height: 1)),
                      const SizedBox(height: 4),
                      Text(
                        ip ?? l10n.transferWaitingNetwork,
                        style: oledMono(size: 11),
                      ),
                    ],
                  ),
                  for (final (i, p) in peers.take(_angles.length).indexed)
                    Align(
                      alignment: Alignment(
                        0.72 * math.cos(_angles[i] * math.pi / 180),
                        0.72 * math.sin(_angles[i] * math.pi / 180),
                      ),
                      child: _PeerPill(
                        peer: p,
                        chosen: p == chosen,
                        onTap: () =>
                            notifier.setActiveTargetFingerprint(p.fingerprint),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (peers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.transferNoDevices,
              textAlign: TextAlign.center,
              style: oledText(size: 13, color: OledInk.mute),
            ),
          ),
        Wrap(
          spacing: 22,
          alignment: WrapAlignment.center,
          children: [
            OledTextLink(
              label: l10n.oledRefreshDevices,
              size: 13,
              onTap: notifier.triggerDiscoveryPulse,
            ),
            OledTextLink(
              label: scanning
                  ? l10n.transferScanningSubnet
                  : l10n.transferScanSubnet,
              size: 13,
              onTap: scanning ? null : notifier.scanSubnet,
            ),
          ],
        ),
      ],
    );
  }
}

/// A device on the radar: the chosen one lit in ion, the others hollow.
class _PeerPill extends StatefulWidget {
  const _PeerPill({
    required this.peer,
    required this.chosen,
    required this.onTap,
  });

  final TransferPeer peer;
  final bool chosen;
  final VoidCallback onTap;

  @override
  State<_PeerPill> createState() => _PeerPillState();
}

class _PeerPillState extends State<_PeerPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.chosen;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(999),
          hoverColor: Colors.transparent,
          child: AnimatedContainer(
            duration: oledMotion(context, 160),
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 16, 8),
            decoration: BoxDecoration(
              color: OledInk.bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: on
                    ? OledInk.ion
                    : (_hover ? OledInk.ink : OledInk.ghost),
              ),
              boxShadow: on
                  ? const [BoxShadow(color: Color(0x553CF2FF), blurRadius: 18)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? OledInk.ion : null,
                    border: on ? null : Border.all(color: OledInk.mute),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    widget.peer.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: oledText(
                      size: 13,
                      weight: FontWeight.w500,
                      color: on || _hover ? OledInk.ink : OledInk.soft,
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

/// The pairing code, what goes to the chosen device, and the send buttons.
class _Send extends ConsumerWidget {
  const _Send({required this.divider});

  /// Beside the radar: a hairline on its side.
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          pin: s.pin,
          creators: s.selectedCreatorKeys,
          folders: s.extraFolders,
          files: s.extraFiles,
          count: s.selectedFilesCount,
          bytes: s.selectedTotalBytes,
          peers: s.peers,
          target: s.activeTargetFingerprint,
          progress: s.progress,
          error: s.lastError,
        ),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final creators = ref.watch(creatorFoldersProvider).folders;
    final target =
        s.peers.where((p) => p.fingerprint == s.target).firstOrNull ??
        s.peers.firstOrNull;
    final progress = s.progress;
    final failed = progress?.phase == TransferPhase.failed;
    final running =
        progress != null &&
        progress.phase != TransferPhase.idle &&
        progress.phase != TransferPhase.done &&
        !failed;
    final hasPayload =
        s.count > 0 ||
        s.creators.isNotEmpty ||
        s.folders.isNotEmpty ||
        s.files.isNotEmpty;
    final pin = s.pin.length == 6
        ? '${s.pin.substring(0, 3)} ${s.pin.substring(3)}'
        : s.pin;

    Widget row({
      required String title,
      required String state,
      Color stateColor = OledInk.mute,
      double? bar,
      VoidCallback? onTap,
      IconData? mark,
    }) => InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFF050505),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF101010))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: oledText(size: 14),
                  ),
                ),
                const SizedBox(width: 14),
                if (mark != null) ...[
                  Icon(mark, size: 14, color: stateColor),
                  const SizedBox(width: 6),
                ],
                Text(state, style: oledMono(color: stateColor)),
              ],
            ),
            if (bar != null) ...[
              const SizedBox(height: 6),
              OledBar(value: bar, height: 3),
            ],
          ],
        ),
      ),
    );

    final status = switch (progress?.phase) {
      TransferPhase.done => l10n.transferDone,
      TransferPhase.failed => progress?.error ?? s.error ?? l10n.transferRetry,
      _ => '${((progress?.fraction ?? 0) * 100).round()} %',
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.oledPairingCode.toUpperCase(), style: oledEyebrow()),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            pin.isEmpty ? '— — —' : pin,
            style: oledDoto(72, height: 0.9).copyWith(letterSpacing: 4),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.oledPairingHint,
          style: oledText(size: 13, color: OledInk.mute),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.only(top: 18),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: OledInk.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  target == null
                      ? l10n.oledSendNoDevice
                      : l10n.oledSendToDevice(target.alias),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: oledText(size: 13),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${s.count} · ${localBytes(l10n, s.bytes)}',
                style: oledMono(size: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (progress != null &&
            progress.phase != TransferPhase.idle &&
            progress.currentName.isNotEmpty)
          row(
            title: progress.currentName,
            state: status,
            stateColor: failed
                ? OledInk.err
                : (running ? OledInk.ion : OledInk.ink),
            bar: progress.fraction,
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final f in creators)
                row(
                  title: f.isUnknown
                      ? l10n.folderUnknownCreator
                      : '@${f.handle}',
                  state: l10n.oledVideoCount(f.count),
                  mark: s.creators.contains(f.key) ? Icons.check_rounded : null,
                  stateColor: s.creators.contains(f.key)
                      ? OledInk.ion
                      : OledInk.mute,
                  onTap: () => notifier.toggleCreator(f.key),
                ),
              for (final path in s.folders)
                row(
                  title: path,
                  state: '',
                  mark: Icons.close_rounded,
                  onTap: () => notifier.removeExtraFolder(path),
                ),
              for (final path in s.files)
                row(
                  title: path,
                  state: '',
                  mark: Icons.close_rounded,
                  onTap: () => notifier.removeExtraFile(path),
                ),
              if (creators.isEmpty && s.folders.isEmpty && s.files.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.transferNeedPayload,
                    style: oledText(size: 13, color: OledInk.mute),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (running)
              OledPill(
                label: l10n.transferCancel,
                height: 46,
                onTap: notifier.cancelTransfer,
              )
            else if (failed)
              OledPill(
                label: l10n.transferRetry,
                kind: OledPillKind.solid,
                height: 46,
                onTap: notifier.retryLastTransfer,
              )
            else
              OledPill(
                label: l10n.transferSend,
                kind: OledPillKind.solid,
                height: 46,
                padding: 22,
                onTap: target == null || !hasPayload
                    ? null
                    : () => notifier.sendTo(target),
              ),
            OledPill(
              label: l10n.oledChooseFiles,
              height: 46,
              onTap: notifier.addExtraFiles,
            ),
          ],
        ),
      ],
    );
    if (!divider) return body;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 40),
      decoration: const BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: OledInk.line)),
      ),
      child: body,
    );
  }
}
