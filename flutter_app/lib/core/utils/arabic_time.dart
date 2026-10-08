/// تنسيق المواعيد بالعربية كما يُكتب في المسجد: «6:05 م»، «الأربعاء 2026/10/07».
class ArabicTime {
  ArabicTime._();

  /// أيام الأسبوع بترتيب الأسبوع عندنا (من السبت).
  static const List<String> weekOrder = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

  static const Map<int, String> _weekdayName = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };

  static String weekday(DateTime t) => _weekdayName[t.weekday]!;

  /// «6:05 م» — ساعة بنظام 12 مع ص/م.
  static String clock(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h12:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }

  /// «2026/10/07»
  static String date(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';

  /// اليوم نسبةً إلى [now]: «اليوم»، «غداً»، اسم اليوم خلال الأيام الستة القادمة، وإلا اليوم
  /// وتاريخه.
  static String relativeDay(DateTime t, DateTime now) {
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    // بالتقويم لا بالساعات: انتقال التوقيت الصيفي لا يجعل الغد «اليوم»
    final diff = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غداً';
    if (diff == -1) return 'أمس';
    if (diff > 1 && diff < 7) return weekday(t);
    final sameYear = t.year == now.year;
    return '${weekday(t)} ${t.day}/${t.month}${sameYear ? '' : '/${t.year}'}';
  }

  /// أيام التكرار المحفوظة («السبت, الاثنين») بترتيب الأسبوع، بلا تكرار.
  static List<String> orderedDays(String? raw) {
    final text = raw ?? '';
    return [for (final d in weekOrder) if (text.contains(d)) d];
  }
}
