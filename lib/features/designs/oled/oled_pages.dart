import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'oled_archive.dart';
import 'oled_home.dart';
import 'oled_settings.dart';
import 'oled_stats.dart';
import 'oled_transfer.dart';

/// OLED's pages (mockups Main, OLED-Archives, -Stats, -Transfert,
/// -Reglages).
Widget? oledPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const OledHome();
    case DesignRoute.archive:
      return OledArchive(current: current);
    case DesignRoute.stats:
      return const OledStats();
    case DesignRoute.transfer:
      return OledTransfer(current: current);
    case DesignRoute.settings:
      return OledSettings(current: current);
  }
}
