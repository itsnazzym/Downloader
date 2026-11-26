import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'pastille_kit.dart';

/// Pastille's transfer (mockup Pastille-Transfert.dc.html): connection, the
/// transfer in flight, the chosen device, nearby devices, what will be sent
/// and the send tile; today's full transfer view (receive tab, payload
/// picker, device tools, direct IP, scan…) follows under « Plus d'options ».
class PastilleTransfer extends ConsumerStatefulWidget {
  const PastilleTransfer({super.key, required this.current});

  final Widget current;

  @override
  ConsumerState<PastilleTransfer> createState() => _PastilleTransferState();
}

class _PastilleTransferState extends ConsumerState<PastilleTransfer> {
  @override
  void initState() {
    super.initState();
    // Today's view starts the server when it is built; it may sit below the
    // fold here, so start it ourselves (start() is idempotent).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(transferControllerProvider.notifier).start());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PastillePage(
      gap: 24,
      children: [
        PastilleHeader(
          eyebrow: l10n.pastilleTransferEyebrow,
          title: l10n.pastilleTransferTitle,
        ),
        const PGrid(
          rowHeight: 150,
          cells: [
            PCell(_ConnectionTile(), h: 2),
            PCell(_ProgressTile(), w: 2, h: 2),
            PCell(_TargetTile()),
            PCell(_DevicesTile()),
            PCell(_PayloadTile(), w: 3, h: 2),
            PCell(_SendTile(), h: 2),
          ],
        ),
        Text(
          l10n.pastilleMoreOptions,
          style: pNum(
            24,
            weight: FontWeight.w700,
            color: pCream,
          ).copyWith(letterSpacing: -0.03 * 24),
        ),
        SizedBox(
          height: math.max(560.0, MediaQuery.sizeOf(context).height - 200),
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
            child: widget.current,
          ),
        ),
      ],
    );
  }
}

TransferPeer? _target(TransferUiState s) {
  for (final p in s.peers) {
    if (p.fingerprint == s.activeTargetFingerprint) return p;
  }
  return null;
}

String _kind(AppLocalizations l10n, TransferDeviceType t) => switch (t) {
  TransferDeviceType.mobile => l10n.transferMobileKindMobile,
  TransferDeviceType.desktop => l10n.transferMobileKindDesktop,
  TransferDeviceType.web => l10n.transferMobileKindWeb,
  TransferDeviceType.headless => l10n.transferMobileKindHeadless,
  TransferDeviceType.server => l10n.transferMobileKindServer,
};

class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final s = ref.watch(transferControllerProvider);
    final qr = s.qrUrl;
    final pin = s.pin.length == 6
        ? '${s.pin.substring(0, 3)} ${s.pin.substring(3)}'
        : s.pin;
    return PTile(
      color: pInkDeep,
      semanticLabel: l10n.pastilleConnection,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.wifi_rounded,
              iconColor: tones.butter,
              text: l10n.pastilleConnection,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tones.cream,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: qr == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          image: true,
                          label: l10n.pastilleQrCode,
                          child: QrImageView(
                            data: qr,
                            padding: EdgeInsets.zero,
                            backgroundColor: tones.cream,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: pInk,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: pInk,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      l10n.pastilleQrCode,
                      style: pSub(context, size: 12),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(l10n.pastillePinCode, style: pSub(context, size: 12)),
            const SizedBox(height: 4),
            Text(
              pin.isEmpty ? '—' : pin,
              maxLines: 1,
              style: pNum(34, color: pCream),
            ),
            const SizedBox(height: 8),
            Text(
              s.lanIp == null
                  ? l10n.transferWaitingNetwork
                  : '${s.lanIp}:${s.port ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pMono(size: 13, color: pCream),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pastilleScanHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: pSub(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTile extends ConsumerWidget {
  const _ProgressTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(transferControllerProvider);
    final c = ref.read(transferControllerProvider.notifier);
    final p = s.progress;
    final target = _target(s);
    final phase = p?.phase ?? TransferPhase.idle;
    final running =
        phase == TransferPhase.transferring ||
        phase == TransferPhase.preparing ||
        phase == TransferPhase.compressing ||
        phase == TransferPhase.waitingPeer;
    final percent = p == null
        ? 0
        : (phase == TransferPhase.done
              ? 100
              : (p.fraction * 100).clamp(0, 100).floor());
    final status = switch (phase) {
      TransferPhase.preparing => l10n.transferPreparing,
      TransferPhase.compressing => l10n.transferCompressing,
      TransferPhase.waitingPeer => l10n.transferWaitingPeer,
      TransferPhase.done => l10n.transferDone,
      TransferPhase.failed => p?.error ?? l10n.transferErrorHttp,
      _ => l10n.pastilleLocalWifi,
    };
    return PTile(
      color: PTones.of(context).lav,
      delay: 60,
      semanticLabel: l10n.pastilleTransferInFlight,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.arrow_forward_rounded,
              text: l10n.pastilleTransferInFlight,
              trailing: target == null
                  ? null
                  : Text(l10n.pastilleTo(target.alias)),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    text: '$percent',
                    style: pNum(96, color: pInk),
                    children: [
                      TextSpan(
                        text: '%',
                        style: pNum(42, color: pInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p == null || p.currentName.isEmpty
                              ? l10n.pastilleNoTransfer
                              : p.currentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: pBody(
                            size: 15,
                            weight: FontWeight.w700,
                            color: pInk,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pSub(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            PDots(
              count: 100,
              maxWidth: 560,
              columns: 25,
              on: percent,
              live: running,
              semanticLabel: '$percent %',
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  if (p != null && running)
                    Text(
                      '${localBytes(l10n, p.bytesPerSecond.round())}/s',
                      style: pMono(
                        size: 13,
                        weight: FontWeight.w500,
                        color: pInk,
                      ),
                    ),
                  const Spacer(),
                  if (running)
                    PButton(
                      label: l10n.transferCancel,
                      height: 38,
                      onTap: c.cancelTransfer,
                    )
                  else if (phase == TransferPhase.failed)
                    PButton(
                      label: l10n.transferRetry,
                      height: 38,
                      onTap: c.retryLastTransfer,
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

class _TargetTile extends ConsumerStatefulWidget {
  const _TargetTile();

  @override
  ConsumerState<_TargetTile> createState() => _TargetTileState();
}

class _TargetTileState extends ConsumerState<_TargetTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _blink.stop();
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final target = _target(ref.watch(transferControllerProvider));
    return PTile(
      color: PTones.of(context).sage,
      delay: 120,
      semanticLabel: l10n.pastilleConnectedDevice,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.smartphone_rounded,
              text: l10n.pastilleConnectedDevice,
            ),
            const Spacer(),
            Text(
              target?.alias ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pNum(22, color: pInk).copyWith(height: 1.1),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (target != null)
                  RepaintBoundary(
                    child: FadeTransition(
                      opacity: Tween(begin: 1.0, end: 0.25).animate(
                        CurvedAnimation(
                          parent: _blink,
                          curve: const _PingPong(),
                        ),
                      ),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: pInk,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                if (target != null) const SizedBox(width: 8),
                Text(
                  target == null
                      ? l10n.pastilleNoDevice
                      : l10n.pastilleConnected,
                  style: pBody(size: 13, weight: FontWeight.w600, color: pInk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 0 → 1 → 0 over one period (the CSS `blink` keyframes).
class _PingPong extends Curve {
  const _PingPong();

  @override
  double transformInternal(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}

/// The mockup's « Historique » has no data source (the controller keeps no
/// transfer history): the nearby devices take its place, tap to choose one.
class _DevicesTile extends ConsumerWidget {
  const _DevicesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(transferControllerProvider);
    final c = ref.read(transferControllerProvider.notifier);
    return PTile(
      color: PTones.of(context).rose,
      delay: 180,
      semanticLabel: l10n.transferDevices,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.devices_rounded,
              text: l10n.transferDevices,
              trailing: Text('${s.peers.length}'),
            ),
            const Spacer(),
            if (s.peers.isEmpty) ...[
              // Still looking: a row of dots whose first one blinks.
              const PDots(
                count: 6,
                columns: 6,
                on: 0,
                live: true,
                maxWidth: 104,
              ),
              const SizedBox(height: 12),
            ],
            if (s.peers.isEmpty)
              Text(
                l10n.transferNoDevices,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: pSub(context),
              ),
            for (final peer in s.peers.take(2))
              InkWell(
                onTap: () => c.setActiveTargetFingerprint(peer.fingerprint),
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Icon(
                        peer.fingerprint == s.activeTargetFingerprint
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        size: 13,
                        color: pInk,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          peer.alias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pBody(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: pInk,
                          ),
                        ),
                      ),
                      Text(
                        _kind(l10n, peer.deviceType),
                        style: pMono(size: 12, color: pSubInk),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PayloadTile extends ConsumerWidget {
  const _PayloadTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tones = PTones.of(context);
    final s = ref.watch(transferControllerProvider);
    final c = ref.read(transferControllerProvider.notifier);
    String name(String path) =>
        path.split(RegExp(r'[\\/]')).where((x) => x.isNotEmpty).lastOrNull ??
        path;
    final rows = <(String, String, Color, VoidCallback)>[
      for (final k in s.selectedCreatorKeys)
        (k, l10n.pastilleCreator, tones.sky, () => c.toggleCreator(k)),
      for (final f in s.extraFolders)
        (name(f), l10n.pastilleFolder, tones.lav, () => c.removeExtraFolder(f)),
      for (final f in s.extraFiles)
        (name(f), l10n.pastilleFile, tones.sage, () => c.removeExtraFile(f)),
    ];
    return PTile(
      color: tones.cream,
      delay: 240,
      semanticLabel: l10n.pastilleFilesToSend,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(
              icon: Icons.insert_drive_file_outlined,
              text: l10n.pastilleFilesToSend,
              trailing: Text(
                '${l10n.transferMobileFileCount(s.selectedFilesCount)} · '
                '${localBytes(l10n, s.selectedTotalBytes)}',
              ),
            ),
            const Spacer(),
            if (rows.isEmpty) ...[
              Text(l10n.transferNeedPayload, style: pSub(context)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PButton(
                    label: l10n.pastilleAddFiles,
                    icon: Icons.add_rounded,
                    onTap: c.addExtraFiles,
                  ),
                  PButton(
                    label: l10n.pastilleAddFolder,
                    icon: Icons.create_new_folder_outlined,
                    kind: PButtonKind.butter,
                    onTap: c.addExtraFolder,
                  ),
                ],
              ),
            ],
            for (var i = 0; i < rows.length && i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PayloadRow(
                name: rows[i].$1,
                kind: rows[i].$2,
                tone: rows[i].$3,
                onRemove: rows[i].$4,
                more: i == 3 && rows.length > 4 ? rows.length - 4 : 0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayloadRow extends StatefulWidget {
  const _PayloadRow({
    required this.name,
    required this.kind,
    required this.tone,
    required this.onRemove,
    required this.more,
  });

  final String name;
  final String kind;
  final Color tone;
  final VoidCallback onRemove;
  final int more;

  @override
  State<_PayloadRow> createState() => _PayloadRowState();
}

class _PayloadRowState extends State<_PayloadRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: true,
      label: widget.name,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onRemove,
            borderRadius: BorderRadius.circular(22),
            hoverColor: Colors.transparent,
            child: AnimatedContainer(
              duration: pMotion(context, 200),
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
              decoration: BoxDecoration(
                color: pInk.withValues(alpha: _hover ? 0.18 : 0.14),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const PCheck(on: true, size: 28),
                  const SizedBox(width: 14),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.tone,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pBody(weight: FontWeight.w700, color: pInk),
                        ),
                        Text(widget.kind, style: pSub(context)),
                      ],
                    ),
                  ),
                  if (widget.more > 0)
                    Text(
                      '+${widget.more}',
                      style: pMono(
                        size: 13,
                        weight: FontWeight.w500,
                        color: pInk,
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

class _SendTile extends ConsumerWidget {
  const _SendTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(transferControllerProvider);
    final c = ref.read(transferControllerProvider.notifier);
    final target = _target(s);
    final busy =
        s.progress != null &&
        s.progress!.phase != TransferPhase.done &&
        s.progress!.phase != TransferPhase.failed &&
        s.progress!.phase != TransferPhase.idle;
    return PTile(
      color: PTones.of(context).butter,
      delay: 300,
      semanticLabel: l10n.pastilleSelection,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PLabel(icon: Icons.send_outlined, text: l10n.pastilleSelection),
            const SizedBox(height: 18),
            Text(
              localBytes(l10n, s.selectedTotalBytes),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: pNum(48, color: pInk),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.transferMobileMediaSelected(s.selectedFilesCount),
              style: pSub(context),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pastilleZip,
                    style: pBody(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: pInk,
                    ),
                  ),
                ),
                PSwitch(
                  value: s.compressZip,
                  onChanged: c.setCompressZip,
                  label: l10n.pastilleZip,
                ),
              ],
            ),
            const SizedBox(height: 14),
            PButton(
              label: l10n.transferSend,
              icon: Icons.arrow_forward_rounded,
              height: 46,
              expand: true,
              onTap: target == null || s.selectedFilesCount == 0 || busy
                  ? null
                  : () {
                      // Same guard as today's view: the demo sends nothing.
                      if (ref.read(showcaseModeProvider)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.transferMobileDemoSendSimulated),
                          ),
                        );
                        return;
                      }
                      unawaited(c.sendTo(target));
                    },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 18,
              child: Text(
                s.lastError ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pSub(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
