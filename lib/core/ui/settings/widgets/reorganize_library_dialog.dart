import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/components/app_button.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/progressive_organizer_service.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';

class ReorganizeLibraryDialog extends ConsumerStatefulWidget {
  const ReorganizeLibraryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ReorganizeLibraryDialog(),
    );
  }

  @override
  ConsumerState<ReorganizeLibraryDialog> createState() =>
      _ReorganizeLibraryDialogState();
}

class _ReorganizeLibraryDialogState extends ConsumerState<ReorganizeLibraryDialog> {
  final ProgressiveOrganizerService _service = ProgressiveOrganizerService();

  bool _isSimulating = true;
  bool _isExecuting = false;
  bool _isCancelled = false;
  bool _isFinished = false;

  ReorganizationPreview? _preview;
  ReorganizeProgress? _currentProgress;
  int _movedCount = 0;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    setState(() => _isSimulating = true);

    final settings = ref.read(settingsProvider);
    final repo = ref.read(downloaderRepositoryProvider);
    final items = repo.getCurrentDownloads();

    var defaultBaseFolder = settings.outputFolder;
    if (defaultBaseFolder.isEmpty) {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        defaultBaseFolder = userProfile != null ? '$userProfile\\Downloads' : 'Downloads';
      } else {
        defaultBaseFolder = 'Downloads';
      }
    }

    final preview = await _service.simulate(
      items: items,
      defaultBaseFolder: defaultBaseFolder,
      organizeBySite: settings.organizeBySite,
      onlineMetadataFetcher: (url) async {
        try {
          return await repo.fetchMetadata(url);
        } catch (_) {
          return null;
        }
      },
    );

    if (mounted) {
      setState(() {
        _preview = preview;
        _isSimulating = false;
      });
    }
  }

  Future<void> _startExecution() async {
    if (_preview == null || _preview!.itemsToMove.isEmpty) return;

    setState(() {
      _isExecuting = true;
      _isCancelled = false;
    });

    final repo = ref.read(downloaderRepositoryProvider);

    try {
      final stream = _service.executeProgressively(
        planItems: _preview!.itemsToMove,
        isCancelled: () => _isCancelled,
        onFileMoved: (itemId, newFilePath, newThumbnailPath) async {
          _movedCount++;
        },
      );

      await for (final progress in stream) {
        if (!mounted) break;
        setState(() {
          _currentProgress = progress;
        });
      }

      // Re-scan and refresh library so all UI paths and thumbnails are updated
      await repo.refreshLibrary();

      if (mounted) {
        setState(() {
          _isExecuting = false;
          _isFinished = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExecuting = false);
        AppToast.showError(context, 'Erreur lors de la réorganisation : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Écran de fin
    if (_isFinished) {
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const Gap(AppSpacing.m),
            Text('Organisation terminée !', style: AppTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• Vidéos réorganisées : $_movedCount',
              style: AppTypography.body,
            ),
            const Gap(AppSpacing.xs),
            Text(
              '• Tous les sous-dossiers créateurs ont été créés avec succès.',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Fermer',
            type: AppButtonType.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // Écran en cours d'exécution
    if (_isExecuting) {
      final ratio = _currentProgress?.ratio ?? 0.0;
      final current = _currentProgress?.current ?? 0;
      final total = _currentProgress?.total ?? _preview?.totalToMove ?? 0;

      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const Gap(AppSpacing.m),
            Text('Organisation en cours...', style: AppTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentProgress?.currentTitle ?? 'Déplacement en cours...',
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(AppSpacing.xs),
            Text(
              'Dossier cible : ${_currentProgress?.targetFolder ?? "..."}',
              style: AppTypography.bodySmall.copyWith(color: colors.primary),
            ),
            const Gap(AppSpacing.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: colors.inputBackground,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const Gap(AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$current / $total (${(ratio * 100).toInt()}%)',
                style: AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isCancelled = true);
            },
            child: const Text('Interrompre proprement'),
          ),
        ],
      );
    }

    // Écran de chargement de la simulation
    if (_isSimulating) {
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colors.primary)),
              const Gap(AppSpacing.l),
              Text('Analyse des vidéos et des métadonnées...', style: AppTypography.body),
              const Gap(AppSpacing.xs),
              Text('Mode Simulation (Dry-Run)', style: AppTypography.caption.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Écran de prévisualisation (Dry-Run Preview)
    final preview = _preview!;
    final breakdown = preview.countPerFolder;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.folder_shared_rounded, color: colors.primary, size: 26),
          const Gap(AppSpacing.m),
          Text('Réorganisation par créateur', style: AppTypography.h3),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aperçu de la réorganisation (Simulation) :',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const Gap(AppSpacing.m),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vidéos à déplacer :', style: AppTypography.body),
                      Text(
                        '${preview.totalToMove}',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: colors.primary),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Déjà bien classées :', style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                      Text('${preview.alreadyOrganizedCount}', style: AppTypography.bodySmall.copyWith(color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
            if (breakdown.isNotEmpty) ...[
              const Gap(AppSpacing.m),
              Text('Dossiers qui seront créés (${breakdown.length}) :', style: AppTypography.caption),
              const Gap(AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: breakdown.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 16, color: colors.textSecondary),
                                const Gap(AppSpacing.s),
                                Text(e.key, style: AppTypography.bodySmall),
                              ],
                            ),
                            Text(
                              '${e.value} vidéo(s)',
                              style: AppTypography.caption.copyWith(color: colors.primary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            if (preview.totalToMove == 0) ...[
              const Gap(AppSpacing.m),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  const Gap(AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Toutes vos vidéos sont déjà parfaitement organisées par créateur !',
                      style: AppTypography.bodySmall.copyWith(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        if (preview.totalToMove > 0)
          AppButton(
            label: 'Appliquer (${preview.totalToMove})',
            type: AppButtonType.primary,
            onPressed: _startExecution,
          ),
      ],
    );
  }
}
