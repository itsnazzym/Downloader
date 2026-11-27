import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'ios_archive.dart';
import 'ios_home.dart';
import 'ios_settings.dart';
import 'ios_stats.dart';
import 'ios_transfer.dart';

/// iOS « Liquid Glass » pages (mockups iOS-Accueil, -Archives, -Stats,
/// -Transfert, -Reglages), desktop only: phones keep today's iOS views.
Widget? iosPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const IosHome();
    case DesignRoute.archive:
      return IosArchive(current: current);
    case DesignRoute.stats:
      return const IosStats();
    case DesignRoute.transfer:
      return IosTransfer(current: current);
    case DesignRoute.settings:
      return IosSettings(current: current);
  }
}
