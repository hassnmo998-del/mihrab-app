import '../../models/models.dart';

/// Contract for authentic Quran recitation and 30 Ajza / 6,236 Ayahs progress calculations.
abstract class RecitationRepository {
  List<MemorizationRecord> getStudentMemorizations(String studentId);
  List<MemorizationRecord> getTodayMemorizations({String? halaqaId, String? sheikhId});
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
  });
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
  });
  void recordHadith({
    required String studentId,
    String? halaqaId,
    required String hadithTitle,
    required int points,
  });
  Set<String> getStudentMemorizedAyahKeys(String studentId);
  Map<String, dynamic> getStudentJuzProgress(String studentId, int juzNumber);
  Map<String, dynamic> getStudentOverallQuranProgress(String studentId);
  Map<int, Map<String, dynamic>> getStudent30AjzaStatus(String studentId);
  int getStudentCompletedAjzaCount(String studentId);
}
