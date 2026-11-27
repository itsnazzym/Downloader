import 'package:flutter/widgets.dart';
import 'package:tapload/core/ui/shell/designed_page.dart';

import 'terminal_archive.dart';
import 'terminal_home.dart';
import 'terminal_settings.dart';
import 'terminal_stats.dart';
import 'terminal_transfer.dart';

/// Terminal's pages (mockups Terminal, Terminal-Archives, -Stats, -Transfert,
/// -Reglages).
Widget? terminalPage(DesignRoute route, Widget current) {
  switch (route) {
    case DesignRoute.home:
      return const TerminalHome();
    case DesignRoute.stats:
      return const TerminalStats();
    case DesignRoute.archive:
      return TerminalArchive(current: current);
    case DesignRoute.settings:
      return TerminalSettings(current: current);
    case DesignRoute.transfer:
      return const TerminalTransfer();
  }
}
