import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'nocturne_home.dart';

/// Nocturne's pages (mockups Nocturne, Nocturne-Archives, -Stats,
/// -Transfert, -Reglages). Null keeps today's view until a page is drawn.
Widget? nocturnePage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const NocturneHome();
    case DesignRoute.archive:
    case DesignRoute.stats:
    case DesignRoute.transfer:
    case DesignRoute.settings:
      return null;
  }
}
