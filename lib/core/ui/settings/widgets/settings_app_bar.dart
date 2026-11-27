import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tapload/core/design_system/foundation/colors.dart';
import 'package:tapload/core/design_system/foundation/typography.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';

import 'settings_app_bar_leading.dart';
import 'settings_tiles.dart';

/// Marks a settings view drawn inside a design's own settings page, which
/// already shows the section title: the view then drops its app bar.
class SettingsFramed extends InheritedWidget {
  const SettingsFramed({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsFramed>() != null;

  @override
  bool updateShouldNotify(SettingsFramed oldWidget) => false;
}

/// App bar shared by the settings sub-pages; none inside a design's frame.
///
/// Desktop keeps the translucent blurred bar. On phones (and with the OLED
/// preset) it is plain black with a hairline: no blur, no elevation tint.
AppBar? buildSettingsAppBar(BuildContext context, {required String title}) {
  if (SettingsFramed.of(context)) return null;
  final colors = AppColors.of(context);

  if (useOledSettingsStyle(context)) {
    final t = OledTokens.of(context);
    return AppBar(
      leading: const SettingsAppBarLeading(),
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: OledText.ui(context, size: 17, weight: FontWeight.w600),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: t.line, height: 1),
      ),
    );
  }

  return AppBar(
    leading: const SettingsAppBarLeading(),
    backgroundColor: colors.background.withValues(alpha: 0.8),
    elevation: 0,
    centerTitle: true,
    flexibleSpace: MediaQuery.disableAnimationsOf(context)
        ? null
        : ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
    title: Text(
      title,
      style: AppTypography.h3.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(color: colors.border.withValues(alpha: 0.5), height: 1),
    ),
  );
}
