import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle get _base => GoogleFonts.outfit();

  static TextStyle get h1 => _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static TextStyle get h2 => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static TextStyle get h3 =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get body =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400);
  static TextStyle get caption =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  static TextStyle get label =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500);
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
