import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/ui/mobile/back_navigation.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/showcase/showcase_mode.dart';

/// Phone version of the archive entry point: one figure, one action.
/// The browser-extension sync only exists on desktop, so it is not offered.
class TikTokHubMobileView extends ConsumerStatefulWidget {
  const TikTokHubMobileView({super.key});

  @override
  ConsumerState<TikTokHubMobileView> createState() =>
      _TikTokHubMobileViewState();
}

class _TikTokHubMobileViewState extends ConsumerState<TikTokHubMobileView> {
  VoidCallback? _unregisterBack;

  @override
  void initState() {
    super.initState();
    // With a library loaded, Back returns to it rather than leaving the tab.
    _unregisterBack = ref.read(backInterceptorsProvider).register(() {
      final state = ref.read(tikTokArchiveProvider);
      if (!state.hasCatalog) return false;
      ref
          .read(tikTokArchiveProvider.notifier)
          .setViewMode(TikTokViewMode.collections);
      return true;
    });
  }

  @override
  void dispose() {
    _unregisterBack?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final state = ref.watch(tikTokArchiveProvider);
    final notifier = ref.read(tikTokArchiveProvider.notifier);
    final isShowcase = ref.watch(showcaseModeProvider);
    final catalog = state.catalog;
    final hasCatalog = state.hasCatalog;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.archiveMobileTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OledText.title(context, size: 28),
                ),
              ),
              OledIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.archiveMobileBackToLibrary,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasCatalog && catalog != null)
            OledCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${catalog.videos.length}',
                    style: OledText.dot(context, size: 56),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.archiveMobileVideoCount(catalog.videos.length)}'
                    ' · ${l10n.archiveHubCollections(catalog.collections.length)}',
                    style: OledText.ui(context, size: 13, color: t.ink2),
                  ),
                  const SizedBox(height: 18),
                  OledButton(
                    label: l10n.archiveHubOpen,
                    onPressed: () =>
                        notifier.setViewMode(TikTokViewMode.collections),
                  ),
                ],
              ),
            ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            OledCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                state.errorMessage!,
                style: OledText.ui(context, size: 13, color: t.warn),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OledCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.archiveHubImport,
                  style: OledText.ui(
                    context,
                    size: 17,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.archiveHubImportHint,
                  style: OledText.ui(context, size: 13, color: t.ink2),
                ),
                const SizedBox(height: 16),
                OledButton(
                  label: l10n.archiveHubPick,
                  icon: Icons.file_open_outlined,
                  filled: !hasCatalog,
                  onPressed: isShowcase
                      ? null
                      : () => unawaited(notifier.pickAndImportFile()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while the catalog is parsed in the background.
class TikTokLoadingMobileView extends StatelessWidget {
  const TikTokLoadingMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OledLiveDot(size: 14),
            const SizedBox(height: 16),
            Text(
              context.l10n.archiveHubLoading,
              style: OledText.ui(context, size: 14, color: t.ink2),
            ),
          ],
        ),
      ),
    );
  }
}
