import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/design_system/foundation/colors.dart';
import '../../../../../core/platform/platform_info.dart';
import '../../../../../core/ui/media_player/media_player_provider.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/enums/download_status.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/filtered_downloads_provider.dart';
import '../../widgets/download_card.dart';
import '../../widgets/download_item_card.dart';
import '../../widgets/download_item_context_menu.dart';
import '../../widgets/download_item_grid_card.dart';

class DownloadRowHost extends ConsumerWidget {
  const DownloadRowHost({
    super.key,
    required this.id,
    this.useGridCard = false,
  });

  final String id;
  final bool useGridCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(downloadItemByIdProvider(id));
    if (item == null) {
      return const SizedBox.shrink();
    }
    final isSelected = ref.watch(
      selectedDownloadIdProvider.select((selected) => selected == id),
    );

    void onTap() {
      if (PlatformInfo.isMobile && item.status == DownloadStatus.completed) {
        final path = item.filePath;
        if (path != null && File(path).existsSync()) {
          ref.read(mediaPlayerProvider.notifier).openFile(path);
          return;
        }
      }
      ref.read(selectedDownloadIdProvider.notifier).state = item.id;
    }

    void onRetry() {
      ref.read(downloadListProvider.notifier).retryDownload(item);
    }

    void onCancel() {
      ref.read(downloadListProvider.notifier).deleteDownload(item.id);
    }

    if (useGridCard) {
      return RepaintBoundary(
        child: DownloadItemContextMenu(
          item: item,
          child: DownloadItemGridCard(
            item: item,
            isSelected: isSelected,
            onTap: onTap,
            onRetry: onRetry,
            onCancel: onCancel,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: _adaptiveDownloadRow(
        context: context,
        ref: ref,
        item: item,
        isSelected: isSelected,
        onTap: onTap,
        onRetry: onRetry,
        onCancel: onCancel,
      ),
    );
  }

  Widget _adaptiveDownloadRow({
    required BuildContext context,
    required WidgetRef ref,
    required DownloadItem item,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onRetry,
    required VoidCallback onCancel,
  }) {
    if (AppColors.of(context).isIosChrome) {
      return DownloadItemContextMenu(
        item: item,
        child: DownloadCard(
          item: item,
          isSelected: isSelected,
          onTap: onTap,
          onRetry: onRetry,
          onCancel: onCancel,
        ),
      );
    }

    return DownloadItemContextMenu(
      item: item,
      child: DownloadItemCard(
        item: item,
        isSelected: isSelected,
        onTap: onTap,
        onRetry: onRetry,
        onCancel: onCancel,
      ),
    );
  }
}
