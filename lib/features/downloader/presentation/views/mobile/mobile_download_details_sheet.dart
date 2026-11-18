import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/android/android_engine_bridge.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/download/download_file_resolver.dart';
import 'package:modern_downloader/core/download/extraction_placeholders.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/download/download_status_guard.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/domain/enums/download_status.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/dialogs/age_verification_help_dialog.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// BottomSheet component replacing the desktop inspector on mobile.
/// Provides touch-friendly controls, actionable error cards, collapsible logs,
/// and native Android sharing/viewing intents.
class MobileDownloadDetailsSheet extends ConsumerStatefulWidget {
  final String downloadId;

  const MobileDownloadDetailsSheet({
    super.key,
    required this.downloadId,
  });

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

class _MobileDownloadDetailsSheetState
    extends ConsumerState<MobileDownloadDetailsSheet> {
  bool _isUpdatingEngine = false;
  String? _engineUpdateStatus;

  Future<void> _updateEngine() async {
    setState(() {
      _isUpdatingEngine = true;
      _engineUpdateStatus = null;
    });
    await HapticFeedback.mediumImpact();
    try {
      final status = await AndroidEngineBridge.instance.updateYtDlp();
      if (!mounted) return;
      setState(() {
        _isUpdatingEngine = false;
        _engineUpdateStatus = 'Moteur mis à jour : $status';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mise à jour yt-dlp réussie : $status'),
          backgroundColor: AppColors.of(context).primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingEngine = false;
        _engineUpdateStatus = 'Erreur lors de la mise à jour : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final item = ref.watch(downloadItemByIdProvider(widget.downloadId));

    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: Text(
            l10n.selectDownload,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    final displayTitle = item.status == DownloadStatus.extracting &&
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildStatusPill(colors, item.status),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Preview Hero
                    _buildMediaHero(
                      context,
                      colors,
                      item,
                      playablePath,
                      hasPlayableFile,
                    ),

                    const Gap(16),

                    // Title
                    Text(
                      displayTitle,
                      style: AppTypography.h2.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),

                    const Gap(6),

                    // URL row
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: item.request.url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copiée dans le presse-papier'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const Gap(6),
                            Expanded(
                              child: Text(
                                item.request.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: colors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Error Section if failed
                    if (item.status == DownloadStatus.failed) ...[
                      const Gap(16),
                      _buildActionableErrorCard(context, colors, l10n, item),
                    ],

                    const Gap(16),

                    // Quick Action Buttons
                    _buildActionButtons(
                      context,
                      colors,
                      l10n,
                      item,
                      playablePath,
                      hasPlayableFile,
                    ),

                    const Gap(20),

                    // Details Accordion / Information List
                    _buildDetailsSection(colors, item, playablePath),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(AppColors colors, DownloadStatus status) {
    Color pillColor;
    String label;
    IconData icon;

    switch (status) {
      case DownloadStatus.completed:
        pillColor = colors.success;
        label = 'Terminé';
        icon = Icons.check_circle_rounded;
        break;
      case DownloadStatus.failed:
        pillColor = colors.error;
        label = 'Échec';
        icon = Icons.error_rounded;
        break;
      case DownloadStatus.downloading:
        pillColor = colors.primary;
        label = 'Téléchargement';
        icon = Icons.downloading_rounded;
        break;
      case DownloadStatus.extracting:
        pillColor = colors.info;
        label = 'Extraction';
        icon = Icons.auto_awesome_rounded;
        break;
      case DownloadStatus.paused:
        pillColor = colors.warning;
        label = 'En pause';
        icon = Icons.pause_circle_rounded;
        break;
      default:
        pillColor = colors.textSecondary;
        label = 'En attente';
        icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pillColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: pillColor),
          const Gap(5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pillColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaHero(
    BuildContext context,
    AppColors colors,
    DownloadItem item,
    String? playablePath,
    bool hasPlayableFile,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.thumbnailUrl != null)
                Image(
                  image: _resolveThumbImage(item.thumbnailUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _fallbackHeroIcon(colors),
                )
              else
                _fallbackHeroIcon(colors),

              // Dark Overlay
              Container(color: Colors.black38),

              // Play Button if completed and exists
              if (hasPlayableFile)
                Center(
                  child: Material(
                    color: colors.primary.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        ref
                            .read(mediaPlayerProvider.notifier)
                            .openFile(playablePath!);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackHeroIcon(AppColors colors) {
    return Center(
      child: Icon(
        Icons.movie_creation_outlined,
        color: colors.textSecondary.withValues(alpha: 0.5),
        size: 54,
      ),
    );
  }

  ImageProvider _resolveThumbImage(String uri) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return NetworkImage(uri);
    }
    return FileImage(File(uri));
  }

  Widget _buildActionableErrorCard(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    DownloadItem item,
  ) {
    final rawError = item.error ?? '';
    final isAgeVerification = DownloadStatusGuard.isAgeVerificationFailure(
      error: item.error,
      url: item.request.url,
    );
    final isBotOrFormatError = rawError.contains('impersonation') ||
        rawError.contains('No video formats found') ||
        rawError.contains('curl_cffi') ||
        rawError.contains('Protection');

    final containerColor = isAgeVerification
        ? Colors.amber.withValues(alpha: 0.12)
        : colors.error.withValues(alpha: 0.08);
    final borderColor = isAgeVerification
        ? Colors.amber.withValues(alpha: 0.4)
        : colors.error.withValues(alpha: 0.3);
    final primaryIconColor = isAgeVerification ? Colors.amber : colors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAgeVerification
                    ? Icons.shield_outlined
                    : Icons.warning_amber_rounded,
                color: primaryIconColor,
                size: 22,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  isAgeVerification
                      ? 'Vérification d\'âge requise (+18)'
                      : isBotOrFormatError
                          ? 'Format non détecté / Protection du site'
                          : 'Erreur lors du téléchargement',
                  style: TextStyle(
                    color: isAgeVerification ? Colors.amber : colors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            isAgeVerification
                ? 'Ce site protège l\'accès aux vidéos par une vérification de majorité ou un blocage territorial. Consultez les solutions recommandées pour débloquer le téléchargement.'
                : isBotOrFormatError
                    ? 'Ce site utilise une protection anti-bot ou requiert un extracteur mis à jour. Essayez de mettre à jour yt-dlp ou d\'ouvrir le lien dans le navigateur.'
                    : (item.error ?? l10n.error),
            style: AppTypography.body.copyWith(
              fontSize: 12.5,
              color: colors.textPrimary,
              height: 1.35,
            ),
          ),
          const Gap(12),
          // Suggested action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isAgeVerification) ...[
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AgeVerificationHelpDialog.show(context, item);
                  },
                  icon: const Icon(Icons.help_outline_rounded, size: 16),
                  label: const Text(
                    'Voir les solutions (+18)',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
              FilledButton.icon(
                onPressed: _isUpdatingEngine ? null : _updateEngine,
                icon: _isUpdatingEngine
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.system_update_alt_rounded, size: 16),
                label: Text(
                  _isUpdatingEngine ? 'Mise à jour...' : 'Mettre à jour yt-dlp',
                  style: const TextStyle(fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (PlatformInfo.isAndroid) {
                    AndroidEngineBridge.instance.openUrl(item.request.url);
                  } else {
                    Process.run(
                      'cmd',
                      ['/c', 'start', '', item.request.url],
                      runInShell: true,
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text(
                  'Ouvrir dans le navigateur',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          if (_engineUpdateStatus != null) ...[
            const Gap(8),
            Text(
              _engineUpdateStatus!,
              style: TextStyle(fontSize: 11, color: colors.primary),
            ),
          ],
          const Gap(10),
          // Collapsible technical logs
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Logs techniques détaillés',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Console yt-dlp',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copier les logs',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: rawError));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logs copiés')),
                              );
                            },
                          ),
                        ],
                      ),
                      const Gap(6),
                      SelectableText(
                        rawError,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFFF8A80),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    DownloadItem item,
    String? playablePath,
    bool hasPlayableFile,
  ) {
    return Column(
      children: [
        if (hasPlayableFile) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                ref.read(mediaPlayerProvider.notifier).openFile(playablePath!);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text(
                'Lire la vidéo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Gap(10),
        ],
        Row(
          children: [
            // Retry / Restart
            if (item.status == DownloadStatus.failed ||
                item.status == DownloadStatus.canceled ||
                item.status == DownloadStatus.completed)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(downloadListProvider.notifier).retryDownload(item);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    item.status == DownloadStatus.completed
                        ? 'Recommencer'
                        : l10n.retry,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            if (hasPlayableFile && PlatformInfo.isAndroid) ...[
              const Gap(8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AndroidEngineBridge.instance.shareFile(playablePath!);
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AndroidEngineBridge.instance.viewFile(playablePath!);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir avec'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            const Gap(8),
            // Delete
            IconButton(
              tooltip: l10n.delete,
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(downloadListProvider.notifier).deleteDownload(item.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection(
    AppColors colors,
    DownloadItem item,
    String? playablePath,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceHighlight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          const Gap(10),
          _detailRow(
            colors,
            'Source',
            item.source.isNotEmpty ? item.source : 'Web',
          ),
          if (item.totalSize.isNotEmpty)
            _detailRow(colors, 'Taille', item.totalSize),
          if (playablePath != null)
            _detailRow(
              colors,
              'Fichier',
              playablePath.split(Platform.pathSeparator).last,
            ),
          _detailRow(colors, 'Identifiant', item.id),
        ],
      ),
    );
  }

  Widget _detailRow(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
