import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'studio_widgets.dart';

/// Studio's transfer (mockup Studio-Transfert.dc.html): pairing (QR, PIN,
/// address), the device to send to, the files to send, the live transfer.
/// Today's view stays mounted (hidden) for its lifecycle and dialogs, and is
/// shown whole under « Toutes les options » for everything else (receive,
/// folder/video pickers, search, subnet scan, direct IP, trusted devices).
class StudioTransfer extends StatefulWidget {
  const StudioTransfer({super.key, required this.current});

  final Widget current;

  @override
  State<StudioTransfer> createState() => _StudioTransferState();
}

class _StudioTransferState extends State<StudioTransfer> {
  final _currentKey = GlobalKey();
  bool _full = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = AppColors.of(context);
    return Stack(
      children: [
        if (!_full)
          Positioned.fill(
            child: _Simple(onAllOptions: () => setState(() => _full = true)),
          ),
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_full)
                Container(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
                  color: c.background,
                  alignment: AlignmentDirectional.centerStart,
                  child: StudioButton(
                    label: l10n.studioSimpleView,
                    icon: Icons.arrow_back_rounded,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: () => setState(() => _full = false),
                  ),
                ),
              Expanded(
                child: KeyedSubtree(
                  key: _currentKey,
                  child: TickerMode(
                    enabled: _full,
                    child: ExcludeFocus(
                      excluding: !_full,
                      child: Offstage(offstage: !_full, child: widget.current),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Simple extends ConsumerWidget {
  const _Simple({required this.onAllOptions});

  final VoidCallback onAllOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final issue = ref.watch(
      transferControllerProvider.select(
        (s) => s.portConflict || s.lastError != null || s.diagnostic != null,
      ),
    );
    return ColoredBox(
      color: c.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth < 640 ? 16.0 : 40.0;
          final two = constraints.maxWidth >= 900;
          const left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_Pairing(), SizedBox(height: 16), _Devices()],
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(side, 30, side, 40),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.transferTitle, style: studioTitle(c)),
                              const SizedBox(height: 6),
                              Text(
                                l10n.studioTransferSubtitle,
                                style: studioText(c, color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        StudioButton(
                          label: l10n.studioAllOptions,
                          icon: Icons.tune_rounded,
                          kind: StudioButtonKind.light,
                          onTap: onAllOptions,
                        ),
                      ],
                    ),
                    if (issue) ...[
                      const SizedBox(height: 14),
                      _Issue(onOpen: onAllOptions),
                    ],
                    const SizedBox(height: 20),
                    if (two)
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          SizedBox(width: 16),
                          Expanded(child: _Files()),
                        ],
                      )
                    else ...[
                      left,
                      const SizedBox(height: 16),
                      const _Files(),
                    ],
                    const _Progress(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Issue extends StatelessWidget {
  const _Issue({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final red = studioText(c, size: 12, color: c.error);
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 14, color: c.error),
        const SizedBox(width: 8),
        Flexible(child: Text('${l10n.studioTransferIssue} ', style: red)),
        InkWell(
          onTap: onOpen,
          child: Text(
            l10n.studioAllOptions,
            style: red.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: c.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pairing extends ConsumerWidget {
  const _Pairing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (qr, pin, ip, port) = ref.watch(
      transferControllerProvider.select((s) => (s.qrUrl, s.pin, s.lanIp, s.port)),
    );
    final pinLabel = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : (pin.isEmpty ? '—' : pin);
    return StudioPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 132,
                height: 132,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: qr == null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          l10n.transferWaitingNetwork,
                          textAlign: TextAlign.center,
                          style: studioText(c, size: 12, color: c.textDisabled),
                        ),
                      )
                    : QrImageView(
                        data: qr,
                        size: 130,
                        padding: const EdgeInsets.all(8),
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: c.primary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: c.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              StudioCap(l10n.studioQrCode),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.studioScanTitle,
                  style: studioTitle(
                    c,
                    17,
                  ).copyWith(letterSpacing: -0.34, height: 1.3),
                ),
                const SizedBox(height: 14),
                StudioCap(l10n.studioPin),
                const SizedBox(height: 4),
                SelectableText(
                  pinLabel,
                  style: studioMono(
                    c,
                    size: 26,
                    color: c.textPrimary,
                  ).copyWith(letterSpacing: 1.56),
                ),
                const SizedBox(height: 14),
                StudioCap(l10n.studioAddress),
                const SizedBox(height: 4),
                SelectableText(
                  ip == null || port == null ? '—' : '$ip:$port',
                  style: studioMono(c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The devices on the network; the chosen one is where « Envoyer » sends.
class _Devices extends ConsumerWidget {
  const _Devices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, target) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.peers, s.activeTargetFingerprint),
      ),
    );
    final controller = ref.read(transferControllerProvider.notifier);
    if (peers.isEmpty) {
      return StudioPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Text(
          l10n.transferNoDevices,
          style: studioText(c, color: c.textSecondary),
        ),
      );
    }
    return StudioPanel(
      child: Column(
        children: [
          for (var i = 0; i < peers.length; i++)
            _DeviceRow(
              peer: peers[i],
              first: i == 0,
              chosen: _targetOf(peers, target)?.fingerprint ==
                  peers[i].fingerprint,
              onChoose: () =>
                  controller.setActiveTargetFingerprint(peers[i].fingerprint),
            ),
        ],
      ),
    );
  }
}

/// The chosen device, or the only one there is.
TransferPeer? _targetOf(List<TransferPeer> peers, String? fingerprint) {
  for (final p in peers) {
    if (p.fingerprint == fingerprint) return p;
  }
  return peers.length == 1 ? peers.first : null;
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.peer,
    required this.first,
    required this.chosen,
    required this.onChoose,
  });

  final TransferPeer peer;
  final bool first;
  final bool chosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final icon = switch (peer.deviceType) {
      TransferDeviceType.mobile => Icons.smartphone_outlined,
      TransferDeviceType.web => Icons.language_rounded,
      _ => Icons.computer_outlined,
    };
    return InkWell(
      onTap: chosen ? null : onChoose,
      hoverColor: studioHover(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: c.borderSubtle)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: studioText(c).copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    peer.deviceModel ?? peer.ip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: studioText(c, size: 12, color: c.textDisabled),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            if (chosen)
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.studioTarget, style: studioText(c, size: 12)),
                ],
              )
            else
              Text(
                l10n.studioChoose,
                style: studioText(c, size: 12, color: c.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// The creators to send (today's « Quoi envoyer » list), the selection total,
/// ZIP and « Envoyer ».
class _Files extends ConsumerWidget {
  const _Files();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final folders = ref.watch(creatorFoldersProvider).folders;
    final items =
        ref.watch(downloadListProvider).valueOrNull ?? const <DownloadItem>[];
    final bytesById = {for (final i in items) i.id: bytesOf(i)};
    final state = ref.watch(
      transferControllerProvider.select(
        (s) => (
          s.selectedCreatorKeys,
          s.selectedFilesCount,
          s.selectedTotalBytes,
          s.compressZip,
          s.peers,
          s.activeTargetFingerprint,
          s.progress != null,
        ),
      ),
    );
    final (selected, count, bytes, zip, peers, target, busy) = state;
    final controller = ref.read(transferControllerProvider.notifier);
    final all = folders.isNotEmpty && selected.length >= folders.length;
    final peer = _targetOf(peers, target);
    final hasPayload = count > 0 || selected.isNotEmpty;

    Widget row({
      required String label,
      required String size,
      required bool on,
      required VoidCallback onTap,
      bool first = false,
    }) => _FileRow(
      label: label,
      size: size,
      on: on,
      onTap: onTap,
      first: first,
    );

    int folderBytes(CreatorFolder f) =>
        f.itemIds.fold(0, (sum, id) => sum + (bytesById[id] ?? 0));

    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(child: StudioCap(l10n.studioFilesToSend)),
                StudioCap(l10n.detailsInfoSize),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  row(
                    label: l10n.transferEntireLibrary,
                    size: localBytes(
                      l10n,
                      bytesById.values.fold(0, (a, b) => a + b),
                    ),
                    on: all,
                    first: true,
                    onTap: () => all
                        ? controller.clearCreators()
                        : controller.replaceCreators({
                            for (final f in folders) f.key,
                          }),
                  ),
                  for (final f in folders)
                    row(
                      label: f.isUnknown
                          ? l10n.folderUnknownCreator
                          : '@${f.handle}',
                      size: localBytes(l10n, folderBytes(f)),
                      on: selected.contains(f.key),
                      onTap: () => controller.toggleCreator(f.key),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: studioHover(c),
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StudioCap(l10n.studioSelection),
                      const SizedBox(height: 3),
                      Text(
                        '${l10n.transferMobileFileCount(count)} · '
                        '${localBytes(l10n, bytes)}',
                        style: studioMono(
                          c,
                          color: c.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StudioSwitch(
                      value: zip,
                      label: l10n.studioZip,
                      onChanged: (_) => controller.toggleCompressZip(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.studioZip,
                      style: studioText(c, color: c.textSecondary),
                    ),
                  ],
                ),
                StudioButton(
                  label: l10n.transferSend,
                  onTap: peer != null && hasPayload && !busy
                      ? () => controller.sendTo(peer)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.label,
    required this.size,
    required this.on,
    required this.onTap,
    required this.first,
  });

  final String label;
  final String size;
  final bool on;
  final VoidCallback onTap;
  final bool first;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      checked: widget.on,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        hoverColor: studioHover(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.borderSubtle)),
          ),
          child: Row(
            children: [
              StudioCheckbox(value: widget.on),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StudioUnderline(
                    text: widget.label,
                    hover: _hover,
                    style: studioText(c).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 70,
                child: Text(
                  widget.size,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: studioMono(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The transfer under way: name, ink line, percent and speed, cancel; on a
/// failure, the reason and « Réessayer ».
class _Progress extends ConsumerWidget {
  const _Progress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final progress = ref.watch(
      transferControllerProvider.select((s) => s.progress),
    );
    if (progress == null) return const SizedBox.shrink();
    final controller = ref.read(transferControllerProvider.notifier);
    final failed = progress.phase == TransferPhase.failed;
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final rate = formatSpeed(l10n, progress.bytesPerSecond);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: StudioPanel(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioCap(l10n.designInProgress),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.currentName.isEmpty
                            ? l10n.transferSending
                            : progress.currentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: studioText(
                          c,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      StudioLine(value: progress.fraction),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (failed) ...[
                  Text(
                    progress.error ?? l10n.studioTransferIssue,
                    style: studioText(c, size: 12, color: c.error),
                  ),
                  const SizedBox(width: 12),
                  StudioButton(
                    label: l10n.transferRetry,
                    kind: StudioButtonKind.light,
                    height: 32,
                    onTap: controller.retryLastTransfer,
                  ),
                ] else ...[
                  const StudioRecDot(),
                  const SizedBox(width: 6),
                  Text(
                    progress.bytesPerSecond > 0
                        ? '$percent % · ${rate.value} ${rate.unit}'
                        : '$percent %',
                    style: studioMono(c, size: 12),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.transferCancel,
                  onPressed: controller.cancelTransfer,
                  iconSize: 16,
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
