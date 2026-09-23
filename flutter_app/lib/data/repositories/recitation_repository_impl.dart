import '../../domain/repositories/recitation_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';
import 'quran_progress_calculator.dart';

/// Concrete implementation of [RecitationRepository] managing authentic Quran recitation,
/// 30 Ajza / 6,236 Ayahs deduplication, Hadith logging, and progress computations.
class RecitationRepositoryImpl implements RecitationRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  RecitationRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<MemorizationRecord> getStudentMemorizations(String studentId) {
    return _localDataSource.memorizationRecords
        .where((m) => m.studentId == studentId)
        .toList();
  }

  @override
  List<MemorizationRecord> getTodayMemorizations(
      {String? halaqaId, String? sheikhId}) {
    final today = DateTime.now();
    return _localDataSource.memorizationRecords.where((m) {
      final sameDay = m.recordedAt.year == today.year &&
          m.recordedAt.month == today.month &&
          m.recordedAt.day == today.day;
      if (!sameDay) return false;
      if (halaqaId != null && m.halaqaId != halaqaId) return false;
      return true;
    }).toList();
  }

  @override
  void recordRecitationBatch({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    String? courseId,
    required List<Map<String, dynamic>> items,
    required String sessionType,
    required int points,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    if (items.isEmpty) return;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final record = MemorizationRecord(
        id: 'mem-${DateTime.now().millisecondsSinceEpoch}-$i',
        studentId: studentId,
        halaqaId: halaqaId,
        sheikhId: sheikhId,
        courseId: courseId,
        surahName: item['surahName'] as String,
        fromAyah: item['fromAyah'] as int,
        toAyah: item['toAyah'] as int,
        juzNumber: item['juzNumber'] as int,
        sessionType: sessionType,
        qualityRating: 'excellent',
        pointsEarned: i == 0 ? points : 0,
        notes: notes,
        countsTowardsStatistics: countsTowardsStatistics,
        recordedAt: DateTime.now(),
      );

      _localDataSource.memorizationRecords.insert(0, record);
      _syncQueueManager.queueSync(
        table: 'memorization_records',
        action: 'upsert',
        data: record.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }

    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (studentIdx != -1) {
      if (countsTowardsStatistics) {
        _localDataSource.students[studentIdx].totalPoints += points;
      }
      final typeAr = sessionType == 'new_memorization'
          ? 'حفظ جديد'
          : (sessionType == 'review' ? 'مراجعة' : 'اختبار إتقان');

      String summaryDescription;
      if (items.length == 1) {
        final it = items.first;
        summaryDescription =
            '$typeAr: سورة ${it['surahName']} (${it['fromAyah']}-${it['toAyah']})';
      } else {
        final surahNames =
            items.map((it) => it['surahName']).toSet().join('، ');
        summaryDescription = '$typeAr: عدة مقاطع ($surahNames)';
      }

      if (courseId != null && courseId.isNotEmpty) {
        final course = _localDataSource.intensiveCourses.firstWhere(
          (c) => c.id == courseId,
          orElse: () => IntensiveCourse(
            id: '',
            mosqueId: '',
            name: 'دورة استثنائية',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );
        summaryDescription += ' [دورة: ${course.name}]';
      }

      if (!countsTowardsStatistics) {
        summaryDescription += ' (سجل خاص - غير محسوب بالإحصائيات العامة)';
      }

      final log = PointsLog(
        id: 'pts-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        points: countsTowardsStatistics ? points : 0,
        reason: summaryDescription,
        category: 'memorization',
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
  }

  @override
  void recordMemorization({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    String? courseId,
    required String surahName,
    required int fromAyah,
    required int toAyah,
    required int juzNumber,
    required String sessionType,
    String qualityRating = 'excellent',
    required int points,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    recordRecitationBatch(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      courseId: courseId,
      items: [
        {
          'surahName': surahName,
          'fromAyah': fromAyah,
          'toAyah': toAyah,
          'juzNumber': juzNumber,
        }
      ],
      sessionType: sessionType,
      points: points,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
  }

  @override
  void recordHadith({
    required String studentId,
    String? halaqaId,
    required String hadithTitle,
    required int points,
  }) {
    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (studentIdx != -1) {
      _localDataSource.students[studentIdx].totalPoints += points;
      final log = PointsLog(
        id: 'pts-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        points: points,
        reason: 'تسميع حديث نبوي شريف: $hadithTitle',
        category: 'hadith',
        createdAt: DateTime.now(),
      );
      _localDataSource.pointsLogs.insert(0, log);
      _localDataSource.saveToStorage();
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
  }

  @override
  Set<String> getStudentMemorizedAyahKeys(String studentId) {
    return QuranProgressCalculator.computeMemorizedAyahKeys(
      records: getStudentMemorizations(studentId),
      intensiveCourses: _localDataSource.intensiveCourses,
    );
  }

  @override
  Map<String, dynamic> getStudentJuzProgress(String studentId, int juzNumber) {
    return QuranProgressCalculator.computeJuzProgress(
      memorizedKeys: getStudentMemorizedAyahKeys(studentId),
      juzNumber: juzNumber,
    );
  }

  @override
  Map<String, dynamic> getStudentOverallQuranProgress(String studentId) {
    return QuranProgressCalculator.computeOverallProgress(
      getStudentMemorizedAyahKeys(studentId),
    );
  }

  @override
  Map<int, Map<String, dynamic>> getStudent30AjzaStatus(String studentId) {
    return QuranProgressCalculator.compute30AjzaStatus(
      getStudentMemorizedAyahKeys(studentId),
    );
  }

  @override
  int getStudentCompletedAjzaCount(String studentId) {
    return getStudentOverallQuranProgress(studentId)['completedAjza'] as int;
  }
}
