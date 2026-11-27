import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'pastille_archive.dart';
import 'pastille_home.dart';
import 'pastille_settings.dart';
import 'pastille_stats.dart';
import 'pastille_transfer.dart';

/// Pastille's pages, drawn from its mockups (Pastille, Pastille-Archives,
/// -Stats, -Transfert, -Reglages). Null keeps today's view.
Widget? pastillePage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const PastilleHome();
    case DesignRoute.stats:
      return const PastilleStats();
    case DesignRoute.settings:
      return PastilleSettings(section: current);
    case DesignRoute.archive:
      return PastilleArchive(current: current);
    case DesignRoute.transfer:
      return PastilleTransfer(current: current);
  }
}
