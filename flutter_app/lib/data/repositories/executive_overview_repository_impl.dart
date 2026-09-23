import '../../domain/repositories/executive_overview_repository.dart';
import '../../domain/repositories/recitation_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';

/// Concrete implementation of [ExecutiveOverviewRepository] aggregating
/// high-level supervisory matrix across students, attendance, recitation, and points.
class ExecutiveOverviewRepositoryImpl implements ExecutiveOverviewRepository {
  final LocalStorageDataSource _localDataSource;
  final RecitationRepository _recitationRepository;

  ExecutiveOverviewRepositoryImpl(
    this._localDataSource,
    this._recitationRepository,
  );

  @override
  List<Map<String, dynamic>> getExecutiveOverview({
    String? mosqueId,
    String? sheikhId,
    String? halaqaId,
    String? searchQuery,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final dateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    var studentsList = _localDataSource.students;
    if (mosqueId != null) {
      studentsList =
          studentsList.where((s) => s.mosqueId == mosqueId).toList();
    }
    if (halaqaId != null) {
      studentsList =
          studentsList.where((s) => s.halaqaId == halaqaId).toList();
    } else if (sheikhId != null) {
      final sheikhHalaqat = _localDataSource.halaqat
          .where((h) => h.isSheikhAssigned(sheikhId))
          .map((h) => h.id)
          .toSet();
      studentsList =
          studentsList.where((s) => sheikhHalaqat.contains(s.halaqaId)).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      studentsList = studentsList
          .where((s) =>
              s.fullName.toLowerCase().contains(q) ||
              s.code.toLowerCase().contains(q))
          .toList();
    }

    return studentsList.map((student) {
      final halaqa = _localDataSource.halaqat.firstWhere(
        (h) => h.id == student.halaqaId,
        orElse: () =>
            Halaqa(id: '', mosqueId: student.mosqueId, name: 'الحلقة العامة'),
      );
      final sheikh = _localDataSource.sheikhs.firstWhere(
        (s) => s.id == (halaqa.sheikhId ?? ''),
        orElse: () => Sheikh(
            id: '',
            mosqueId: student.mosqueId,
            fullName: 'المحفظ المعتمد',
            code: ''),
      );
      final att = _localDataSource.attendanceRecords.firstWhere(
        (a) => a.studentId == student.id && a.sessionDate == dateStr,
        orElse: () => AttendanceRecord(
            id: '',
            studentId: student.id,
            halaqaId: student.halaqaId,
            sessionDate: dateStr,
            status: 'unrecorded'),
      );
      final quranRecs = _localDataSource.memorizationRecords
          .where((m) => m.studentId == student.id)
          .toList();
      final lastQuran = quranRecs.isNotEmpty ? quranRecs.first : null;
      final hadithLogs = _localDataSource.pointsLogs
          .where((p) => p.studentId == student.id && p.category == 'hadith')
          .toList();
      final lastHadith = hadithLogs.isNotEmpty ? hadithLogs.first : null;
      final completedAjza =
          _recitationRepository.getStudentCompletedAjzaCount(student.id);

      return {
        'student': student,
        'halaqa': halaqa,
        'sheikh': sheikh,
        'attendance': att,
        'lastQuran': lastQuran,
        'lastHadith': lastHadith,
        'completedAjza': completedAjza,
        'totalPoints': student.totalPoints,
      };
    }).toList();
  }
}
