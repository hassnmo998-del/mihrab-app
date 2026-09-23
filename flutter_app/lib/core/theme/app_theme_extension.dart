import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Custom Mosque Theme Extension.
/// Allows any widget in the app to access centralized feature tokens via `Theme.of(context).extension<MosqueThemeExtension>()`
/// or the convenient `context.mosqueTheme` extension method.
class MosqueThemeExtension extends ThemeExtension<MosqueThemeExtension> {
  final Color coursePurple;
  final Color coursePurpleBg;
  final Color tripOrange;
  final Color tripOrangeBg;
  final Color trackTeal;
  final Color trackTealBg;
  final Color goldAccent;
  final Color cardBorder;
  final Color containerBg;

  const MosqueThemeExtension({
    required this.coursePurple,
    required this.coursePurpleBg,
    required this.tripOrange,
    required this.tripOrangeBg,
    required this.trackTeal,
    required this.trackTealBg,
    required this.goldAccent,
    required this.cardBorder,
    required this.containerBg,
  });

  /// Factory creating an extension tailored harmoniously to the active palette.
  factory MosqueThemeExtension.forPalette(AppThemePalette palette, {required bool isDark}) {
    final primary = isDark ? palette.darkPrimary : palette.primary;
    final accent = palette.accent;
    final softBg = isDark ? palette.darkCard : palette.accentSoftBg;

    return MosqueThemeExtension(
      coursePurple: primary,
      coursePurpleBg: softBg,
      tripOrange: accent,
      tripOrangeBg: softBg,
      trackTeal: isDark ? palette.darkPrimary : palette.primary,
      trackTealBg: softBg,
      goldAccent: accent,
      cardBorder: isDark ? palette.darkBorder : palette.lightBorder,
      containerBg: isDark ? palette.darkInputFill : palette.lightInputFill,
    );
  }

  static const light = MosqueThemeExtension(
    coursePurple: Color(0xFFC86D3B),
    coursePurpleBg: Color(0xFFFDF6EC),
    tripOrange: Color(0xFFC5A059),
    tripOrangeBg: Color(0xFFFDF6EC),
    trackTeal: Color(0xFFC86D3B),
    trackTealBg: Color(0xFFFDF6EC),
    goldAccent: Color(0xFFC5A059),
    cardBorder: Color(0xFFEAE2D7),
    containerBg: Color(0xFFF6F1EA),
  );

  static const dark = MosqueThemeExtension(
    coursePurple: Color(0xFFDE935E),
    coursePurpleBg: Color(0xFF231822),
    tripOrange: Color(0xFFC5A059),
    tripOrangeBg: Color(0xFF231822),
    trackTeal: Color(0xFFDE935E),
    trackTealBg: Color(0xFF231822),
    goldAccent: Color(0xFFE8C274),
    cardBorder: Color(0xFF382735),
    containerBg: Color(0xFF1E141C),
  );

  @override
  ThemeExtension<MosqueThemeExtension> copyWith({
    Color? coursePurple,
    Color? coursePurpleBg,
    Color? tripOrange,
    Color? tripOrangeBg,
    Color? trackTeal,
    Color? trackTealBg,
    Color? goldAccent,
    Color? cardBorder,
    Color? containerBg,
  }) {
    return MosqueThemeExtension(
      coursePurple: coursePurple ?? this.coursePurple,
      coursePurpleBg: coursePurpleBg ?? this.coursePurpleBg,
      tripOrange: tripOrange ?? this.tripOrange,
      tripOrangeBg: tripOrangeBg ?? this.tripOrangeBg,
      trackTeal: trackTeal ?? this.trackTeal,
      trackTealBg: trackTealBg ?? this.trackTealBg,
      goldAccent: goldAccent ?? this.goldAccent,
      cardBorder: cardBorder ?? this.cardBorder,
      containerBg: containerBg ?? this.containerBg,
    );
  }

  @override
  ThemeExtension<MosqueThemeExtension> lerp(ThemeExtension<MosqueThemeExtension>? other, double t) {
    if (other is! MosqueThemeExtension) return this;
    return MosqueThemeExtension(
      coursePurple: Color.lerp(coursePurple, other.coursePurple, t) ?? coursePurple,
      coursePurpleBg: Color.lerp(coursePurpleBg, other.coursePurpleBg, t) ?? coursePurpleBg,
      tripOrange: Color.lerp(tripOrange, other.tripOrange, t) ?? tripOrange,
      tripOrangeBg: Color.lerp(tripOrangeBg, other.tripOrangeBg, t) ?? tripOrangeBg,
      trackTeal: Color.lerp(trackTeal, other.trackTeal, t) ?? trackTeal,
      trackTealBg: Color.lerp(trackTealBg, other.trackTealBg, t) ?? trackTealBg,
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t) ?? goldAccent,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      containerBg: Color.lerp(containerBg, other.containerBg, t) ?? containerBg,
    );
  }
}

extension MosqueThemeContext on BuildContext {
  MosqueThemeExtension get mosqueTheme =>
      Theme.of(this).extension<MosqueThemeExtension>() ?? MosqueThemeExtension.light;
}
