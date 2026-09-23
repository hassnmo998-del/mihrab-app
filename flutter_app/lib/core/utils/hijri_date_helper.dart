class HijriData {
  final int year;
  final int month;
  final int day;

  const HijriData({
    required this.year,
    required this.month,
    required this.day,
  });
}

/// Helper class for calculating and formatting Hijri and Gregorian dates in Arabic.
class HijriDateHelper {
  static const List<String> hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> gregorianMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> weekDays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  /// Converts digits to Arabic Eastern digits (٠١٢٣٤٥٦٧٨٩)
  static String toArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  /// Returns Arabic weekday name for the given date
  static String getWeekdayName(DateTime date) {
    int idx = date.weekday == 7 ? 0 : date.weekday;
    return weekDays[idx];
  }

  /// Converts a Gregorian [date] into Tabular Hijri date
  static HijriData convertToHijri(DateTime date) {
    int gYear = date.year;
    int gMonth = date.month;
    int gDay = date.day;

    int a = ((14 - gMonth) ~/ 12);
    int y = gYear + 4800 - a;
    int m = gMonth + 12 * a - 3;

    int jdn = gDay +
        ((153 * m + 2) ~/ 5) +
        365 * y +
        (y ~/ 4) -
        (y ~/ 100) +
        (y ~/ 400) -
        32045;

    int l = jdn - 1948440 + 10632;
    int n = ((l - 1) ~/ 10631);
    l = l - 10631 * n + 354;

    int j = (((10985 - l) ~/ 5316)) * (((50 * l) ~/ 17719)) +
        (((l) ~/ 5670)) * (((43 * l) ~/ 15238));
    l = l -
        (((30 - j) ~/ 15)) * (((17719 * j) ~/ 50)) -
        (((j) ~/ 16)) * (((15238 * j) ~/ 43)) +
        29;

    int hMonth = ((24 * l) ~/ 709);
    int hDay = l - ((709 * hMonth) ~/ 24);
    int hYear = 30 * n + j - 30;

    if (hMonth < 1) hMonth = 1;
    if (hMonth > 12) hMonth = 12;
    if (hDay < 1) hDay = 1;

    return HijriData(year: hYear, month: hMonth, day: hDay);
  }

  /// Formats Hijri date in Arabic (e.g., "الإثنين، ١٤ ربيع الأول ١٤٤٨ هـ")
  static String formatHijri(DateTime date, {bool useArabicDigits = true, bool includeSuffix = true}) {
    final h = convertToHijri(date);
    final dayName = getWeekdayName(date);
    final monthName = hijriMonths[h.month - 1];
    final dayStr = useArabicDigits ? toArabicDigits('${h.day}') : '${h.day}';
    final yearStr = useArabicDigits ? toArabicDigits('${h.year}') : '${h.year}';
    final suffix = includeSuffix ? ' هـ' : '';
    return '$dayName، $dayStr $monthName $yearStr$suffix';
  }

  /// Formats Gregorian date in Arabic (e.g., "الإثنين، ٢١ سبتمبر ٢٠٢٦ م")
  static String formatGregorian(DateTime date, {bool useArabicDigits = true, bool includeSuffix = true}) {
    final dayName = getWeekdayName(date);
    final monthName = gregorianMonths[date.month - 1];
    final dayStr = useArabicDigits ? toArabicDigits('${date.day}') : '${date.day}';
    final yearStr = useArabicDigits ? toArabicDigits('${date.year}') : '${date.year}';
    final suffix = includeSuffix ? ' م' : '';
    return '$dayName، $dayStr $monthName $yearStr$suffix';
  }
}
