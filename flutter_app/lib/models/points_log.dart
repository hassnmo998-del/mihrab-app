class PointsLog {
  final String id;
  final String studentId;
  final int points;
  final String reason;
  final String category; // 'memorization', 'hadith', 'attendance', 'dhikr', 'behavior', 'competition', 'manual'
  final DateTime createdAt;
  final String? competitionId;

  PointsLog({
    required this.id,
    required this.studentId,
    required this.points,
    required this.reason,
    required this.category,
    required this.createdAt,
    this.competitionId,
  });

  factory PointsLog.fromJson(Map<String, dynamic> json) {
    return PointsLog(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      points: json['points'] ?? 0,
      reason: json['reason'] ?? '',
      category: json['category'] ?? 'memorization',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      competitionId: json['competition_id'] ?? json['competitionId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'points': points,
    'reason': reason,
    'category': category,
    'created_at': createdAt.toIso8601String(),
    'competition_id': competitionId,
  };
}
