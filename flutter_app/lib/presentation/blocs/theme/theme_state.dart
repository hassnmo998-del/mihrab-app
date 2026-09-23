import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final bool isDark;
  final double fontScale;
  final String fontFamily;
  final String paletteId;

  const ThemeState({
    required this.themeMode,
    required this.isDark,
    this.fontScale = 1.0,
    this.fontFamily = 'Amiri',
    this.paletteId = 'terracotta',
  });

  ThemeData get themeData => AppTheme.buildTheme(
        isDark: isDark,
        paletteId: paletteId,
        fontFamily: fontFamily,
      );

  factory ThemeState.light({
    double fontScale = 1.0,
    String fontFamily = 'Amiri',
    String paletteId = 'terracotta',
  }) {
    return ThemeState(
      themeMode: ThemeMode.light,
      isDark: false,
      fontScale: fontScale,
      fontFamily: fontFamily,
      paletteId: paletteId,
    );
  }

  factory ThemeState.dark({
    double fontScale = 1.0,
    String fontFamily = 'Amiri',
    String paletteId = 'terracotta',
  }) {
    return ThemeState(
      themeMode: ThemeMode.dark,
      isDark: true,
      fontScale: fontScale,
      fontFamily: fontFamily,
      paletteId: paletteId,
    );
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDark,
    double? fontScale,
    String? fontFamily,
    String? paletteId,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDark: isDark ?? this.isDark,
      fontScale: fontScale ?? this.fontScale,
      fontFamily: fontFamily ?? this.fontFamily,
      paletteId: paletteId ?? this.paletteId,
    );
  }

  @override
  List<Object?> get props => [themeMode, isDark, fontScale, fontFamily, paletteId];
}