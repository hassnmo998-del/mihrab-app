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

  @override
  void recordAttendance({
    required String studentId,
    required String halaqaId,
    required String sessionDate, // 'YYYY-MM-DD'
    required String status, // 'present', 'absent', 'late', 'excused'
    int pointsEarned = 0,
    String? notes,
  }) {
    // 1. Reuse existing record id if this student already had attendance on that date
    String recordId = 'att-${DateTime.now().millisecondsSinceEpoch}';
    final existingIdx = _localDataSource.attendanceRecords.indexWhere(
        (a) => a.studentId == studentId && a.sessionDate == sessionDate);
    if (existingIdx != -1) {
      recordId = _localDataSource.attendanceRecords[existingIdx].id;
      _localDataSource.attendanceRecords.removeAt(existingIdx);
    }

    final record = AttendanceRecord(
      id: recordId,
      studentId: studentId,
      halaqaId: halaqaId,
      sessionDate: sessionDate,
      status: status,
      pointsEarned: pointsEarned,
      notes: notes,
    );
    _localDataSource.attendanceRecords.insert(0, record);

    // 2. Award points to student if positive
    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (studentIdx != -1 && pointsEarned > 0) {
      _localDataSource.students[studentIdx].totalPoints += pointsEarned;
      final log = PointsLog(
        id: 'pts-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        points: pointsEarned,
        reason:
            'حضور جلسة $sessionDate (${status == "present" ? "حضور نظامي" : "حضور متأخر"})',
        category: 'attendance',
        createdAt: DateTime.now(),
      );
      _localDataSource.pointsLogs.insert(0, log);
      _syncQueueManager.queueSync(
        table: 'points_logs',
        action: 'upsert',
        data: log.toJson(),
        remoteDataSource: _remoteDataSource,
      );
      _syncQueueManager.queueSync(
        table: 'students',
        action: 'upsert',
        data: _localDataSource.students[studentIdx].toJson(),
        remoteDataSource: _remoteDataSource,
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
