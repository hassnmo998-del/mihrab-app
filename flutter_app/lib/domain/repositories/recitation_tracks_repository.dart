import '../../models/models.dart';

/// Contract for custom recitation tracks (Hadith, Mutun, Fiqh, Books) and unit deduplication.
abstract class RecitationTracksRepository {
  List<RecitationTrack> getRecitationTracks({
    String? mosqueId,
    String? halaqaId,
    bool activeOnly = true,
  });
  RecitationTrack addRecitationTrack({
    required String mosqueId,
    required String name,
    String category = 'custom',
    String unitLabel = 'حديث',
    int totalUnits = 40,
    int pointsPerUnit = 2,
    bool isActive = true,
    List<String> targetHalaqaIds = const [],
    String? sheikhId,
  });
  void updateRecitationTrack(RecitationTrack track);
  void deleteRecitationTrack(String trackId);
  SubjectRecitationRecord recordSubjectRecitation({
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
  });
  Map<String, dynamic> getStudentSubjectProgress(String studentId, String trackId);
  List<Map<String, dynamic>> getAllStudentSubjectProgresses(String studentId);
}
