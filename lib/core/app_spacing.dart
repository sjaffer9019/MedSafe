import 'package:flutter/material.dart';

/// Consistent spacing system based on 4/8px grid.
class AppSpacing {
  static const double xxs  = 2;
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  static const screenPadding = EdgeInsets.all(lg);
  static const cardPadding   = EdgeInsets.all(lg);
  static const sectionGap    = SizedBox(height: xl);
}

/// Standard border radii.
class AppRadius {
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double full = 999;
}
