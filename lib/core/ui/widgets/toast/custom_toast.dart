import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'active_download_hud.dart';
import 'toast_service.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);

    return Positioned(
      bottom: 24,
      right: 24,
      child: Align(
        alignment: Alignment.bottomRight,
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ActiveDownloadHud(),
              ...toasts.map((toast) {
                return Padding(
                  key: ValueKey(toast.id),
                  padding: const EdgeInsets.only(top: 8),
                  child: _ToastCard(
                    toast: toast,
                    onDismiss: () {
                      ref.read(toastProvider.notifier).dismiss(toast.id);
                    },
                  ),
                );
              }),
            ],
          ),
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

    return Dismissible(
      key: ValueKey(toast.id),
      onDismissed: (_) => onDismiss(),
      child:
          ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.of(
                        context,
                      ).surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: color.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
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
                                style: TextStyle(
                                  color: AppColors.of(context).textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (toast.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  toast.description!,
                                  style: TextStyle(
                                    color: AppColors.of(context).textSecondary,
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
                            color: AppColors.of(context).textDisabled,
                            size: 18,
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.5, duration: 300.ms, curve: Curves.easeOut),
    );
  }
}
