import '../../domain/repositories/competitions_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [CompetitionsRepository] managing competitions CRUD,
/// course leaderboard recalculation, and honor ranking matrix.
class CompetitionsRepositoryImpl implements CompetitionsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager? _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  CompetitionsRepositoryImpl(
    this._localDataSource, {
    OfflineSyncQueueManager? syncQueueManager,
    SupabaseRemoteDataSource? remoteDataSource,
  })  : _syncQueueManager = syncQueueManager,
        _remoteDataSource = remoteDataSource;

  @override
  List<Competition> getCompetitions({String? gender, String? mosqueId}) {
    var list = _localDataSource.competitions;
    if (gender != null) {
      list = list.where((c) => c.genderBranch == gender).toList();
    }
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      list = list
          .where((c) =>
              c.mosqueId.isEmpty ||
              c.mosqueId == 'all' ||
              c.mosqueId == mosqueId)
          .toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Competition addCompetition({
    String mosqueId = '',
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    bool countQuran = true,
    bool countHadith = true,
    bool countAttendance = true,
    int bonusPoints = 0,
    required String genderBranch,
  }) {
    final comp = Competition(
      id: 'comp-${DateTime.now().millisecondsSinceEpoch}',
      mosqueId: mosqueId,
      title: title.trim(),
      description: description.trim(),
      startDate: startDate,
      endDate: endDate,
      countQuran: countQuran,
      countHadith: countHadith,
      countAttendance: countAttendance,
      bonusPoints: bonusPoints,
      genderBranch: genderBranch,
    );

    _localDataSource.competitions.insert(0, comp);
    _localDataSource.saveToStorage();

    _syncQueueManager?.queueSync(
      table: 'competitions',
      action: 'upsert',
      data: comp.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return comp;
  }

  @override
  void updateCompetition(Competition comp) {
    final idx =
        _localDataSource.competitions.indexWhere((c) => c.id == comp.id);
    if (idx != -1) {
      _localDataSource.competitions[idx] = comp;
      _localDataSource.saveToStorage();

      _syncQueueManager?.queueSync(
        table: 'competitions',
        action: 'upsert',
        data: comp.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteCompetition(String competitionId) {
    _localDataSource.competitions.removeWhere((c) => c.id == competitionId);
    _localDataSource.saveToStorage();

    _syncQueueManager?.queueSync(
      table: 'competitions',
      action: 'delete',
      data: {},
      id: competitionId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  List<Map<String, dynamic>> getRankings({
    String? competitionId,
    String? mosqueId,
    String? halaqaId,
    String? gender,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var candidateStudents = _localDataSource.students;
    if (gender != null) {
      // الفرع يُقرأ من سجل المسجد لا من حقل الطالب: بعض الطالبات سُجّلن سابقاً
      // بقيمة 'male' افتراضياً فكانت أسماؤهن تظهر في ترتيب الرجال.
      final branchByMosqueId = <String, String>{
        for (final m in _localDataSource.mosques) m.id: m.gender,
      };
      candidateStudents = candidateStudents
          .where((s) => (branchByMosqueId[s.mosqueId] ?? s.gender) == gender)
          .toList();
    }
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      candidateStudents =
          candidateStudents.where((s) => s.mosqueId == mosqueId).toList();
    }
    if (halaqaId != null && halaqaId.isNotEmpty && halaqaId != 'all') {
      candidateStudents =
          candidateStudents.where((s) => s.halaqaId == halaqaId).toList();
    }

    final isCourseRank =
        courseId != null && courseId.isNotEmpty && courseId != 'all';
    if (isCourseRank) {
      final course = _localDataSource.intensiveCourses.firstWhere(
        (c) => c.id == courseId,
        orElse: () => IntensiveCourse(
            id: '',
            mosqueId: '',
            name: '',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            createdAt: DateTime.now()),
      );
      if (course.studentIds.isNotEmpty) {
        candidateStudents = candidateStudents
            .where((s) => course.studentIds.contains(s.id))
            .toList();
      }
    }

    final results = <Map<String, dynamic>>[];

    for (var student in candidateStudents) {
      final mosque = _localDataSource.mosques.firstWhere(
        (m) => m.id == student.mosqueId,
        orElse: () => Mosque(
            id: '',
            name: 'مسجد',
            city: '',
            gender: student.gender,
            accessCode: ''),
      );
      final halaqa = _localDataSource.halaqat.firstWhere(
        (h) => h.id == student.halaqaId,
        orElse: () =>
            Halaqa(id: '', mosqueId: '', name: 'حلقة عامة'),
      );

      int score = 0;
      
      if (isCourseRank) {
        // حساب نقاط دورة معينة
        final quranPts = _localDataSource.memorizationRecords
            .where((m) =>
                m.studentId == student.id &&
                m.courseId == courseId &&
                m.countsTowardsStatistics)
            .fold<int>(0, (sum, m) => sum + m.pointsEarned);
        final subjectPts = _localDataSource.subjectRecitationRecords
            .where((s) =>
                s.studentId == student.id &&
                s.courseId == courseId &&
                s.countsTowardsStatistics)
            .fold<int>(0, (sum, s) => sum + s.pointsEarned);
        score = quranPts + subjectPts;
      } else if (startDate != null || endDate != null) {
        // حساب النقاط بناءً على فترة زمنية محددة
        score = _localDataSource.pointsLogs.where((log) {
          if (log.studentId != student.id) return false;
          bool afterStart = startDate == null || log.createdAt.isAfter(startDate) || log.createdAt.isAtSameMomentAs(startDate);
          bool beforeEnd = endDate == null || log.createdAt.isBefore(endDate) || log.createdAt.isAtSameMomentAs(endDate);
          return afterStart && beforeEnd;
        }).fold<int>(0, (sum, log) => sum + log.points);
      } else {
        // الترتيب العام الشامل (الكل)
        score = student.totalPoints;
      }

      results.add({
        'student': student,
        'score': score,
        'mosqueName': mosque.name,
        'halaqaName': halaqa.name,
      });
    }

    // Sort descending
    results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    for (int i = 0; i < results.length; i++) {
      results[i]['rank'] = i + 1;
    }

    return results;
  }
}
