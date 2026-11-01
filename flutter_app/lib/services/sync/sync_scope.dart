import '../../models/models.dart';

/// المساجد التي يحتاجها هذا الجهاز من السحابة.
///
/// كل جهاز كان يجلب بيانات كل المساجد؛ على مستوى دولة هذا يعني أن هاتف طالب
/// يحمّل بيانات مئات الآلاف. هنا يُحدَّد النطاق من الجلسات المحفوظة على الجهاز:
/// - [dataMosqueIds]: مساجد تُجلب بياناتها كاملة (جلسة إدارة أو شيخ أو طالب أو صراف).
/// - [rowOnlyMosqueIds]: مساجد يكفي صفّ المسجد نفسه (الفرع النسائي أو الأب)، فلا تصل
///   بيانات القسم الآخر إلى الجهاز.
class SyncScope {
  /// أكبر عدد مساجد في نطاق واحد (حدّ دالة `sync_changes` في الخادم).
  static const int maxDataMosques = 100;

  final Set<String> dataMosqueIds;
  final Set<String> rowOnlyMosqueIds;

  const SyncScope({
    this.dataMosqueIds = const {},
    this.rowOnlyMosqueIds = const {},
  });

  bool get isEmpty => dataMosqueIds.isEmpty;

  /// كل المساجد التي يلزم صفّها (بياناتها كاملة أو صفّها فقط).
  Set<String> get allMosqueRowIds => {...dataMosqueIds, ...rowOnlyMosqueIds};

  /// مفتاح ثابت للنطاق: تغيّره (دخول مسجد جديد، خروج) يفرض جلباً أساسياً كاملاً.
  String get key {
    final ids = dataMosqueIds.toList()..sort();
    return ids.join(',');
  }

  bool contains(String? mosqueId) =>
      mosqueId != null && dataMosqueIds.contains(mosqueId);

  /// يحسب النطاق من الجلسات المحفوظة، أو يعيد `null` إذا تعذّر الجزم.
  ///
  /// `null` يعني «ارجع إلى المزامنة الكاملة هذه المرة»: جلسة لا نعرف مسجدها، أو نطاق
  /// أكبر من الحدّ. الخطأ هنا لو حدث يعني حذف بيانات المستخدم من جهازه، فنفضّل
  /// دائماً الطريقة القديمة الثقيلة على تخمين نطاق ناقص.
  ///
  /// جلسات المشرف العام والزائر لا تحتاج بيانات مسجد (للمشرف العام دوال مجمَّعة).
  static SyncScope? fromSessions({
    required Iterable<ActiveSession> sessions,
    required Iterable<Student> students,
    required Iterable<Sheikh> sheikhs,
    required Iterable<Mosque> mosques,
  }) {
    final data = <String>{};

    for (final s in sessions) {
      if (s.role == 'super_admin' || s.role == 'visitor') continue;

      var mosqueId = (s.mosqueId ?? '').trim();
      if (mosqueId.isEmpty) {
        mosqueId = _resolveMosqueId(s, students, sheikhs) ?? '';
      }
      if (mosqueId.isEmpty) return null; // جلسة لا نعرف مسجدها: لا نخمّن
      data.add(mosqueId);
    }

    if (data.length > maxDataMosques) return null;

    final rowOnly = <String>{};
    for (final m in mosques) {
      if (!data.contains(m.id)) continue;
      for (final linked in [m.parentMosqueId, m.womenBranchId]) {
        if (linked != null && linked.isNotEmpty && !data.contains(linked)) {
          rowOnly.add(linked);
        }
      }
    }

    return SyncScope(dataMosqueIds: data, rowOnlyMosqueIds: rowOnly);
  }

  static String? _resolveMosqueId(
    ActiveSession s,
    Iterable<Student> students,
    Iterable<Sheikh> sheikhs,
  ) {
    if (s.role == 'student') {
      for (final st in students) {
        if ((s.studentId != null && st.id == s.studentId) || st.code == s.code) {
          return st.mosqueId;
        }
      }
    } else if (s.role == 'sheikh') {
      for (final sh in sheikhs) {
        if ((s.sheikhId != null && sh.id == s.sheikhId) || sh.code == s.code) {
          return sh.mosqueId;
        }
      }
    }
    return null;
  }
}
