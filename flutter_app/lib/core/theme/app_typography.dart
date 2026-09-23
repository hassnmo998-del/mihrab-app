import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized Typography Engine.
/// Dynamically swaps between [Amiri], [Tajawal], and [Cairo]
/// across all text roles in the application based on [currentFontFamily].
class AppTypography {
  AppTypography._();

  /// The active font family selected globally via Settings / ThemeCubit.
  static String currentFontFamily = 'Amiri';

  /// Master font builder that respects the user's selected font family.
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    String? family,
  }) {
    final target = family ?? currentFontFamily;
    switch (target) {
      case 'Cairo':
        return GoogleFonts.cairo(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
        );
      case 'Tajawal':
        return GoogleFonts.tajawal(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
        );
      case 'Amiri':
      default:
        return GoogleFonts.amiri(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
        );
    }
  }

  // Base text theme generator for ThemeData
  static TextTheme textTheme(bool isDark, [String? family]) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      // Display & Headlines
      headlineLarge: font(family: family, fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary, height: 1.25),
      headlineMedium: font(family: family, fontSize: 23, fontWeight: FontWeight.bold, color: textPrimary, height: 1.3),
      headlineSmall: font(family: family, fontSize: 19, fontWeight: FontWeight.bold, color: textPrimary, height: 1.35),

      // Titles
      titleLarge: font(family: family, fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
      titleMedium: font(family: family, fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
      titleSmall: font(family: family, fontSize: 13.5, fontWeight: FontWeight.w600, color: textSecondary),

      // Body Text
      bodyLarge: font(family: family, fontSize: 15, fontWeight: FontWeight.normal, color: textPrimary, height: 1.35),
      bodyMedium: font(family: family, fontSize: 13.5, fontWeight: FontWeight.normal, color: textPrimary, height: 1.35),
      bodySmall: font(family: family, fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary, height: 1.3),

      // Labels & Buttons
      labelLarge: font(family: family, fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
      labelMedium: font(family: family, fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
      labelSmall: font(family: family, fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
    );
  }

  // =========================================================================
  // Verve Minimal Design System Tokens (The Single Source of Truth)
  // =========================================================================

  /// Main page / tab title (e.g. "المشايخ والمعلمات المعتمدون (3)")
  static TextStyle verveHeaderTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );
  }

  /// Large serif row number (e.g. "01", "02", "03")
  static TextStyle verveNumber(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: 26,
      fontWeight: FontWeight.normal,
      color: isDark ? Colors.white30 : AppColors.terracottaPrimary.withValues(alpha: 0.65),
      height: 1,
    );
  }

  /// Primary entity name (e.g. Sheikh Name, Halaqa Name, Student Name)
  static TextStyle verveTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: 19,
      fontWeight: FontWeight.bold,
      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );
  }

  /// Secondary metadata & description
  static TextStyle verveSubtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    );
  }

  /// Dialog Titles
  static TextStyle dialogTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );
  }

  /// Button texts
  static TextStyle buttonText({Color? color}) {
    return font(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: color ?? Colors.white,
    );
  }

  // Quick Utility Styles
  static TextStyle titleBold(BuildContext context, {double fontSize = 15, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );
  }

  static TextStyle bodyRegular(BuildContext context, {double fontSize = 13.5, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return font(
      fontSize: fontSize,
      fontWeight: FontWeight.normal,
      color: color ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
    );
  }

  static TextStyle badgeText({Color? color, double fontSize = 12}) {
    return font(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color ?? AppColors.terracottaPrimary,
    );
  }
}