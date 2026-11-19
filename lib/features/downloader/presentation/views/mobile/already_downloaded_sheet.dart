import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/services/title_cleaner_service.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Shown when a download turned out to be a file that was already on disk:
/// nothing was transferred, so the row would otherwise just flash "done".
class AlreadyDownloadedSheet {
  const AlreadyDownloadedSheet._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    DownloadItem item,
  ) {
    final t = OledTokens.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: t.line),
      ),
      builder: (sheetContext) => _Body(
        item: item,
        onOpen: () {
          Navigator.pop(sheetContext);
          final path = item.filePath;
          if (path != null && path.isNotEmpty) {
            unawaited(ref.read(mediaPlayerProvider.notifier).openFile(path));
          }
        },
        onReplace: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(sheetContext);
          unawaited(
            ref.read(downloadListProvider.notifier).retryDownload(item),
          );
        },
        onClose: () => Navigator.pop(sheetContext),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.item,
    required this.onOpen,
    required this.onReplace,
    required this.onClose,
  });

  final DownloadItem item;
  final VoidCallback onOpen;
  final VoidCallback onReplace;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final title = TitleCleanerService.clean(item.title ?? l10n.unknown);
    final canOpen = (item.filePath ?? '').isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.alreadyTitle, style: OledText.title(context, size: 22)),
            const SizedBox(height: 10),
            Text(
              l10n.alreadyBody(title),
              style: OledText.ui(
                context,
                size: 15,
                weight: FontWeight.w400,
                color: t.ink2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            if (canOpen) ...[
              OledButton(label: l10n.alreadyOpen, onPressed: onOpen),
              const SizedBox(height: 10),
            ],
            OledButton(
              label: l10n.alreadyReplace,
              filled: !canOpen,
              onPressed: onReplace,
            ),
            const SizedBox(height: 10),
            OledButton(
              label: l10n.alreadyDismiss,
              filled: false,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
