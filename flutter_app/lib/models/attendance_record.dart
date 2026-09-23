class AttendanceRecord {
  final String id;
  final String studentId;
  final String halaqaId;
  final String sessionDate; // 'YYYY-MM-DD'
  final String status; // 'present', 'absent', 'late', 'excused'
  final int pointsEarned;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.halaqaId,
    required this.sessionDate,
    required this.status,
    this.pointsEarned = 0,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      halaqaId: json['halaqa_id']?.toString() ?? json['halaqaId']?.toString() ?? '',
      sessionDate: json['session_date'] ?? json['sessionDate'] ?? '',
      status: json['status'] ?? 'present',
      pointsEarned: json['points_earned'] ?? json['pointsEarned'] ?? 0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'halaqa_id': halaqaId,
    'session_date': sessionDate,
    'status': status,
    'points_earned': pointsEarned,
    'notes': notes,
  };
}
