part of 'mosque_repository_impl.dart';

/// Recitation, Quran memorization, and custom tracks delegation mixin.
mixin MosqueRepoRecitationMixin
    implements RecitationRepository, RecitationTracksRepository {
  RecitationRepositoryImpl get recitationRepository;
  RecitationTracksRepositoryImpl get recitationTracksRepository;

  // Quran Memorization & Recitation
  @override
  List<MemorizationRecord> getStudentMemorizations(String studentId) =>
      recitationRepository.getStudentMemorizations(studentId);

  @override
  List<MemorizationRecord> getTodayMemorizations(
          {String? halaqaId, String? sheikhId}) =>
      recitationRepository.getTodayMemorizations(
        halaqaId: halaqaId,
        sheikhId: sheikhId,
      );

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
  }) =>
      recitationRepository.recordRecitationBatch(
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
  }) =>
      recitationRepository.recordMemorization(
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

  @override
  void recordHadith({
    required String studentId,
    String? halaqaId,
    required String hadithTitle,
    required int points,
  }) =>
      recitationRepository.recordHadith(
        studentId: studentId,
        halaqaId: halaqaId,
        hadithTitle: hadithTitle,
        points: points,
      );

  @override
  Set<String> getStudentMemorizedAyahKeys(String studentId) =>
      recitationRepository.getStudentMemorizedAyahKeys(studentId);

  @override
  Map<String, dynamic> getStudentJuzProgress(
          String studentId, int juzNumber) =>
      recitationRepository.getStudentJuzProgress(studentId, juzNumber);

  @override
  Map<String, dynamic> getStudentOverallQuranProgress(String studentId) =>
      recitationRepository.getStudentOverallQuranProgress(studentId);

  @override
  Map<int, Map<String, dynamic>> getStudent30AjzaStatus(String studentId) =>
      recitationRepository.getStudent30AjzaStatus(studentId);

  @override
  int getStudentCompletedAjzaCount(String studentId) =>
      recitationRepository.getStudentCompletedAjzaCount(studentId);

  // Custom Recitation Tracks
  @override
  List<RecitationTrack> getRecitationTracks({
    String? mosqueId,
    String? halaqaId,
    bool activeOnly = true,
  }) =>
      recitationTracksRepository.getRecitationTracks(
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        activeOnly: activeOnly,
      );

  @override
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
  }) =>
      recitationTracksRepository.addRecitationTrack(
        mosqueId: mosqueId,
        name: name,
        category: category,
        unitLabel: unitLabel,
        totalUnits: totalUnits,
        pointsPerUnit: pointsPerUnit,
        isActive: isActive,
        targetHalaqaIds: targetHalaqaIds,
        sheikhId: sheikhId,
      );

  @override
  void updateRecitationTrack(RecitationTrack track) =>
      recitationTracksRepository.updateRecitationTrack(track);

  @override
  void deleteRecitationTrack(String trackId) =>
      recitationTracksRepository.deleteRecitationTrack(trackId);

  @override
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
  }) =>
      recitationTracksRepository.recordSubjectRecitation(
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

  @override
  Map<String, dynamic> getStudentSubjectProgress(
          String studentId, String trackId) =>
      recitationTracksRepository.getStudentSubjectProgress(studentId, trackId);

  @override
  List<Map<String, dynamic>> getAllStudentSubjectProgresses(
          String studentId) =>
      recitationTracksRepository.getAllStudentSubjectProgresses(studentId);
}
