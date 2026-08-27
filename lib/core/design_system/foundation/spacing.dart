import 'package:flutter/material.dart';
import 'colors.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double s = 12.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  const AppRadius._();

  static const Radius small = Radius.circular(4.0);
  static const Radius medium = Radius.circular(8.0);
  static const Radius large = Radius.circular(12.0);
  static const Radius xl = Radius.circular(16.0);
  static const Radius full = Radius.circular(999.0);

  static BorderRadius get smallBorder => BorderRadius.all(small);
  static BorderRadius get mediumBorder => BorderRadius.all(medium);
  static BorderRadius get largeBorder => BorderRadius.all(large);
  static BorderRadius get xlBorder => BorderRadius.all(xl);
  static BorderRadius get fullBorder => BorderRadius.all(full);

  static BorderRadius panelOf(BuildContext context) {
    return AppColors.of(context).isIosChrome ? xlBorder : mediumBorder;
  }

  static BorderRadius controlOf(BuildContext context) {
    return AppColors.of(context).isIosChrome ? largeBorder : mediumBorder;
  }
}
