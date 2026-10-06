import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/data_service.dart';
import 'theme_state.dart';
import 'package:flutter/material.dart';
class ThemeCubit extends Cubit<ThemeState> {
  final DataService _dataService;

  /// الثيم الذي كان مختاراً قبل دخول الجهاز «الحالة النسائية». وجود المفتاح معناه أن
  /// التحويل إلى الزهري جرى مرة، فلا يُعاد ولو غيّرت المستخدمة الثيم بيدها بعده.
  static const String paletteBeforeWomenKey = 'palette_before_women';

  bool? _womenMode;
  Future<void> _womenSync = Future<void>.value();

  ThemeCubit({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(
        (dataService ?? DataService()).isDarkMode
            ? ThemeState.dark()
            : ThemeState.light(),
      ) {
    _initTheme().whenComplete(() {
      if (isClosed) return;
      _dataService.addListener(_onDataChanged);
      _onDataChanged();
    });
  }

  /// يكتمل حين يُطبَّق آخر تغيير في ثيم القسم النسائي (للاختبارات).
  Future<void> get womenPaletteSettled => _womenSync;

  /// أي كود لقسم نسائي (إدارة، معلمة، طالبة، صرّافة) يُدخل الجهاز الحالة النسائية من أي
  /// ماسح كان؛ لذلك يُراقب هنا `DataService.isWomenMode` نفسه لا شاشات المسح.
  void _onDataChanged() {
    final women = _dataService.isWomenMode;
    if (women == _womenMode) return;
    _womenMode = women;
    _womenSync = _womenSync.then((_) => _applyWomenPalette(women));
  }

  Future<void> _applyWomenPalette(bool women) async {
    if (isClosed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(paletteBeforeWomenKey);
      if (women && before == null) {
        await prefs.setString(paletteBeforeWomenKey, state.paletteId);
        if (state.paletteId != AppColors.womenPaletteId) {
          await setPalette(AppColors.womenPaletteId);
        }
      } else if (!women && before != null) {
        await prefs.remove(paletteBeforeWomenKey);
        // خرجت من كل الأقسام النسائية: يعود ثيمها السابق ما لم تكن اختارت غير الزهري
        if (state.paletteId == AppColors.womenPaletteId && before != AppColors.womenPaletteId) {
          await setPalette(before);
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
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

  Future<void> setPalette(String paletteId) async {
    if (isClosed) return;
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