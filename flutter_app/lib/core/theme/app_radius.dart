import 'package:flutter/material.dart';

/// Centralized Border Radius Tokens.
/// Modifying these tokens updates all cards, dialogs, buttons, inputs, and badges across the app.
/// Aligned with the C:\UI UX\4 Verve Editorial Luxury language:
/// - Smooth Pill / Stadium buttons, badges, and chips.
/// - Dignified 18-24px curves for cards, dialogs, and sheets.
class AppRadius {
  AppRadius._();

  // Primitive Radius Values
  static const double rXs = 6.0;
  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 16.0;
  static const double rXl = 20.0;
  static const double rXxl = 24.0;
  static const double rPill = 999.0;

  // BorderRadius objects
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius xs = BorderRadius.all(Radius.circular(rXs));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(rSm));
  static const BorderRadius md = BorderRadius.all(Radius.circular(rMd));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(rLg));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(rXl));
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(rXxl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(rPill));

  // Component-Specific Semantic Radiuses (Verve Ministerial Style)
  static const BorderRadius card = xl;       // 20px
  static const BorderRadius dialog = xxl;    // 24px
  static const BorderRadius button = pill;   // 999px (Pill / Stadium)
  static const BorderRadius input = BorderRadius.all(Radius.circular(14.0)); // 14px
  static const BorderRadius badge = pill;    // 999px (Pill Status Badge)
  static const BorderRadius banner = xl;     // 20px
  static const BorderRadius chip = pill;     // 999px (Pill Chip)
  static const BorderRadius sheet = xxl;     // 24px
}
