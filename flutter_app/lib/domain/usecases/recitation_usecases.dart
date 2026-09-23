import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for recording custom subject recitation progress (e.g. Hadith, Mutoon).
class RecordSubjectRecitationUseCase {
  final MosqueRepository _repository;

  const RecordSubjectRecitationUseCase(this._repository);

  SubjectRecitationRecord call({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    required String trackId,
    required String trackName,
    required int fromUnit,
    required int toUnit,
    required int pointsEarned,
    String? courseId,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    return _repository.recordSubjectRecitation(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      trackId: trackId,
      trackName: trackName,
      fromUnit: fromUnit,
      toUnit: toUnit,
      pointsEarned: pointsEarned,
      courseId: courseId,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
  }
}

/// Use case for retrieving comprehensive student progress (Quran & custom subjects).
class GetStudentProgressUseCase {
  final MosqueRepository _repository;

  const GetStudentProgressUseCase(this._repository);

  /// Get overall Quran progress or track-specific progress
  Map<String, dynamic> call(String studentId, {String? trackId}) {
    if (trackId != null && trackId.isNotEmpty) {
      return _repository.getStudentSubjectProgress(studentId, trackId);
    }
    return _repository.getStudentOverallQuranProgress(studentId);
  }

  /// Overall Quran memorization statistics (completed Ajza, memorized ayahs)
  Map<String, dynamic> getOverallQuranProgress(String studentId) =>
      _repository.getStudentOverallQuranProgress(studentId);

  /// Status of all 30 Quran Ajza
  Map<int, Map<String, dynamic>> get30AjzaStatus(String studentId) =>
      _repository.getStudent30AjzaStatus(studentId);

  /// Specific subject track progress
  Map<String, dynamic> getSubjectProgress(String studentId, String trackId) =>
      _repository.getStudentSubjectProgress(studentId, trackId);

  /// All subject progress maps for student
  List<Map<String, dynamic>> getAllSubjectProgresses(String studentId) =>
      _repository.getAllStudentSubjectProgresses(studentId);
}

/// Use case for smart session & recitation timing detection (±30 minutes buffer).
class DetectTimingModeUseCase {
  final MosqueRepository _repository;

  const DetectTimingModeUseCase(this._repository);

  Map<String, dynamic> call({
    required String halaqaId,
    String? studentId,
    DateTime? currentTime,
  }) {
    return _repository.detectSessionTimingMode(
      halaqaId: halaqaId,
      studentId: studentId,
      currentTime: currentTime,
    );
  }
}

/// Use case for recording Quran memorization segment.
class RecordMemorizationUseCase {
  final MosqueRepository _repository;

  const RecordMemorizationUseCase(this._repository);

  void call({
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
    _repository.recordMemorization(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      courseId: courseId,
      surahName: surahName,
      fromAyah: fromAyah,
      toAyah: toAyah,
      juzNumber: juzNumber,
      sessionType: sessionType,
      qualityRating: qualityRating,
      points: points,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
  }
}

/// Use case for batch recording multiple Quran portions.
class RecordRecitationBatchUseCase {
  final MosqueRepository _repository;

  const RecordRecitationBatchUseCase(this._repository);

  void call({
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
    _repository.recordRecitationBatch(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      courseId: courseId,
      items: items,
      sessionType: sessionType,
      points: points,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
  }
}
