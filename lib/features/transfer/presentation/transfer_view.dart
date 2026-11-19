import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/downloader/presentation/models/creator_folder.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/creator_folders_provider.dart';
import 'package:modern_downloader/features/transfer/domain/send_memory.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_creator_query.dart';
import 'package:modern_downloader/features/transfer/domain/transfer_models.dart';
import 'package:modern_downloader/features/onboarding/presentation/onboarding_targets.dart';
import 'package:modern_downloader/features/transfer/presentation/transfer_controller.dart';
import 'package:modern_downloader/features/transfer/presentation/widgets/dot_radar.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';
import 'package:modern_downloader/showcase/showcase_data.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';

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

    if (PlatformInfo.isMobile) {
      return _OledTransferBody(state: state);
    }

    final isMobile =
        PlatformInfo.isMobile || MediaQuery.sizeOf(context).width < 640;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 40,
        isMobile ? 12 : 24,
        isMobile ? 16 : 40,
        isMobile ? 16 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(state: state),
          const Gap(16),
          if (state.progress != null || state.diagnostic != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LiveTransferBanner(
                progress: state.progress,
                diagnostic: state.diagnostic,
                scanStatus: state.scanStatus,
                lastError: state.lastError,
                onRetry: () => ref
                    .read(transferControllerProvider.notifier)
                    .retryLastTransfer(),
                onCancel: () => ref
                    .read(transferControllerProvider.notifier)
                    .cancelTransfer(),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pin_outlined,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  l10n.transferMobilePeerPinRequired(peer.alias),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        l10n.transferMobilePeerPinExplain,
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
                  hintText: l10n.transferMobilePinExample,
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
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
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
    final isMobile =
        PlatformInfo.isMobile || MediaQuery.sizeOf(context).width < 640;

    final tabSwitcher = _SegmentedTabSwitcher(
      selected: state.activeTab,
      onSelect: (tab) {
        ref.read(transferControllerProvider.notifier).setTab(tab);
      },
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.transferTitle,
                style: AppTypography.h1.copyWith(
                  color: colors.textPrimary,
                  fontSize: 22,
                ),
              ),
              tabSwitcher,
            ],
          ),
          const Gap(8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (state.lanIp != null)
                _NetworkStatusChip(ip: state.lanIp!, port: state.port ?? 0),
              if (state.pin.isNotEmpty) _PinBadge(pin: state.pin),
            ],
          ),
          const Gap(4),
          Text(
            state.portConflict
                ? (PlatformInfo.isMobile
                      ? l10n.transferMobilePortAltActive(state.port ?? 53318)
                      : l10n.transferPortBusy)
                : l10n.transferSubtitle,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

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
                    _NetworkStatusChip(ip: state.lanIp!, port: state.port ?? 0),
                  if (state.pin.isNotEmpty) _PinBadge(pin: state.pin),
                ],
              ),
              const Gap(4),
              Text(
                state.portConflict
                    ? (PlatformInfo.isMobile
                          ? l10n.transferMobilePortAltActive(
                              state.port ?? 53318,
                            )
                          : l10n.transferPortBusy)
                    : l10n.transferSubtitle,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        tabSwitcher,
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
      message: context.l10n.transferMobilePinLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: colors.textSecondary,
            ),
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
        border: Border.all(color: colors.success.withValues(alpha: 0.25)),
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
  const _SegmentedTabSwitcher({required this.selected, required this.onSelect});

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
            icon: PlatformInfo.isMobile
                ? Icons.download_rounded
                : Icons.qr_code_2_rounded,
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
          color: selected
              ? colors.primary.withValues(alpha: 0.22)
              : Colors.transparent,
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
    required this.scanStatus,
    required this.lastError,
    required this.onRetry,
    required this.onCancel,
  });

  final TransferProgress? progress;
  final TransferDiagnostic? diagnostic;
  final TransferScanStatus? scanStatus;
  final String? lastError;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final isFailed =
        progress?.phase == TransferPhase.failed || diagnostic != null;
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
                          : _noticeTitle(l10n, diagnostic, lastError),
                      style: AppTypography.body.copyWith(
                        color: isFailed ? colors.error : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (diagnostic != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _diagnosticText(l10n, diagnostic!),
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
              ],
              IconButton(
                tooltip: l10n.transferCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onCancel,
              ),
            ],
          ),
          if (progress != null && !isFailed && !isDone) ...[
            const Gap(12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress!.fraction.isNaN || progress!.fraction.isInfinite
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
                  (progress!.phase == TransferPhase.preparing &&
                          scanStatus != null)
                      ? _scanText(l10n, scanStatus!)
                      : '${FormatUtils.formatBytes(progress!.bytesDone)} / ${FormatUtils.formatBytes(progress!.bytesTotal)}',
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
                style: AppTypography.caption.copyWith(
                  color: colors.textPrimary,
                ),
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
            if (container.read(showcaseModeProvider)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.transferMobileDemoSendSimulated),
                ),
              );
              return;
            }
            unawaited(
              container.read(transferControllerProvider.notifier).sendTo(peer),
            );
          },
        );

        if (!wide) {
          return ListView(children: [payload, const Gap(18), peers]);
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
    if (PlatformInfo.isMobile) {
      final oled = OledCard(padding: const EdgeInsets.all(16), child: child);
      return fill ? SizedBox.expand(child: oled) : oled;
    }
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

class _MePanel extends ConsumerStatefulWidget {
  const _MePanel({required this.state, required this.fill});

  final TransferUiState state;
  final bool fill;

  @override
  ConsumerState<_MePanel> createState() => _MePanelState();
}

class _MePanelState extends ConsumerState<_MePanel> {
  late bool _showQr;

  @override
  void initState() {
    super.initState();
    _showQr = !PlatformInfo.isMobile;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final state = widget.state;
    final qr = state.qrUrl;
    final isMobile = PlatformInfo.isMobile;

    return _DoppelrandCard(
      fill: widget.fill,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMobile
                    ? Icons.smartphone_rounded
                    : Icons.desktop_windows_rounded,
                size: 22,
                color: colors.primary,
              ),
              const Gap(10),
              Flexible(
                child: Text(
                  state.alias,
                  style: AppTypography.h3.copyWith(color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(4),
          Text(
            l10n.transferListeningOn,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const Gap(20),
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
            // Status Radar Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.transferMobileReadyToReceive,
                          style: AppTypography.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          l10n.transferMobileVisibleOnWifi,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.transferMobileBroadcastTooltip,
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 20),
                    onPressed: () {
                      ref
                          .read(transferControllerProvider.notifier)
                          .triggerDiscoveryPulse();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.transferMobileBroadcastDone),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Gap(18),
            // Security PIN Block
            Text(
              l10n.transferMobilePinLabel.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                letterSpacing: 2,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.pin,
                  style: AppTypography.mono.copyWith(
                    fontSize: 28,
                    letterSpacing: 6,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: l10n.transferCopyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    unawaited(
                      Clipboard.setData(ClipboardData(text: state.pin)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'PIN ${state.pin} ${l10n.transferCopied}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Gap(12),
            // Direct Address
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
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
            const Gap(20),
            // QR Code Section (Collapsible on Mobile, Expanded by Default on Desktop)
            if (isMobile)
              TextButton.icon(
                onPressed: () => setState(() => _showQr = !_showQr),
                icon: Icon(
                  _showQr
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.qr_code_2_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                label: Text(
                  _showQr
                      ? l10n.transferMobileQrHide
                      : l10n.transferMobileQrShowMobileToMobile,
                  style: AppTypography.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_showQr) ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                  size: isMobile ? 160 : 190,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
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

class _PeersPanelState extends ConsumerState<_PeersPanel>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
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
    final state = ref.watch(transferControllerProvider);

    if (state.isScanningSubnet) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

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
              style: AppTypography.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Gap(14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _rotationController.repeat();
                    unawaited(
                      ref
                          .read(transferControllerProvider.notifier)
                          .triggerDiscoveryPulse()
                          .whenComplete(() {
                            if (mounted &&
                                !ref
                                    .read(transferControllerProvider)
                                    .isScanningSubnet) {
                              _rotationController.stop();
                              _rotationController.reset();
                            }
                          }),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(l10n.transferMobileRefresh),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showDirectIpDialog(context, ref),
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: Text(l10n.transferDirectIpTitle),
                ),
              ],
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
              if (peers.isNotEmpty) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${peers.length}',
                    style: AppTypography.caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 1. Refresh button (with rotation animation)
              IconButton(
                tooltip: l10n.transferMobileRefreshSearch,
                icon: RotationTransition(
                  turns: _rotationController,
                  child: const Icon(Icons.sync_rounded, size: 20),
                ),
                onPressed: () {
                  _rotationController.repeat();
                  unawaited(
                    ref
                        .read(transferControllerProvider.notifier)
                        .triggerDiscoveryPulse()
                        .whenComplete(() {
                          if (mounted &&
                              !ref
                                  .read(transferControllerProvider)
                                  .isScanningSubnet) {
                            _rotationController.stop();
                            _rotationController.reset();
                          }
                        }),
                  );
                },
              ),
              // 2. Subnet scan button
              IconButton(
                tooltip: l10n.transferScanSubnet,
                icon: const Icon(Icons.travel_explore_rounded, size: 20),
                onPressed: () {
                  unawaited(
                    ref.read(transferControllerProvider.notifier).scanSubnet(),
                  );
                },
              ),
              // 3. Direct IP button
              IconButton(
                tooltip: l10n.transferDirectIpTitle,
                icon: const Icon(Icons.add_link_rounded, size: 20),
                onPressed: () => _showDirectIpDialog(context, ref),
              ),
              // 4. Clear peer list button
              if (peers.isNotEmpty)
                IconButton(
                  tooltip: l10n.transferMobileClearList,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  onPressed: () {
                    ref.read(transferControllerProvider.notifier).clearPeers();
                  },
                ),
            ],
          ),
          if (state.isScanningSubnet) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.subnetScanProgress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
          ],
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

class _PeerTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
              IconButton(
                tooltip: peer.known
                    ? l10n.transferMobileUnmarkKnown
                    : l10n.transferMobileMarkKnown,
                icon: Icon(
                  peer.known ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: peer.known
                      ? const Color(0xFFF59E0B)
                      : colors.textSecondary.withValues(alpha: 0.45),
                  size: 20,
                ),
                onPressed: () {
                  ref
                      .read(transferControllerProvider.notifier)
                      .toggleTrusted(peer);
                },
              ),
              const Gap(4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                                : l10n.transferMobileUpToDateCount(
                                    preview.already,
                                  ))
                          : l10n.transferSend,
                      style: AppTypography.label.copyWith(
                        color:
                            (onlyNew &&
                                preview.found > 0 &&
                                preview.newest == 0)
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
                        color:
                            (onlyNew &&
                                preview.found > 0 &&
                                preview.newest == 0)
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
        _error = context.l10n.transferMobileDeviceNotFound;
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
              labelText: l10n.transferMobileIpAddress,
              prefixIcon: const Icon(Icons.lan_rounded, size: 20),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transferMobilePortDefault,
              prefixIcon: const Icon(Icons.tag_rounded, size: 20),
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
  const _PayloadPanel({super.key, required this.state, required this.fill});

  final TransferUiState state;
  final bool fill;

  @override
  ConsumerState<_PayloadPanel> createState() => _PayloadPanelState();
}

class _PayloadPanelState extends ConsumerState<_PayloadPanel> {
  final _query = TextEditingController();
  final _scrollController = ScrollController();
  late final _demoMedia = createShowcaseDownloads()
      .where((item) => item.status == DownloadStatus.completed)
      .toList(growable: false);
  final Set<String> _demoSelectedIds = {
    'showcase-squeezie-imposteur',
    'showcase-jujutsu-kaisen-trailer',
    'showcase-one-piece-trailer',
  };

  Widget _demoThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && isAllowedShowcaseThumbnailUrl(uri)) {
      return Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => const Icon(Icons.movie_outlined),
      );
    }
    return Image.asset(url, width: 48, height: 48, fit: BoxFit.cover);
  }

  void _showDemoFileNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.transferMobileDemoNoFiles)),
    );
  }

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
    final l10n = context.l10n;
    final parts = <String>[
      if (selectedCreators > 0)
        l10n.transferMobileCreatorCount(selectedCreators),
      if (extraFolders > 0) l10n.transferMobileFolderCount(extraFolders),
      if (extraFiles > 0) l10n.transferMobileFileCount(extraFiles),
    ];
    return parts.join(_metaSep);
  }

  Future<void> _pickFoldersFlow() async {
    if (ref.read(showcaseModeProvider)) return;
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
          SnackBar(
            content: Text(
              context.l10n.transferMobileFolderPickError(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final state = widget.state;
    final isShowcase = ref.watch(showcaseModeProvider);
    final folders = ref.watch(creatorFoldersProvider).folders;
    final selected = state.selectedCreatorKeys;
    final allSelected = isShowcase
        ? _demoSelectedIds.length == _demoMedia.length
        : folders.isNotEmpty && selected.length >= folders.length;
    final hits = TransferCreatorQuery.matches(folders, _query.text);
    final folderByKey = {for (final folder in folders) folder.key: folder};
    final hasAnyPayload =
        selected.isNotEmpty ||
        state.extraFolders.isNotEmpty ||
        state.extraFiles.isNotEmpty ||
        state.selectedFilesCount > 0 ||
        (isShowcase && _demoSelectedIds.isNotEmpty);

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: colors.primary,
                      ),
                      const Gap(6),
                      Text(
                        isShowcase
                            ? '${l10n.transferMobileMediaCount(_demoSelectedIds.length)}${PlatformInfo.isMobile ? ', ' : ' · '}${l10n.transferMobileSimulation}'
                            : '${l10n.transferMobileVideoCount(state.selectedFilesCount)}$_metaSep${FormatUtils.formatBytes(state.selectedTotalBytes)}',
                        style: _numStyle(
                          context,
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
                  if (isShowcase) {
                    setState(() {
                      if (allSelected) {
                        _demoSelectedIds.clear();
                      } else {
                        _demoSelectedIds.addAll(
                          _demoMedia.map((item) => item.id),
                        );
                      }
                    });
                    return;
                  }
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
                label: l10n.transferMobileFoldersAction,
                onTap: isShowcase ? _showDemoFileNotice : _pickFoldersFlow,
              ),
              _QuickAction(
                icon: Icons.video_library_outlined,
                label: l10n.transferMobileVideosAction,
                onTap: () {
                  if (isShowcase) {
                    _showDemoFileNotice();
                    return;
                  }
                  unawaited(
                    ref
                        .read(transferControllerProvider.notifier)
                        .addExtraFiles(),
                  );
                },
              ),
            ],
          ),
          if (!isShowcase && hasAnyPayload && state.sendPreview.found > 0) ...[
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
          if (!isShowcase && hasAnyPayload) ...[
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
              hintText: isShowcase
                  ? l10n.transferMobileSearchDemoMedia
                  : l10n.transferSearchCreator,
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
          if ((isShowcase && _demoSelectedIds.isNotEmpty) ||
              selected.isNotEmpty ||
              state.extraFolders.isNotEmpty ||
              state.extraFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isShowcase
                          ? '${l10n.transferMobileMediaSelected(_demoSelectedIds.length)}${PlatformInfo.isMobile ? ', ' : ' · '}${l10n.transferMobileNoDataSent}'
                          : _selectionSummary(
                              selectedCreators: selected.length,
                              extraFolders: state.extraFolders.length,
                              extraFiles: state.extraFiles.length,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _numStyle(
                        context,
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Gap(8),
                  TextButton(
                    onPressed: () {
                      if (isShowcase) {
                        setState(_demoSelectedIds.clear);
                        return;
                      }
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
                  children: isShowcase
                      ? _buildDemoMediaList(colors)
                      : _buildPayloadList(
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
            ...(isShowcase
                ? _buildDemoMediaList(colors)
                : _buildPayloadList(
                    state: state,
                    folders: folders,
                    selected: selected,
                    allSelected: allSelected,
                    hits: hits,
                    folderByKey: folderByKey,
                  )),
        ],
      ),
    );
  }

  List<Widget> _buildDemoMediaList(AppColors colors) {
    final query = _query.text.trim().toLowerCase();
    return [
      for (final item in _demoMedia)
        if (query.isEmpty || (item.title ?? '').toLowerCase().contains(query))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.surfaceHighlight.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  if (!_demoSelectedIds.add(item.id)) {
                    _demoSelectedIds.remove(item.id);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _demoSelectedIds.contains(item.id),
                        onChanged: (_) => setState(() {
                          if (!_demoSelectedIds.add(item.id)) {
                            _demoSelectedIds.remove(item.id);
                          }
                        }),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _demoThumbnail(item.thumbnailUrl!),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title ??
                                  context.l10n.transferMobileMediaFallback,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.totalSize,
                              style: AppTypography.mono.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
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
    ];
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
                  ? l10n.transferMobileLibraryNewOfTotal(
                      l10n.transferEntireLibrary,
                      preview.newest,
                      preview.found,
                    )
                  : l10n.transferEntireLibrary,
            ),
            onDeleted: () {
              ref.read(transferControllerProvider.notifier).clearCreators();
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
                        ? l10n.transferMobileNameNewCount(
                            baseName,
                            counts.newest,
                          )
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
            ref.read(transferControllerProvider.notifier).removeExtraFile(path);
          },
        ),
      ],
      if (_query.text.trim().isNotEmpty) ...[
        const Gap(8),
        if (hits.isEmpty)
          Text(
            l10n.transferNoCreatorMatch,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
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
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
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
                  '${l10n.transferVideosFound(preview.found)}$_metaSep${l10n.transferAlreadyTransferred(preview.already)}$_metaSep${l10n.transferNewVideos(preview.newest)}',
                  style: _numStyle(
                    context,
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
                    color: onlyNewVideos
                        ? colors.primary
                        : colors.textSecondary,
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
                      style: _numStyle(
                        context,
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
    final l10n = context.l10n;
    // Text drawn on the primary fill. White everywhere except on mobile, where
    // the OLED primary is near white.
    final onPrimary = PlatformInfo.isMobile ? colors.onPrimary : Colors.white;

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
                            ? '${l10n.transferMobileVideosZipped(count)}$_metaSep${FormatUtils.formatBytes(totalBytes)}'
                            : '${l10n.transferMobileVideoCount(count)}$_metaSep${FormatUtils.formatBytes(totalBytes)}',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          PlatformInfo.isMobile
                              ? l10n.transferMobileZipActive
                              : l10n.transferMobileZipActive.toUpperCase(),
                          style: _numStyle(
                            context,
                            fontSize: PlatformInfo.isMobile ? 11 : 9,
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
                      ? (count > 50
                            ? l10n.transferMobileZipHintLarge
                            : l10n.transferMobileZipHintMulti)
                      : l10n.transferMobileZipHintOff,
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
            message: l10n.transferMobileZipTooltip,
            child: InkWell(
              onTap: onToggleZip,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
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
                      compressZip
                          ? Icons.check_rounded
                          : Icons.archive_outlined,
                      size: 15,
                      color: compressZip ? onPrimary : colors.textSecondary,
                    ),
                    const Gap(6),
                    Text(
                      compressZip
                          ? l10n.transferMobileZipEnabled
                          : l10n.transferMobileZipArchive,
                      style: AppTypography.caption.copyWith(
                        color: compressZip ? onPrimary : colors.textPrimary,
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
                child: Icon(
                  Icons.folder_copy_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.transferMobileSubfoldersTitle,
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    Text(
                      l10n.transferMobileSubfoldersFoundIn(parentName),
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
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
              hintText: l10n.transferMobileSubfoldersFilter,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
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
                label: Text(l10n.transferMobileCheckAll),
              ),
              const Gap(8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selected.removeAll(filtered);
                  });
                },
                icon: const Icon(Icons.deselect_rounded, size: 16),
                label: Text(l10n.transferMobileUncheckAll),
              ),
              const Spacer(),
              Text(
                l10n.transferMobileSelectedOfTotal(
                  _selected.length,
                  widget.subfolders.length,
                ),
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
                      l10n.transferMobileNoFolderMatch,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
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
                          color: isChecked
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        title: Text(
                          name,
                          style: AppTypography.body.copyWith(
                            color: isChecked
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontWeight: isChecked
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        activeColor: colors.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
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
          label: Text(l10n.transferMobileAddFolders(_selected.length)),
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
    if (PlatformInfo.isMobile) {
      return OledChip(label: label, selected: selected, onTap: onTap);
    }
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

/// Separator for compact meta strings: a comma on the OLED mobile layout.
String get _metaSep => PlatformInfo.isMobile ? ', ' : ' • ';

/// Style for small figures: mono on desktop, tabular UI font on mobile.
TextStyle _numStyle(
  BuildContext context, {
  required double fontSize,
  required Color color,
  FontWeight? fontWeight,
}) {
  if (PlatformInfo.isMobile) {
    return OledText.ui(
      context,
      size: fontSize,
      weight: fontWeight ?? FontWeight.w500,
      color: color,
    );
  }
  return AppTypography.mono.copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

String _peerKind(AppLocalizations l10n, TransferPeer peer) {
  final model = peer.deviceModel;
  if (model != null && model.trim().isNotEmpty) return model.trim();
  return switch (peer.deviceType) {
    TransferDeviceType.mobile => l10n.transferMobileKindMobile,
    TransferDeviceType.desktop => l10n.transferMobileKindDesktop,
    TransferDeviceType.web => l10n.transferMobileKindWeb,
    TransferDeviceType.headless => l10n.transferMobileKindHeadless,
    TransferDeviceType.server => l10n.transferMobileKindServer,
  };
}

/// Freshness of a peer, from 1 to 4 bars. There is no radio signal strength
/// on a LAN, so this reflects how recently the device announced itself.
int _peerSignal(TransferPeer peer) {
  final seen = peer.lastSeen;
  if (seen == null) return 4;
  final minutes = DateTime.now().difference(seen).inMinutes;
  if (minutes < 2) return 4;
  if (minutes < 10) return 3;
  if (minutes < 30) return 2;
  return 1;
}

/// Android OLED layout of the transfer screen. Same controller and same
/// actions as the desktop layout, restyled with the OLED kit.
class _OledTransferBody extends ConsumerWidget {
  const _OledTransferBody({required this.state});

  final TransferUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(transferControllerProvider.notifier);
    final receiving = state.activeTab == TransferTab.receive;
    final peers = state.peers;

    void sendTo(TransferPeer peer) {
      if (ref.read(showcaseModeProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.transferMobileDemoSendSimulated)),
        );
        return;
      }
      unawaited(notifier.sendTo(peer));
    }

    final transferCard = (state.progress != null || state.diagnostic != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _OledTransferCard(
              progress: state.progress,
              diagnostic: state.diagnostic,
              scanStatus: state.scanStatus,
              lastError: state.lastError,
              onRetry: notifier.retryLastTransfer,
              onCancel: notifier.cancelTransfer,
            ),
          )
        : null;

    final nearby = l10n.transferMobileNearbyCount(peers.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                receiving
                    ? l10n.transferMobileHeaderReceiving
                    : l10n.transferMobileHeaderSending,
                style: OledText.title(context),
              ),
            ),
            if (state.lanIp != null) _OledNetworkChip(ip: state.lanIp!),
          ],
        ),
        if (state.portConflict)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.transferMobilePortAltActive(state.port ?? 53318),
              style: OledText.ui(context, size: 12, color: t.warn),
            ),
          ),
        const SizedBox(height: 16),
        OledCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.transferMobileReceiveFiles,
                      style: OledText.ui(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receiving
                          ? l10n.transferMobileVisibleOnLan
                          : l10n.transferMobileShowPinQr,
                      style: OledText.ui(context, size: 12, color: t.ink2),
                    ),
                  ],
                ),
              ),
              OledToggle(
                value: receiving,
                onChanged: (on) => notifier.setTab(
                  on ? TransferTab.receive : TransferTab.send,
                ),
              ),
            ],
          ),
        ),
        if (receiving) ...[
          const SizedBox(height: 16),
          _OledReceivePanel(state: state),
          if (transferCard != null) transferCard,
        ] else ...[
          const SizedBox(height: 8),
          Center(
            child: DotRadar(
              size: 240,
              blips: [
                for (final peer in peers.take(4))
                  peer.deviceType == TransferDeviceType.mobile
                      ? Icons.smartphone_rounded
                      : Icons.desktop_windows_rounded,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  nearby,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.ui(
                    context,
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              OledIconButton(
                icon: Icons.sync_rounded,
                tooltip: l10n.transferMobileRefreshSearch,
                outlined: false,
                onPressed: () => unawaited(notifier.triggerDiscoveryPulse()),
              ),
            ],
          ),
          if (state.isScanningSubnet)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: state.subnetScanProgress,
                  minHeight: 2,
                  backgroundColor: t.line,
                  valueColor: AlwaysStoppedAnimation<Color>(t.ink),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OledChip(
                label: l10n.transferScanSubnet,
                selected: false,
                onTap: () => unawaited(notifier.scanSubnet()),
              ),
              OledChip(
                label: l10n.transferDirectIpTitle,
                selected: false,
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => const _DirectIpDialog(),
                  );
                },
              ),
              if (peers.isNotEmpty)
                OledChip(
                  label: l10n.transferMobileClearList,
                  selected: false,
                  onTap: notifier.clearPeers,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (peers.isEmpty)
            OledCard(
              radius: 20,
              child: Text(
                l10n.transferNoDevices,
                style: OledText.ui(context, size: 14, color: t.ink2),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < peers.length; i++)
                    _OledPeerRow(
                      peer: peers[i],
                      preview: state.sendPreview,
                      onlyNew: state.onlyNewVideos,
                      emphasis: i == 0,
                      showDivider: i < peers.length - 1,
                      onSend: () => sendTo(peers[i]),
                    ),
                ],
              ),
            ),
          if (transferCard != null) transferCard,
          const SizedBox(height: 20),
          _PayloadPanel(
            key: OnboardingTargets.transfer,
            state: state,
            fill: false,
          ),
        ],
      ],
    );
  }
}

class _OledNetworkChip extends StatelessWidget {
  const _OledNetworkChip({required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            ip,
            style: OledText.ui(context, size: 13, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _OledPeerRow extends ConsumerWidget {
  const _OledPeerRow({
    required this.peer,
    required this.preview,
    required this.onlyNew,
    required this.emphasis,
    required this.showDivider,
    required this.onSend,
  });

  final TransferPeer peer;
  final SendPreview preview;
  final bool onlyNew;
  final bool emphasis;
  final bool showDivider;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final hasPreview = onlyNew && preview.found > 0;
    final upToDate = hasPreview && preview.newest == 0;
    final fresh = preview.newest;
    final meta = [
      _peerKind(l10n, peer),
      peer.ip,
      if (hasPreview && fresh > 0) l10n.transferMobileNewVideosCount(fresh),
    ].join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: t.line.withValues(alpha: 0.07)))
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 66),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          child: Row(
            children: [
              _SignalBars(level: _peerSignal(peer)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      peer.alias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OledText.ui(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OledText.ui(context, size: 12, color: t.ink2),
                    ),
                  ],
                ),
              ),
              OledIconButton(
                icon: peer.known
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                tooltip: peer.known
                    ? l10n.transferMobileUnmarkKnown
                    : l10n.transferMobileMarkKnown,
                outlined: false,
                color: peer.known ? t.ink : t.ink3,
                onPressed: () => unawaited(
                  ref
                      .read(transferControllerProvider.notifier)
                      .toggleTrusted(peer),
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: OledButton(
                  label: upToDate
                      ? l10n.transferMobileUpToDate
                      : l10n.transferSend,
                  onPressed: onSend,
                  filled: emphasis && !upToDate,
                  height: 44,
                  expand: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final ink = OledTokens.of(context).ink;
    return SizedBox(
      width: 20,
      height: 16,
      child: CustomPaint(
        painter: _SignalBarsPainter(level: level, ink: ink),
      ),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  _SignalBarsPainter({required this.level, required this.ink});

  final int level;
  final Color ink;

  static const List<double> _tops = [10.0, 6.5, 3.0, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _tops.length; i++) {
      final left = i * 5.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, _tops[i], left + 4, 16),
        const Radius.circular(1),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = ink.withValues(alpha: i < level ? 1.0 : 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_SignalBarsPainter old) =>
      old.level != level || old.ink != ink;
}

class _OledTransferCard extends StatelessWidget {
  const _OledTransferCard({
    required this.progress,
    required this.diagnostic,
    required this.scanStatus,
    required this.lastError,
    required this.onRetry,
    required this.onCancel,
  });

  final TransferProgress? progress;
  final TransferDiagnostic? diagnostic;
  final TransferScanStatus? scanStatus;
  final String? lastError;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final current = progress;
    final failed = current?.phase == TransferPhase.failed || diagnostic != null;
    final done = current?.phase == TransferPhase.done;
    // Non-null only while a transfer is actually running.
    final TransferProgress? live = (current != null && !failed && !done)
        ? current
        : null;
    final showPercent =
        live != null && live.phase == TransferPhase.transferring;
    final title = current != null
        ? _progressLabel(l10n, current)
        : _noticeTitle(l10n, diagnostic, lastError);
    final percent = current == null ? 0 : (current.fraction * 100).round();

    String? meta;
    if (live != null) {
      if (live.phase == TransferPhase.preparing && scanStatus != null) {
        meta = _scanText(l10n, scanStatus!);
      } else {
        meta = l10n.transferMobileBytesOf(
          FormatUtils.formatBytes(live.bytesDone),
          FormatUtils.formatBytes(live.bytesTotal),
        );
        if (live.bytesPerSecond > 0) {
          meta =
              '$meta, ${FormatUtils.formatBytes(live.bytesPerSecond.round())}/s';
        }
      }
    }

    return OledCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (failed || done) ...[
                Icon(
                  failed
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: failed ? t.warn : t.ink,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.ui(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                    color: failed ? t.warn : t.ink,
                  ),
                ),
              ),
              if (showPercent) ...[
                const SizedBox(width: 12),
                Text('$percent', style: OledText.dot(context, size: 26)),
                const SizedBox(width: 4),
                Text(
                  '%',
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: t.ink2,
                  ),
                ),
              ],
              OledIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.transferCancel,
                outlined: false,
                onPressed: onCancel,
              ),
            ],
          ),
          if (live != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: live.fraction > 0 ? live.fraction : null,
                  minHeight: 4,
                  backgroundColor: t.ink.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(t.ink),
                ),
              ),
            ),
            if (meta != null) ...[
              const SizedBox(height: 8),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(context, size: 12, color: t.ink2),
              ),
            ],
          ],
          if (diagnostic != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Text(
                _diagnosticText(l10n, diagnostic!),
                style: OledText.ui(context, size: 12, color: t.ink2),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OledButton(
                  label: l10n.transferRetry,
                  icon: Icons.refresh_rounded,
                  filled: false,
                  height: 44,
                  expand: false,
                  onPressed: onRetry,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OledReceivePanel extends ConsumerStatefulWidget {
  const _OledReceivePanel({required this.state});

  final TransferUiState state;

  @override
  ConsumerState<_OledReceivePanel> createState() => _OledReceivePanelState();
}

class _OledReceivePanelState extends ConsumerState<_OledReceivePanel> {
  bool _showQr = false;

  void _copy(String text, String message) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final state = widget.state;
    final qr = state.qrUrl;
    final directUrl = 'http://${state.lanIp}:${state.port}';

    return OledCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone_rounded, size: 20, color: t.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.ui(
                    context,
                    size: 18,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.transferListeningOn,
            style: OledText.ui(context, size: 12, color: t.ink2),
          ),
          const SizedBox(height: 16),
          if (qr == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                state.lastError ?? l10n.transferWaitingNetwork,
                textAlign: TextAlign.center,
                style: OledText.ui(context, size: 14, color: t.ink2),
              ),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: t.ink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.transferMobileReadyToReceive,
                        style: OledText.ui(
                          context,
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.transferMobileVisibleOnWifi,
                        style: OledText.ui(context, size: 12, color: t.ink2),
                      ),
                    ],
                  ),
                ),
                OledIconButton(
                  icon: Icons.wifi_tethering_rounded,
                  tooltip: l10n.transferMobileBroadcastTooltip,
                  onPressed: () {
                    unawaited(
                      ref
                          .read(transferControllerProvider.notifier)
                          .triggerDiscoveryPulse(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.transferMobileBroadcastDone),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.transferMobilePinLabel,
              textAlign: TextAlign.center,
              style: OledText.ui(context, size: 12, color: t.ink2),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.pin, style: OledText.dot(context, size: 44)),
                const SizedBox(width: 8),
                OledIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: l10n.transferCopyLink,
                  outlined: false,
                  onPressed: () => _copy(
                    state.pin,
                    'PIN ${state.pin} ${l10n.transferCopied}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OledButton(
              label: directUrl,
              icon: Icons.link_rounded,
              filled: false,
              height: 48,
              onPressed: () =>
                  _copy(directUrl, '$directUrl ${l10n.transferCopied}'),
            ),
            const SizedBox(height: 10),
            OledButton(
              label: _showQr
                  ? l10n.transferMobileQrHide
                  : l10n.transferMobileQrShow,
              icon: _showQr
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.qr_code_2_rounded,
              filled: false,
              height: 48,
              onPressed: () => setState(() => _showQr = !_showQr),
            ),
            if (_showQr) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: qr,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
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
