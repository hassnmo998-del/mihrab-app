import '../../core/utils/access_code_generator.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// المكان الوحيد الذي تُكتب منه حركة نقاط: الحضور، التسميع، الحديث، المتون، الإضافة
/// والخصم اليدويان، وصرف الجوائز.
///
/// كل حركة: سطر في سجل النقاط + تحديث رصيد الطالب + رفع السطر + رفع **عمود الرصيد
/// وحده**. كان كل موضع يرفع سجل الطالب كاملاً من نسخته، فيكتب جهازٌ نسخته قديمة فوق
/// اسم الطالب أو حلقته أو رصيده كما عدّلها جهاز آخر.
class PointsWriter {
  final LocalStorageDataSource _local;
  final OfflineSyncQueueManager _queue;
  final SupabaseRemoteDataSource? _remote;

  const PointsWriter(this._local, this._queue, this._remote);

  /// يسجّل حركة [points] (موجبة أو سالبة) للطالب ويعيدها، أو `null` إن لم يوجد الطالب.
  ///
  /// مع [logId] الحركة «قيمة حالية» لا إضافة: إن وُجدت حركة بهذا المعرّف استُبدلت
  /// قيمتها وعُدّل الرصيد بالفرق فقط (نقاط حضور يوم واحد مثلاً). بدونه حركة جديدة.
  PointsLog? apply({
    required String studentId,
    required int points,
    required String reason,
    required String category,
    String? logId,
  }) {
    final studentIdx = _local.students.indexWhere((s) => s.id == studentId);
    if (studentIdx == -1) return null;
    final student = _local.students[studentIdx];

    final existingIdx = logId == null ? -1 : _local.pointsLogs.indexWhere((l) => l.id == logId);
    final previous = existingIdx == -1 ? null : _local.pointsLogs[existingIdx];
    if (previous != null && previous.points == points && previous.reason == reason) {
      return previous; // لا تغيير: لا كتابة ولا رفع
    }

    final log = PointsLog(
      id: logId ?? AccessCodeGenerator.entityId('pts'),
      studentId: studentId,
      points: points,
      reason: reason,
      category: category,
      // تعديل حركة قائمة لا ينقلها من يومها
      createdAt: previous?.createdAt ?? DateTime.now(),
    );
    if (existingIdx == -1) {
      _local.pointsLogs.insert(0, log);
    } else {
      _local.pointsLogs[existingIdx] = log;
    }
    student.totalPoints += points - (previous?.points ?? 0);

    _queue.queueSync(
      table: 'points_logs',
      action: 'upsert',
      data: log.toJson(),
      remoteDataSource: _remote,
    );
    _queue.queueSync(
      table: 'students',
      action: 'patch',
      id: student.id,
      data: {'total_points': student.totalPoints},
      remoteDataSource: _remote,
    );
    return log;
  }
}
