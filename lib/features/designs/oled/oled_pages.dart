import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'oled_home.dart';

/// OLED's pages (mockups Main, OLED-Archives, -Stats, -Transfert,
/// -Reglages). Null keeps today's view until a page is drawn.
Widget? oledPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const OledHome();
    case DesignRoute.archive:
    case DesignRoute.stats:
    case DesignRoute.transfer:
    case DesignRoute.settings:
      return null;
  }
}
