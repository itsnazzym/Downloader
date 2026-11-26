import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'nocturne_widgets.dart';

/// Nocturne's transfer (mockup Nocturne-Transfert.dc.html): QR, PIN and
/// address, the target device, the transfer in progress as a ring, what to
/// send and the devices.
///
/// Today's view ([current]) stays mounted behind it: it starts the transfer
/// service and asks about incoming transfers and device PINs. « Toutes les
/// options » brings it to the front for the rest (receive tab, direct IP,
/// trusted devices, send memory, subfolder picking, diagnostics).
class NocturneTransfer extends StatefulWidget {
  const NocturneTransfer({super.key, required this.current});

  final Widget current;

  @override
  State<NocturneTransfer> createState() => _NocturneTransferState();
}

class _NocturneTransferState extends State<NocturneTransfer> {
  bool _detailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final toggle = NocturneButton(
      label: _detailed ? l10n.nocturneSimpleView : l10n.nocturneAllOptions,
      icon: _detailed ? Icons.dashboard_outlined : Icons.tune_rounded,
      kind: NocturneButtonKind.ghost,
      onTap: () => setState(() => _detailed = !_detailed),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 34, wide ? 40 : 20, 0),
          child: NocturneHeader(
            eyebrow: l10n.nocturneTransferEyebrow,
            title: l10n.nocturneTransferTitle,
            trailing: toggle,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _detailed ? 1 : 0,
            sizing: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 40 : 20,
                  22,
                  wide ? 40 : 20,
                  40,
                ),
                child: _Board(wide: wide),
              ),
              // Mounted for its listeners; no animation while hidden.
              TickerMode(enabled: _detailed, child: widget.current),
            ],
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 14, height: 14);
    if (!wide) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QrCard(),
          gap,
          _TargetCard(),
          gap,
          _ProgressCard(),
          gap,
          _PayloadCard(),
          gap,
          _DevicesCard(),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 615, child: _QrCard()),
              gap,
              Expanded(
                flex: 495,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TargetCard(),
                    gap,
                    Expanded(child: _ProgressCard()),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap,
        // No IntrinsicHeight here: the payload list scrolls.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 830, child: _PayloadCard()),
            gap,
            Expanded(flex: 280, child: _DevicesCard()),
          ],
        ),
      ],
    );
  }
}

class _QrCard extends ConsumerWidget {
  const _QrCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (qr, pin, ip, port) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.qrUrl, s.pin, s.lanIp, s.port),
      ),
    );
    final pinLabel = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : pin;
    Widget fact(String label, String value, double size) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: nocturneText(c, size: 12.5, color: c.textDisabled)),
        const SizedBox(height: 6),
        Text(
          value,
          style: nocturneMono(
            c,
            size: size,
            color: size > 20 ? c.textPrimary : c.textSecondary,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 154,
                height: 154,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.inputBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.primary.withValues(alpha: 0.12)),
                ),
                child: qr == null
                    ? Center(
                        child: Text(
                          l10n.transferWaitingNetwork,
                          textAlign: TextAlign.center,
                          style: nocturneText(
                            c,
                            size: 12,
                            color: c.textDisabled,
                          ),
                        ),
                      )
                    : QrImageView(
                        data: qr,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: c.textPrimary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: c.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.nocturneQrCaption,
                style: nocturneText(c, size: 12, color: c.textDisabled),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.nocturneScanTitle,
                  style: nocturneText(
                    c,
                    size: 17,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: -0.25),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 30,
                  runSpacing: 12,
                  children: [
                    fact(l10n.nocturnePinLabel, pinLabel, 26),
                    fact(
                      l10n.nocturneAddressLabel,
                      ip == null || port == null
                          ? l10n.transferWaitingNetwork
                          : '$ip:$port',
                      13,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _deviceIcon(TransferDeviceType type) => switch (type) {
  TransferDeviceType.mobile => Icons.smartphone_rounded,
  TransferDeviceType.desktop => Icons.desktop_windows_outlined,
  _ => Icons.devices_other_rounded,
};

/// The device a send goes to (picked in « Appareils »).
class _TargetCard extends ConsumerWidget {
  const _TargetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, target) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.peers, s.activeTargetFingerprint),
      ),
    );
    final peer =
        peers.where((p) => p.fingerprint == target).firstOrNull ??
        peers.firstOrNull;
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              peer == null
                  ? Icons.wifi_find_rounded
                  : _deviceIcon(peer.deviceType),
              size: 20,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer?.alias ?? l10n.transferNoDevices,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nocturneText(
                    c,
                    size: peer == null ? 13 : 14.5,
                    weight: peer == null ? FontWeight.w400 : FontWeight.w700,
                    color: peer == null ? c.textSecondary : c.textPrimary,
                  ),
                ),
                if (peer != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          peer.known
                              ? l10n.transferKnown
                              : l10n.nocturneOnNetwork,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nocturneText(
                            c,
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The transfer in progress as a ring; follows the progress ticks alone.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (progress, error) = ref.watch(
      transferControllerProvider.select((s) => (s.progress, s.lastError)),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final failed = progress?.phase == TransferPhase.failed;
    final running =
        progress != null &&
        progress.phase != TransferPhase.idle &&
        progress.phase != TransferPhase.done &&
        progress.phase != TransferPhase.failed;
    final fraction = progress?.fraction ?? 0;
    final speed = formatSpeed(l10n, progress?.bytesPerSecond);
    final status = switch (progress?.phase) {
      null || TransferPhase.idle => l10n.nocturneNoTransfer,
      TransferPhase.done => l10n.transferDone,
      TransferPhase.failed => progress?.error ?? error ?? l10n.transferErrorHttp,
      _ => l10n.transferSending,
    };
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Row(
        children: [
          NocturneRing(
            value: fraction,
            size: 80,
            stroke: 8,
            radius: 32,
            child: Text(
              '${(fraction * 100).round()}%',
              style: nocturneMono(
                c,
                size: 15,
                color: c.textPrimary,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: nocturneText(
                    c,
                    size: 12,
                    weight: FontWeight.w600,
                    color: failed ? c.error : c.primary,
                  ),
                ),
                if (progress != null && progress.currentName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    progress.currentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c, size: 15, weight: FontWeight.w700),
                  ),
                ],
                if (running) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${localBytes(l10n, progress.bytesDone)} / '
                    '${localBytes(l10n, progress.bytesTotal)} · '
                    '${speed.value} ${speed.unit}',
                    style: nocturneMono(c),
                  ),
                ],
              ],
            ),
          ),
          if (running)
            NocturneButton(
              label: l10n.transferCancel,
              kind: NocturneButtonKind.ghost,
              height: 34,
              padding: 12,
              onTap: notifier.cancelTransfer,
            )
          else if (failed)
            NocturneButton(
              label: l10n.transferRetry,
              height: 34,
              padding: 12,
              onTap: notifier.retryLastTransfer,
            ),
        ],
      ),
    );
  }
}

/// « Fichiers à envoyer »: the library's creators, extra folders and files.
class _PayloadCard extends ConsumerWidget {
  const _PayloadCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          creators: s.selectedCreatorKeys,
          folders: s.extraFolders,
          files: s.extraFiles,
          zip: s.compressZip,
          onlyNew: s.onlyNewVideos,
          count: s.selectedFilesCount,
          bytes: s.selectedTotalBytes,
          peers: s.peers,
          target: s.activeTargetFingerprint,
        ),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final creators = ref.watch(creatorFoldersProvider).folders;
    final all = creators.isNotEmpty && s.creators.length >= creators.length;
    final target =
        s.peers.where((p) => p.fingerprint == s.target).firstOrNull ??
        s.peers.firstOrNull;
    final hasPayload =
        s.count > 0 ||
        s.creators.isNotEmpty ||
        s.folders.isNotEmpty ||
        s.files.isNotEmpty;
    Widget row({
      required bool checked,
      required String title,
      required String meta,
      required VoidCallback onTap,
      String? seed,
      IconData? icon,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: checked ? c.surfaceHighlight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: c.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                NocturneCheck(checked: checked),
                const SizedBox(width: 14),
                if (icon != null)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: nocturneTint(title.hashCode),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: c.textSecondary),
                  )
                else
                  NocturneMonogram(text: seed ?? title, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nocturneText(c, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Text(meta, style: nocturneMono(c)),
              ],
            ),
          ),
        ),
      ),
    );
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: NocturneTitle(l10n.nocturneFilesToSend)),
              Wrap(
                spacing: 6,
                children: [
                  NocturneButton(
                    label: l10n.transferEntireLibrary,
                    icon: all
                        ? Icons.check_box_rounded
                        : Icons.library_add_check_outlined,
                    kind: NocturneButtonKind.ghost,
                    height: 32,
                    padding: 10,
                    onTap: all
                        ? notifier.clearCreators
                        : () => notifier.replaceCreators({
                            for (final f in creators) f.key,
                          }),
                  ),
                  NocturneButton(
                    label: l10n.nocturneAddFolder,
                    icon: Icons.create_new_folder_outlined,
                    kind: NocturneButtonKind.ghost,
                    height: 32,
                    padding: 10,
                    onTap: notifier.addExtraFolder,
                  ),
                  NocturneButton(
                    label: l10n.nocturneAddFiles,
                    icon: Icons.note_add_outlined,
                    kind: NocturneButtonKind.ghost,
                    height: 32,
                    padding: 10,
                    onTap: notifier.addExtraFiles,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in creators)
                  row(
                    checked: s.creators.contains(f.key),
                    title: f.isUnknown
                        ? l10n.folderUnknownCreator
                        : '@${f.handle}',
                    seed: f.handle ?? '?',
                    meta: l10n.nocturneCountVideos(f.count),
                    onTap: () => notifier.toggleCreator(f.key),
                  ),
                for (final path in s.folders)
                  row(
                    checked: true,
                    title: path,
                    icon: Icons.folder_outlined,
                    meta: '',
                    onTap: () => notifier.removeExtraFolder(path),
                  ),
                for (final path in s.files)
                  row(
                    checked: true,
                    title: path,
                    icon: Icons.insert_drive_file_outlined,
                    meta: '',
                    onTap: () => notifier.removeExtraFile(path),
                  ),
                if (creators.isEmpty && s.folders.isEmpty && s.files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.transferNeedPayload,
                      style: nocturneText(c, color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: c.primary.withValues(alpha: 0.08)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.nocturneTotalSelected,
                    style: nocturneText(c, size: 12.5, color: c.textDisabled),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.transferMobileFileCount(s.count)} · '
                    '${localBytes(l10n, s.bytes)}',
                    style: nocturneMono(
                      c,
                      size: 15,
                      color: c.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Toggle(
                    label: l10n.transferOnlyNewToggle,
                    value: s.onlyNew,
                    onChanged: notifier.setOnlyNewVideos,
                  ),
                  _Toggle(
                    label: l10n.nocturneZip,
                    value: s.zip,
                    onChanged: notifier.setCompressZip,
                  ),
                  NocturneButton(
                    label: target == null
                        ? l10n.transferSend
                        : l10n.nocturneSendTo(target.alias),
                    icon: Icons.arrow_forward_rounded,
                    kind: NocturneButtonKind.primary,
                    height: 38,
                    padding: 16,
                    onTap: target == null || !hasPayload
                        ? null
                        : () => notifier.sendTo(target),
                  ),
                ],
              ),
            ],
          ),
        ],
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
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NocturneSwitch(value: value, label: label, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(label, style: nocturneText(c, color: c.textSecondary)),
      ],
    );
  }
}

/// The mockup's « Envois récents » has no history behind it: the devices
/// found on the Wi-Fi take its place (pick the target, trust, rescan).
class _DevicesCard extends ConsumerWidget {
  const _DevicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (peers, target, scanning) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.peers, s.activeTargetFingerprint, s.isScanningSubnet),
      ),
    );
    final notifier = ref.read(transferControllerProvider.notifier);
    final current =
        peers.where((p) => p.fingerprint == target).firstOrNull ??
        peers.firstOrNull;
    return NocturneCard(
      lift: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: NocturneTitle(l10n.transferDevices)),
              NocturneIconButton(
                icon: Icons.refresh_rounded,
                tooltip: l10n.nocturneRefreshDevices,
                ghost: true,
                size: 36,
                onTap: notifier.triggerDiscoveryPulse,
              ),
              NocturneIconButton(
                icon: Icons.travel_explore_rounded,
                tooltip: scanning
                    ? l10n.transferScanningSubnet
                    : l10n.transferScanSubnet,
                ghost: true,
                size: 36,
                onTap: scanning ? null : notifier.scanSubnet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                children: [
                  NocturneOrbit(
                    size: 56,
                    icon: Icons.smartphone_rounded,
                    arc: scanning ? 0.25 : 0,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.transferNoDevices,
                      style: nocturneText(
                        c,
                        size: 12.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final p in peers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => notifier.setActiveTargetFingerprint(
                    p.fingerprint,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p == current
                                ? c.primary.withValues(alpha: 0.16)
                                : c.surfaceHighlight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            p == current
                                ? Icons.check_rounded
                                : _deviceIcon(p.deviceType),
                            size: 16,
                            color: p == current ? c.primary : c.textSecondary,
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
                                style: nocturneText(c, weight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  p.ip,
                                  if (p.deviceModel != null) p.deviceModel!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: nocturneText(
                                  c,
                                  size: 12,
                                  color: c.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
