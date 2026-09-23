import 'package:flutter/material.dart';

/// Centralized Spacing and Inset Tokens.
class AppSpacing {
  AppSpacing._();

  // Primitive Numeric Values
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // Semantic Insets
  static const EdgeInsets screenPadding = EdgeInsets.all(s16);
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);
  static const EdgeInsets dialogPadding = EdgeInsets.all(s20);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: s20, vertical: s12);
  static const EdgeInsets buttonDensePadding = EdgeInsets.symmetric(horizontal: s14, vertical: s8);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: s16, vertical: s12);
  static const EdgeInsets inputDensePadding = EdgeInsets.symmetric(horizontal: s12, vertical: s8);
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(horizontal: s10, vertical: s4);
  static const EdgeInsets bannerPadding = EdgeInsets.all(s16);
}
