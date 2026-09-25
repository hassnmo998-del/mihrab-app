import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'app_theme_extension.dart';

export 'app_colors.dart';
export 'app_radius.dart';
export 'app_spacing.dart';
export 'app_typography.dart';
export 'app_shadows.dart';
export 'app_theme_extension.dart';

/// Centralized Master Theme Engine.
/// This file and the tokens in `lib/core/theme/` control 100% of the styling in the app.
class AppTheme {
  AppTheme._();

  // Backward-compatible static getters (dynamically bound to active palette)
  static Color get emeraldPrimary => AppColors.emeraldPrimary;
  static Color get emeraldDark => AppColors.emeraldDark;
  static Color get emeraldDeep => AppColors.emeraldDeep;
  static Color get emeraldLight => AppColors.emeraldLight;
  static Color get emeraldAccent => AppColors.emeraldAccent;

  static Color get gold => AppColors.gold;
  static Color get goldLight => AppColors.goldLight;
  static Color get goldBright => AppColors.goldBright;
  static Color get goldDark => AppColors.goldDark;

  static Color get lightBg => AppColors.lightBg;
  static Color get lightSurface => AppColors.lightSurface;
  static Color get lightBorder => AppColors.lightBorder;
  static const Color lightTextPrimary = AppColors.lightTextPrimary;
  static const Color lightTextSecondary = AppColors.lightTextSecondary;

  static Color get darkBg => AppColors.darkBg;
  static Color get darkSurface => AppColors.darkSurface;
  static Color get darkCard => AppColors.darkCard;
  static Color get darkBorder => AppColors.darkBorder;
  static const Color darkTextPrimary = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;

  // Compatibility aliases
  static Color get accentGreen => AppColors.emeraldLight;
  static Color get whatsappGreen => AppColors.emeraldPrimary;
  static Color get waGreenFab => AppColors.emeraldPrimary;
  static Color get waGreenHeader => AppColors.emeraldDark;
  static Color get waGreenDark => AppColors.emeraldDeep;
  static const Color waGreenCheck = Color(0xFF10B981);
  static const Color waOutgoingBubbleLight = Color(0xFFD1FAE5);

  // Semantic & Soft Tokens
  static Color get emeraldSoftBg => AppColors.emeraldSoftBg;
  static Color get emeraldSoftDark => AppColors.emeraldSoftDark;
  static Color get emeraldMint => AppColors.emeraldMint;
  static Color get goldSoftBg => AppColors.goldSoftBg;
  static Color get goldSoftBorder => AppColors.goldSoftBorder;
  static Color get goldBrownText => AppColors.goldBrownText;
  static Color get goldDeepText => AppColors.goldDeepText;
  static Color get podiumGold => AppColors.podiumGold;
  static const Color podiumSilver = AppColors.podiumSilver;
  static const Color podiumBronze = AppColors.podiumBronze;
  static const Color womenPink = AppColors.womenPink;
  static Color get cashierYellow => AppColors.cashierYellow;
  static Color get infoBlue => AppColors.infoBlue;
  static Color get infoBlueDark => AppColors.infoBlueDark;
  static const Color waOutgoingBubbleDark = Color(0xFF064E3B);
  static Color get waDarkCard => AppColors.darkCard;
  static Color get waDarkBg => AppColors.darkBg;
  static Color get waDarkSurface => AppColors.darkSurface;
  static Color get waLightBg => AppColors.lightBg;
  static const Color waLightChatBg = Color(0xFFF1F5F9);
  static Color get waLightCard => AppColors.lightSurface;
  static const Color waLightTextPrimary = AppColors.lightTextPrimary;
  static const Color waLightTextSecondary = AppColors.lightTextSecondary;
  static const Color waDarkTextPrimary = AppColors.darkTextPrimary;
  static const Color waDarkTextSecondary = AppColors.darkTextSecondary;

  // =========================================================================
  // Dynamic Themes (Generated on the fly based on selected fontFamily)
  // =========================================================================
  // =========================================================================
  // Dynamic Themes (Generated on the fly based on selected palette & font)
  // =========================================================================
  static ThemeData get lightTheme => buildTheme(isDark: false);
  static ThemeData get darkTheme => buildTheme(isDark: true);

  static ThemeData buildTheme({
    required bool isDark,
    String paletteId = 'terracotta',
    String? fontFamily,
  }) {
    AppColors.currentPaletteId = paletteId;
    AppColors.isDarkMode = isDark;
    final palette = AppColors.getPaletteById(paletteId);
    if (fontFamily != null) {
      AppTypography.currentFontFamily = fontFamily;
    }
    final activeFont = fontFamily ?? AppTypography.currentFontFamily;
    final primaryColor = isDark ? palette.darkPrimary : palette.primary;
    final accentColor = palette.accent;
    final scaffoldBg = isDark ? palette.darkBg : palette.lightBg;
    final surfaceColor = isDark ? palette.darkSurface : palette.lightSurface;
    final cardColor = isDark ? palette.darkCard : palette.lightCard;
    final borderColor = isDark ? palette.darkBorder : palette.lightBorder;
    final inputFillColor = isDark ? palette.darkInputFill : palette.lightInputFill;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: activeFont,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: isDark
          ? ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.black,
        secondary: accentColor,
        onSecondary: Colors.black,
        surface: surfaceColor,
        onSurface: AppColors.darkTextPrimary,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      )
          : ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        surface: surfaceColor,
        onSurface: AppColors.lightTextPrimary,
        error: const Color(0xFFDC2626),
        onError: Colors.white,
      ),
      textTheme: AppTypography.textTheme(isDark, activeFont),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.font(
          family: activeFont,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: primaryColor,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialog,
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
        titleTextStyle: AppTypography.font(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: AppTypography.font(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 14,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primaryColor.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor);
          }
          return IconThemeData(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.font(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            );
          }
          return AppTypography.font(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.3),
        selectionHandleColor: primaryColor,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(
            color: primaryColor,
            width: 1.2,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: const StadiumBorder(),
          textStyle: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        contentPadding: AppSpacing.inputPadding,
        labelStyle: AppTypography.font(
          fontSize: 14,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        hintStyle: AppTypography.font(
          fontSize: 14,
          color: (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary).withValues(alpha: 0.7),
        ),
      ),

      // Dropdown Theme
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
          border: OutlineInputBorder(
            borderRadius: AppRadius.input,
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
        ),
        menuStyle: MenuStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          ),
          backgroundColor: WidgetStatePropertyAll(
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
          ),
          elevation: const WidgetStatePropertyAll(8),
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryColor;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
          }),
        ),
      ),

      // Data Table Theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF231822) : const Color(0xFFF7F2EB),
        ),
        headingTextStyle: AppTypography.font(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        dataTextStyle: AppTypography.font(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 13,
        ),
        dividerThickness: 0.8,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(
          side: BorderSide(
            color: Color(0x33888888),
          ),
        ),
        backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF1EAE1),
        selectedColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: AppTypography.font(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: AppTypography.font(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // TabBar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: AppTypography.font(fontWeight: FontWeight.w600, fontSize: 14),
      ),

      // Switch & Checkbox Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primaryColor
            : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primaryColor.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.3)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primaryColor
            : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Extensions
      extensions: [
        MosqueThemeExtension.forPalette(palette, isDark: isDark),
      ],
    );
  }
}