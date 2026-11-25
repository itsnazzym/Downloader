import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/ui/shell/designed_page.dart';

import 'signal/signal_pages.dart';

/// Each design's own pages, built from its mockup. Null keeps today's view.
Widget? designPageFor(String designId, DesignRoute route) {
  switch (designId) {
    case 'signal':
      return signalPage(route);
  }
  return null;
}
