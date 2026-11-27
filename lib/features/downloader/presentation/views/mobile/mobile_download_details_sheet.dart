import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';
import 'package:tapload/core/design_system/components/app_toast.dart';
import 'package:tapload/core/download/download_file_resolver.dart';
import 'package:tapload/core/download/download_status_guard.dart';
import 'package:tapload/core/download/extraction_placeholders.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/services/title_cleaner_service.dart';
import 'package:tapload/core/ui/media_player/media_player_provider.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/domain/enums/download_status.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/features/downloader/presentation/providers/live_activity.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// BottomSheet component replacing the desktop inspector on mobile.
/// Provides touch-friendly controls, a step-by-step failure diagnostic,
/// collapsible technical logs, and native Android sharing/viewing intents.
class MobileDownloadDetailsSheet extends ConsumerStatefulWidget {
  final String downloadId;

  const MobileDownloadDetailsSheet({super.key, required this.downloadId});

  static Future<void> show(BuildContext context, String downloadId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileDownloadDetailsSheet(downloadId: downloadId),
    );
  }

  @override
  ConsumerState<MobileDownloadDetailsSheet> createState() =>
      _MobileDownloadDetailsSheetState();
}

/// Plain-language reading of a failed download.
class _Diagnosis {
  const _Diagnosis({required this.code, required this.headline});

  /// HTTP-like status code found in the error, when any.
  final String? code;
  final String headline;
}

class _MobileDownloadDetailsSheetState
    extends ConsumerState<MobileDownloadDetailsSheet> {
  static const int _stepCount = 5;

  static String _stepLabel(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.detailsStepResolve;
      case 1:
        return l10n.detailsStepReadPage;
      case 2:
        return l10n.detailsStepExtractFormats;
      case 3:
        return l10n.detailsStepDownload;
      default:
        return l10n.detailsStepMerge;
    }
  }

  bool _isUpdatingEngine = false;
  bool _engineUpdateFailed = false;
  String? _engineUpdateStatus;
  bool _logsOpen = false;

  /// Updates yt-dlp. Returns true when the update succeeded.
  Future<bool> _updateEngine() async {
    setState(() {
      _isUpdatingEngine = true;
      _engineUpdateFailed = false;
      _engineUpdateStatus = null;
    });
    await HapticFeedback.mediumImpact();
    try {
      final status = await AndroidEngineBridge.instance.updateYtDlp();
      if (!mounted) return false;
      setState(() {
        _isUpdatingEngine = false;
        _engineUpdateStatus = context.l10n.detailsEngineUpdated(status);
      });
      AppToast.showSuccess(
        context,
        context.l10n.detailsYtDlpUpdateSuccess(status),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isUpdatingEngine = false;
        _engineUpdateFailed = true;
        _engineUpdateStatus = context.l10n.detailsEngineUpdateError('$e');
      });
      return false;
    }
  }

  /// Engine update followed by a fresh attempt.
  Future<void> _repair(DownloadItem item) async {
    final updated = await _updateEngine();
    if (!updated || !mounted) return;
    unawaited(ref.read(downloadListProvider.notifier).retryDownload(item));
    Navigator.of(context).pop();
  }

  void _retry(DownloadItem item) {
    HapticFeedback.lightImpact();
    ref.read(downloadListProvider.notifier).retryDownload(item);
    Navigator.of(context).pop();
  }

  void _delete(DownloadItem item) {
    HapticFeedback.mediumImpact();
    ref.read(downloadListProvider.notifier).deleteDownload(item.id);
    Navigator.of(context).pop();
  }

  void _copyLink(DownloadItem item) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: item.request.url));
    AppToast.showInfo(context, context.l10n.detailsLinkCopied);
  }

  void _openInBrowser(DownloadItem item) {
    HapticFeedback.lightImpact();
    if (PlatformInfo.isAndroid) {
      AndroidEngineBridge.instance.openUrl(item.request.url);
    } else {
      Process.run('cmd', [
        '/c',
        'start',
        '',
        item.request.url,
      ], runInShell: true);
    }
  }

  void _play(String playablePath) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ref.read(mediaPlayerProvider.notifier).openFile(playablePath);
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(widget.downloadId));

    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: Center(
          child: Text(
            l10n.selectDownload,
            style: OledText.ui(context, size: 14, color: t.ink2),
          ),
        ),
      );
    }

    final displayTitle =
        item.status == DownloadStatus.extracting &&
            ExtractionPlaceholders.isGenericTitle(item.title)
        ? l10n.extractingTitle
        : TitleCleanerService.clean(item.title ?? l10n.unknown);

    final playablePath = DownloadFileResolver.resolvePlayablePath(
      item.filePath,
      title: item.title,
      outputFolder: item.request.outputFolder,
    );
    final hasPlayableFile =
        playablePath != null && File(playablePath).existsSync();
    final failed = item.status == DownloadStatus.failed;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(child: _buildStatusLabel(context, t, item.status)),
                  OledIconButton(
                    icon: Icons.close_rounded,
                    tooltip: l10n.close,
                    outlined: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: failed
                    ? _buildFailedBody(context, t, item, displayTitle)
                    : _buildStandardBody(
                        context,
                        t,
                        item,
                        displayTitle,
                        playablePath,
                        hasPlayableFile,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  static bool _isLive(DownloadStatus status) =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.extracting ||
      status == DownloadStatus.processing;

  static String _statusText(AppLocalizations l10n, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return l10n.statusCompleted;
      case DownloadStatus.failed:
        return l10n.detailsStatusFailed;
      case DownloadStatus.downloading:
        return l10n.detailsStatusDownloading;
      case DownloadStatus.extracting:
        return l10n.detailsStatusExtracting;
      case DownloadStatus.processing:
        return l10n.statusProcessing;
      case DownloadStatus.paused:
        return l10n.statusPaused;
      case DownloadStatus.canceled:
        return l10n.statusCanceled;
      case DownloadStatus.duplicate:
        return l10n.detailsStatusDuplicate;
      case DownloadStatus.queued:
        return l10n.statusQueued;
    }
  }

  Widget _buildStatusLabel(
    BuildContext context,
    OledTokens t,
    DownloadStatus status,
  ) {
    final failed = status == DownloadStatus.failed;
    final l10n = context.l10n;
    final text = failed ? l10n.detailsDiagnostic : _statusText(l10n, status);
    return Row(
      children: [
        if (_isLive(status)) ...[
          const OledLiveDot(),
          const Gap(8),
        ] else if (failed) ...[
          Icon(Icons.error_outline_rounded, size: 18, color: t.warn),
          const Gap(8),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OledText.ui(
              context,
              size: 15,
              weight: FontWeight.w600,
              color: failed ? t.warn : t.ink,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Completed / active items
  // ---------------------------------------------------------------------------

  Widget _buildStandardBody(
    BuildContext context,
    OledTokens t,
    DownloadItem item,
    String displayTitle,
    String? playablePath,
    bool hasPlayableFile,
  ) {
    final l10n = context.l10n;
    final host = _hostOf(item.request.url);
    final metaParts = <String>[
      if (item.status == DownloadStatus.completed ||
          item.status == DownloadStatus.canceled)
        _statusText(l10n, item.status),
      if (item.totalSize.isNotEmpty) item.totalSize,
      if (item.source.isNotEmpty) item.source else if (host.isNotEmpty) host,
    ];
    final showProgress =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.processing ||
        item.status == DownloadStatus.paused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPreview(context, t, item, playablePath, hasPlayableFile),
        const Gap(16),
        Text(
          displayTitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: OledText.title(context, size: 22),
        ),
        if (metaParts.isNotEmpty) ...[
          const Gap(6),
          Text(
            metaParts.join(', '),
            style: OledText.ui(context, size: 13, color: t.ink2),
          ),
        ],
        if (showProgress) ...[const Gap(18), _buildProgress(context, t, item)],
        const Gap(20),
        _buildStandardActions(context, t, item, playablePath, hasPlayableFile),
        const Gap(20),
        _buildInfoCard(context, t, item, playablePath),
      ],
    );
  }

  Widget _buildPreview(
    BuildContext context,
    OledTokens t,
    DownloadItem item,
    String? playablePath,
    bool hasPlayableFile,
  ) {
    final thumb = item.thumbnailUrl;
    final isRemote =
        thumb != null &&
        (thumb.startsWith('http://') || thumb.startsWith('https://'));
    final isLocal = thumb != null && thumb.isNotEmpty && !isRemote;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            fit: StackFit.expand,
            children: [
              OledThumb(
                url: isRemote ? thumb : null,
                width: box.maxWidth,
                height: box.maxHeight,
                radius: 18,
              ),
              if (isLocal)
                Padding(
                  padding: const EdgeInsets.all(1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image(
                      image: FileImage(File(thumb)),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (hasPlayableFile)
                Center(
                  child: Material(
                    color: t.ink,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _play(playablePath!),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: t.onInk,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// "6,2 Mo/s" when the speed can be read, the raw text otherwise.
  String _speedText(AppLocalizations l10n, String raw) {
    final bytes = parseSpeed(raw);
    if (bytes == null) return raw;
    final label = formatSpeed(l10n, bytes);
    return '${label.value} ${label.unit}';
  }

  Widget _buildProgress(BuildContext context, OledTokens t, DownloadItem item) {
    final l10n = context.l10n;
    final percent = (item.progress.clamp(0.0, 1.0) * 100).round();
    final live = item.status != DownloadStatus.paused;
    final stats = <String>[
      if (item.downloadedSize.isNotEmpty && item.totalSize.isNotEmpty)
        l10n.downloadCardSizeOf(item.downloadedSize, item.totalSize)
      else if (item.totalSize.isNotEmpty)
        item.totalSize,
      if (live && item.speed.isNotEmpty) _speedText(l10n, item.speed),
      if (live && item.eta.isNotEmpty) etaLabel(l10n, item.eta),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$percent', style: OledText.dot(context, size: 56)),
            const Gap(6),
            Text(
              '%',
              style: OledText.ui(
                context,
                size: 16,
                weight: FontWeight.w600,
                color: t.ink2,
              ),
            ),
          ],
        ),
        const Gap(10),
        OledFragmentMap(
          progress: item.progress,
          active: item.status == DownloadStatus.paused ? 0 : 4,
        ),
        if (stats.isNotEmpty) ...[
          const Gap(10),
          Text(
            stats.join(', '),
            style: OledText.ui(context, size: 12, color: t.ink2),
          ),
        ],
      ],
    );
  }

  Widget _buildStandardActions(
    BuildContext context,
    OledTokens t,
    DownloadItem item,
    String? playablePath,
    bool hasPlayableFile,
  ) {
    final l10n = context.l10n;
    final canRestart =
        item.status == DownloadStatus.completed ||
        item.status == DownloadStatus.canceled;
    final tiles = <Widget>[
      if (hasPlayableFile && PlatformInfo.isAndroid) ...[
        _ActionTile(
          label: l10n.detailsShare,
          onTap: () {
            HapticFeedback.lightImpact();
            AndroidEngineBridge.instance.shareFile(playablePath!);
          },
        ),
        _ActionTile(
          label: l10n.detailsOpenWith,
          onTap: () {
            HapticFeedback.lightImpact();
            AndroidEngineBridge.instance.viewFile(playablePath!);
          },
        ),
      ],
      _ActionTile(label: l10n.detailsCopyLink, onTap: () => _copyLink(item)),
      if (canRestart)
        _ActionTile(
          label: item.status == DownloadStatus.completed
              ? l10n.detailsRestart
              : l10n.retry,
          onTap: () => _retry(item),
        ),
      _ActionTile(
        label: l10n.delete,
        color: t.warn,
        onTap: () => _delete(item),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPlayableFile) ...[
          OledButton(
            label: l10n.detailsPlayVideo,
            icon: Icons.play_arrow_rounded,
            onPressed: () => _play(playablePath!),
          ),
          const Gap(10),
        ],
        _buildTileGrid(tiles),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    OledTokens t,
    DownloadItem item,
    String? playablePath,
  ) {
    final l10n = context.l10n;
    return OledCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailsInfoTitle,
            style: OledText.ui(context, size: 15, weight: FontWeight.w600),
          ),
          const Gap(10),
          _detailRow(
            context,
            t,
            l10n.detailsInfoSource,
            item.source.isNotEmpty ? item.source : 'Web',
          ),
          if (item.totalSize.isNotEmpty)
            _detailRow(context, t, l10n.detailsInfoSize, item.totalSize),
          if (playablePath != null)
            _detailRow(
              context,
              t,
              l10n.detailsInfoFile,
              playablePath.split(Platform.pathSeparator).last,
            ),
          _detailRow(context, t, l10n.detailsInfoId, item.id),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    OledTokens t,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: OledText.ui(context, size: 12, color: t.ink2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: OledText.ui(context, size: 12, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Failed items
  // ---------------------------------------------------------------------------

  Widget _buildFailedBody(
    BuildContext context,
    OledTokens t,
    DownloadItem item,
    String displayTitle,
  ) {
    final l10n = context.l10n;
    final rawError = item.error ?? '';
    final host = _hostOf(item.request.url);
    final isAgeVerification = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    final diagnosis = _diagnose(
      l10n,
      rawError,
      host: host,
      isAgeVerification: isAgeVerification,
    );
    final blockedByWifiOnly = rawError.toLowerCase().contains(
      'wi-fi only is on',
    );
    final failedStep = blockedByWifiOnly ? 0 : _failedStepIndex(item);
    final subtitle = [displayTitle, if (host.isNotEmpty) host].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (diagnosis.code != null)
          Text(
            diagnosis.code!,
            style: OledText.dot(context, size: 88, color: t.warn),
          ),
        if (diagnosis.code != null) const Gap(8),
        Text(
          diagnosis.headline,
          style: OledText.ui(
            context,
            size: 20,
            weight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const Gap(3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: OledText.ui(context, size: 13, color: t.ink2),
        ),
        const Gap(18),
        _buildSteps(context, t, failedStep),
        const Gap(14),
        if (!blockedByWifiOnly) ...[
          OledButton(
            label: _isUpdatingEngine
                ? l10n.detailsUpdatingEngine
                : l10n.detailsRepairAuto,
            height: 56,
            onPressed: _isUpdatingEngine ? null : () => _repair(item),
          ),
          const Gap(8),
          OledButton(
            label: l10n.detailsSignInBrowser,
            filled: false,
            onPressed: () => _openInBrowser(item),
          ),
        ],
        if (isAgeVerification) ...[
          const Gap(8),
          OledButton(
            label: l10n.detailsAgeSolutions,
            filled: false,
            onPressed: () {
              HapticFeedback.lightImpact();
              AgeVerificationHelpDialog.show(context, item);
            },
          ),
        ],
        if (_engineUpdateStatus != null) ...[
          const Gap(8),
          Text(
            _engineUpdateStatus!,
            style: OledText.ui(
              context,
              size: 12,
              color: _engineUpdateFailed ? t.warn : t.ink2,
            ),
          ),
        ],
        const Gap(10),
        _buildTileGrid([
          _ActionTile(label: l10n.retry, onTap: () => _retry(item)),
          _ActionTile(
            label: l10n.detailsCopyLink,
            onTap: () => _copyLink(item),
          ),
          _ActionTile(
            label: l10n.delete,
            color: t.warn,
            onTap: () => _delete(item),
          ),
        ]),
        const Gap(12),
        _buildTechnicalDetails(context, t, rawError),
      ],
    );
  }

  Widget _buildSteps(BuildContext context, OledTokens t, int failedStep) {
    return OledCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
      child: Stack(
        children: [
          Positioned(
            left: 9,
            top: 14,
            bottom: 14,
            width: 2,
            child: ColoredBox(color: t.line),
          ),
          Column(
            children: [
              for (var i = 0; i < _stepCount; i++)
                _buildStepRow(context, t, i, failedStep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context,
    OledTokens t,
    int index,
    int failedStep,
  ) {
    final l10n = context.l10n;
    final label = _stepLabel(l10n, index);
    if (index < failedStep) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 13, color: t.onInk),
            ),
            const Gap(14),
            Expanded(child: Text(label, style: OledText.ui(context, size: 14))),
          ],
        ),
      );
    }
    if (index == failedStep) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.warn, shape: BoxShape.circle),
              child: Text(
                '!',
                style: OledText.ui(
                  context,
                  size: 13,
                  weight: FontWeight.w800,
                  color: t.onInk,
                ),
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: OledText.ui(
                      context,
                      size: 14,
                      weight: FontWeight.w700,
                      color: t.warn,
                    ),
                  ),
                  Text(
                    _stepFailureDetail(l10n, index),
                    style: OledText.ui(context, size: 12, color: t.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Opacity(
      opacity: 0.45,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: t.bg,
                shape: BoxShape.circle,
                border: Border.all(color: t.lineStrong, width: 1.5),
              ),
            ),
            const Gap(14),
            Expanded(child: Text(label, style: OledText.ui(context, size: 14))),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetails(
    BuildContext context,
    OledTokens t,
    String rawError,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _logsOpen = !_logsOpen);
            },
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.detailsTechnicalDetails,
                      style: OledText.ui(
                        context,
                        size: 13,
                        weight: FontWeight.w600,
                        color: t.ink2,
                      ),
                    ),
                  ),
                  Icon(
                    _logsOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: t.ink2,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_logsOpen)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    rawError.isEmpty ? l10n.detailsNoLogs : rawError,
                    style: OledText.log(
                      context,
                      color: rawError.isEmpty ? t.ink3 : t.warn,
                    ),
                  ),
                ),
                OledIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: l10n.detailsCopyLogs,
                  outlined: false,
                  color: t.ink2,
                  onPressed: rawError.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: rawError));
                          AppToast.showInfo(context, l10n.detailsLogsCopied);
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnosis helpers
  // ---------------------------------------------------------------------------

  static String _hostOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Which step of [_stepLabel] failed, derived from what the item reached.
  static int _failedStepIndex(DownloadItem item) {
    final step = item.step.toLowerCase();
    if (step.contains('merg') ||
        step.contains('ffmpeg') ||
        step.contains('recode') ||
        step.contains('fusion')) {
      return 4;
    }
    if (item.progress > 0 || item.downloadedSize.isNotEmpty) return 3;
    return 2;
  }

  static String _stepFailureDetail(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.detailsStepFailMetered;
      case 4:
        return l10n.detailsStepFailMerge;
      case 3:
        return l10n.detailsStepFailTransfer;
      default:
        return l10n.detailsStepFailNoMedia;
    }
  }

  /// Reads an error string (raw yt-dlp log or already-mapped message, see
  /// `YtDlpException`) into a status code and a plain-language headline.
  static _Diagnosis _diagnose(
    AppLocalizations l10n,
    String raw, {
    required String host,
    required bool isAgeVerification,
  }) {
    final lower = raw.toLowerCase();
    final code = _extractCode(raw);

    String headline;
    if (isAgeVerification) {
      headline = l10n.detailsHeadlineAgeVerification;
    } else if (lower.contains('wi-fi only is on')) {
      headline = l10n.detailsWifiOnlyHeadline;
    } else if (code == '403' && host.isNotEmpty) {
      headline = l10n.detailsHeadlineHostRefused(host);
    } else if (code == '429' ||
        lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('captcha') ||
        lower.contains('temporairement limitée')) {
      headline = l10n.detailsHeadlineTooManyRequests;
    } else if (lower.contains('private video') ||
        lower.contains('vidéo privée') ||
        lower.contains('status_self_see')) {
      headline = l10n.detailsHeadlinePrivateVideo;
    } else if (lower.contains('not available in your country') ||
        lower.contains('geo-restricted')) {
      headline = l10n.detailsHeadlineGeoBlocked;
    } else if (lower.contains('copyright')) {
      headline = l10n.detailsHeadlineCopyright;
    } else if (lower.contains('suspend')) {
      headline = l10n.detailsHeadlineSuspended;
    } else if (lower.contains('aucune vidéo dans ce tweet') ||
        lower.contains('no video could be found')) {
      headline = l10n.detailsHeadlineNoMedia;
    } else if (lower.contains('unsupported url') ||
        lower.contains('non prise en charge')) {
      headline = l10n.detailsHeadlineUnsupportedUrl;
    } else if (lower.contains('unavailable') ||
        lower.contains('indisponible') ||
        code == '404' ||
        code == '410') {
      headline = l10n.detailsHeadlineUnavailable;
    } else if (lower.contains('live stream')) {
      headline = l10n.detailsHeadlineLiveOffline;
    } else if (lower.contains('impersonat') ||
        lower.contains('curl_cffi') ||
        lower.contains('cloudflare') ||
        lower.contains('anti-bot') ||
        lower.contains('protection')) {
      headline = l10n.detailsHeadlineAntiBot;
    } else if (lower.contains('no video formats found') ||
        lower.contains('no formats found') ||
        lower.contains('aucun format') ||
        lower.contains('unable to extract')) {
      headline = l10n.detailsHeadlineNoFormats;
    } else if (lower.contains('connexion ou cookies') ||
        lower.contains('login required') ||
        lower.contains('sign in') ||
        lower.contains('requires authentication') ||
        code == '401') {
      headline = l10n.detailsHeadlineLoginRequired;
    } else if (lower.contains('network') ||
        lower.contains('timed out') ||
        lower.contains('connection') ||
        lower.contains('socket')) {
      headline = l10n.detailsHeadlineNetwork;
    } else {
      headline = l10n.detailsHeadlineFailed;
    }
    return _Diagnosis(code: code, headline: headline);
  }

  /// First 4xx/5xx status code found in [raw], if any.
  static String? _extractCode(String raw) {
    final patterns = [
      RegExp(r'HTTP(?:\s+Error)?\s*[:/]?\s*(\d{3})', caseSensitive: false),
      RegExp(
        r'\b(\d{3})\s+(?:Forbidden|Not Found|Too Many Requests|Unauthorized|'
        r'Gone|Bad Request|Service Unavailable|Internal Server Error|'
        r'Bad Gateway)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= 400 && value <= 599) {
        return '$value';
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Shared layout
  // ---------------------------------------------------------------------------

  /// Rows of up to three equally sized tiles.
  Widget _buildTileGrid(List<Widget> tiles) {
    const columns = 3;
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      final children = <Widget>[];
      for (var i = 0; i < columns; i++) {
        if (i > 0) children.add(const Gap(8));
        final index = start + i;
        children.add(
          Expanded(
            child: index < tiles.length ? tiles[index] : const SizedBox(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const Gap(8));
      rows.add(Row(children: children));
    }
    return Column(children: rows);
  }
}

/// Flat translucent action tile used in the grids.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Material(
      color: t.fillStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(
                  context,
                  size: 13,
                  weight: FontWeight.w600,
                  color: color ?? t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
