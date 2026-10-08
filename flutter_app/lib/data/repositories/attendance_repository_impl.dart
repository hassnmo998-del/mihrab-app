import '../../services/points_ledger.dart';
import 'points_writer.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [AttendanceRepository] managing daily session attendance,
/// commitment percentage formula, points awarding, and background sync.
class AttendanceRepositoryImpl implements AttendanceRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  PointsWriter get _points => PointsWriter(_localDataSource, _syncQueueManager, _remoteDataSource);

  AttendanceRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<AttendanceRecord> getAttendanceForDate(
      String halaqaId, String sessionDate) {
    return _localDataSource.attendanceRecords
        .where((a) => a.halaqaId == halaqaId && a.sessionDate == sessionDate)
        .toList();
  }

  /// يرصد حالة الطالب في يوم. **الرصد يُعاد بأمان**: لليوم الواحد سجل حضور واحد وحركة
  /// نقاط واحدة تحمل نقاط حالته الحالية، فتغيير الحالة (حاضر ← متأخر ← غائب) أو الضغط
  /// مرتين يعدّل النقاط إلى قيمتها الجديدة ولا يضيف فوق السابقة.
  ///
  /// كان كل ضغطة تضيف نقاطها من جديد: «حاضر» مرتين = النقاط مضاعفة، و«حاضر» ثم
  /// «غائب» = الطالب يحتفظ بنقاط الحضور.
  @override
  void recordAttendance({
    required String studentId,
    required String halaqaId,
    required String sessionDate, // 'YYYY-MM-DD'
    required String status, // 'present', 'absent', 'late', 'excused'
    int pointsEarned = 0,
    String? notes,
  }) {
    // الحضور يمنح نقاطاً ولا يخصم؛ الخصم له طريقه اليدوي
    final points = pointsEarned < 0 ? 0 : pointsEarned;

    // 1) سجل واحد لليوم: يُحتفظ بمعرّف القائم، وما تكرر من نسخ أقدم يُحذف
    final sameDay = _localDataSource.attendanceRecords
        .where((a) => a.studentId == studentId && a.sessionDate == sessionDate)
        .toList();
    final recordId =
        sameDay.isNotEmpty ? sameDay.first.id : PointsLedger.attendanceRecordId(studentId, sessionDate);
    for (final old in sameDay) {
      _localDataSource.attendanceRecords.remove(old);
      if (old.id != recordId) {
        _syncQueueManager.queueSync(
          table: 'attendance',
          action: 'delete',
          data: {},
          id: old.id,
          remoteDataSource: _remoteDataSource,
        );
      }
    }

    final record = AttendanceRecord(
      id: recordId,
      studentId: studentId,
      halaqaId: halaqaId,
      sessionDate: sessionDate,
      status: status,
      pointsEarned: points,
      notes: notes,
    );
    _localDataSource.attendanceRecords.insert(0, record);

    // 2) نقاط اليوم = [points] بالضبط. حركات اليوم من نسخ أقدم (بمعرّفات عشوائية)
    //    محسوبة في الرصيد أصلاً، فتحمل حركة اليوم الفرق عنها.
    final logId = PointsLedger.attendanceLogId(studentId, sessionDate);
    final prefix = PointsLedger.attendanceReasonPrefix(sessionDate);
    final legacy = _localDataSource.pointsLogs
        .where((l) =>
            l.studentId == studentId &&
            l.id != logId &&
            l.category == PointsLedger.attendanceCategory &&
            l.reason.startsWith(prefix))
        .fold<int>(0, (sum, l) => sum + l.points);
    final target = points - legacy;
    final hasEntry = _localDataSource.pointsLogs.any((l) => l.id == logId);
    if (target != 0 || hasEntry) {
      _points.apply(
        studentId: studentId,
        points: target,
        reason: PointsLedger.attendanceReason(sessionDate, status),
        category: PointsLedger.attendanceCategory,
        logId: logId,
      );
    }

    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'attendance',
      action: 'upsert',
      data: record.toJson(),
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  Map<String, dynamic> getStudentAttendanceSummary(String studentId) {
    final records = _localDataSource.attendanceRecords
        .where((a) => a.studentId == studentId)
        .toList();
    records.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    int present = 0;
    int late = 0;
    int absent = 0;

    for (var r in records) {
      if (r.status == 'present') {
        present++;
      } else if (r.status == 'late') {
        late++;
      } else if (r.status == 'absent') {
        absent++;
      }
    }

    final total = records.length;
    final rate = total > 0
        ? ((present + late * 0.5) / total * 100).toStringAsFixed(1)
        : '100.0';

    return {
      'records': records,
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'attendanceRate': rate,
    };
  }
}
