class MemorizationRecord {
  final String id;
  final String studentId;
  final String? halaqaId;
  final String? sheikhId;
  final String? courseId;
  final String surahName;
  final int fromAyah;
  final int toAyah;
  final int juzNumber;
  final String sessionType; // 'new_memorization', 'review', 'test'
  final String qualityRating; // 'excellent', 'good', 'needs_improvement'
  final int pointsEarned;
  final String? notes;
  final bool countsTowardsStatistics;
  final DateTime recordedAt;

  MemorizationRecord({
    required this.id,
    required this.studentId,
    this.halaqaId,
    this.sheikhId,
    this.courseId,
    required this.surahName,
    required this.fromAyah,
    required this.toAyah,
    required this.juzNumber,
    required this.sessionType,
    required this.qualityRating,
    required this.pointsEarned,
    this.notes,
    this.countsTowardsStatistics = true,
    required this.recordedAt,
  });

  factory MemorizationRecord.fromJson(Map<String, dynamic> json) {
    return MemorizationRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      halaqaId: json['halaqa_id']?.toString() ?? json['halaqaId']?.toString(),
      sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
      courseId: json['course_id']?.toString() ?? json['courseId']?.toString(),
      surahName: json['surah_name'] ?? json['surahName'] ?? '',
      fromAyah: json['from_ayah'] ?? json['fromAyah'] ?? 1,
      toAyah: json['to_ayah'] ?? json['toAyah'] ?? 1,
      juzNumber: json['juz_number'] ?? json['juzNumber'] ?? 1,
      sessionType: json['session_type'] ?? json['sessionType'] ?? 'new_memorization',
      qualityRating: json['quality_rating'] ?? json['qualityRating'] ?? 'excellent',
      pointsEarned: json['points_earned'] ?? json['pointsEarned'] ?? 0,
      notes: json['notes'],
      countsTowardsStatistics: json['counts_towards_statistics'] ?? json['countsTowardsStatistics'] ?? true,
      recordedAt: json['recorded_at'] != null ? DateTime.parse(json['recorded_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'halaqa_id': halaqaId,
    'sheikh_id': sheikhId,
    'course_id': courseId,
    'surah_name': surahName,
    'from_ayah': fromAyah,
    'to_ayah': toAyah,
    'juz_number': juzNumber,
    'session_type': sessionType,
    'quality_rating': qualityRating,
    'points_earned': pointsEarned,
    'notes': notes,
    'counts_towards_statistics': countsTowardsStatistics,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
