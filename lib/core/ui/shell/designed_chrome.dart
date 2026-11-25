import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';

import 'chromes/signal_chrome.dart';

/// The navigation frame of a design around the current page. The classic
/// sidebar ([DesignNav.sidebar]) stays in AppShell.
Widget designedChrome(DesignNav nav, String location, Widget child) {
  switch (nav) {
    case DesignNav.topTabs:
    case DesignNav.sidebar:
    case DesignNav.centerDock:
    case DesignNav.textSidebar:
    case DesignNav.keySidebar:
    case DesignNav.iconRail:
    case DesignNav.bottomDock:
      return SignalChrome(location: location, child: child);
  }
}
