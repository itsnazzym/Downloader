import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/ui/layout/pane_layout_provider.dart';
import 'package:tapload/core/ui/widgets/resizable_width_pane.dart';
import 'package:tapload/features/onboarding/presentation/onboarding_targets.dart';
import '../providers/filtered_downloads_provider.dart';
import 'inspector/collapsed_inspector_rail.dart';
import 'inspector/download_inspector.dart';
import 'mobile/mobile_download_details_sheet.dart';
import 'widgets/download_list.dart';
import 'widgets/download_search_field.dart';
import 'widgets/mobile_clipboard_paste_capsule.dart';
import 'widgets/toolbar/download_top_bar.dart';
import 'widgets/toolbar/mobile_library_header.dart';

/// Main container view for the Downloader screen.
/// Coordinates the top toolbar, download list, responsive layout, and inspector pane.
class DownloadView extends ConsumerWidget {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = PlatformInfo.isMobile;
    final sidebarWidth = isMobile
        ? 0.0
        : ref.watch(paneLayoutProvider.select((s) => s.visibleSidebarWidth));
    final availableWidth = MediaQuery.sizeOf(context).width - sidebarWidth;
    final isNarrow = isMobile || availableWidth < 620;

    if (isNarrow) {
      ref.listen<String?>(selectedDownloadIdProvider, (previous, next) {
        if (next == null || next == previous) return;
        if (isMobile) {
          MobileDownloadDetailsSheet.show(context, next).whenComplete(() {
            if (ref.read(selectedDownloadIdProvider) == next) {
              ref.read(selectedDownloadIdProvider.notifier).state = null;
            }
          });
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) {
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.86,
              child: DownloadInspector(downloadId: next),
            );
          },
        ).whenComplete(() {
          if (ref.read(selectedDownloadIdProvider) == next) {
            ref.read(selectedDownloadIdProvider.notifier).state = null;
          }
        });
      });
    }

    // 3-Column Layout: [Sidebar (handled by Shell)] [Main List] [Inspector]
    return Row(
      children: [
        // Main Content (List)
        Expanded(
          child: Focus(
            autofocus: true,
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                    DownloadSearchFocus.request,
                const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                    DownloadSearchFocus.request,
              },
              child: Column(
                children: [
                  if (isMobile) ...[
                    MobileLibraryHeader(key: OnboardingTargets.topBar),
                    const MobileClipboardPasteCapsule(),
                  ] else ...[
                    DownloadTopBar(key: OnboardingTargets.topBar),
                    const _DownloadTopHairline(),
                  ],
                  Expanded(
                    child: DownloadList(key: OnboardingTargets.creatorList),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Inspector Panel (Desktop / Wide screen)
        if (!isNarrow)
          Consumer(
            builder: (context, ref, child) {
              final selectedId = ref.watch(selectedDownloadIdProvider);
              if (selectedId == null) return const SizedBox.shrink();

              final layout = ref.watch(paneLayoutProvider);
              return ResizableWidthPane(
                width: layout.visibleInspectorWidth,
                minWidth: PaneLayout.inspectorRail,
                maxWidth: PaneLayout.inspectorMax,
                contentMinWidth: PaneLayout.inspectorMin,
                resizeFrom: PaneResizeFrom.leading,
                onWidthChanged: (width) {
                  ref
                      .read(paneLayoutProvider.notifier)
                      .setInspectorWidth(width);
                },
                onDragActive: (active) {
                  ref.read(paneResizeActiveProvider.notifier).state = active;
                },
                onResizeEnd: () {
                  ref.read(paneResizeActiveProvider.notifier).state = false;
                  ref.read(paneLayoutProvider.notifier).commitInspectorDrag();
                  ref.read(paneLayoutProvider.notifier).persist();
                },
                onToggleCollapse: () {
                  ref
                      .read(paneLayoutProvider.notifier)
                      .toggleInspectorCollapsed();
                  ref.read(paneLayoutProvider.notifier).persist();
                },
                child: layout.inspectorCollapsed
                    ? CollapsedInspectorRail(
                        onExpand: () {
                          ref
                              .read(paneLayoutProvider.notifier)
                              .expandInspector();
                          ref.read(paneLayoutProvider.notifier).persist();
                        },
                      )
                    : ColoredBox(
                        color: AppColors.of(context).surface,
                        child: DownloadInspector(downloadId: selectedId),
                      ),
              );
            },
          ),
      ],
    );
  }
}

class _DownloadTopHairline extends StatelessWidget {
  const _DownloadTopHairline();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).border,
      child: const SizedBox(height: 1, width: double.infinity),
    );
  }
}
