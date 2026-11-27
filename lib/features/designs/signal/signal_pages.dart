import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'signal_archive.dart';
import 'signal_home.dart';
import 'signal_settings.dart';
import 'signal_stats.dart';
import 'signal_transfer.dart';

/// Signal's pages (mockups: Main, Signal-Archives, -Stats, -Transfert,
/// -Reglages).
Widget? signalPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const SignalHome();
    case DesignRoute.stats:
      return const SignalStats();
    case DesignRoute.settings:
      return SignalSettings(current: current);
    case DesignRoute.archive:
      return SignalArchive(current: current);
    case DesignRoute.transfer:
      return const SignalTransfer();
  }
}
