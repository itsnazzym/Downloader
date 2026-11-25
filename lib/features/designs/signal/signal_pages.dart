import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'signal_home.dart';

/// Signal's pages (mockups: Main, Signal-Archives, -Stats, -Transfert,
/// -Reglages). Null keeps today's view until a page is drawn.
Widget? signalPage(DesignRoute route) {
  switch (route) {
    case DesignRoute.home:
      return const SignalHome();
    case DesignRoute.archive:
    case DesignRoute.stats:
    case DesignRoute.transfer:
    case DesignRoute.settings:
      return null;
  }
}
