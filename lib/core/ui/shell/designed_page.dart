import 'package:flutter/widgets.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/theme/design_spec.dart';
import 'package:tapload/core/ui/settings/widgets/settings_app_bar.dart';
import 'package:tapload/features/designs/design_pages.dart';

/// The top-level pages a design can redraw from its own mockup.
enum DesignRoute { home, archive, stats, transfer, settings }

/// Shows the active design's own version of [route] on desktop, or
/// [fallback] (today's view) when the design has none, on mobile, and for
/// the platform looks (OLED, iOS). Read in build, so switching design in
/// Appearance swaps the page live.
class DesignedPage extends StatelessWidget {
  const DesignedPage({super.key, required this.route, required this.fallback});

  final DesignRoute route;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) return fallback;
    final page = designPageFor(
      DesignSpec.of(context).id,
      route,
      // The design draws the section title itself.
      route == DesignRoute.settings
          ? SettingsFramed(child: fallback)
          : fallback,
    );
    return page ?? fallback;
  }
}
