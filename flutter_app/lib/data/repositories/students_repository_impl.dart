import '../../domain/repositories/students_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [StudentsRepository] managing student enrollment,
/// welcome points ledger, updates, cascades, and points history.
class StudentsRepositoryImpl implements StudentsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  StudentsRepositoryImpl(
      this._localDataSource,
      this._syncQueueManager, {
        SupabaseRemoteDataSource? remoteDataSource,
      }) : _remoteDataSource = remoteDataSource;

  @override
  List<Student> getStudents({
    String? halaqaId,
    String? sheikhId,
    String? mosqueId,
    String? gender,
  }) {
    var list = _localDataSource.students;
    if (halaqaId != null) {
      list = list.where((s) => s.halaqaId == halaqaId).toList();
    }
    if (sheikhId != null) {
      final assignedHalaqaIds = _localDataSource.halaqat
          .where((h) => h.isSheikhAssigned(sheikhId))
          .map((h) => h.id)
          .toSet();
      list = list
          .where((s) =>
      assignedHalaqaIds.contains(s.halaqaId) || s.sheikhId == sheikhId)
          .toList();
    }
    if (mosqueId != null) {
      list = list.where((s) => s.mosqueId == mosqueId).toList();
    }
    if (gender != null) {
      list = list.where((s) => s.gender == gender).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Student addStudent({
    required String mosqueId,
    required String halaqaId,
    String? sheikhId,
    required String fullName,
    required String gender,
    required String phone,
    String? notes,
    String? birthDate,
    int welcomePoints = 0,
    String? profileImageUrl,
  }) {
    final suffix =
    (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final code = 'STD-$suffix';

    final student = Student(
      id: LocalStorageDataSource.genId('student'),
      mosqueId: mosqueId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      fullName: fullName.trim(),
      gender: gender,
      phone: phone.trim(),
      notes: notes?.trim(),
      birthDate: birthDate,
      totalPoints: welcomePoints,
      code: code,
      profileImageUrl: profileImageUrl,
    );

    _localDataSource.students.insert(0, student);

    if (welcomePoints > 0) {
      final log = PointsLog(
        id: 'pts-${DateTime.now().millisecondsSinceEpoch}',
        studentId: student.id,
        points: welcomePoints,
        reason: 'نقاط الترحيب بالانتساب للحلقة القرآنية',
        category: 'manual',
        createdAt: DateTime.now(),
      );
      _localDataSource.pointsLogs.insert(0, log);
      _syncQueueManager.queueSync(
        table: 'points_logs',
        action: 'upsert',
        data: log.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }

    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'students',
      action: 'upsert',
      data: student.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return student;
  }

  @override
  void updateStudent({
    required String studentId,
    required String fullName,
    required String halaqaId,
    required String phone,
    String? birthDate,
    String? notes,
    String? profileImageUrl,
  }) {
    final idx =
    _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (idx != -1) {
      _localDataSource.students[idx].fullName = fullName.trim();
      _localDataSource.students[idx].halaqaId = halaqaId;
      _localDataSource.students[idx].phone = phone.trim();
      if (birthDate != null) _localDataSource.students[idx].birthDate = birthDate.trim();
      if (notes != null) _localDataSource.students[idx].notes = notes.trim();
      _localDataSource.students[idx].profileImageUrl = profileImageUrl;

      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'students',
        action: 'upsert',
        data: _localDataSource.students[idx].toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteStudent(String studentId) {
    _localDataSource.students.removeWhere((s) => s.id == studentId);
    _localDataSource.pointsLogs.removeWhere((p) => p.studentId == studentId);
    _localDataSource.memorizationRecords
        .removeWhere((m) => m.studentId == studentId);
    _localDataSource.attendanceRecords
        .removeWhere((a) => a.studentId == studentId);
    _localDataSource.messages.removeWhere((m) => m.studentId == studentId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'students',
      action: 'delete',
      data: {},
      id: studentId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  List<PointsLog> getStudentPointsLog(String studentId) {
    return _localDataSource.pointsLogs
        .where((p) => p.studentId == studentId)
        .toList();
  }

  @override
  Map<String, dynamic> adjustStudentPoints({
    required String studentId,
    required int delta,
    String? reason,
    String? actorName,
  }) {
    if (delta == 0) {
      return {
        'success': false,
        'message': 'يرجى تحديد عدد نقاط أكبر من صفر',
        'applied': 0,
      };
    }

    final idx = _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (idx == -1) {
      return {
        'success': false,
        'message': 'بيانات الطالب غير موجودة',
        'applied': 0,
      };
    }

    final student = _localDataSource.students[idx];
    final previousTotal = student.totalPoints;

    // منع هبوط رصيد الطالب إلى ما دون الصفر عند الخصم اليدوي
    var applied = delta;
    if (delta < 0 && previousTotal + delta < 0) {
      applied = -previousTotal;
    }
    if (applied == 0) {
      return {
        'success': false,
        'message': 'رصيد الطالب صفر، لا يمكن الخصم منه',
        'applied': 0,
        'previousTotal': previousTotal,
        'total': previousTotal,
      };
    }

    student.totalPoints = previousTotal + applied;

    final trimmedReason = reason?.trim();
    final baseReason = (trimmedReason == null || trimmedReason.isEmpty)
        ? (applied > 0 ? 'إضافة نقاط يدوية' : 'خصم نقاط يدوي')
        : trimmedReason;
    final actor = actorName?.trim();
    final finalReason =
        (actor == null || actor.isEmpty) ? baseReason : '$baseReason — بواسطة: $actor';

    final log = PointsLog(
      id: LocalStorageDataSource.genId('pts'),
      studentId: student.id,
      points: applied,
      reason: finalReason,
      category: 'manual',
      createdAt: DateTime.now(),
    );
    _localDataSource.pointsLogs.insert(0, log);
    _localDataSource.saveToStorage();

    _syncQueueManager.queueSync(
      table: 'students',
      action: 'upsert',
      data: student.toJson(),
      remoteDataSource: _remoteDataSource,
    );
    _syncQueueManager.queueSync(
      table: 'points_logs',
      action: 'upsert',
      data: log.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return {
      'success': true,
      'message': applied > 0
          ? 'تمت إضافة $applied نقطة • الرصيد الحالي: ${student.totalPoints}'
          : 'تم خصم ${applied.abs()} نقطة • الرصيد الحالي: ${student.totalPoints}',
      'applied': applied,
      'requested': delta,
      'previousTotal': previousTotal,
      'total': student.totalPoints,
      'clamped': applied != delta,
    };
  }
}