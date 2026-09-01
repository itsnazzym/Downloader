import 'dart:io';

import 'package:flutter/widgets.dart';

class PlatformInfo {
  static const double compactWidthBreakpoint = 720;

  static bool get isWindows => Platform.isWindows;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool useMobileLayout(BuildContext context) {
    return isMobile ||
        MediaQuery.sizeOf(context).width < compactWidthBreakpoint;
  }
}
