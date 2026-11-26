import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';

import 'chromes/nocturne_chrome.dart';
import 'chromes/pastille_chrome.dart';
import 'chromes/porcelaine_chrome.dart';
import 'chromes/signal_chrome.dart';
import 'chromes/studio_chrome.dart';
import 'chromes/terminal_chrome.dart';

/// The navigation frame of a design around the current page. The classic
/// sidebar ([DesignNav.sidebar]) stays in AppShell.
Widget designedChrome(DesignNav nav, String location, Widget child) {
  switch (nav) {
    case DesignNav.centerDock:
      return PorcelaineChrome(location: location, child: child);
    case DesignNav.bottomDock:
      return PastilleChrome(location: location, child: child);
    case DesignNav.iconRail:
      return NocturneChrome(location: location, child: child);
    case DesignNav.textSidebar:
      return StudioChrome(location: location, child: child);
    case DesignNav.keySidebar:
      return TerminalChrome(location: location, child: child);
    case DesignNav.topTabs:
    case DesignNav.sidebar:
      return SignalChrome(location: location, child: child);
  }
}
