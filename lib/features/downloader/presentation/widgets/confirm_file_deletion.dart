import 'package:flutter/material.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import '../../domain/entities/download_item.dart';
import '../../domain/enums/download_status.dart';

/// Asks before an action that deletes [item]'s finished file from disk
/// (delete, or re-download which removes the file first). Rows without a
/// finished file (failed, canceled, queued) return true without asking.
Future<bool> confirmFileDeletion(
  BuildContext context,
  DownloadItem item, {
  required String actionLabel,
}) async {
  if (item.status != DownloadStatus.completed) return true;
  final l10n = context.l10n;
  final colors = AppColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        l10n.downloadCardDeleteConfirm(item.title ?? item.request.url),
      ),
      content: Text(l10n.fileDeletedFromDisk),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: Colors.white,
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
