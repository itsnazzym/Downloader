import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/design_skin.dart';
import '../../../../../core/design_system/foundation/colors.dart';
import '../../../../../core/platform/platform_info.dart';
import '../../../domain/entities/download_item.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/filtered_downloads_provider.dart';
import '../../views/mobile/mobile_download_details_sheet.dart';
import '../../widgets/download_card.dart';
import '../../widgets/download_item_card.dart';
import '../../widgets/download_item_context_menu.dart';
import '../../widgets/download_item_grid_card.dart';
import '../../widgets/confirm_file_deletion.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import '../../widgets/mobile_download_card.dart';

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
      if (PlatformInfo.isMobile) {
        MobileDownloadDetailsSheet.show(context, item.id);
        return;
      }
      ref.read(selectedDownloadIdProvider.notifier).state = item.id;
    }

    if (PlatformInfo.isMobile) {
      // The mobile card confirms its own swipe-to-delete.
      return RepaintBoundary(
        child: MobileDownloadCard(
          item: item,
          onTap: onTap,
          onRetry: () =>
              ref.read(downloadListProvider.notifier).retryDownload(item),
          onCancel: () =>
              ref.read(downloadListProvider.notifier).deleteDownload(item.id),
        ),
      );
    }

    // Both remove a finished file from disk first, so ask before doing it.
    // Read before awaiting: the row may be gone when the dialog closes.
    final notifier = ref.read(downloadListProvider.notifier);
    Future<void> onRetry() async {
      if (!await confirmFileDeletion(
        context,
        item,
        actionLabel: context.l10n.restartDownload,
      )) {
        return;
      }
      await notifier.retryDownload(item);
    }

    Future<void> onCancel() async {
      if (!await confirmFileDeletion(
        context,
        item,
        actionLabel: context.l10n.delete,
      )) {
        return;
      }
      await notifier.deleteDownload(item.id);
    }

    // A desktop design draws its own row; menu and selection stay shared.
    final skin = DesignSkin.of(context)?.row;
    if (skin != null) {
      return RepaintBoundary(
        child: DownloadItemContextMenu(
          item: item,
          child: skin(
            context,
            DesignRow(
              item: item,
              isSelected: isSelected,
              grid: useGridCard,
              onTap: onTap,
              onRetry: onRetry,
              onCancel: onCancel,
            ),
          ),
        ),
      );
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
