import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'porcelaine_tiles.dart' show PLiveDot, pSpeedParts;
import 'porcelaine_widgets.dart';

/// True while the Transfert page shows today's full view (receive tab,
/// network scan, IP connection, extra folders, send history…).
final porcelaineTransferAllToolsProvider = StateProvider<bool>((ref) => false);

/// Porcelaine's transfer (Porcelaine-Transfert.dc.html): connection, device,
/// live transfer on the left; what to send and nearby devices on the right.
/// « Tous les outils » shows [current], today's complete view.
class PorcelaineTransfer extends ConsumerWidget {
  const PorcelaineTransfer({super.key, required this.current});

  final Widget current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = ref.watch(porcelaineTransferAllToolsProvider);
    final header = PPageTitle(
      title: l10n.porcelaineTransferTitle,
      subtitle: l10n.porcelaineTransferSubtitle,
    );
    if (!all) return _Simple(header: header);
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 1284 ? (box.maxWidth - 1220) / 2 : 32.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              Center(
                child: PBtn(
                  label: l10n.porcelaineSimpleView,
                  icon: Icons.arrow_back_rounded,
                  height: 36,
                  onTap: () =>
                      ref
                              .read(porcelaineTransferAllToolsProvider.notifier)
                              .state =
                          false,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pCardFill(colors),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: pCardShadow(colors),
                  ),
                  child: current,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Simple extends ConsumerStatefulWidget {
  const _Simple({required this.header});

  final Widget header;

  @override
  ConsumerState<_Simple> createState() => _SimpleState();
}

class _SimpleState extends ConsumerState<_Simple> {
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
    // Today's view answers these with dialogs; this page does the same while
    // it replaces it.
    ref.listen(transferControllerProvider.select((s) => s.incoming), (
      previous,
      next,
    ) {
      if (next != null && previous == null) unawaited(_incoming(next));
    });
    ref.listen(transferControllerProvider.select((s) => s.peerPinPrompt), (
      previous,
      next,
    ) {
      if (next != null && previous == null) unawaited(_peerPin(next));
    });
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        const left = [_ConnectionCard(), _DeviceCard(), _ProgressCard()];
        const right = [_FilesCard(), _PeersCard()];
        Widget stack(List<Widget> cards) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in cards.indexed) ...[
              if (i > 0) const SizedBox(height: 20),
              c,
            ],
          ],
        );
        return PPage(
          children: [
            widget.header,
            const SizedBox(height: 30),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: stack(left)),
                  const SizedBox(width: 20),
                  Expanded(flex: 7, child: stack(right)),
                ],
              )
            else
              stack([...left, ...right]),
          ],
        );
      },
    );
  }

  Future<void> _incoming(IncomingOffer offer) async {
    final l10n = context.l10n;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _Dialog(
        title: l10n.transferIncomingTitle,
        body: Text(
          l10n.transferIncomingBody(
            offer.peerAlias,
            offer.files.length,
            localBytes(l10n, offer.totalBytes),
          ),
        ),
        cancel: l10n.transferReject,
        ok: l10n.transferAccept,
        onOk: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (!mounted) return;
    ref
        .read(transferControllerProvider.notifier)
        .answerIncoming(accept ?? false);
  }

  Future<void> _peerPin(TransferPeer peer) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        return _Dialog(
          title: l10n.transferMobilePeerPinRequired(peer.alias),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.transferMobilePeerPinExplain,
                style: pBody(colors, size: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 10,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: pDisp(26, color: colors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.transferMobilePinExample,
                  filled: true,
                  fillColor: colors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
            ],
          ),
          cancel: l10n.cancel,
          ok: l10n.transferSend,
          onOk: () => Navigator.pop(context, controller.text.trim()),
          onCancel: () => Navigator.pop(context),
        );
      },
    );
    controller.dispose();
    if (!mounted) return;
    final notifier = ref.read(transferControllerProvider.notifier);
    notifier.dismissPeerPin();
    if (pin == null || pin.isEmpty) return;
    unawaited(notifier.sendTo(peer, pin: pin));
  }
}

class _Dialog extends StatelessWidget {
  const _Dialog({
    required this.title,
    required this.body,
    required this.cancel,
    required this.ok,
    required this.onOk,
    required this.onCancel,
  });

  final String title;
  final Widget body;
  final String cancel;
  final String ok;
  final VoidCallback onOk;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: pDisp(22, color: colors.textPrimary)),
              const SizedBox(height: 12),
              DefaultTextStyle(style: pBody(colors), child: body),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PBtn(label: cancel, kind: PBtnKind.ghost, onTap: onCancel),
                  const SizedBox(width: 8),
                  PBtn(label: ok, kind: PBtnKind.accent, onTap: onOk),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Connexion ──────────────────────────────────────────────────────────────

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (qr, pin, ip, port, busy) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.qrUrl, s.pin, s.lanIp, s.port, s.portConflict),
      ),
    );
    final address = ip == null || port == null ? null : '$ip:$port';
    final groupedPin = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : pin;
    Widget tile(String label, Widget value) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: pBody(colors, size: 12, color: colors.textDisabled),
          ),
          value,
        ],
      ),
    );
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.wifi_rounded,
            label: l10n.porcelaineConnection,
            tint: colors.primary,
            bottom: 16,
          ),
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 171,
                    height: 171,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: colors.textPrimary.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: -8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: qr == null
                        ? Center(
                            child: Text(
                              l10n.transferWaitingNetwork,
                              textAlign: TextAlign.center,
                              style: pBody(
                                colors,
                                size: 12,
                                color: colors.textDisabled,
                              ),
                            ),
                          )
                        : Semantics(
                            label: l10n.porcelaineQrCode,
                            child: QrImageView(
                              data: qr,
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: colors.textPrimary,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.porcelaineQrCode,
                    style: pMono(
                      colors,
                      size: 11.5,
                      color: colors.textDisabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.porcelaineScanTitle,
                      style: pDisp(
                        22,
                        color: colors.textPrimary,
                      ).copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.porcelaineScanHint,
                      style: pBody(
                        colors,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.transferPortBusy,
                        style: pBody(colors, size: 12.5, color: colors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: tile(
                  l10n.porcelainePinCode,
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      groupedPin.isEmpty ? '—' : groupedPin,
                      style: pDisp(
                        30,
                        color: colors.textPrimary,
                      ).copyWith(height: 1.1, letterSpacing: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: tile(
                  l10n.porcelaineAddress,
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            address ?? l10n.transferWaitingNetwork,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pMono(
                              colors,
                              size: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Appareil connecté ──────────────────────────────────────────────────────

/// The device files go to: the chosen one, else the first found.
TransferPeer? _target(TransferUiState s) {
  for (final p in s.peers) {
    if (p.fingerprint == s.activeTargetFingerprint) return p;
  }
  return s.peers.isEmpty ? null : s.peers.first;
}

IconData _deviceIcon(TransferPeer p) => switch (p.deviceType) {
  TransferDeviceType.mobile => Icons.smartphone_rounded,
  TransferDeviceType.desktop => Icons.computer_rounded,
  _ => Icons.devices_other_rounded,
};

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final peer = ref.watch(transferControllerProvider.select(_target));
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.smartphone_rounded,
            label: l10n.porcelaineConnectedDevice,
            tint: pGreen,
            bottom: 16,
          ),
          if (peer == null)
            Text(
              l10n.transferNoDevices,
              style: pBody(colors, color: colors.textSecondary),
            )
          else
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDD2C2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _deviceIcon(peer),
                    size: 18,
                    color: colors.textPrimary,
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
                        style: pBody(colors, size: 15, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: pGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.porcelaineConnected,
                            style: pBody(colors, size: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Transfert en cours ─────────────────────────────────────────────────────

String _phaseLabel(AppLocalizations l10n, TransferProgress p) =>
    switch (p.phase) {
      TransferPhase.preparing => l10n.transferPreparing,
      TransferPhase.compressing => l10n.transferCompressing,
      TransferPhase.waitingPeer => l10n.transferWaitingPeer,
      TransferPhase.done => l10n.transferDone,
      TransferPhase.failed => l10n.transferErrorHttp,
      _ => l10n.transferSending,
    };

/// Same wording as today's transfer banner.
String _diagnosticText(AppLocalizations l10n, TransferDiagnostic d) =>
    switch (d.code) {
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
        (d.detail != null && d.detail!.isNotEmpty)
            ? d.detail!
            : l10n.transferMobileDiagCommunication,
    };

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (progress, lastError, diagnostic, peer) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.progress, s.lastError, s.diagnostic, _target(s)),
      ),
    );
    if (progress == null && diagnostic == null) {
      return const SizedBox.shrink();
    }
    final error = diagnostic != null
        ? _diagnosticText(l10n, diagnostic)
        : (lastError ?? l10n.transferErrorHttp);
    final notifier = ref.read(transferControllerProvider.notifier);
    final p = progress;
    final failed = p == null || p.phase == TransferPhase.failed;
    final done = p?.phase == TransferPhase.done;
    final fraction = p == null || p.bytesTotal <= 0
        ? 0.0
        : (p.bytesDone / p.bytesTotal).clamp(0.0, 1.0);
    final running = p != null && !failed && !done;
    final speed = p == null ? 0.0 : p.bytesPerSecond;
    final (n, u) = pSpeedParts(l10n, speed);
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.upload_rounded,
            label: l10n.porcelaineTransferInProgress,
            tint: colors.primary,
            bottom: 16,
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: PLiveDot(live: running),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.currentName.isNotEmpty == true
                          ? p!.currentName
                          : (p == null
                                ? l10n.transferErrorHttp
                                : _phaseLabel(l10n, p)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pBody(colors, weight: FontWeight.w500),
                    ),
                    if (peer != null)
                      Text(
                        l10n.porcelaineToDevice(peer.alias),
                        style: pBody(
                          colors,
                          size: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text.rich(
                TextSpan(
                  text: '${(fraction * 100).round()}',
                  style: pDisp(
                    44,
                    color: colors.textPrimary,
                  ).copyWith(height: 0.85),
                  children: [
                    TextSpan(
                      text: '%',
                      style: pDisp(20, color: colors.textDisabled),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PBar(value: fraction, color: failed ? colors.error : null),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  failed
                      ? error
                      : (running
                            ? '$n $u · ${localBytes(l10n, p.bytesDone)} / ${localBytes(l10n, p.bytesTotal)}'
                            : _phaseLabel(l10n, p)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pMono(
                    colors,
                    color: failed ? colors.error : colors.textSecondary,
                  ),
                ),
              ),
              if (running)
                PBtn(
                  label: l10n.transferCancel,
                  kind: PBtnKind.ghost,
                  height: 32,
                  fontSize: 13,
                  onTap: notifier.cancelTransfer,
                )
              else if (failed)
                PBtn(
                  label: l10n.transferRetry,
                  height: 32,
                  fontSize: 13,
                  onTap: notifier.retryLastTransfer,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fichiers à envoyer ─────────────────────────────────────────────────────

class _FilesCard extends ConsumerWidget {
  const _FilesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final folders = ref.watch(creatorFoldersProvider).folders;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final byId = {for (final i in items) i.id: i};
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          selected: s.selectedCreatorKeys,
          zip: s.compressZip,
          onlyNew: s.onlyNewVideos,
          bytes: s.selectedTotalBytes,
          files: s.selectedFilesCount,
          extras: s.extraFiles.length + s.extraFolders.length,
          target: _target(s),
          busy:
              s.progress != null &&
              s.progress!.phase != TransferPhase.done &&
              s.progress!.phase != TransferPhase.failed,
        ),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final picked = folders.where((f) => s.selected.contains(f.key)).length;
    final target = s.target;
    final canSend =
        target != null && (s.files > 0 || s.selected.isNotEmpty) && !s.busy;
    void send() {
      if (ref.read(showcaseModeProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transferMobileDemoSendSimulated)),
        );
        return;
      }
      unawaited(notifier.sendTo(target!));
    }

    return KeyedSubtree(
      key: OnboardingTargets.transfer,
      child: PCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PHead(
              icon: Icons.check_box_outlined,
              label: l10n.porcelaineFilesToSend,
              bottom: 12,
              trailing: Expanded(
                child: Text(
                  '$picked / ${folders.length}',
                  textAlign: TextAlign.end,
                  style: pMono(colors, size: 13),
                ),
              ),
            ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.designLibraryEmpty,
                  style: pBody(colors, color: colors.textSecondary),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 290),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final f in folders)
                    _FileRow(
                      name: f.isUnknown ? l10n.unknown : f.handle!,
                      meta: l10n.porcelaineVideoCount(f.count),
                      size: localBytes(
                        l10n,
                        f.itemIds.fold<int>(
                          0,
                          (a, id) =>
                              a + (byId[id] == null ? 0 : bytesOf(byId[id]!)),
                        ),
                      ),
                      thumb: f.previewUrls.firstWhere(
                        (u) => u != null,
                        orElse: () => null,
                      ),
                      seed: f.key,
                      selected: s.selected.contains(f.key),
                      onTap: () => notifier.toggleCreator(f.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                PBtn(
                  label: l10n.transferMobileVideosAction,
                  icon: Icons.add_rounded,
                  kind: PBtnKind.ghost,
                  height: 32,
                  fontSize: 13,
                  onTap: notifier.addExtraFiles,
                ),
                PBtn(
                  label: l10n.transferMobileFoldersAction,
                  icon: Icons.create_new_folder_outlined,
                  kind: PBtnKind.ghost,
                  height: 32,
                  fontSize: 13,
                  onTap: notifier.addExtraFolder,
                ),
                if (s.extras > 0 || s.selected.isNotEmpty)
                  PBtn(
                    label: l10n.transferClearSelection,
                    kind: PBtnKind.ghost,
                    height: 32,
                    fontSize: 13,
                    onTap: notifier.clearAllPayload,
                  ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 14),
              color: colors.textPrimary.withValues(alpha: 0.07),
            ),
            _Toggle(
              label: l10n.porcelaineCompressZip,
              value: s.zip,
              onChanged: notifier.setCompressZip,
            ),
            const SizedBox(height: 10),
            _Toggle(
              label: l10n.transferOnlyNewToggle,
              value: s.onlyNew,
              onChanged: notifier.setOnlyNewVideos,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.porcelaineSelectedTotal,
                        style: pBody(
                          colors,
                          size: 12,
                          color: colors.textDisabled,
                        ),
                      ),
                      Text(
                        localBytes(l10n, s.bytes),
                        style: pDisp(
                          28,
                          color: colors.textPrimary,
                        ).copyWith(height: 1.1),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: target == null
                      ? l10n.transferNoDevices
                      : (canSend ? target.alias : l10n.transferNeedPayload),
                  child: PBtn(
                    label: l10n.transferSend,
                    icon: Icons.arrow_forward_rounded,
                    kind: PBtnKind.accent,
                    height: 44,
                    padding: 22,
                    onTap: canSend ? send : null,
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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(child: Text(label, style: pBody(colors, size: 13.5))),
          PSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.name,
    required this.meta,
    required this.size,
    required this.thumb,
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String meta;
  final String size;
  final String? thumb;
  final String seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final on = widget.selected;
    return Semantics(
      checked: on,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: on
                ? Color.alphaBlend(
                    colors.primary.withValues(alpha: 0.07),
                    colors.surface,
                  )
                : (_hover
                      ? colors.textPrimary.withValues(alpha: 0.04)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: pMotion(context, 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: on ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: on
                            ? null
                            : Border.all(
                                width: 1.5,
                                color: colors.textPrimary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                      ),
                      child: on
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: colors.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    PThumb(
                      url: widget.thumb,
                      seed: widget.seed,
                      width: 56,
                      height: 36,
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
                            style: pBody(colors, weight: FontWeight.w500),
                          ),
                          Text(
                            widget.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pBody(
                              colors,
                              size: 12,
                              color: colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(widget.size, style: pMono(colors, size: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Appareils à proximité (no send history exists for « Envois récents ») ──

class _PeersCard extends ConsumerWidget {
  const _PeersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, target) = ref.watch(
      transferControllerProvider.select((s) => (s.peers, _target(s))),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PHead(
            icon: Icons.devices_rounded,
            label: l10n.porcelaineNearbyDevices,
            tint: pSlate,
            bottom: 8,
          ),
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l10n.transferNoDevices,
                style: pBody(colors, color: colors.textSecondary),
              ),
            ),
          for (final (i, p) in peers.indexed)
            Container(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: colors.textPrimary.withValues(alpha: 0.07),
                        ),
                      ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => notifier.setActiveTargetFingerprint(p.fingerprint),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFCFD1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _deviceIcon(p),
                          size: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.alias,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: pBody(
                                colors,
                                size: 13.5,
                                weight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              [
                                if (p.deviceModel != null) p.deviceModel!,
                                p.ip,
                                if (p.known) l10n.transferKnown,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: pBody(
                                colors,
                                size: 12,
                                color: colors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.fingerprint == target?.fingerprint) ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: pGreen,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.porcelaineRecipient,
                          style: pBody(
                            colors,
                            size: 12.5,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PBtn(
                label: l10n.porcelaineSearchDevices,
                icon: Icons.radar_rounded,
                height: 34,
                fontSize: 13,
                onTap: () => unawaited(notifier.triggerDiscoveryPulse()),
              ),
              PBtn(
                label: l10n.porcelaineAllTransferTools,
                icon: Icons.tune_rounded,
                kind: PBtnKind.ghost,
                height: 34,
                fontSize: 13,
                onTap: () =>
                    ref
                            .read(porcelaineTransferAllToolsProvider.notifier)
                            .state =
                        true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
