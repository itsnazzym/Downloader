import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'nocturne_archive.dart';
import 'nocturne_home.dart';
import 'nocturne_settings.dart';
import 'nocturne_stats.dart';
import 'nocturne_transfer.dart';

/// Nocturne's pages (mockups Nocturne, Nocturne-Archives, -Stats,
/// -Transfert, -Reglages). Null keeps today's view until a page is drawn.
Widget? nocturnePage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const NocturneHome();
    case DesignRoute.stats:
      return const NocturneStats();
    case DesignRoute.settings:
      return NocturneSettings(current: current);
    case DesignRoute.archive:
      return NocturneArchive(current: current);
    case DesignRoute.transfer:
      return NocturneTransfer(current: current);
  }
}
