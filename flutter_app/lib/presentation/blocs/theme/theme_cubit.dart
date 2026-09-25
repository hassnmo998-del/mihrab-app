import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/data_service.dart';
import 'theme_state.dart';
import 'package:flutter/material.dart';
class ThemeCubit extends Cubit<ThemeState> {
  final DataService _dataService;

  ThemeCubit({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(
        (dataService ?? DataService()).isDarkMode
            ? ThemeState.dark()
            : ThemeState.light(),
      ) {
    _initTheme();
  }

  Future<void> _initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode') ?? _dataService.isDarkMode;
      final rawScale = prefs.getDouble('font_scale') ?? 1.0;
      final fontScale = rawScale > 1.15 ? 1.15 : rawScale;
      final fontFamily = prefs.getString('font_family') ?? 'Amiri';
      final paletteId = prefs.getString('palette_id') ?? 'terracotta';
      AppColors.currentPaletteId = paletteId;
      AppColors.isDarkMode = isDark;
      AppTypography.currentFontFamily = fontFamily;

      emit(state.copyWith(
        isDark: isDark,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        fontScale: fontScale,
        fontFamily: fontFamily,
        paletteId: paletteId,
      ));
    } catch (_) {}
  }

  void setPalette(String paletteId) async {
    AppColors.currentPaletteId = paletteId;
    emit(state.copyWith(paletteId: paletteId));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('palette_id', paletteId);
    } catch (_) {}
  }

  void toggleTheme() {
    final nextDark = !state.isDark;
    setTheme(nextDark);
  }

  void setTheme(bool isDark) async {
    AppColors.isDarkMode = isDark;
    emit(state.copyWith(
      isDark: isDark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    ));

    if (_dataService.isDarkMode != isDark) {
      _dataService.toggleTheme();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDark);
    } catch (_) {}
  }

  void setFontScale(double scale) async {
    final effectiveScale = scale > 1.15 ? 1.15 : scale;
    emit(state.copyWith(fontScale: effectiveScale));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', effectiveScale);
    } catch (_) {}
  }

  void setFontFamily(String family) async {
    AppTypography.currentFontFamily = family;
    emit(state.copyWith(fontFamily: family));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('font_family', family);
    } catch (_) {}
  }
}