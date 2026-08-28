import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'active_download_hud.dart';
import 'toast_service.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});

  static const double overlayWidth = 320;
  static const double overlayMaxHeightFraction = 0.42;
  static const double overlayMinHeight = 96;
  static const double overlayMaxHeight = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = (mediaHeight * overlayMaxHeightFraction).clamp(
      overlayMinHeight,
      overlayMaxHeight,
    );

    return Positioned(
      right: 24,
      bottom: 24,
      width: overlayWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ActiveDownloadHud(),
            for (final toast in toasts)
              Padding(
                key: ValueKey(toast.id),
                padding: const EdgeInsets.only(top: 8),
                child: _ToastCard(
                  toast: toast,
                  onDismiss: () {
                    ref.read(toastProvider.notifier).dismiss(toast.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastMessage toast;
  final VoidCallback onDismiss;

  const _ToastCard({required this.toast, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (toast.type) {
      case ToastType.success:
        color = AppColors.of(context).success;
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        color = AppColors.of(context).error;
        icon = Icons.error_rounded;
        break;
      case ToastType.warning:
        color = AppColors.of(context).warning;
        icon = Icons.warning_rounded;
        break;
      case ToastType.info:
        color = AppColors.of(context).info;
        icon = Icons.info_rounded;
        break;
    }

    final colors = AppColors.of(context);

    return Dismissible(
          key: ValueKey(toast.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onDismiss(),
          child: Material(
            color: colors.surface.withValues(alpha: 0.94),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            toast.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (toast.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              toast.description!,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textDisabled,
                        size: 18,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: 0.5, duration: 300.ms, curve: Curves.easeOut);
  }
}
