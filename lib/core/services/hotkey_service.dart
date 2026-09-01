import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/downloader/presentation/views/dialogs/add_download_dialog.dart';
import '../logger/logger_service.dart';
import '../platform/platform_info.dart';
import '../providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global keyboard shortcuts handler.
/// Wraps the app shell to intercept key events.
class HotkeyHandler extends ConsumerStatefulWidget {
  final Widget child;

  const HotkeyHandler({super.key, required this.child});

  @override
  ConsumerState<HotkeyHandler> createState() => _HotkeyHandlerState();
}

class _HotkeyHandlerState extends ConsumerState<HotkeyHandler> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          _handleKeyEvent(context, ref, event);
        }
      },
      child: widget.child,
    );
  }

  void _handleKeyEvent(
    BuildContext context,
    WidgetRef ref,
    KeyDownEvent event,
  ) {
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      LoggerService.debug('Hotkey: Ctrl+N → New Download');
      showDialog(
        context: context,
        builder: (context) => const AddDownloadDialog(),
      );
      return;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.comma) {
      LoggerService.debug('Hotkey: Ctrl+, → Settings');
      context.go('/settings/general');
      return;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      LoggerService.debug('Hotkey: Ctrl+D → Statistics');
      context.go('/stats');
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!PlatformInfo.isDesktop) return;
      final settings = ref.read(settingsProvider);
      if (settings.minimizeToTray) {
        LoggerService.debug('Hotkey: Esc → Minimize to tray');
        windowManager.hide();
      } else {
        windowManager.minimize();
      }
      return;
    }
  }
}
