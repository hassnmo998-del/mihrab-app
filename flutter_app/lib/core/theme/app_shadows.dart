import 'package:flutter/material.dart';

/// Centralized Elevation and BoxShadow Tokens.
/// Uses warm, diffused ambient lighting rather than harsh drop shadows.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static final List<BoxShadow> subtle = [
    BoxShadow(
      color: const Color(0xFF2B1911).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF2B1911).withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> dialog = [
    BoxShadow(
      color: const Color(0xFF180F15).withValues(alpha: 0.18),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static final List<BoxShadow> heroBanner = [
    BoxShadow(
      color: const Color(0xFF180F15).withValues(alpha: 0.20),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
