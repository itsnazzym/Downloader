import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/live_activity.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_creator_query.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/design_data.dart';
import 'terminal_widgets.dart';

TransferController _ctl(WidgetRef ref) =>
    ref.read(transferControllerProvider.notifier);

/// The peer `Envoyer` goes to: the chosen one, else the controller's guess.
TransferPeer? _target(TransferUiState s, TransferController c) {
  final fp = c.resolveTargetFingerprint();
  for (final peer in s.peers) {
    if (peer.id == fp) return peer;
  }
  return s.peers.isEmpty ? null : s.peers.first;
}

/// Terminal's transfer (mockup Terminal-Transfert.dc.html): receive (QR,
/// PIN, address), what to send, the transfer in flight, nearby devices.
class TerminalTransfer extends ConsumerStatefulWidget {
  const TerminalTransfer({super.key});

  @override
  ConsumerState<TerminalTransfer> createState() => _TerminalTransferState();
}

class _TerminalTransferState extends ConsumerState<TerminalTransfer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ctl(ref).start());
    });
  }

  void _notice(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  void _send() {
    final s = ref.read(transferControllerProvider);
    final peer = _target(s, _ctl(ref));
    if (peer == null) return;
    if (ref.read(showcaseModeProvider)) {
      _notice(context.l10n.transferMobileDemoSendSimulated);
      return;
    }
    unawaited(_ctl(ref).sendTo(peer));
  }

  void _toggleLibrary() {
    final folders = ref.read(creatorFoldersProvider).folders;
    final selected = ref.read(transferControllerProvider).selectedCreatorKeys;
    if (folders.isNotEmpty && selected.length >= folders.length) {
      _ctl(ref).clearCreators();
    } else {
      _ctl(ref).replaceCreators({for (final f in folders) f.key});
    }
  }

  Future<void> _pickFolders() async {
    if (ref.read(showcaseModeProvider)) {
      _notice(context.l10n.transferMobileDemoNoFiles);
      return;
    }
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null || path.isEmpty || !mounted) return;
      final subfolders = await _ctl(ref).inspectSubfolders(path);
      if (!mounted) return;
      if (subfolders != null && subfolders.length > 1) {
        final picked = await showDialog<List<String>>(
          context: context,
          builder: (_) =>
              _SubfoldersDialog(parent: path, subfolders: subfolders),
        );
        if (picked != null && picked.isNotEmpty) _ctl(ref).addFolders(picked);
      } else {
        _ctl(ref).addFolders([path]);
      }
    } catch (e) {
      if (mounted) {
        _notice(context.l10n.transferMobileFolderPickError(e.toString()));
      }
    }
  }

  void _addFiles() {
    if (ref.read(showcaseModeProvider)) {
      _notice(context.l10n.transferMobileDemoNoFiles);
      return;
    }
    unawaited(_ctl(ref).addExtraFiles());
  }

  Future<void> _broadcast() async {
    await _ctl(ref).triggerDiscoveryPulse();
    if (mounted) _notice(context.l10n.transferMobileBroadcastDone);
  }

  void _copyLink() {
    final s = ref.read(transferControllerProvider);
    if (s.lanIp == null || s.port == null) return;
    Clipboard.setData(ClipboardData(text: 'http://${s.lanIp}:${s.port}'));
    _notice(context.l10n.transferCopied);
  }

  void _directIp() => showDialog<void>(
    context: context,
    builder: (_) => const _DirectIpDialog(),
  );

  Future<void> _showIncoming(IncomingOffer offer) async {
    final l10n = context.l10n;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TDialog(
        title: l10n.transferIncomingTitle,
        body: Text(
          l10n.transferIncomingBody(
            offer.peerAlias,
            offer.files.length,
            localBytes(l10n, offer.totalBytes),
          ),
        ),
        actions: [
          TButton(
            label: l10n.transferReject,
            onTap: () => Navigator.pop(ctx, false),
          ),
          TButton(
            label: l10n.transferAccept,
            kind: TButtonKind.primary,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (mounted) _ctl(ref).answerIncoming(accept ?? false);
  }

  Future<void> _showPeerPin(TransferPeer peer) async {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => TDialog(
        title: l10n.transferMobilePeerPinRequired(peer.alias),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '# ${l10n.transferMobilePeerPinExplain}',
              style: tm(colors.textSecondary),
            ),
            const SizedBox(height: 14),
            TField(
              controller: controller,
              hint: l10n.transferMobilePinExample,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TButton(label: l10n.cancel, onTap: () => Navigator.pop(ctx)),
          TButton(
            label: l10n.transferSend,
            kind: TButtonKind.primary,
            onTap: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    _ctl(ref).dismissPeerPin();
    if (pin == null || pin.isEmpty) return;
    unawaited(_ctl(ref).sendTo(peer, pin: pin));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Without these two, an incoming offer or a PIN request would hang.
    ref.listen(transferControllerProvider.select((s) => s.incoming), (a, b) {
      if (b != null && a == null) unawaited(_showIncoming(b));
    });
    ref.listen(transferControllerProvider.select((s) => s.peerPinPrompt), (
      a,
      b,
    ) {
      if (b != null && a == null) unawaited(_showPeerPin(b));
    });
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TPrompt('send', l10n.terminalFlagWifi),
        const SizedBox(height: 12),
        _WifiPanel(onCopy: _copyLink),
        const SizedBox(height: 12),
        const _TargetPanel(),
        const SizedBox(height: 12),
        THints([
          ('b', l10n.terminalBroadcast),
          ('k', l10n.transferCopyLink.toLowerCase()),
        ]),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TPrompt('send', l10n.terminalFlagSelect),
        const SizedBox(height: 12),
        _SelectPanel(
          key: OnboardingTargets.transfer,
          onLibrary: _toggleLibrary,
          onFolders: _pickFolders,
          onFiles: _addFiles,
          onSend: _send,
        ),
        const SizedBox(height: 12),
        THints([
          ('a', l10n.terminalCheckAll),
          ('f v', l10n.terminalAddFiles),
          ('z', 'zip'),
          (l10n.terminalEnterKey, l10n.transferSend.toLowerCase()),
        ]),
      ],
    );
    return TerminalPageKeys(
      bindings: {
        'a': _toggleLibrary,
        'f': _pickFolders,
        'v': _addFiles,
        'z': _ctl(ref).toggleCompressZip,
        'enter': _send,
        'c': _ctl(ref).cancelTransfer,
        'r': _ctl(ref).retryLastTransfer,
        'u': () => unawaited(_ctl(ref).triggerDiscoveryPulse()),
        'n': () => unawaited(_ctl(ref).scanSubnet()),
        'i': _directIp,
        'b': _broadcast,
        'k': _copyLink,
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => c.maxWidth < 700
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [left, const SizedBox(height: 18), right],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 18),
                              Expanded(child: right),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  TPrompt('send', l10n.terminalFlagStatus),
                  const SizedBox(height: 12),
                  const _StatusPanel(),
                  const SizedBox(height: 12),
                  THints([
                    ('c', l10n.cancel.toLowerCase()),
                    ('r', l10n.retry.toLowerCase()),
                  ]),
                  const SizedBox(height: 18),
                  _PeersTable(onDirectIp: _directIp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WifiPanel extends ConsumerWidget {
  const _WifiPanel({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (qr, pin, ip, port, busy, error) = ref.watch(
      transferControllerProvider.select(
        (s) => (s.qrUrl, s.pin, s.lanIp, s.port, s.portConflict, s.lastError),
      ),
    );
    final note = busy
        ? l10n.transferPortBusy
        : qr == null
        ? (error ?? l10n.transferWaitingNetwork)
        : l10n.terminalScanHint;
    final spacedPin = pin.length == 6
        ? '${pin.substring(0, 3)} ${pin.substring(3)}'
        : pin;
    return TPanel(
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        children: [
          Column(
            children: [
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.border),
                ),
                child: qr == null
                    ? null
                    : QrImageView(
                        data: qr,
                        padding: EdgeInsets.zero,
                        backgroundColor: colors.background,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: colors.primary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: colors.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text('QR code', style: tm(colors.textDisabled)),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.terminalPin, style: tm(colors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  spacedPin.isEmpty ? '—' : spacedPin,
                  style: tm(
                    colors.primary,
                    size: 28,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 2.2),
                ),
                const SizedBox(height: 12),
                Text(l10n.terminalAddress, style: tm(colors.textSecondary)),
                const SizedBox(height: 2),
                if (ip != null && port != null)
                  Tooltip(
                    message: l10n.transferCopyLink,
                    child: InkWell(
                      onTap: onCopy,
                      child: Text('$ip:$port', style: tm(colors.textPrimary)),
                    ),
                  )
                else
                  Text('—', style: tm(colors.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  '# $note',
                  style: tm(busy ? colors.warning : colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `appareil <name> ● connecté`: where `Envoyer` goes.
class _TargetPanel extends ConsumerWidget {
  const _TargetPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    // Rebuilds when the target can change; _target reads the rest.
    ref.watch(
      transferControllerProvider.select(
        (s) => (s.peers, s.activeTargetFingerprint, s.lastPeerAttempt),
      ),
    );
    final peer = _target(ref.read(transferControllerProvider), _ctl(ref));
    return TPanel(
      child: Row(
        children: [
          Text(l10n.terminalDevice, style: tm(colors.textSecondary)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              peer?.alias ?? l10n.transferNoDevices,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tm(
                peer == null ? colors.textDisabled : colors.textPrimary,
                weight: peer == null ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
          if (peer != null)
            Text(
              '● ${peer.known ? l10n.transferKnown.toLowerCase() : l10n.terminalOnline}',
              style: tm(colors.primary),
            ),
        ],
      ),
    );
  }
}

class _SelectPanel extends ConsumerStatefulWidget {
  const _SelectPanel({
    super.key,
    required this.onLibrary,
    required this.onFolders,
    required this.onFiles,
    required this.onSend,
  });

  final VoidCallback onLibrary;
  final VoidCallback onFolders;
  final VoidCallback onFiles;
  final VoidCallback onSend;

  @override
  ConsumerState<_SelectPanel> createState() => _SelectPanelState();
}

class _SelectPanelState extends ConsumerState<_SelectPanel> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          creators: s.selectedCreatorKeys,
          folders: s.extraFolders,
          files: s.extraFiles,
          zip: s.compressZip,
          count: s.selectedFilesCount,
          bytes: s.selectedTotalBytes,
          preview: s.sendPreview,
          onlyNew: s.onlyNewVideos,
          hasPeer: s.peers.isNotEmpty,
          busy:
              s.progress != null &&
              s.progress!.phase != TransferPhase.done &&
              s.progress!.phase != TransferPhase.failed,
        ),
      ),
    );
    final all = ref.watch(creatorFoldersProvider).folders;
    final hits = TransferCreatorQuery.matches(all, _query.text);
    final hasPayload =
        s.creators.isNotEmpty || s.folders.isNotEmpty || s.files.isNotEmpty;
    Widget row(bool on, String name, String right, VoidCallback onTap) =>
        THoverLine(
          selected: on,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(on ? '[x]' : '[ ]', style: tm(colors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tm(colors.textPrimary, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(right, style: tm(colors.textSecondary)),
            ],
          ),
        );
    return TPanel(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: SizedBox(
              height: 30,
              child: TField(
                controller: _query,
                prefix: '/',
                hint: l10n.transferSearchCreator,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (hits.isNotEmpty) _ctl(ref).addCreator(hits.first.key);
                },
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 186),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in hits)
                  row(
                    s.creators.contains(f.key),
                    f.isUnknown ? l10n.folderUnknownCreator : '@${f.handle}',
                    l10n.terminalVidCount(f.count),
                    () => _ctl(ref).toggleCreator(f.key),
                  ),
                for (final path in s.folders)
                  row(
                    true,
                    '${p.basename(path)}/',
                    '',
                    () => _ctl(ref).removeExtraFolder(path),
                  ),
                for (final path in s.files)
                  row(
                    true,
                    p.basename(path),
                    '',
                    () => _ctl(ref).removeExtraFile(path),
                  ),
                if (hits.isEmpty && s.folders.isEmpty && s.files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '# ${l10n.transferNeedPayload}',
                      style: tm(colors.textDisabled),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TButton(
                  keyHint: 'a',
                  label: l10n.transferEntireLibrary,
                  height: 28,
                  onTap: widget.onLibrary,
                ),
                TButton(
                  keyHint: 'f',
                  label: l10n.transferMobileFoldersAction,
                  height: 28,
                  onTap: widget.onFolders,
                ),
                TButton(
                  keyHint: 'v',
                  label: l10n.transferMobileVideosAction,
                  height: 28,
                  onTap: widget.onFiles,
                ),
                if (hasPayload)
                  TButton(
                    label: l10n.terminalClearPayload,
                    height: 28,
                    onTap: _ctl(ref).clearAllPayload,
                  ),
              ],
            ),
          ),
          if (hasPayload && s.preview.found > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '# ${l10n.transferVideosFound(s.preview.found)} · '
                    '${l10n.transferAlreadyTransferred(s.preview.already)} · '
                    '${l10n.transferNewVideos(s.preview.newest)}',
                    style: tm(colors.textSecondary),
                  ),
                  if (s.preview.already > 0)
                    TLink(
                      label: l10n.transferForgetDeviceHistory.toLowerCase(),
                      onTap: () async {
                        final fp = _ctl(ref).resolveTargetFingerprint();
                        if (fp == null) return;
                        await _ctl(ref).forgetDeviceMemory(fp);
                        if (context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(l10n.transferHistoryCleared),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TSwitch(
                      value: s.zip,
                      onChanged: (_) => _ctl(ref).toggleCompressZip(),
                      label: l10n.transferMobileZipTooltip,
                    ),
                    _Assign(l10n.terminalZipKey, s.zip),
                    if (s.preview.found > 0) ...[
                      const SizedBox(width: 8),
                      TSwitch(
                        value: s.onlyNew,
                        onChanged: (_) => _ctl(ref).toggleOnlyNewVideos(),
                        label: l10n.transferOnlyNewToggle,
                      ),
                      _Assign(l10n.terminalOnlyNewKey, s.onlyNew),
                    ],
                  ],
                ),
                Wrap(
                  spacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '${l10n.terminalTotal} ',
                        children: [
                          TextSpan(
                            text: localBytes(l10n, s.bytes),
                            style: tm(colors.textPrimary),
                          ),
                          TextSpan(
                            text: ' · ${l10n.transferMobileFileCount(s.count)}',
                          ),
                        ],
                      ),
                      style: tm(colors.textSecondary),
                    ),
                    TButton(
                      keyHint: l10n.terminalEnterKey,
                      label: l10n.transferSend,
                      kind: TButtonKind.primary,
                      onTap: !hasPayload || !s.hasPeer || s.busy
                          ? null
                          : widget.onSend,
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

/// `key = value` with the value in the accent colour.
class _Assign extends StatelessWidget {
  const _Assign(this.name, this.value);

  final String name;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        text: '$name = ',
        children: [TextSpan(text: '$value', style: tm(colors.primary))],
      ),
      style: tm(colors.textPrimary),
    );
  }
}

/// The transfer in flight: the only part that follows progress ticks.
class _StatusPanel extends ConsumerWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(transferControllerProvider);
    final progress = s.progress;
    final diagnostic = s.diagnostic;
    if (progress == null && diagnostic == null) {
      return TPanel(
        child: Text(
          '# ${l10n.terminalNoTransfer}',
          style: tm(colors.textSecondary),
        ),
      );
    }
    final failed =
        progress?.phase == TransferPhase.failed || diagnostic != null;
    final target =
        s.peers
            .where((peer) => peer.id == s.activeTargetFingerprint)
            .firstOrNull ??
        s.lastPeerAttempt;
    final speed = formatSpeed(l10n, progress?.bytesPerSecond);
    final pct = ((progress?.fraction ?? 0) * 100).round();
    return TPanel(
      accentLeft: failed ? colors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: failed ? '✕ ' : '▶ ',
                        style: tm(failed ? colors.error : colors.primary),
                      ),
                      TextSpan(
                        text: progress != null
                            ? _progressLabel(l10n, progress)
                            : _noticeTitle(l10n, diagnostic, s.lastError),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tm(colors.textPrimary),
                ),
              ),
              if (target != null) ...[
                const SizedBox(width: 18),
                Text('→ ${target.alias}', style: tm(colors.textDisabled)),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TSeg(
                    value: progress.fraction,
                    color: failed ? colors.error : null,
                  ),
                ),
                const SizedBox(width: 18),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$pct% ', style: tm(colors.primary)),
                      TextSpan(text: '${speed.value} ${speed.unit}'.trim()),
                    ],
                  ),
                  style: tm(colors.textPrimary),
                ),
              ],
            ),
          ],
          if (diagnostic != null) ...[
            const SizedBox(height: 6),
            Text(
              '# ${_diagnosticText(l10n, diagnostic)}',
              style: tm(colors.textSecondary),
            ),
          ],
          if (progress?.phase == TransferPhase.preparing &&
              s.scanStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              '# ${_scanText(l10n, s.scanStatus!)}',
              style: tm(colors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (!failed && progress?.phase != TransferPhase.done)
                TButton(
                  keyHint: 'c',
                  label: l10n.transferCancel,
                  height: 28,
                  onTap: _ctl(ref).cancelTransfer,
                ),
              if (failed)
                TButton(
                  keyHint: 'r',
                  label: l10n.transferRetry,
                  height: 28,
                  onTap: _ctl(ref).retryLastTransfer,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeersTable extends ConsumerWidget {
  const _PeersTable({required this.onDirectIp});

  final VoidCallback onDirectIp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final s = ref.watch(
      transferControllerProvider.select(
        (s) => (
          peers: s.peers,
          preview: s.sendPreview,
          onlyNew: s.onlyNewVideos,
          scanning: s.isScanningSubnet,
          target: s.activeTargetFingerprint,
        ),
      ),
    );
    final target = _target(ref.read(transferControllerProvider), _ctl(ref));
    final head = tm(colors.textDisabled);
    final upToDate = s.onlyNew && s.preview.found > 0 && s.preview.newest == 0;
    final sendLabel = s.onlyNew && s.preview.found > 0
        ? (s.preview.newest > 0
              ? l10n.transferSendNewOnly(s.preview.newest)
              : l10n.transferMobileUpToDateCount(s.preview.already))
        : l10n.transferSend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TPrompt(
                'send',
                l10n.terminalFlagPeers,
                comment: '${s.peers.length}',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TButton(
                  keyHint: 'u',
                  label: l10n.transferMobileRefresh,
                  height: 28,
                  onTap: () => _ctl(ref).triggerDiscoveryPulse(),
                ),
                TButton(
                  keyHint: 'n',
                  label: l10n.transferScanSubnet,
                  height: 28,
                  onTap: s.scanning ? null : () => _ctl(ref).scanSubnet(),
                ),
                TButton(
                  keyHint: 'i',
                  label: l10n.transferDirectIpTitle,
                  height: 28,
                  onTap: onDirectIp,
                ),
                if (s.peers.isNotEmpty)
                  TButton(
                    label: l10n.transferMobileClearList,
                    height: 28,
                    onTap: _ctl(ref).clearPeers,
                  ),
              ],
            ),
          ],
        ),
        if (s.scanning) ...[
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) => TSeg(
              value:
                  ref.watch(
                    transferControllerProvider.select(
                      (s) => s.subnetScanProgress,
                    ),
                  ) ??
                  0,
              height: 6,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(l10n.terminalColState, style: head),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(l10n.terminalDevice, style: head)),
              const SizedBox(width: 14),
              SizedBox(
                width: 160,
                child: Text(l10n.terminalAddress, style: head),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 230,
                child: Text(
                  l10n.terminalActions,
                  textAlign: TextAlign.right,
                  style: head,
                ),
              ),
            ],
          ),
        ),
        if (s.peers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
            child: Text(
              '# ${l10n.transferNoDevices}',
              style: tm(colors.textSecondary),
            ),
          ),
        for (final peer in s.peers)
          THoverLine(
            selected: target?.id == peer.id,
            onTap: () => _ctl(ref).setActiveTargetFingerprint(peer.id),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    target?.id == peer.id ? '(•)' : '( )',
                    style: tm(colors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: peer.alias,
                      style: tm(colors.textPrimary, weight: FontWeight.w600),
                      children: [
                        if ((peer.deviceModel ?? '').isNotEmpty)
                          TextSpan(
                            text: '  ${peer.deviceModel}',
                            style: tm(colors.textDisabled),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 160,
                  child: Text(
                    '${peer.ip}:${peer.port}',
                    style: tm(colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 230,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: peer.known
                            ? l10n.transferMobileUnmarkKnown
                            : l10n.transferMobileMarkKnown,
                        child: InkWell(
                          onTap: () => _ctl(ref).toggleTrusted(peer),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              peer.known
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: peer.known
                                  ? colors.warning
                                  : colors.textDisabled,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: upToDate
                            ? Text(
                                sendLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tm(colors.textDisabled),
                              )
                            : TLink(
                                label: '→ $sendLabel',
                                onTap: () {
                                  if (ref.read(showcaseModeProvider)) {
                                    ScaffoldMessenger.maybeOf(
                                      context,
                                    )?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.transferMobileDemoSendSimulated,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  unawaited(_ctl(ref).sendTo(peer));
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
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
    final peer = await _ctl(
      ref,
    ).connectDirectIp(ip, port: int.tryParse(_port.text.trim()) ?? 53317);
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
    final colors = AppColors.of(context);
    return TDialog(
      title: l10n.transferDirectIpTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.transferMobileIpAddress, style: tm(colors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: TField(
              controller: _ip,
              hint: l10n.transferDirectIpHint,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.transferMobilePortDefault, style: tm(colors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: TField(controller: _port, onSubmitted: (_) => _submit()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('# $_error', style: tm(colors.error)),
          ],
        ],
      ),
      actions: [
        TButton(
          label: l10n.cancel,
          onTap: _connecting ? null : () => Navigator.pop(context),
        ),
        TButton(
          label: _connecting ? '…' : l10n.transferDirectIpAction,
          kind: TButtonKind.primary,
          onTap: _connecting ? null : _submit,
        ),
      ],
    );
  }
}

/// Today's subfolder picker: all ticked, filter, tick all or none.
class _SubfoldersDialog extends StatefulWidget {
  const _SubfoldersDialog({required this.parent, required this.subfolders});

  final String parent;
  final List<String> subfolders;

  @override
  State<_SubfoldersDialog> createState() => _SubfoldersDialogState();
}

class _SubfoldersDialogState extends State<_SubfoldersDialog> {
  late final Set<String> _picked = widget.subfolders.toSet();
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final q = _filter.text.trim().toLowerCase();
    final shown = [
      for (final path in widget.subfolders)
        if (q.isEmpty || p.basename(path).toLowerCase().contains(q)) path,
    ];
    return TDialog(
      title: l10n.transferMobileSubfoldersTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '# ${l10n.transferMobileSubfoldersFoundIn(p.basename(widget.parent))}',
            style: tm(colors.textSecondary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: TField(
              controller: _filter,
              prefix: '/',
              hint: l10n.transferMobileSubfoldersFilter,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TLink(
                label: l10n.transferMobileCheckAll,
                onTap: () => setState(() => _picked.addAll(shown)),
              ),
              const SizedBox(width: 14),
              TLink(
                label: l10n.transferMobileUncheckAll,
                onTap: () => setState(() => _picked.removeAll(shown)),
              ),
              const Spacer(),
              Text(
                l10n.transferMobileSelectedOfTotal(
                  _picked.length,
                  widget.subfolders.length,
                ),
                style: tm(colors.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: shown.isEmpty
                ? Text(
                    '# ${l10n.transferMobileNoFolderMatch}',
                    style: tm(colors.textDisabled),
                  )
                : ListView(
                    children: [
                      for (final path in shown)
                        THoverLine(
                          selected: _picked.contains(path),
                          onTap: () => setState(() {
                            if (!_picked.remove(path)) _picked.add(path);
                          }),
                          child: Text(
                            '${_picked.contains(path) ? '[x]' : '[ ]'} ${p.basename(path)}',
                            style: tm(colors.textPrimary),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      actions: [
        TButton(label: l10n.cancel, onTap: () => Navigator.pop(context)),
        TButton(
          label: l10n.transferMobileAddFolders(_picked.length),
          kind: TButtonKind.primary,
          onTap: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final path in widget.subfolders)
                    if (_picked.contains(path)) path,
                ]),
        ),
      ],
    );
  }
}

String _noticeTitle(
  AppLocalizations l10n,
  TransferDiagnostic? diagnostic,
  String? lastError,
) {
  if (diagnostic?.code == TransferDiagnosticCode.unreachable) {
    return l10n.transferMobileDeviceUnreachable(diagnostic?.detail ?? '');
  }
  return lastError ?? l10n.transferTitle;
}

String _diagnosticText(AppLocalizations l10n, TransferDiagnostic diagnostic) {
  return switch (diagnostic.code) {
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
      (diagnostic.detail != null && diagnostic.detail!.isNotEmpty)
          ? diagnostic.detail!
          : l10n.transferMobileDiagCommunication,
  };
}

String _scanText(AppLocalizations l10n, TransferScanStatus scan) {
  return scan.totalFolders > 0
      ? l10n.transferMobileScanFolders(
          scan.scannedFolders,
          scan.totalFolders,
          scan.videos,
        )
      : l10n.transferMobileScanVideosFound(scan.videos);
}

String _progressLabel(AppLocalizations l10n, TransferProgress progress) {
  return switch (progress.phase) {
    TransferPhase.preparing => l10n.transferPreparing,
    TransferPhase.compressing => l10n.transferCompressing,
    TransferPhase.waitingPeer => l10n.transferWaitingPeer,
    TransferPhase.done => l10n.transferDone,
    TransferPhase.failed => switch (progress.error) {
      'empty' => l10n.transferNeedPayload,
      'httpError' => l10n.transferErrorHttp,
      'timeout' => l10n.transferErrorHttp,
      'connectionRefused' => l10n.transferErrorHttp,
      'busy' => l10n.transferErrorBusy,
      'rejected' => l10n.transferErrorRejected,
      _ => progress.error ?? l10n.transferErrorHttp,
    },
    TransferPhase.transferring =>
      progress.currentName.isEmpty
          ? l10n.transferSending
          : progress.currentName,
    TransferPhase.idle => l10n.transferSending,
  };
}
