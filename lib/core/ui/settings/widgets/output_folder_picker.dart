import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import 'library_migration_dialog.dart';

/// Lets the user pick a new download folder, then asks whether the files
/// already downloaded should move with it.
Future<void> pickOutputFolder(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final notifier = ref.read(settingsProvider.notifier);
  final path = await FilePicker.platform.getDirectoryPath();
  if (path == null || !context.mounted) return;

  final shouldMigrate = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.settingsOutputChangeFolderTitle),
      content: Text(l10n.settingsOutputChangeFolderBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(l10n.settingsOutputChangeFolderOnly),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(l10n.settingsOutputMigrateFiles),
        ),
      ],
    ),
  );

  if (shouldMigrate == true && context.mounted) {
    await LibraryMigrationDialog.show(context, ref, targetFolder: path);
  } else {
    notifier.setOutputFolder(path);
  }
}
