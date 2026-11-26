import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'studio_home.dart';
import 'studio_settings.dart';
import 'studio_stats.dart';

/// Studio's pages, drawn from its mockups. Null keeps today's view until a page
/// is drawn.
Widget? studioPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const StudioHome();
    case DesignRoute.archive:
    case DesignRoute.stats:
      return const StudioStats();
    case DesignRoute.transfer:
      return null;
    case DesignRoute.settings:
      return StudioSettings(current: current);
  }
}
