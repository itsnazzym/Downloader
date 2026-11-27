import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'porcelaine_archive.dart';
import 'porcelaine_home.dart';
import 'porcelaine_settings.dart';
import 'porcelaine_stats.dart';
import 'porcelaine_transfer.dart';

/// Porcelaine's pages (mockups: Espace, Porcelaine-Archives, -Stats,
/// -Transfert, -Reglages). Null keeps today's view until a page is drawn.
Widget? porcelainePage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const PorcelaineHome();
    case DesignRoute.stats:
      return const PorcelaineStats();
    case DesignRoute.settings:
      return PorcelaineSettings(current: current);
    case DesignRoute.transfer:
      return PorcelaineTransfer(current: current);
    case DesignRoute.archive:
      return const PorcelaineArchive();
  }
}
