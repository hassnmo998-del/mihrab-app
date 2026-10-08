import '../models/models.dart';

/// سجل النقاط (`points_logs`) هو مصدر الحقيقة لكل ما يخص نقاط الطلاب.
///
/// كل حركة سطر مستقل بمعرّفه، فتندمج حركات الأجهزة المختلفة بلا تعارض. أما عدّاد
/// `total_points` في سجل الطالب فكان كل جهاز يكتبه كاملاً من نسخته: جهاز يعمل بلا
/// إنترنت (أو بنسخة أقدم بثوانٍ) يكتب فوق ما أضافه أو صرفه جهاز آخر، فينحرف الرصيد عن
/// الحركات. لذلك يُشتق الرصيد من السجل، والعدّاد مجرد نسخة منه.
class PointsLedger {
  PointsLedger._();

  /// صرف الجوائز: يُنقص الرصيد ولا يُنقص ما اكتسبه الطالب.
  static const String rewardCategory = 'reward';
  static const String attendanceCategory = 'attendance';

  /// رصيد كل طالب: مجموع حركاته كلها (المكتسب ناقص المصروف والمخصوم).
  static Map<String, int> balances(Iterable<PointsLog> logs) {
    final sums = <String, int>{};
    for (final log in logs) {
      sums[log.studentId] = (sums[log.studentId] ?? 0) + log.points;
    }
    return sums;
  }

  /// ما اكتسبه كل طالب في الفترة، وهو ما يُرتَّب به الطلاب: كل الحركات ما عدا صرف
  /// الجوائز. من يستبدل نقاطه بجائزة لا ينزل ترتيبه، والخصم اليدوي (عقوبة) يُحتسب.
  static Map<String, int> earned(Iterable<PointsLog> logs, {DateTime? from, DateTime? to}) {
    final sums = <String, int>{};
    for (final log in logs) {
      if (log.category == rewardCategory) continue;
      if (from != null && log.createdAt.isBefore(from)) continue;
      if (to != null && log.createdAt.isAfter(to)) continue;
      sums[log.studentId] = (sums[log.studentId] ?? 0) + log.points;
    }
    return sums;
  }

  /// معرّف سجل حضور الطالب في يوم: واحد لكل (طالب، يوم) على كل الأجهزة، فرصد شيخين
  /// للطالب نفسه في اليوم نفسه سجل واحد لا سجلان.
  static String attendanceRecordId(String studentId, String sessionDate) => 'att-$studentId-$sessionDate';

  /// معرّف حركة نقاط حضور ذلك اليوم: حركة واحدة تحمل نقاط اليوم الحالية. تغيير الحالة
  /// (حاضر ← متأخر ← غائب) يعدّلها ولا يضيف فوقها.
  static String attendanceLogId(String studentId, String sessionDate) => 'pts-att-$studentId-$sessionDate';

  /// نص سبب حركة الحضور؛ يبدأ دائماً بـ [attendanceReasonPrefix] ليُعرف يومها.
  static String attendanceReason(String sessionDate, String status) {
    final label = switch (status) {
      'present' => 'حضور نظامي',
      'late' => 'حضور متأخر',
      'excused' => 'غياب بعذر',
      _ => 'غياب',
    };
    return '${attendanceReasonPrefix(sessionDate)} ($label)';
  }

  static String attendanceReasonPrefix(String sessionDate) => 'حضور جلسة $sessionDate';
}
