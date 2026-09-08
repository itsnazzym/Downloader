import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../platform/platform_info.dart';

/// An adaptive AppBar leading widget for settings pages.
/// On mobile or navigable stacks, displays a back button to return to /settings.
/// On desktop two-pane layouts, stays hidden.
class SettingsAppBarLeading extends StatelessWidget {
  const SettingsAppBarLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final showBack = PlatformInfo.useMobileLayout(context) ||
        Navigator.of(context).canPop() ||
        PlatformInfo.isMobile;

    if (!showBack) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/settings');
        }
      },
    );
  }
}
