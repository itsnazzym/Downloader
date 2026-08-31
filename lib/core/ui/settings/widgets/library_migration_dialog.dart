import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';

import '../../../design_system/foundation/colors.dart';
import '../../../design_system/foundation/spacing.dart';
import '../../../design_system/foundation/typography.dart';
import '../../../design_system/components/app_toast.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/library_migration_service.dart';
import '../../../../features/downloader/presentation/providers/downloader_provider.dart';

class LibraryMigrationDialog extends ConsumerStatefulWidget {
  final String? initialTargetFolder;

  const LibraryMigrationDialog({
    super.key,
    this.initialTargetFolder,
  });

  static Future<void> show(BuildContext context, WidgetRef ref, {String? targetFolder}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => LibraryMigrationDialog(initialTargetFolder: targetFolder),
    );
  }

  @override
  ConsumerState<LibraryMigrationDialog> createState() => _LibraryMigrationDialogState();
}

class _LibraryMigrationDialogState extends ConsumerState<LibraryMigrationDialog> {
  String? _targetFolder;
  bool _deleteSource = true;
  bool _isMigrating = false;
  MigrationProgress? _progress;
  MigrationResult? _result;

  @override
  void initState() {
    super.initState();
    _targetFolder = widget.initialTargetFolder;
  }

  Future<void> _pickTargetFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && mounted) {
      setState(() => _targetFolder = path);
    }
  }

  Future<void> _startMigration() async {
    if (_targetFolder == null || _targetFolder!.isEmpty) {
      await _pickTargetFolder();
      if (_targetFolder == null || _targetFolder!.isEmpty) return;
    }

    setState(() {
      _isMigrating = true;
      _progress = const MigrationProgress(
        status: 'Initialisation de la migration...',
        current: 0,
        total: 100,
        percentage: 0.0,
      );
    });

    final service = LibraryMigrationService();

    try {
      final res = await service.migrateLibrary(
        newOutputFolder: _targetFolder!,
        deleteSourceFiles: _deleteSource,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );

      if (!mounted) return;
      ref.read(settingsProvider.notifier).setOutputFolder(_targetFolder!);
      await ref.read(downloaderRepositoryProvider).refreshLibrary();

      if (!mounted) return;
      setState(() {
        _isMigrating = false;
        _result = res;
      });

      AppToast.showSuccess(
        context,
        'Migration réussie : ${res.videosMoved} vidéos et ${res.thumbnailsMoved} miniatures transférées.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
        AppToast.showError(context, 'Erreur lors de la migration: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentOutput = ref.watch(settingsProvider).outputFolder;

    if (_result != null) {
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const Gap(AppSpacing.m),
            Text('Migration Terminée !', style: AppTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Vidéos déplacées : ${_result!.videosMoved}', style: AppTypography.body),
            const Gap(AppSpacing.xs),
            Text('• Miniatures déplacées : ${_result!.thumbnailsMoved}', style: AppTypography.body),
            const Gap(AppSpacing.xs),
            Text('• Base de données mise à jour : ${_result!.databaseItemsUpdated} éléments', style: AppTypography.body),
            if (_result!.freedGigabytes > 0.01) ...[
              const Gap(AppSpacing.xs),
              Text(
                '• Espace libéré sur l\'ancien disque : ${_result!.freedGigabytes.toStringAsFixed(2)} Go',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: colors.primary),
              ),
            ],
            if (_result!.errors.isNotEmpty) ...[
              const Gap(AppSpacing.m),
              Text('Avertissements : ${_result!.errors.length}', style: const TextStyle(color: Colors.orange)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    if (_isMigrating) {
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const Gap(AppSpacing.m),
            Text('Migration en cours...', style: AppTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_progress?.status ?? 'Veuillez patienter...', style: AppTypography.body),
            const Gap(AppSpacing.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress?.percentage,
                minHeight: 8,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const Gap(AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_progress?.current ?? 0} / ${_progress?.total ?? 0}',
                  style: AppTypography.caption.copyWith(color: colors.textSecondary),
                ),
                Text(
                  '${((_progress?.percentage ?? 0) * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_progress?.currentFile != null && _progress!.currentFile!.isNotEmpty) ...[
              const Gap(AppSpacing.s),
              Text(
                _progress!.currentFile!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.drive_file_move_rounded, color: colors.primary, size: 28),
          const Gap(AppSpacing.m),
          Text('Migrer la Bibliothèque', style: AppTypography.h3),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transférer automatiquement tous vos fichiers vidéo, dossiers de sources, miniatures et mettre à jour votre base de données sans aucune perte.',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const Gap(AppSpacing.l),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dossier actuel :', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                  const Gap(AppSpacing.xs),
                  Text(currentOutput.isEmpty ? 'Non configuré' : currentOutput, style: AppTypography.body),
                  const Divider(height: 20),
                  Text('Nouveau dossier cible :', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                  const Gap(AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _targetFolder ?? 'Sélectionner un dossier...',
                          style: AppTypography.body.copyWith(
                            color: _targetFolder == null ? colors.textSecondary : colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open_rounded),
                        onPressed: _pickTargetFolder,
                        tooltip: 'Choisir le dossier',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.m),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Supprimer les fichiers de l\'ancien dossier après transfert (libère l\'espace disque)',
                style: AppTypography.bodySmall,
              ),
              value: _deleteSource,
              onChanged: (v) => setState(() => _deleteSource = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.drive_file_move_rounded, size: 18),
          label: const Text('Lancer la Migration'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _targetFolder != null && _targetFolder!.isNotEmpty
              ? _startMigration
              : _pickTargetFolder,
        ),
      ],
    );
  }
}
