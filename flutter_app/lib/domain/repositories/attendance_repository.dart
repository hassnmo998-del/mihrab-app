import '../../models/models.dart';

/// Contract for Attendance management and commitment calculations.
abstract class AttendanceRepository {
  List<AttendanceRecord> getAttendanceForDate(String halaqaId, String sessionDate);
  void recordAttendance({
    required String studentId,
    required String halaqaId,
    required String sessionDate,
    required String status,
    int pointsEarned = 0,
    String? notes,
  });
  Map<String, dynamic> getStudentAttendanceSummary(String studentId);
}
