import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'ios/ios_pages.dart';
import 'nocturne/nocturne_pages.dart';
import 'oled/oled_pages.dart';
import 'pastille/pastille_pages.dart';
import 'porcelaine/porcelaine_pages.dart';
import 'signal/signal_pages.dart';
import 'studio/studio_pages.dart';
import 'terminal/terminal_pages.dart';

/// Each design's own pages, built from its mockup. Null keeps today's view.
/// [current] is today's view for the route: a design may frame it (settings
/// sections its mockup does not draw) instead of losing it.
Widget? designPageFor(String designId, DesignRoute route, Widget current) {
  switch (designId) {
    case 'signal':
      return signalPage(route, current);
    case 'porcelaine':
      return porcelainePage(route, current);
    case 'pastille':
      return pastillePage(route, current);
    case 'studio':
      return studioPage(route, current);
    case 'terminal':
      return terminalPage(route, current);
    case 'nocturne':
      return nocturnePage(route, current);
    case 'oled':
      return oledPage(route, current);
    case 'ios':
      return iosPage(route, current);
  }
  return null;
}
