import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'studio_archive.dart';
import 'studio_home.dart';
import 'studio_settings.dart';
import 'studio_stats.dart';
import 'studio_transfer.dart';

/// Studio's pages (mockups: Studio, Studio-Archives, -Stats, -Transfert,
/// -Reglages).
Widget? studioPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const StudioHome();
    case DesignRoute.archive:
      return StudioArchive(current: current);
    case DesignRoute.stats:
      return const StudioStats();
    case DesignRoute.transfer:
      return StudioTransfer(current: current);
    case DesignRoute.settings:
      return StudioSettings(current: current);
  }
}
