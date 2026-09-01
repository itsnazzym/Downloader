import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/platform/file_opener.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/enums/download_status.dart';
import '../providers/downloader_provider.dart';

/// Right-click (or long-press) menu for a download item.
class DownloadItemContextMenu extends ConsumerWidget {
  final DownloadItem item;
  final Widget child;

  const DownloadItemContextMenu({
    super.key,
    required this.item,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showMenu(context, ref, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showMenu(context, ref, details.globalPosition);
      },
      child: child,
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset globalPosition,
  ) async {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final filePath = item.filePath;
    final fileExists =
        filePath != null && filePath.isNotEmpty && File(filePath).existsSync();
    final isActive =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.extracting ||
        item.status == DownloadStatus.processing;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      color: colors.surface.withValues(alpha: 0.96),
      elevation: 12,
      items: [
        _item(
          value: 'restart',
          icon: Icons.restart_alt_rounded,
          label: l10n.restartDownload,
          color: colors.primary,
          bold: true,
        ),
        if (fileExists)
          _item(
            value: 'open',
            icon: Icons.play_circle_outline_rounded,
            label: l10n.openFile,
            color: colors.textPrimary,
          ),
        if (fileExists)
          _item(
            value: 'folder',
            icon: Icons.folder_open_rounded,
            label: l10n.openFolder,
            color: colors.textPrimary,
          ),
        _item(
          value: 'copy',
          icon: Icons.link_rounded,
          label: l10n.copyUrl,
          color: colors.textPrimary,
        ),
        if (!isActive)
          _item(
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            label: l10n.delete,
            color: colors.error,
          ),
      ],
    );

    if (!context.mounted || selected == null) return;

    final notifier = ref.read(downloadListProvider.notifier);
    final path = filePath;
    switch (selected) {
      case 'restart':
        await notifier.retryDownload(item);
        break;
      case 'open':
        if (fileExists && path != null) {
          await ref.read(mediaPlayerProvider.notifier).openFile(path);
        }
        break;
      case 'folder':
        if (fileExists && path != null) {
          _revealInFolder(path);
        }
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.request.url));
        break;
      case 'delete':
        await notifier.deleteDownload(item.id);
        break;
    }
  }

  PopupMenuItem<String> _item({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
    bool bold = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _revealInFolder(String path) {
    FileOpener.reveal(path);
  }
}
