import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/utils/format_utils.dart';
import 'package:tapload/features/downloader/presentation/models/creator_folder.dart';
import 'package:tapload/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import 'package:tapload/features/transfer/domain/transfer_models.dart';
import 'package:tapload/features/transfer/presentation/transfer_controller.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'signal_controls.dart';
import 'signal_widgets.dart';

/// Signal's transfer page (mockup Signal-Transfert.dc.html): the QR / PIN
/// card and the devices on the left, the files to send and the live
/// transfer on the right. Replaces today's view entirely, so it also owns
/// what today's view did on its own: starting the server and answering the
/// incoming-offer and peer-PIN prompts.
class SignalTransfer extends ConsumerStatefulWidget {
  const SignalTransfer({super.key});

  @override
  ConsumerState<SignalTransfer> createState() => _SignalTransferState();
}

class _SignalTransferState extends ConsumerState<SignalTransfer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(transferControllerProvider.notifier).start());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transferControllerProvider.select((s) => s.incoming), (
      previous,
      next,
    ) {
      if (next == null || previous != null) return;
      unawaited(_showIncoming(next));
    });
    ref.listen(transferControllerProvider.select((s) => s.peerPinPrompt), (
      previous,
      next,
    ) {
      if (next == null || previous != null) return;
      unawaited(_showPeerPin(next));
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        const left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_ReceiveCard(), SizedBox(height: 16), _DevicesCard()],
        );
        const right = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_FilesCard(), _LiveCard()],
        );
        return SingleChildScrollView(
          padding: signalPagePadding(constraints.maxWidth),
          child: wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: left),
                    SizedBox(width: 16),
                    Expanded(flex: 7, child: right),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [right, SizedBox(height: 16), left],
                ),
        );
      },
    );
  }

  Future<void> _showIncoming(IncomingOffer offer) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.transferIncomingTitle),
        content: Text(
          l10n.transferIncomingBody(
            offer.peerAlias,
            offer.files.length,
            FormatUtils.formatBytes(offer.totalBytes),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.transferReject),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.transferAccept),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ref
        .read(transferControllerProvider.notifier)
        .answerIncoming(accept ?? false);
  }

  Future<void> _showPeerPin(TransferPeer peer) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.transferMobilePeerPinRequired(peer.alias)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.transferMobilePeerPinExplain,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 10,
              autofocus: true,
              textAlign: TextAlign.center,
              style: AppTypography.mono.copyWith(
                fontSize: 22,
                letterSpacing: 4,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: l10n.transferMobilePinExample,
                counterText: '',
              ),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: Text(l10n.transferSend),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    ref.read(transferControllerProvider.notifier).dismissPeerPin();
    if (pin == null || pin.isEmpty) return;
    unawaited(
      ref.read(transferControllerProvider.notifier).sendTo(peer, pin: pin),
    );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Sends the chosen files to [peer], or explains why it cannot.
void _sendTo(BuildContext context, WidgetRef ref, TransferPeer peer) {
  if (ref.read(showcaseModeProvider)) {
    _snack(context, context.l10n.transferMobileDemoSendSimulated);
    return;
  }
  unawaited(ref.read(transferControllerProvider.notifier).sendTo(peer));
}

/// The device the files go to: the one picked, else the only one around.
TransferPeer? _target(List<TransferPeer> peers, String? fingerprint) {
  for (final p in peers) {
    if (p.fingerprint == fingerprint) return p;
  }
  return peers.length == 1 ? peers.first : null;
}

IconData _deviceIcon(TransferPeer peer) => switch (peer.deviceType) {
  TransferDeviceType.mobile => Icons.smartphone_rounded,
  TransferDeviceType.web => Icons.public_rounded,
  _ => Icons.desktop_windows_outlined,
};

// ── Receive: QR, PIN, address ───────────────────────────────────────────────

class _ReceiveCard extends ConsumerWidget {
  const _ReceiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (qr, pin, ip, port, alias, conflict, error) = ref.watch(
      transferControllerProvider.select(
        (s) => (
          s.qrUrl,
          s.pin,
          s.lanIp,
          s.port,
          s.alias,
          s.portConflict,
          s.lastError,
        ),
      ),
    );
    final pinLabel = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : pin;
    final address = ip == null ? null : '$ip:$port';
    return SignalCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignalEyebrow(l10n.signalTransferWifi),
          const SizedBox(height: 4),
          Text(
            l10n.signalTransferTitle,
            style: AppTypography.display(
              30,
              weight: FontWeight.w600,
            ).copyWith(color: colors.textPrimary, height: 1.1),
          ),
          const SizedBox(height: 22),
          if (qr == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                error ?? l10n.transferWaitingNetwork,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 168,
                      height: 168,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.textPrimary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 40,
                            spreadRadius: -12,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qr,
                        padding: EdgeInsets.zero,
                        backgroundColor: colors.textPrimary,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: colors.background,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: colors.background,
                        ),
                        semanticsLabel: l10n.transferMobileQrShow,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 168,
                      child: Text(
                        alias,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.signalTransferScanHint,
                        style: AppTypography.body.copyWith(
                          fontSize: 15,
                          height: 1.45,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SignalEyebrow(l10n.signalTransferCode),
                      Tooltip(
                        message: l10n.transferCopyLink,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            unawaited(
                              Clipboard.setData(ClipboardData(text: pin)),
                            );
                            _snack(context, '$pin ${l10n.transferCopied}');
                          },
                          child: Text(
                            pinLabel,
                            textDirection: TextDirection.ltr,
                            style:
                                AppTypography.display(
                                  40,
                                  weight: FontWeight.w600,
                                ).copyWith(
                                  color: colors.textPrimary,
                                  height: 1.1,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (address != null)
                        Tooltip(
                          message: l10n.transferAddressTooltip,
                          child: SignalInset(
                            padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.mono.copyWith(
                                      fontSize: 13,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                SignalIconButton(
                                  icon: Icons.copy_rounded,
                                  tooltip: l10n.transferCopyLink,
                                  size: 32,
                                  iconSize: 15,
                                  onTap: () {
                                    final url = 'http://$address';
                                    unawaited(
                                      Clipboard.setData(
                                        ClipboardData(text: url),
                                      ),
                                    );
                                    _snack(
                                      context,
                                      '$url ${l10n.transferCopied}',
                                    );
                                  },
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
          if (conflict) ...[
            const SizedBox(height: 14),
            Text(
              l10n.transferPortBusy,
              style: AppTypography.body.copyWith(
                fontSize: 12.5,
                color: colors.warning,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _TargetBox(),
        ],
      ),
    );
  }
}

/// The mockup's « Appareil connecté » box: the device the files go to.
class _TargetBox extends ConsumerWidget {
  const _TargetBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, active) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.peers, s.activeTargetFingerprint),
      ),
    );
    final target = _target(peers, active);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              target == null ? Icons.wifi_find_rounded : _deviceIcon(target),
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.signalTransferTarget,
                  style: AppTypography.body.copyWith(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  target?.alias ?? l10n.transferNoDevices,
                  maxLines: target == null ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: target == null
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (target != null)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.inputBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    target.known
                        ? l10n.transferKnown
                        : l10n.signalTransferReachable,
                    style: AppTypography.body.copyWith(
                      fontSize: 12.5,
                      color: colors.textPrimary,
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

// ── Devices (in place of the mockup's « Envois récents ») ───────────────────

class _DevicesCard extends ConsumerWidget {
  const _DevicesCard();

  Future<void> _directIp(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _DirectIpDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, active, scanning, preview, onlyNew) = ref.watch(
      transferControllerProvider.select(
        (s) => (
          s.peers,
          s.activeTargetFingerprint,
          s.isScanningSubnet,
          s.sendPreview,
          s.onlyNewVideos,
        ),
      ),
    );
    final n = ref.read(transferControllerProvider.notifier);
    final target = _target(peers, active);
    return SignalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SignalEyebrow(l10n.transferDevices)),
              SignalIconButton(
                icon: Icons.sync_rounded,
                tooltip: l10n.transferMobileRefreshSearch,
                size: 32,
                onTap: () {
                  unawaited(n.triggerDiscoveryPulse());
                  _snack(context, l10n.transferMobileBroadcastDone);
                },
              ),
              SignalIconButton(
                icon: Icons.travel_explore_rounded,
                tooltip: l10n.transferScanSubnet,
                size: 32,
                onTap: scanning ? null : () => unawaited(n.scanSubnet()),
              ),
              SignalIconButton(
                icon: Icons.add_link_rounded,
                tooltip: l10n.transferDirectIpTitle,
                size: 32,
                onTap: () => _directIp(context),
              ),
              if (peers.isNotEmpty)
                SignalIconButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: l10n.transferMobileClearList,
                  size: 32,
                  onTap: n.clearPeers,
                ),
            ],
          ),
          if (scanning) ...[
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) => SignalMeter(
                value:
                    ref.watch(
                      transferControllerProvider.select(
                        (s) => s.subnetScanProgress,
                      ),
                    ) ??
                    0,
                color: colors.primary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (peers.isEmpty)
            _NoDevices(
              onScan: scanning ? null : () => unawaited(n.scanSubnet()),
              onDirectIp: () => _directIp(context),
            ),
          for (final peer in peers)
            _PeerRow(
              peer: peer,
              selected: peer.fingerprint == target?.fingerprint,
              sendLabel: onlyNew && preview.found > 0 && preview.newest > 0
                  ? l10n.transferSendNewOnly(preview.newest)
                  : l10n.transferSend,
              onSelect: () => n.setActiveTargetFingerprint(peer.fingerprint),
              onStar: () => unawaited(n.toggleTrusted(peer)),
              onSend: () => _sendTo(context, ref, peer),
            ),
        ],
      ),
    );
  }
}

/// No device yet: a quiet radar, what to do on the phone, and the two ways
/// to look for it.
class _NoDevices extends StatelessWidget {
  const _NoDevices({required this.onScan, required this.onDirectIp});

  final VoidCallback? onScan;
  final VoidCallback onDirectIp;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    Widget ring(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.textPrimary.withValues(alpha: alpha)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ring(72, 0.06),
                    ring(52, 0.1),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.14),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.smartphone_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.transferNoDevices,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.signalTransferNoDevicesHint,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SignalButton(
                label: l10n.transferScanSubnet,
                icon: Icons.travel_explore_rounded,
                accent: false,
                height: 36,
                fontSize: 13,
                onTap: onScan,
              ),
              SignalButton(
                label: l10n.transferDirectIpTitle,
                icon: Icons.add_link_rounded,
                accent: false,
                height: 36,
                fontSize: 13,
                onTap: onDirectIp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeerRow extends StatefulWidget {
  const _PeerRow({
    required this.peer,
    required this.selected,
    required this.sendLabel,
    required this.onSelect,
    required this.onStar,
    required this.onSend,
  });

  final TransferPeer peer;
  final bool selected;
  final String sendLabel;
  final VoidCallback onSelect;
  final VoidCallback onStar;
  final VoidCallback onSend;

  @override
  State<_PeerRow> createState() => _PeerRowState();
}

class _PeerRowState extends State<_PeerRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final peer = widget.peer;
    return Semantics(
      selected: widget.selected,
      child: InkWell(
        onTap: widget.onSelect,
        onHover: (h) => setState(() => _hover = h),
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: colors.primary.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: signalMotion(context, 160),
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            color: widget.selected || _hover
                ? colors.surfaceHighlight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _deviceIcon(peer),
                  size: 18,
                  color: widget.selected
                      ? colors.primary
                      : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.alias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        if (peer.known) l10n.transferKnown,
                        peer.deviceModel ?? peer.ip,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        color: colors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              SignalIconButton(
                icon: peer.known
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                tooltip: peer.known
                    ? l10n.transferMobileUnmarkKnown
                    : l10n.transferMobileMarkKnown,
                color: peer.known ? colors.warning : null,
                size: 36,
                onTap: widget.onStar,
              ),
              const SizedBox(width: 4),
              SignalButton(
                label: widget.sendLabel,
                accent: false,
                height: 36,
                fontSize: 12.5,
                icon: Icons.near_me_outlined,
                onTap: widget.onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectIpDialog extends ConsumerStatefulWidget {
  const _DirectIpDialog();

  @override
  ConsumerState<_DirectIpDialog> createState() => _DirectIpDialogState();
}

class _DirectIpDialogState extends ConsumerState<_DirectIpDialog> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '53317');
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ip = _ip.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    final peer = await ref
        .read(transferControllerProvider.notifier)
        .connectDirectIp(ip, port: int.tryParse(_port.text.trim()) ?? 53317);
    if (!mounted) return;
    if (peer != null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _connecting = false;
        _error = context.l10n.transferMobileDeviceNotFound;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.transferDirectIpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ip,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.transferDirectIpHint,
              labelText: l10n.transferMobileIpAddress,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transferMobilePortDefault,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _connecting ? null : _submit,
          child: Text(l10n.transferDirectIpAction),
        ),
      ],
    );
  }
}

// ── Files to send ───────────────────────────────────────────────────────────

class _FilesCard extends ConsumerStatefulWidget {
  const _FilesCard();

  @override
  ConsumerState<_FilesCard> createState() => _FilesCardState();
}

class _FilesCardState extends ConsumerState<_FilesCard> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _label(CreatorFolder f) =>
      f.isUnknown ? context.l10n.folderUnknownCreator : '@${f.handle}';

  Future<void> _pickFolders() async {
    if (ref.read(showcaseModeProvider)) return;
    final n = ref.read(transferControllerProvider.notifier);
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null || path.isEmpty || !mounted) return;
      final subfolders = await n.inspectSubfolders(path);
      if (!mounted) return;
      if (subfolders != null && subfolders.length > 1) {
        final picked = await showDialog<List<String>>(
          context: context,
          builder: (_) => _SubfolderDialog(parent: path, folders: subfolders),
        );
        if (picked != null && picked.isNotEmpty) n.addFolders(picked);
      } else {
        n.addFolders([path]);
      }
    } catch (e) {
      if (mounted) {
        _snack(context, context.l10n.transferMobileFolderPickError('$e'));
      }
    }
  }

  void _send(List<TransferPeer> peers, String? active) {
    final l10n = context.l10n;
    final target = _target(peers, active);
    if (target != null) {
      _sendTo(context, ref, target);
      return;
    }
    if (peers.isEmpty) {
      _snack(context, l10n.transferNoDevices);
      return;
    }
    _snack(context, l10n.signalTransferPickDevice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          keys: s.selectedCreatorKeys,
          folders: s.extraFolders,
          files: s.extraFiles,
          zip: s.compressZip,
          count: s.selectedFilesCount,
          bytes: s.selectedTotalBytes,
          preview: s.sendPreview,
          onlyNew: s.onlyNewVideos,
          peers: s.peers,
          active: s.activeTargetFingerprint,
        ),
      ),
    );
    final n = ref.read(transferControllerProvider.notifier);
    final creators = ref.watch(creatorFoldersProvider).folders;
    final q = _query.text.trim().toLowerCase();
    final shown = [
      for (final f in creators)
        if (q.isEmpty || _label(f).toLowerCase().contains(q)) f,
    ];
    final all = creators.isNotEmpty && s.keys.length >= creators.length;
    final counts = {for (final c in s.preview.folders) c.key: c};
    final hasPayload =
        s.keys.isNotEmpty || s.folders.isNotEmpty || s.files.isNotEmpty;
    return KeyedSubtree(
      key: OnboardingTargets.transfer,
      child: SignalCard(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.signalTransferFiles,
                    style: AppTypography.display(
                      22,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${s.keys.length} / ${creators.length}',
                    style: AppTypography.mono.copyWith(
                      fontSize: 13,
                      color: colors.textDisabled,
                    ),
                  ),
                  const Spacer(),
                  if (hasPayload)
                    _TextAction(
                      label: l10n.transferClearSelection,
                      onTap: n.clearAllPayload,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SignalChip(
                  label: l10n.transferEntireLibrary,
                  selected: all,
                  onTap: () => all
                      ? n.clearCreators()
                      : n.replaceCreators({for (final f in creators) f.key}),
                ),
                SignalChip(
                  label: l10n.transferMobileFoldersAction,
                  selected: false,
                  onTap: () => unawaited(_pickFolders()),
                ),
                SignalChip(
                  label: l10n.transferMobileVideosAction,
                  selected: false,
                  onTap: () => unawaited(n.addExtraFiles()),
                ),
                if (creators.length > 4)
                  SizedBox(
                    width: 200,
                    child: SignalInset(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: colors.textDisabled,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _query,
                              onChanged: (_) => setState(() {}),
                              style: AppTypography.body.copyWith(
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                              decoration: signalBareInput(
                                context,
                                l10n.transferSearchCreator,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        l10n.transferNoCreatorMatch,
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  for (final f in shown)
                    _FileRow(
                      checked: s.keys.contains(f.key),
                      thumb: f.previewUrls.firstWhere(
                        (u) => u != null,
                        orElse: () => null,
                      ),
                      title: _label(f),
                      subtitle: counts[f.key] == null
                          ? l10n.transferMobileVideoCount(f.count)
                          : '${l10n.transferMobileVideoCount(f.count)} · '
                                '${l10n.transferFolderBreakdown(counts[f.key]!.newest, counts[f.key]!.already)}',
                      onTap: () => n.toggleCreator(f.key),
                    ),
                  for (final path in s.folders)
                    _ExtraRow(
                      icon: Icons.folder_outlined,
                      title: p.basename(path),
                      subtitle: path,
                      onRemove: () => n.removeExtraFolder(path),
                    ),
                  for (final path in s.files)
                    _ExtraRow(
                      icon: Icons.movie_outlined,
                      title: p.basename(path),
                      subtitle: path,
                      onRemove: () => n.removeExtraFile(path),
                    ),
                ],
              ),
            ),
            if (hasPayload && s.preview.found > 0) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          l10n.transferVideosFound(s.preview.found),
                          l10n.transferAlreadyTransferred(s.preview.already),
                          l10n.transferNewVideos(s.preview.newest),
                        ].join(' · '),
                        style: AppTypography.body.copyWith(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    if (s.preview.already > 0 && s.active != null)
                      SignalIconButton(
                        icon: Icons.history_toggle_off_rounded,
                        tooltip: l10n.transferForgetDeviceHistory,
                        size: 32,
                        onTap: () async {
                          await n.forgetDeviceMemory(s.active!);
                          if (context.mounted) {
                            _snack(context, l10n.transferHistoryCleared);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: colors.textPrimary.withValues(alpha: 0.07),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 14,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SwitchLine(
                        label: l10n.transferMobileZipArchive,
                        value: s.zip,
                        onChanged: n.setCompressZip,
                      ),
                      const SizedBox(height: 8),
                      _SwitchLine(
                        label: l10n.transferOnlyNewToggle,
                        value: s.onlyNew,
                        onChanged: n.setOnlyNewVideos,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SignalEyebrow(l10n.signalTransferTotal),
                          Text(
                            '${l10n.transferMobileFileCount(s.count)} · '
                            '${localBytes(l10n, s.bytes)}',
                            style: AppTypography.mono.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      SignalButton(
                        label: l10n.transferSend,
                        icon: Icons.near_me_outlined,
                        onTap: hasPayload
                            ? () => _send(s.peers, s.active)
                            : null,
                      ),
                    ],
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

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignalSwitch(value: value, onChanged: onChanged, label: label),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.body.copyWith(
            fontSize: 13.5,
            color: AppColors.of(context).textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            fontSize: 12.5,
            color: colors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: colors.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.checked,
    required this.thumb,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool checked;
  final String? thumb;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      checked: widget.checked,
      label: widget.title,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: colors.primary.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: signalMotion(context, 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? colors.surfaceHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SignalCheck(value: widget.checked),
              const SizedBox(width: 16),
              SignalThumb(url: widget.thumb, width: 44, height: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        color: colors.textSecondary,
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

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Icon(Icons.check_rounded, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 16),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono.copyWith(
                    fontSize: 11.5,
                    color: colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          SignalIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.transferClearSelection,
            size: 32,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SubfolderDialog extends StatefulWidget {
  const _SubfolderDialog({required this.parent, required this.folders});

  final String parent;
  final List<String> folders;

  @override
  State<_SubfolderDialog> createState() => _SubfolderDialogState();
}

class _SubfolderDialogState extends State<_SubfolderDialog> {
  late final Set<String> _picked = widget.folders.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = _picked.length == widget.folders.length;
    return AlertDialog(
      title: Text(
        l10n.transferMobileSubfoldersFoundIn(p.basename(widget.parent)),
      ),
      content: SizedBox(
        width: 460,
        height: 360,
        child: Column(
          children: [
            CheckboxListTile(
              value: all,
              title: Text(all ? l10n.deselectAll : l10n.selectAll),
              onChanged: (_) => setState(() {
                if (all) {
                  _picked.clear();
                } else {
                  _picked.addAll(widget.folders);
                }
              }),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final f in widget.folders)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(f),
                      title: Text(p.basename(f)),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(f);
                        } else {
                          _picked.remove(f);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final f in widget.folders)
                    if (_picked.contains(f)) f,
                ]),
          child: Text(l10n.transferMobileFolderCount(_picked.length)),
        ),
      ],
    );
  }
}

// ── Live transfer ───────────────────────────────────────────────────────────

String _progressLabel(AppLocalizations l10n, TransferProgress progress) {
  return switch (progress.phase) {
    TransferPhase.preparing => l10n.transferPreparing,
    TransferPhase.compressing => l10n.transferCompressing,
    TransferPhase.waitingPeer => l10n.transferWaitingPeer,
    TransferPhase.done => l10n.transferDone,
    TransferPhase.failed => switch (progress.error) {
      'empty' => l10n.transferNeedPayload,
      'busy' => l10n.transferErrorBusy,
      'rejected' => l10n.transferErrorRejected,
      'httpError' || 'timeout' || 'connectionRefused' => l10n.transferErrorHttp,
      _ => progress.error ?? l10n.transferErrorHttp,
    },
    TransferPhase.transferring =>
      progress.currentName.isEmpty
          ? l10n.transferSending
          : progress.currentName,
    TransferPhase.idle => l10n.transferSending,
  };
}

String _diagnosticText(AppLocalizations l10n, TransferDiagnostic d) {
  return switch (d.code) {
    TransferDiagnosticCode.unreachable => l10n.transferMobileDiagUnreachable,
    TransferDiagnosticCode.timeout => l10n.transferMobileDiagTimeout,
    TransferDiagnosticCode.connectionRefused =>
      l10n.transferMobileDiagConnectionRefused,
    TransferDiagnosticCode.pinRequired => l10n.transferMobileDiagPinRequired,
    TransferDiagnosticCode.rejected => l10n.transferMobileDiagRejected,
    TransferDiagnosticCode.busy => l10n.transferMobileDiagBusy,
    TransferDiagnosticCode.checksumMismatch =>
      l10n.transferMobileDiagChecksumMismatch,
    TransferDiagnosticCode.communication =>
      (d.detail?.isNotEmpty ?? false)
          ? d.detail!
          : l10n.transferMobileDiagCommunication,
  };
}

/// Shown while something is sent (or just failed). Watches the ticking
/// progress here only, so the rest of the page does not rebuild.
class _LiveCard extends ConsumerWidget {
  const _LiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          progress: s.progress,
          diagnostic: s.diagnostic,
          scan: s.scanStatus,
          error: s.lastError,
          peer:
              _target(s.peers, s.activeTargetFingerprint) ?? s.lastPeerAttempt,
        ),
      ),
    );
    final progress = s.progress;
    if (progress == null && s.diagnostic == null) {
      return const SizedBox.shrink();
    }
    final n = ref.read(transferControllerProvider.notifier);
    final failed =
        progress?.phase == TransferPhase.failed || s.diagnostic != null;
    final done = progress?.phase == TransferPhase.done;
    final running = !failed && !done;
    final fraction = progress?.fraction ?? 0;
    final speed = progress == null || progress.bytesPerSecond <= 0
        ? ''
        : '${localBytes(l10n, progress.bytesPerSecond.round())}/s';
    final scan = s.scan;
    final title = progress == null
        ? l10n.transferErrorHttp
        : _progressLabel(l10n, progress);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SignalCard(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: failed
                        ? colors.error
                        : (done ? colors.success : colors.primary),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.signalTransferInProgress,
                    style: AppTypography.display(
                      22,
                      weight: FontWeight.w600,
                    ).copyWith(color: colors.textPrimary),
                  ),
                ),
                if (failed)
                  SignalButton(
                    label: l10n.transferRetry,
                    icon: Icons.refresh_rounded,
                    accent: false,
                    height: 36,
                    fontSize: 12.5,
                    onTap: n.retryLastTransfer,
                  ),
                SignalIconButton(
                  icon: Icons.close_rounded,
                  tooltip: l10n.transferCancel,
                  onTap: n.cancelTransfer,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 120,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Icon(Icons.movie_outlined, color: colors.textDisabled),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: failed ? colors.error : colors.textPrimary,
                        ),
                      ),
                      if (s.peer != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.signalTransferTo(s.peer!.alias),
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (progress != null && !failed)
                  SignalFigure(
                    value: '${(fraction * 100).round()}',
                    unit: '%',
                    size: 48,
                    gap: 0,
                  ),
              ],
            ),
            if (s.diagnostic != null) ...[
              const SizedBox(height: 12),
              Text(
                _diagnosticText(l10n, s.diagnostic!),
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.error,
                ),
              ),
            ] else if (failed && s.error != null) ...[
              const SizedBox(height: 12),
              Text(
                s.error!,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SignalMeter(
              value: fraction,
              color: failed ? colors.error : colors.primary,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    scan != null && running
                        ? (scan.totalFolders > 0
                              ? l10n.transferMobileScanFolders(
                                  scan.scannedFolders,
                                  scan.totalFolders,
                                  scan.videos,
                                )
                              : l10n.transferMobileScanVideosFound(scan.videos))
                        : progress == null
                        ? l10n.signalTransferWifi
                        : '${localBytes(l10n, progress.bytesDone)} / '
                              '${localBytes(l10n, progress.bytesTotal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono.copyWith(
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  speed,
                  style: AppTypography.mono.copyWith(
                    fontSize: 12.5,
                    color: colors.textSecondary,
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
