import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/transfer/domain/send_memory.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_creator_query.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_progress_label.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';

class TransferView extends ConsumerStatefulWidget {
  const TransferView({super.key});

  @override
  ConsumerState<TransferView> createState() => _TransferViewState();
}

class _TransferViewState extends ConsumerState<TransferView> {
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
    final state = ref.watch(transferControllerProvider);

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(state: state),
          const Gap(16),
          if (state.progress != null || state.diagnosticMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LiveTransferBanner(
                progress: state.progress,
                diagnostic: state.diagnosticMessage,
                lastError: state.lastError,
                onRetry: () =>
                    ref.read(transferControllerProvider.notifier).retryLastTransfer(),
                onCancel: () =>
                    ref.read(transferControllerProvider.notifier).cancelTransfer(),
              ),
            ),
          if (state.isScanningSubnet)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SubnetScanBanner(progress: state.subnetScanProgress),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: state.activeTab == TransferTab.send
                  ? _SendTabContent(state: state)
                  : _ReceiveTabContent(state: state),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIncoming(IncomingOffer offer) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
        );
      },
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
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pin_outlined, color: colors.primary, size: 20),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  'Code PIN requis par ${peer.alias}',
                  style: AppTypography.h3.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: colors.textSecondary),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        'Cet appareil récepteur protège ses réceptions par un code PIN défini dans ses paramètres LocalSend.\n\nSaisissez le code PIN configuré sur votre téléphone (ou désactivez l\'option PIN dans les paramètres de votre téléphone pour envoyer sans code).',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 10,
                autofocus: true,
                textAlign: TextAlign.center,
                style: AppTypography.mono.copyWith(
                  fontSize: 22,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ex: 1234',
                  hintStyle: AppTypography.mono.copyWith(
                    fontSize: 16,
                    letterSpacing: 2,
                    color: colors.textSecondary.withValues(alpha: 0.4),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 2),
                  ),
                ),
                onSubmitted: (val) => Navigator.pop(context, val.trim()),
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
        );
      },
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

class _HeaderBar extends ConsumerWidget {
  const _HeaderBar({required this.state});

  final TransferUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    l10n.transferTitle,
                    style: AppTypography.h1.copyWith(color: colors.textPrimary),
                  ),
                  if (state.lanIp != null)
                    _NetworkStatusChip(
                      ip: state.lanIp!,
                      port: state.port ?? 0,
                    ),
                  if (state.pin.isNotEmpty)
                    _PinBadge(pin: state.pin),
                ],
              ),
              const Gap(4),
              Text(
                state.portConflict ? l10n.transferPortBusy : l10n.transferSubtitle,
                style: AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const Gap(16),
        _SegmentedTabSwitcher(
          selected: state.activeTab,
          onSelect: (tab) {
            ref.read(transferControllerProvider.notifier).setTab(tab);
          },
        ),
      ],
    );
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: 'Code PIN de sécurité',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: colors.textSecondary),
            const Gap(5),
            Text(
              pin,
              style: AppTypography.mono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkStatusChip extends StatelessWidget {
  const _NetworkStatusChip({required this.ip, required this.port});

  final String ip;
  final int port;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: colors.success.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.success,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(7),
          Text(
            '$ip:$port',
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabSwitcher extends StatelessWidget {
  const _SegmentedTabSwitcher({
    required this.selected,
    required this.onSelect,
  });

  final TransferTab selected;
  final ValueChanged<TransferTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabPill(
            icon: Icons.file_upload_outlined,
            label: l10n.transferTabSend,
            selected: selected == TransferTab.send,
            onTap: () => onSelect(TransferTab.send),
          ),
          _TabPill(
            icon: Icons.qr_code_2_rounded,
            label: l10n.transferTabReceive,
            selected: selected == TransferTab.receive,
            onTap: () => onSelect(TransferTab.receive),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: selected
              ? Border.all(color: colors.primary.withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? colors.primary : colors.textSecondary,
            ),
            const Gap(8),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: selected ? colors.primary : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTransferBanner extends StatelessWidget {
  const _LiveTransferBanner({
    required this.progress,
    required this.diagnostic,
    required this.lastError,
    required this.onRetry,
    required this.onCancel,
  });

  final TransferProgress? progress;
  final String? diagnostic;
  final String? lastError;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final isFailed = progress?.phase == TransferPhase.failed || diagnostic != null;
    final isDone = progress?.phase == TransferPhase.done;

    final borderColor = isFailed
        ? colors.error.withValues(alpha: 0.35)
        : (isDone
            ? colors.success.withValues(alpha: 0.35)
            : colors.primary.withValues(alpha: 0.35));

    final bgColor = isFailed
        ? colors.error.withValues(alpha: 0.08)
        : (isDone
            ? colors.success.withValues(alpha: 0.08)
            : colors.primary.withValues(alpha: 0.08));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isFailed
                    ? Icons.warning_amber_rounded
                    : (isDone
                        ? Icons.check_circle_outline_rounded
                        : Icons.sync_rounded),
                size: 20,
                color: isFailed
                    ? colors.error
                    : (isDone ? colors.success : colors.primary),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress != null
                          ? _progressLabel(l10n, progress!)
                          : (lastError ?? l10n.transferTitle),
                      style: AppTypography.body.copyWith(
                        color: isFailed ? colors.error : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (diagnostic != null && diagnostic!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          diagnostic!,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Gap(12),
              if (isFailed) ...[
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l10n.transferRetry),
                ),
                const Gap(8),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ] else if (!isDone) ...[
                TextButton(
                  onPressed: onCancel,
                  child: Text(l10n.transferCancel),
                ),
              ] else ...[
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ],
          ),
          if (progress != null && !isFailed && !isDone) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: TransferProgressLabel.isIndeterminate(progress!)
                    ? null
                    : progress!.fraction,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FormatUtils.formatBytes(progress!.bytesDone)} / ${FormatUtils.formatBytes(progress!.bytesTotal)}',
                  style: AppTypography.mono.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (progress!.bytesPerSecond > 0)
                  Text(
                    '⚡ ${FormatUtils.formatBytes(progress!.bytesPerSecond.round())}/s',
                    style: AppTypography.mono.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubnetScanBanner extends StatelessWidget {
  const _SubnetScanBanner({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const Gap(10),
              Text(
                l10n.transferScanningSubnet,
                style: AppTypography.caption.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              if (progress != null)
                Text(
                  '${(progress! * 100).toInt()}%',
                  style: AppTypography.mono.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const Gap(8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SendTabContent extends StatelessWidget {
  const _SendTabContent({required this.state});

  final TransferUiState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final payload = _PayloadPanel(
          key: OnboardingTargets.transfer,
          state: state,
          fill: wide,
        );
        final peers = _PeersPanel(
          peers: state.peers,
          fill: wide,
          preview: state.sendPreview,
          onlyNew: state.onlyNewVideos,
          onSend: (peer) {
            final container = ProviderScope.containerOf(context);
            unawaited(
              container.read(transferControllerProvider.notifier).sendTo(peer),
            );
          },
        );

        if (!wide) {
          return ListView(
            children: [
              payload,
              const Gap(18),
              peers,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: payload),
            const Gap(18),
            Expanded(flex: 6, child: peers),
          ],
        );
      },
    );
  }
}

class _ReceiveTabContent extends StatelessWidget {
  const _ReceiveTabContent({required this.state});

  final TransferUiState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _MePanel(state: state, fill: false),
        ),
      ),
    );
  }
}

class _DoppelrandCard extends StatelessWidget {
  const _DoppelrandCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.fill = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final card = Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        padding: padding,
        child: child,
      ),
    );

    if (fill) return SizedBox.expand(child: card);
    return card;
  }
}

class _MePanel extends StatelessWidget {
  const _MePanel({required this.state, required this.fill});

  final TransferUiState state;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final qr = state.qrUrl;

    return _DoppelrandCard(
      fill: fill,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.desktop_windows_rounded, size: 20, color: colors.primary),
              const Gap(8),
              Text(
                state.alias,
                style: AppTypography.h3.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const Gap(4),
          Text(
            l10n.transferListeningOn,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const Gap(24),
          if (qr == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                state.lastError ?? l10n.transferWaitingNetwork,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: qr,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
            const Gap(20),
            Text(
              'CODE PIN',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                letterSpacing: 2,
                fontSize: 10,
              ),
            ),
            const Gap(4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.pin,
                  style: AppTypography.mono.copyWith(
                    fontSize: 30,
                    letterSpacing: 8,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: l10n.transferCopyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    unawaited(Clipboard.setData(ClipboardData(text: state.pin)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PIN ${state.pin} ${l10n.transferCopied}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Gap(14),
            InkWell(
              onTap: () {
                final directUrl = 'http://${state.lanIp}:${state.port}';
                unawaited(Clipboard.setData(ClipboardData(text: directUrl)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$directUrl ${l10n.transferCopied}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, size: 15, color: colors.primary),
                    const Gap(8),
                    Text(
                      'http://${state.lanIp}:${state.port}',
                      style: AppTypography.mono.copyWith(
                        fontSize: 12,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      l10n.transferCopyLink,
                      style: AppTypography.caption.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeersPanel extends ConsumerStatefulWidget {
  const _PeersPanel({
    required this.peers,
    required this.onSend,
    required this.fill,
    this.preview = SendPreview.empty,
    this.onlyNew = true,
  });

  final List<TransferPeer> peers;
  final ValueChanged<TransferPeer> onSend;
  final bool fill;
  final SendPreview preview;
  final bool onlyNew;

  @override
  ConsumerState<_PeersPanel> createState() => _PeersPanelState();
}

class _PeersPanelState extends ConsumerState<_PeersPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final peers = widget.peers;
    final fill = widget.fill;
    final onSend = widget.onSend;

    final emptyState = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_tethering_rounded,
                size: 30,
                color: colors.primary,
              ),
            ),
            const Gap(14),
            Text(
              l10n.transferNoDevices,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(14),
            FilledButton.tonalIcon(
              onPressed: () => _showDirectIpDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l10n.transferDirectIpTitle),
            ),
          ],
        ),
      ),
    );

    return _DoppelrandCard(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.transferDevices,
                style: AppTypography.h3.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.transferScanSubnet,
                icon: const Icon(Icons.wifi_find_rounded, size: 20),
                onPressed: () {
                  unawaited(
                    ref.read(transferControllerProvider.notifier).scanSubnet(),
                  );
                },
              ),
              IconButton(
                tooltip: l10n.transferDirectIpTitle,
                icon: const Icon(Icons.add_link_rounded, size: 20),
                onPressed: () => _showDirectIpDialog(context, ref),
              ),
            ],
          ),
          const Gap(14),
          if (peers.isEmpty)
            (fill ? Expanded(child: emptyState) : emptyState)
          else if (fill)
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: peers.length,
                  separatorBuilder: (context, index) => const Gap(10),
                  itemBuilder: (context, index) => _PeerTile(
                    peer: peers[index],
                    preview: widget.preview,
                    onlyNew: widget.onlyNew,
                    onTap: () => onSend(peers[index]),
                  ),
                ),
              ),
            )
          else
            for (final peer in peers) ...[
              _PeerTile(
                peer: peer,
                preview: widget.preview,
                onlyNew: widget.onlyNew,
                onTap: () => onSend(peer),
              ),
              const Gap(10),
            ],
        ],
      ),
    );
  }

  void _showDirectIpDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => const _DirectIpDialog(),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({
    required this.peer,
    required this.onTap,
    this.preview = SendPreview.empty,
    this.onlyNew = true,
  });

  final TransferPeer peer;
  final VoidCallback onTap;
  final SendPreview preview;
  final bool onlyNew;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  peer.deviceType == TransferDeviceType.mobile
                      ? Icons.smartphone_rounded
                      : Icons.desktop_windows_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.alias,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Text(
                          '${peer.ip}:${peer.port}',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (peer.known) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.transferKnown,
                              style: AppTypography.caption.copyWith(
                                color: colors.success,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (onlyNew && preview.found > 0 && preview.newest == 0)
                      ? colors.success.withValues(alpha: 0.18)
                      : colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (onlyNew && preview.found > 0)
                          ? (preview.newest > 0
                              ? l10n.transferSendNewOnly(preview.newest)
                              : 'À jour (${preview.already})')
                          : l10n.transferSend,
                      style: AppTypography.label.copyWith(
                        color: (onlyNew && preview.found > 0 && preview.newest == 0)
                            ? colors.success
                            : colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: (onlyNew && preview.found > 0 && preview.newest == 0)
                            ? colors.success
                            : colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (onlyNew && preview.found > 0 && preview.newest == 0)
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 11,
                        color: Colors.white,
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

class _DirectIpDialog extends ConsumerStatefulWidget {
  const _DirectIpDialog();

  @override
  ConsumerState<_DirectIpDialog> createState() => _DirectIpDialogState();
}

class _DirectIpDialogState extends ConsumerState<_DirectIpDialog> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '53317');
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 53317;
    if (ip.isEmpty) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    final peer = await ref
        .read(transferControllerProvider.notifier)
        .connectDirectIp(ip, port: port);

    if (!mounted) return;
    if (peer != null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _connecting = false;
        _error = 'Appareil introuvable à cette adresse.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);

    return AlertDialog(
      title: Text(l10n.transferDirectIpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.transferDirectIpHint,
              labelText: 'Adresse IP',
              prefixIcon: const Icon(Icons.lan_rounded, size: 20),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Port (défaut : 53317)',
              prefixIcon: Icon(Icons.tag_rounded, size: 20),
            ),
          ),
          if (_error != null) ...[
            const Gap(12),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: colors.error),
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
          child: _connecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.transferDirectIpAction),
        ),
      ],
    );
  }
}

class _PayloadPanel extends ConsumerStatefulWidget {
  const _PayloadPanel({
    super.key,
    required this.state,
    required this.fill,
  });

  final TransferUiState state;
  final bool fill;

  @override
  ConsumerState<_PayloadPanel> createState() => _PayloadPanelState();
}

class _PayloadPanelState extends ConsumerState<_PayloadPanel> {
  final _query = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _query.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _labelFor(CreatorFolder folder) {
    final l10n = context.l10n;
    if (folder.isUnknown) return l10n.folderUnknownCreator;
    return '@${folder.handle}';
  }

  String _selectionSummary({
    required int selectedCreators,
    required int extraFolders,
    required int extraFiles,
  }) {
    final parts = <String>[
      if (selectedCreators > 0)
        '$selectedCreators créateur${selectedCreators > 1 ? 's' : ''}',
      if (extraFolders > 0)
        '$extraFolders dossier${extraFolders > 1 ? 's' : ''}',
      if (extraFiles > 0)
        '$extraFiles fichier${extraFiles > 1 ? 's' : ''}',
    ];
    return parts.join(' • ');
  }

  Future<void> _pickFoldersFlow() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null || path.isEmpty || !mounted) return;
      final subfolders = await ref
          .read(transferControllerProvider.notifier)
          .inspectSubfolders(path);
      if (!mounted) return;
      if (subfolders != null && subfolders.length > 1) {
        final selected = await showDialog<List<String>>(
          context: context,
          builder: (ctx) => _SubfolderSelectionDialog(
            parentPath: path,
            subfolders: subfolders,
          ),
        );
        if (selected != null && selected.isNotEmpty) {
          ref.read(transferControllerProvider.notifier).addFolders(selected);
          return;
        }
      } else {
        ref.read(transferControllerProvider.notifier).addFolders([path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection dossier : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final state = widget.state;
    final folders = ref.watch(creatorFoldersProvider).folders;
    final selected = state.selectedCreatorKeys;
    final allSelected = folders.isNotEmpty && selected.length >= folders.length;
    final hits = TransferCreatorQuery.matches(folders, _query.text);
    final folderByKey = {for (final folder in folders) folder.key: folder};
    final hasAnyPayload = selected.isNotEmpty ||
        state.extraFolders.isNotEmpty ||
        state.extraFiles.isNotEmpty ||
        state.selectedFilesCount > 0;

    return _DoppelrandCard(
      fill: widget.fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.transferPayload,
                style: AppTypography.h3.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              if (hasAnyPayload)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 13, color: colors.primary),
                      const Gap(6),
                      Text(
                        '${state.selectedFilesCount} vidéo${state.selectedFilesCount > 1 ? 's' : ''} • ${FormatUtils.formatBytes(state.selectedTotalBytes)}',
                        style: AppTypography.mono.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickAction(
                icon: Icons.library_add_check_outlined,
                label: l10n.transferEntireLibrary,
                selected: allSelected,
                onTap: () {
                  if (allSelected) {
                    ref
                        .read(transferControllerProvider.notifier)
                        .clearCreators();
                    return;
                  }
                  ref.read(transferControllerProvider.notifier).replaceCreators(
                    {for (final folder in folders) folder.key},
                  );
                },
              ),
              _QuickAction(
                icon: Icons.create_new_folder_outlined,
                label: 'Dossiers...',
                onTap: _pickFoldersFlow,
              ),
              _QuickAction(
                icon: Icons.video_library_outlined,
                label: 'Vidéos...',
                onTap: () {
                  unawaited(
                    ref
                        .read(transferControllerProvider.notifier)
                        .addExtraFiles(),
                  );
                },
              ),
            ],
          ),
          if (hasAnyPayload && state.sendPreview.found > 0) ...[
            const Gap(12),
            _SendMemoryStatusBanner(
              preview: state.sendPreview,
              onlyNewVideos: state.onlyNewVideos,
              onToggleOnlyNew: () {
                ref
                    .read(transferControllerProvider.notifier)
                    .toggleOnlyNewVideos();
              },
              onForgetHistory: (state.sendPreview.already > 0)
                  ? () async {
                      final activeFp = ref
                          .read(transferControllerProvider.notifier)
                          .resolveTargetFingerprint();
                      if (activeFp == null) return;
                      await ref
                          .read(transferControllerProvider.notifier)
                          .forgetDeviceMemory(activeFp);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.transferHistoryCleared),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ],
          if (hasAnyPayload) ...[
            const Gap(12),
            _PayloadCompressionBanner(
              count: state.selectedFilesCount,
              totalBytes: state.selectedTotalBytes,
              compressZip: state.compressZip,
              onToggleZip: () {
                ref
                    .read(transferControllerProvider.notifier)
                    .toggleCompressZip();
              },
            ),
          ],
          const Gap(12),
          TextField(
            controller: _query,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (hits.isEmpty) return;
              ref
                  .read(transferControllerProvider.notifier)
                  .addCreator(hits.first.key);
              _query.clear();
              setState(() {});
            },
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.transferSearchCreator,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const Gap(10),
          if (selected.isNotEmpty || state.extraFolders.isNotEmpty || state.extraFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectionSummary(
                        selectedCreators: selected.length,
                        extraFolders: state.extraFolders.length,
                        extraFiles: state.extraFiles.length,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.mono.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Gap(8),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(transferControllerProvider.notifier)
                          .clearAllPayload();
                    },
                    child: Text(l10n.transferClearSelection),
                  ),
                ],
              ),
            ),
          if (widget.fill)
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  children: _buildPayloadList(
                    state: state,
                    folders: folders,
                    selected: selected,
                    allSelected: allSelected,
                    hits: hits,
                    folderByKey: folderByKey,
                  ),
                ),
              ),
            )
          else
            ..._buildPayloadList(
              state: state,
              folders: folders,
              selected: selected,
              allSelected: allSelected,
              hits: hits,
              folderByKey: folderByKey,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPayloadList({
    required TransferUiState state,
    required List<CreatorFolder> folders,
    required Set<String> selected,
    required bool allSelected,
    required List<CreatorFolder> hits,
    required Map<String, CreatorFolder> folderByKey,
  }) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final preview = state.sendPreview;

    return [
      if (allSelected) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: InputChip(
            label: Text(
              preview.already > 0
                  ? '${l10n.transferEntireLibrary} (${preview.newest} nlle${preview.newest > 1 ? 's' : ''} / ${preview.found})'
                  : l10n.transferEntireLibrary,
            ),
            onDeleted: () {
              ref
                  .read(transferControllerProvider.notifier)
                  .clearCreators();
            },
          ),
        ),
        if (preview.folders.isNotEmpty) ...[
          const Gap(6),
          for (final f in preview.folders) ...[
            _HitRow(
              icon: Icons.folder_special_outlined,
              title: f.key,
              subtitle: l10n.transferFolderBreakdown(f.newest, f.already),
            ),
            const Gap(2),
          ],
        ],
      ] else if (selected.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in selected.take(12)) ...[
                Builder(
                  builder: (context) {
                    final counts = preview.forKey(key);
                    final baseName = _labelFor(
                      folderByKey[key] ??
                          CreatorFolder(
                            key: key,
                            handle: key,
                            itemIds: const [],
                            previewUrls: const [],
                          ),
                    );
                    final label = (counts != null && counts.already > 0)
                        ? '$baseName (${counts.newest} nlle${counts.newest > 1 ? 's' : ''})'
                        : baseName;
                    return InputChip(
                      label: Text(label),
                      onDeleted: () {
                        ref
                            .read(transferControllerProvider.notifier)
                            .toggleCreator(key);
                      },
                    );
                  },
                ),
              ],
              if (selected.length > 12)
                InputChip(
                  label: Text('+${selected.length - 12}'),
                  onPressed: () {},
                ),
            ],
          ),
        ),
      for (final path in state.extraFolders) ...[
        const Gap(6),
        _HitRow(
          icon: Icons.folder_outlined,
          title: p.basename(path.replaceAll(r'\', '/')),
          subtitle: path,
          onRemove: () {
            ref
                .read(transferControllerProvider.notifier)
                .removeExtraFolder(path);
          },
        ),
      ],
      for (final path in state.extraFiles) ...[
        const Gap(6),
        _HitRow(
          icon: Icons.video_file_outlined,
          title: p.basename(path.replaceAll(r'\', '/')),
          subtitle: path,
          onRemove: () {
            ref
                .read(transferControllerProvider.notifier)
                .removeExtraFile(path);
          },
        ),
      ],
      if (_query.text.trim().isNotEmpty) ...[
        const Gap(8),
        if (hits.isEmpty)
          Text(
            l10n.transferNoCreatorMatch,
            style: AppTypography.body.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final folder in hits) ...[
            Builder(
              builder: (context) {
                final counts = preview.forKey(folder.key);
                final subtitle = counts != null
                    ? '${l10n.folderVideoCount(folder.count)} • ${l10n.transferFolderBreakdown(counts.newest, counts.already)}'
                    : l10n.folderVideoCount(folder.count);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _HitRow(
                    icon: Icons.person_outline_rounded,
                    title: _labelFor(folder),
                    subtitle: subtitle,
                    onTap: () {
                      ref
                          .read(transferControllerProvider.notifier)
                          .addCreator(folder.key);
                      _query.clear();
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ],
      ],
    ];
  }
}

class _SendMemoryStatusBanner extends StatelessWidget {
  const _SendMemoryStatusBanner({
    required this.preview,
    required this.onlyNewVideos,
    required this.onToggleOnlyNew,
    required this.onForgetHistory,
  });

  final SendPreview preview;
  final bool onlyNewVideos;
  final VoidCallback onToggleOnlyNew;
  final VoidCallback? onForgetHistory;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: colors.primary,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  '${l10n.transferVideosFound(preview.found)} • ${l10n.transferAlreadyTransferred(preview.already)} • ${l10n.transferNewVideos(preview.newest)}',
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (onForgetHistory != null && preview.already > 0)
                Tooltip(
                  message: l10n.transferForgetDeviceHistory,
                  child: IconButton(
                    icon: Icon(
                      Icons.history_toggle_off_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    onPressed: onForgetHistory,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const Gap(8),
          InkWell(
            onTap: onToggleOnlyNew,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: onlyNewVideos
                    ? colors.primary.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: onlyNewVideos
                      ? colors.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    onlyNewVideos
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: onlyNewVideos ? colors.primary : colors.textSecondary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      l10n.transferOnlyNewToggle,
                      style: AppTypography.caption.copyWith(
                        color: onlyNewVideos
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: onlyNewVideos
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (onlyNewVideos && preview.newest > 0)
                    Text(
                      '${preview.newest} (${FormatUtils.formatBytes(preview.newBytes)})',
                      style: AppTypography.mono.copyWith(
                        fontSize: 11,
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayloadCompressionBanner extends StatelessWidget {
  const _PayloadCompressionBanner({
    required this.count,
    required this.totalBytes,
    required this.compressZip,
    required this.onToggleZip,
  });

  final int count;
  final int totalBytes;
  final bool compressZip;
  final VoidCallback onToggleZip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: compressZip
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: compressZip
              ? colors.primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: compressZip
                  ? colors.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              compressZip ? Icons.archive_rounded : Icons.folder_zip_outlined,
              size: 18,
              color: compressZip ? colors.primary : colors.textSecondary,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        compressZip && count > 1
                            ? '$count vidéos (regroupées en ZIP) • ${FormatUtils.formatBytes(totalBytes)}'
                            : '$count vidéo${count > 1 ? 's' : ''} • ${FormatUtils.formatBytes(totalBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (compressZip) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ZIP ACTIF',
                          style: AppTypography.mono.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(2),
                Text(
                  compressZip
                      ? 'Plusieurs fichiers → une archive ZIP (sans compression, vidéos déjà compressées)'
                      : 'Les fichiers partent tels quels vers LocalSend (sans sous-dossiers)',
                  style: AppTypography.caption.copyWith(
                    color: compressZip ? colors.primary : colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
          Tooltip(
            message: 'Regrouper plusieurs fichiers en une archive ZIP (copie, pas de compression)',
            child: InkWell(
              onTap: onToggleZip,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: compressZip
                      ? colors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: compressZip
                        ? colors.primary
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      compressZip ? Icons.check_rounded : Icons.archive_outlined,
                      size: 15,
                      color: compressZip ? Colors.white : colors.textSecondary,
                    ),
                    const Gap(6),
                    Text(
                      compressZip ? 'Archive ZIP : Activé' : 'Archiver en ZIP',
                      style: AppTypography.caption.copyWith(
                        color: compressZip ? Colors.white : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubfolderSelectionDialog extends StatefulWidget {
  const _SubfolderSelectionDialog({
    required this.parentPath,
    required this.subfolders,
  });

  final String parentPath;
  final List<String> subfolders;

  @override
  State<_SubfolderSelectionDialog> createState() =>
      _SubfolderSelectionDialogState();
}

class _SubfolderSelectionDialogState extends State<_SubfolderSelectionDialog> {
  late final Set<String> _selected;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.subfolders.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final parentName = p.basename(widget.parentPath);
    final filtered = widget.subfolders.where((path) {
      final name = p.basename(path).toLowerCase();
      return _filter.isEmpty || name.contains(_filter.toLowerCase().trim());
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_copy_rounded, color: colors.primary, size: 20),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sélectionner des dossiers',
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Dossiers trouvés dans $parentName',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          TextField(
            autofocus: false,
            onChanged: (val) => setState(() => _filter = val),
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Filtrer les sous-dossiers...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const Gap(10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selected.addAll(filtered);
                  });
                },
                icon: const Icon(Icons.select_all_rounded, size: 16),
                label: const Text('Tout cocher'),
              ),
              const Gap(8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selected.removeAll(filtered);
                  });
                },
                icon: const Icon(Icons.deselect_rounded, size: 16),
                label: const Text('Tout décocher'),
              ),
              const Spacer(),
              Text(
                '${_selected.length}/${widget.subfolders.length} sélectionnés',
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Aucun dossier ne correspond',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final name = p.basename(item);
                      final isChecked = _selected.contains(item);
                      return CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(item);
                            } else {
                              _selected.remove(item);
                            }
                          });
                        },
                        secondary: Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: isChecked ? colors.primary : colors.textSecondary,
                        ),
                        title: Text(
                          name,
                          style: AppTypography.body.copyWith(
                            color: isChecked ? colors.textPrimary : colors.textSecondary,
                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        activeColor: colors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        dense: true,
                      );
                    },
                  ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Ajouter (${_selected.length}) dossiers'),
        ),
      ],
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onRemove,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              const Gap(6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: selected ? colors.primary : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
