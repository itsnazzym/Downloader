import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'studio_home.dart';

/// Studio's pages, drawn from its mockups. Null keeps today's view until a page
/// is drawn.
Widget? studioPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const StudioHome();
    case DesignRoute.archive:
    case DesignRoute.stats:
    case DesignRoute.transfer:
    case DesignRoute.settings:
      return null;
  }
}
