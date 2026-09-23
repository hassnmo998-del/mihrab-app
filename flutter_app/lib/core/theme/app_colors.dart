import 'package:flutter/material.dart';

/// Centralized Color Tokens for Verve Editorial Ministerial Palette.
/// Every token dynamically derives from the active [currentPalette] and [isDarkMode].
class AppColors {
  AppColors._();

  // Dynamic Mode & Palette State
  static bool isDarkMode = false;
  static String currentPaletteId = 'terracotta';
  static AppThemePalette get currentPalette => getPaletteById(currentPaletteId);

  // Dynamic Primary & Accents
  static Color get primary => isDarkMode ? currentPalette.darkPrimary : currentPalette.primary;
  static Color get dynamicPrimary => primary;
  static Color get dynamicDarkPrimary => currentPalette.darkPrimary;
  static Color get dynamicAccent => currentPalette.accent;

  // Backward-compatible dynamic tokens mapped to the active theme palette
  static Color get terracottaPrimary => primary;
  static Color get terracottaDark => currentPalette.darkPrimary;
  static Color get terracottaLight => currentPalette.accent;
  static Color get sunsetGlow => currentPalette.accent;

  // Dynamic Theme Gradients for Hero & Banners
  static LinearGradient get sunsetTwilightGradient => currentPalette.gradient;

  static LinearGradient get sunsetSoftHeaderGradient => LinearGradient(
    colors: [
      currentPalette.primary.withValues(alpha: 0.85),
      currentPalette.darkPrimary,
    ],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  // Dynamic Brand & Ministerial Accents
  static Color get obsidianEspresso => isDarkMode ? currentPalette.darkCard : const Color(0xFF160E14);
  static Color get wineDark => currentPalette.darkSurface;
  static Color get wineAuburn => currentPalette.primary;

  // Ministerial Gold & Royal Accents (reflects active palette accent)
  static Color get gold => currentPalette.accent;
  static Color get goldLight => currentPalette.accentLight;
  static Color get goldBright => currentPalette.accentLight;
  static Color get goldDark => currentPalette.accentDark;
  static Color get goldSoftBg => currentPalette.accentSoftBg;
  static Color get goldSoftBorder => isDarkMode ? currentPalette.darkBorder : currentPalette.lightBorder;
  static Color get goldBrownText => currentPalette.accentDark;
  static Color get goldDeepText => currentPalette.accentDark;

  // Dynamic Quranic / Ministerial Tokens (mapped to theme primary)
  static Color get emeraldPrimary => primary;
  static Color get emeraldDark => isDarkMode ? currentPalette.darkSurface : currentPalette.primary;
  static Color get emeraldDeep => isDarkMode ? currentPalette.darkBg : currentPalette.darkPrimary;
  static Color get emeraldLight => isDarkMode ? currentPalette.darkPrimary : currentPalette.primary;
  static Color get emeraldAccent => currentPalette.accent;
  static Color get emeraldSoftBg => currentPalette.accentSoftBg;
  static Color get emeraldSoftDark => currentPalette.darkSurface;
  static Color get emeraldMint => currentPalette.accentLight;
  static const Color emeraldSuccess = Color(0xFF10B981);

  // Feature-Specific Semantic Colors (harmonized with active palette)
  static Color get coursePurple => currentPalette.primary;
  static Color get coursePurpleBgLight => currentPalette.accentSoftBg;
  static Color get coursePurpleBgDark => currentPalette.darkCard;

  static Color get tripOrange => currentPalette.accent;
  static Color get tripOrangeBgLight => currentPalette.accentSoftBg;
  static Color get tripOrangeBgDark => currentPalette.darkCard;

  static Color get trackTeal => isDarkMode ? currentPalette.darkPrimary : currentPalette.primary;
  static Color get trackTealBgLight => currentPalette.accentSoftBg;
  static Color get trackTealBgDark => currentPalette.darkCard;

  // Attendance Statuses (Fixed semantic statuses)
  static const Color attendancePresent = Color(0xFF10B981);
  static const Color attendanceLate = Color(0xFFF59E0B);
  static const Color attendanceAbsent = Color(0xFFEF4444);

  // Podiums & Roles
  static Color get podiumGold => currentPalette.accent;
  static const Color podiumSilver = Color(0xFF94A3B8);
  static const Color podiumBronze = Color(0xFFBA6E46);
  static const Color womenPink = Color(0xFFC24176);
  static Color get cashierYellow => currentPalette.accentLight;
  static Color get infoBlue => isDarkMode ? currentPalette.darkCard : currentPalette.accentSoftBg;
  static Color get infoBlueDark => currentPalette.darkPrimary;

  // =========================================================================
  // Light Palette Neutrals (Harmonized with currentPalette)
  // =========================================================================
  static Color get lightBg => currentPalette.lightBg;
  static Color get lightSurface => currentPalette.lightSurface;
  static Color get lightCard => currentPalette.lightCard;
  static Color get lightBorder => currentPalette.lightBorder;
  static Color get lightBorderSubtle => currentPalette.lightBorder;
  static const Color lightTextPrimary = Color(0xFF1D1319);
  static const Color lightTextSecondary = Color(0xFF756760);
  static Color get lightInputFill => currentPalette.lightInputFill;

  // =========================================================================
  // Dark Palette Neutrals (Harmonized with currentPalette)
  // =========================================================================
  static Color get darkBg => currentPalette.darkBg;
  static Color get darkSurface => currentPalette.darkSurface;
  static Color get darkCard => currentPalette.darkCard;
  static Color get darkBorder => currentPalette.darkBorder;
  static Color get darkBorderSubtle => currentPalette.darkBorder;
  static const Color darkTextPrimary = Color(0xFFFAF5F0);
  static const Color darkTextSecondary = Color(0xFFA89B94);
  static Color get darkInputFill => currentPalette.darkInputFill;

  // =========================================================================
  // Tajweed Quran Colors (ألوان مصحف التجويد المعتمدة شرعياً)
  // =========================================================================
  static const Color tajweedGhunnah = Color(0xFF10B981); // الغنة والإخفاء (أخضر)
  static const Color tajweedQalqalah = Color(0xFF0284C7); // القلقلة (أزرق سماوي)
  static const Color tajweedIdgham = Color(0xFF6B7280);   // الإدغام بلا غنة (رمادي)
  static const Color tajweedIkhfa = Color(0xFF059669);    // الإخفاء بغنة
  static const Color tajweedIqlab = Color(0xFF0284C7);    // الإقلاب
  static const Color tajweedMadd = Color(0xFFDC2626);     // المد اللازم والمتصل
  static const Color tajweedMaddObligatory = Color(0xFFDC2626); // المد اللازم والواجب (أحمر قاني)
  static const Color tajweedMaddPermissible = Color(0xFFF97316); // المد الجائز والعارض (برتقالي)
  static const Color tajweedTafkheem = Color(0xFF2563EB); // تفخيم الراء واللام (أزرق داكن)

  // =========================================================================
  // 7 Distinct Theme Palettes (سبع باقات ألوان كاملة ومتقنة)
  // =========================================================================
  static const List<AppThemePalette> palettes = [
    // 1. Terracotta (التيراكوتا الشامي)
    AppThemePalette(
      id: 'terracotta',
      name: 'التيراكوتا الشامي',
      subtitle: 'الدفء التراثي العريق',
      primary: Color(0xFFC86D3B),
      darkPrimary: Color(0xFFDE935E),
      accent: Color(0xFFC5A059),
      accentDark: Color(0xFF8C5D1E),
      accentLight: Color(0xFFE8C274),
      accentSoftBg: Color(0xFFFDF6EC),
      gradient: LinearGradient(
        colors: [Color(0xFF2C1420), Color(0xFFBA653E), Color(0xFFDE935E)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFFAF6F0),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFEAE2D7),
      lightInputFill: Color(0xFFF6F1EA),
      darkBg: Color(0xFF120B10),
      darkSurface: Color(0xFF1C131A),
      darkCard: Color(0xFF231822),
      darkBorder: Color(0xFF382735),
      darkInputFill: Color(0xFF1E141C),
    ),

    // 2. Emerald (الزمردي النبوي)
    AppThemePalette(
      id: 'emerald',
      name: 'الزمردي النبوي',
      subtitle: 'أخضر المساجد والسكينة',
      primary: Color(0xFF059669),
      darkPrimary: Color(0xFF10B981),
      accent: Color(0xFFD4AF37),
      accentDark: Color(0xFF92701A),
      accentLight: Color(0xFFFDE68A),
      accentSoftBg: Color(0xFFECFDF5),
      gradient: LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF34D399)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFF2F9F5),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFD1E7DD),
      lightInputFill: Color(0xFFE8F4EE),
      darkBg: Color(0xFF081611),
      darkSurface: Color(0xFF0E231B),
      darkCard: Color(0xFF132D23),
      darkBorder: Color(0xFF1B4032),
      darkInputFill: Color(0xFF10281F),
    ),

    // 3. Sapphire (الياقوت الأندلسي)
    AppThemePalette(
      id: 'sapphire',
      name: 'الياقوت الأندلسي',
      subtitle: 'أزرق ملكي عميق ووقار',
      primary: Color(0xFF1D4ED8),
      darkPrimary: Color(0xFF3B82F6),
      accent: Color(0xFFE8C274),
      accentDark: Color(0xFF99732B),
      accentLight: Color(0xFFFDE68A),
      accentSoftBg: Color(0xFFEFF6FF),
      gradient: LinearGradient(
        colors: [Color(0xFF1E1B4B), Color(0xFF1D4ED8), Color(0xFF60A5FA)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFF3F6FC),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFD7E2F2),
      lightInputFill: Color(0xFFEAF0FA),
      darkBg: Color(0xFF0A1020),
      darkSurface: Color(0xFF101932),
      darkCard: Color(0xFF172242),
      darkBorder: Color(0xFF22325C),
      darkInputFill: Color(0xFF121B35),
    ),

    // 4. Amethyst (الجمشت القرآني)
    AppThemePalette(
      id: 'amethyst',
      name: 'الجمشت القرآني',
      subtitle: 'بنفسجي إسلامي روحاني',
      primary: Color(0xFF7C3AED),
      darkPrimary: Color(0xFF8B5CF6),
      accent: Color(0xFFFBBF24),
      accentDark: Color(0xFFB45309),
      accentLight: Color(0xFFFDE68A),
      accentSoftBg: Color(0xFFF5F3FF),
      gradient: LinearGradient(
        colors: [Color(0xFF2E1065), Color(0xFF7C3AED), Color(0xFFA78BFA)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFF8F5FC),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFE5DEEE),
      lightInputFill: Color(0xFFF0EBF8),
      darkBg: Color(0xFF110B1E),
      darkSurface: Color(0xFF1A122C),
      darkCard: Color(0xFF22173B),
      darkBorder: Color(0xFF332356),
      darkInputFill: Color(0xFF1C1330),
    ),

    // 5. Amber (الكهرمان الذهبي)
    AppThemePalette(
      id: 'amber',
      name: 'الكهرمان الذهبي',
      subtitle: 'إشراقة الذهب والأمجاد',
      primary: Color(0xFFD97706),
      darkPrimary: Color(0xFFF59E0B),
      accent: Color(0xFFB45309),
      accentDark: Color(0xFF78350F),
      accentLight: Color(0xFFFCD34D),
      accentSoftBg: Color(0xFFFFFBEB),
      gradient: LinearGradient(
        colors: [Color(0xFF451A03), Color(0xFFD97706), Color(0xFFFCD34D)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFFAF7F0),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFEAE2D2),
      lightInputFill: Color(0xFFF5EFE3),
      darkBg: Color(0xFF140F08),
      darkSurface: Color(0xFF1E170F),
      darkCard: Color(0xFF281F15),
      darkBorder: Color(0xFF3C2F20),
      darkInputFill: Color(0xFF201811),
    ),

    // 6. Teal (الفيروزي الدمشقي)
    AppThemePalette(
      id: 'teal',
      name: 'الفيروزي الدمشقي',
      subtitle: 'زرقة البحر والأروقة الدمشقية',
      primary: Color(0xFF0D9488),
      darkPrimary: Color(0xFF14B8A6),
      accent: Color(0xFFEAB308),
      accentDark: Color(0xFFA16207),
      accentLight: Color(0xFFFDE047),
      accentSoftBg: Color(0xFFF0FDFA),
      gradient: LinearGradient(
        colors: [Color(0xFF134E4A), Color(0xFF0D9488), Color(0xFF2DD4BF)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFF1F8F7),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFD0E6E4),
      lightInputFill: Color(0xFFE5F2F1),
      darkBg: Color(0xFF081616),
      darkSurface: Color(0xFF0E2222),
      darkCard: Color(0xFF142E2E),
      darkBorder: Color(0xFF1E4343),
      darkInputFill: Color(0xFF102727),
    ),

    // 7. Ruby (العقيقي القرمزي)
    AppThemePalette(
      id: 'ruby',
      name: 'العقيقي القرمزي',
      subtitle: 'أحمر عقيقي فاخر وجريء',
      primary: Color(0xFFBE123C),
      darkPrimary: Color(0xFFF43F5E),
      accent: Color(0xFFF59E0B),
      accentDark: Color(0xFFB45309),
      accentLight: Color(0xFFFDE68A),
      accentSoftBg: Color(0xFFFFF1F2),
      gradient: LinearGradient(
        colors: [Color(0xFF4C0519), Color(0xFFBE123C), Color(0xFFFB7185)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      lightBg: Color(0xFFFDF4F5),
      lightSurface: Color(0xFFFFFFFF),
      lightCard: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFECCED3),
      lightInputFill: Color(0xFFF7E6E9),
      darkBg: Color(0xFF180A0E),
      darkSurface: Color(0xFF241016),
      darkCard: Color(0xFF2E151D),
      darkBorder: Color(0xFF45202B),
      darkInputFill: Color(0xFF261118),
    ),
  ];

  static AppThemePalette getPaletteById(String id) {
    return palettes.firstWhere(
      (p) => p.id == id,
      orElse: () => palettes.first,
    );
  }
}

/// Rich palette data holder containing light/dark surfaces, backgrounds, borders, and accents.
class AppThemePalette {
  final String id;
  final String name;
  final String subtitle;
  final Color primary;
  final Color darkPrimary;
  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color accentSoftBg;
  final LinearGradient gradient;

  // Light Mode Tokens
  final Color lightBg;
  final Color lightSurface;
  final Color lightCard;
  final Color lightBorder;
  final Color lightInputFill;

  // Dark Mode Tokens
  final Color darkBg;
  final Color darkSurface;
  final Color darkCard;
  final Color darkBorder;
  final Color darkInputFill;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primary,
    required this.darkPrimary,
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.accentSoftBg,
    required this.gradient,
    required this.lightBg,
    required this.lightSurface,
    required this.lightCard,
    required this.lightBorder,
    required this.lightInputFill,
    required this.darkBg,
    required this.darkSurface,
    required this.darkCard,
    required this.darkBorder,
    required this.darkInputFill,
  });
}
