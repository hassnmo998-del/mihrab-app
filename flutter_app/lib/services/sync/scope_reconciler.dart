import '../../data/datasources/local_storage_datasource.dart';
import 'scaled_sync_engine.dart';
import 'sync_scope.dart';

/// يطبّق على النسخة المحلية ما لا تعرفه المزامنة بالتزايد: الحذف.
///
/// الاستعلام بـ`updated_at` لا يرى الصف المحذوف، ولا الصف الذي خرج من نطاق الجهاز.
/// هنا شيئان:
/// - [applyTombstones]: يحذف ما حُذف في السحابة منذ آخر دورة.
/// - [reconcileBaseline]: بعد جلب أساسي كامل، يجعل ما في الجهاز ضمن النطاق مطابقاً
///   للسحابة تماماً، ويمسح كل ما خرج من النطاق (نسخة قديمة كانت تحمل بيانات كل
///   المساجد). **لا يلمس أبداً** ما ينتظر في طابور الرفع: تعديل أُجري بلا إنترنت
///   أهم من أي ترتيب.
class ScopeReconciler {
  const ScopeReconciler._();

  /// يحذف الصفوف المحذوفة سحابياً. يعيد عددها.
  static int applyTombstones(
    LocalStorageDataSource ds,
    Iterable<SyncTombstone> tombstones, {
    required bool Function(String table, String id) isPendingUpsert,
  }) {
    var removed = 0;
    for (final t in tombstones) {
      if (isPendingUpsert(t.table, t.id)) continue;
      void drop<T>(List<T> list, String Function(T) idOf) {
        final n = list.length;
        list.removeWhere((x) => idOf(x) == t.id);
        removed += n - list.length;
      }

      switch (t.table) {
        case 'mosques':
          drop(ds.mosques, (x) => x.id);
        case 'sheikhs':
          drop(ds.sheikhs, (x) => x.id);
        case 'halaqat':
          drop(ds.halaqat, (x) => x.id);
        case 'students':
          drop(ds.students, (x) => x.id);
        case 'community_events':
          drop(ds.communityEvents, (x) => x.id);
        case 'memorization_records':
          drop(ds.memorizationRecords, (x) => x.id);
        case 'attendance':
          drop(ds.attendanceRecords, (x) => x.id);
        case 'messages':
          drop(ds.messages, (x) => x.id);
        case 'competitions':
          drop(ds.competitions, (x) => x.id);
        case 'intensive_courses':
          drop(ds.intensiveCourses, (x) => x.id);
        case 'trips':
          drop(ds.trips, (x) => x.id);
        case 'rewards':
          drop(ds.rewards, (x) => x.id);
        case 'reward_redemptions':
          drop(ds.redemptions, (x) => x.id);
        case 'recitation_tracks':
          drop(ds.recitationTracks, (x) => x.id);
        case 'subject_recitation_records':
          drop(ds.subjectRecitationRecords, (x) => x.id);
        case 'points_logs':
          drop(ds.pointsLogs, (x) => x.id);
        case 'event_questions':
          drop(ds.eventQuestions, (x) => x.id);
      }
    }
    return removed;
  }

  /// بعد جلب أساسي كامل ([rows] فيها كل جداول النطاق ولو فارغة).
  ///
  /// [keepEventIds] و[keepMosqueIds]: دروس «اكتشف» العامة من مساجد أخرى وصفوف مساجدها،
  /// تبقى رغم خروجها من النطاق. يعيد عدد الصفوف المحذوفة.
  static int reconcileBaseline(
    LocalStorageDataSource ds,
    SyncScope scope,
    Map<String, List<Map<String, dynamic>>> rows, {
    required bool Function(String table, String id) isPendingUpsert,
    Set<String> keepEventIds = const {},
    Set<String> keepMosqueIds = const {},
  }) {
    // بلا نطاق لا نمسح شيئاً أبداً: غياب النطاق يعني «لا نعرف»، لا «لا شيء لك».
    if (scope.isEmpty) return 0;

    Set<String> idsOf(String table) =>
        {for (final r in rows[table] ?? const []) '${r['id']}'};

    var removed = 0;
    void prune<T>(
      List<T> list,
      String table,
      String Function(T) idOf,
      bool Function(T) inScope, {
      bool Function(T)? alsoKeep,
    }) {
      final remote = idsOf(table);
      final n = list.length;
      list.removeWhere((x) {
        final id = idOf(x);
        if (isPendingUpsert(table, id)) return false;
        if (alsoKeep != null && alsoKeep(x)) return false;
        return !(inScope(x) && remote.contains(id));
      });
      removed += n - list.length;
    }

    prune(
      ds.mosques,
      'mosques',
      (x) => x.id,
      (x) => scope.allMosqueRowIds.contains(x.id),
      alsoKeep: (x) => keepMosqueIds.contains(x.id),
    );
    prune(ds.students, 'students', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.sheikhs, 'sheikhs', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.halaqat, 'halaqat', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(
      ds.communityEvents,
      'community_events',
      (x) => x.id,
      (x) => scope.contains(x.mosqueId),
      alsoKeep: (x) => keepEventIds.contains(x.id),
    );
    prune(ds.competitions, 'competitions', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.intensiveCourses, 'intensive_courses', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.trips, 'trips', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.rewards, 'rewards', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.redemptions, 'reward_redemptions', (x) => x.id, (x) => scope.contains(x.mosqueId));
    prune(ds.recitationTracks, 'recitation_tracks', (x) => x.id, (x) => scope.contains(x.mosqueId));

    // ما يتبع الطالب أو الدرس يُحكم عليه بعد أن استقرّت قوائم الطلاب والدروس
    final studentIds = {for (final s in ds.students) s.id};
    final eventIds = {
      for (final e in ds.communityEvents)
        if (scope.contains(e.mosqueId)) e.id,
    };
    prune(ds.attendanceRecords, 'attendance', (x) => x.id, (x) => studentIds.contains(x.studentId));
    prune(ds.memorizationRecords, 'memorization_records', (x) => x.id, (x) => studentIds.contains(x.studentId));
    prune(ds.subjectRecitationRecords, 'subject_recitation_records', (x) => x.id, (x) => studentIds.contains(x.studentId));
    prune(ds.pointsLogs, 'points_logs', (x) => x.id, (x) => studentIds.contains(x.studentId));
    prune(ds.messages, 'messages', (x) => x.id, (x) => studentIds.contains(x.studentId));
    prune(ds.eventQuestions, 'event_questions', (x) => x.id, (x) => eventIds.contains(x.eventId));

    return removed;
  }
}
