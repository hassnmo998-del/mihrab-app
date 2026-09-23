class SubjectRecitationRecord {
  final String id;
  final String studentId;
  final String? halaqaId;
  final String? sheikhId;
  final String trackId;
  final String trackName;
  final int fromUnit;
  final int toUnit;
  final int unitsCount;
  final int pointsEarned;
  final String? courseId;
  final String? notes;
  final bool countsTowardsStatistics;
  final DateTime recordedAt;

  SubjectRecitationRecord({
    required this.id,
    required this.studentId,
    this.halaqaId,
    this.sheikhId,
    required this.trackId,
    required this.trackName,
    required this.fromUnit,
    required this.toUnit,
    required this.unitsCount,
    required this.pointsEarned,
    this.courseId,
    this.notes,
    this.countsTowardsStatistics = true,
    required this.recordedAt,
  });

  factory SubjectRecitationRecord.fromJson(Map<String, dynamic> json) => SubjectRecitationRecord(
    id: json['id']?.toString() ?? '',
    studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
    halaqaId: json['halaqa_id']?.toString() ?? json['halaqaId']?.toString(),
    sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
    trackId: json['track_id']?.toString() ?? json['trackId']?.toString() ?? '',
    trackName: json['track_name'] ?? json['trackName'] ?? '',
    fromUnit: json['from_unit'] ?? json['fromUnit'] ?? 1,
    toUnit: json['to_unit'] ?? json['toUnit'] ?? 1,
    unitsCount: json['units_count'] ?? json['unitsCount'] ?? 1,
    pointsEarned: json['points_earned'] ?? json['pointsEarned'] ?? 0,
    courseId: json['course_id']?.toString() ?? json['courseId']?.toString(),
    notes: json['notes'],
    countsTowardsStatistics: json['counts_towards_statistics'] ?? json['countsTowardsStatistics'] ?? true,
    recordedAt: json['recorded_at'] != null ? DateTime.parse(json['recorded_at']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'halaqa_id': halaqaId,
    'sheikh_id': sheikhId,
    'track_id': trackId,
    'track_name': trackName,
    'from_unit': fromUnit,
    'to_unit': toUnit,
    'units_count': unitsCount,
    'points_earned': pointsEarned,
    'course_id': courseId,
    'notes': notes,
    'counts_towards_statistics': countsTowardsStatistics,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
