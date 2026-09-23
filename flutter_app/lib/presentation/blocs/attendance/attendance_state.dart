import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum AttendanceStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class AttendanceState extends Equatable {
  final AttendanceStatus status;
  final String sessionDate;
  final String? halaqaId;
  final String? studentId;
  final List<AttendanceRecord> records;
  final Map<String, dynamic>? studentSummary;
  final Map<String, dynamic>? halaqaSessionStats;
  final String? errorMessage;
  final String? successMessage;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.sessionDate = '',
    this.halaqaId,
    this.studentId,
    this.records = const [],
    this.studentSummary,
    this.halaqaSessionStats,
    this.errorMessage,
    this.successMessage,
  });

  factory AttendanceState.initial() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return AttendanceState(sessionDate: todayStr);
  }

  // Helper Getters for Halaqa Stats
  int get presentCount =>
      (halaqaSessionStats?['presentCount'] as num?)?.toInt() ??
      records.where((r) => r.status == 'present').length;

  int get lateCount =>
      (halaqaSessionStats?['lateCount'] as num?)?.toInt() ??
      records.where((r) => r.status == 'late').length;

  int get absentCount =>
      (halaqaSessionStats?['absentCount'] as num?)?.toInt() ??
      records.where((r) => r.status == 'absent').length;

  int get excusedCount =>
      (halaqaSessionStats?['excusedCount'] as num?)?.toInt() ??
      records.where((r) => r.status == 'excused').length;

  int get totalRecorded => records.length;

  double get attendancePercentage {
    if (halaqaSessionStats?['attendancePercentage'] != null) {
      return (halaqaSessionStats!['attendancePercentage'] as num).toDouble();
    }
    if (totalRecorded == 0) return 100.0;
    return ((presentCount + (lateCount * 0.5)) / totalRecorded * 100);
  }

  // Student Summary Getters
  int get studentTotalSessions =>
      (studentSummary?['total'] as num?)?.toInt() ?? 0;
  int get studentPresentCount =>
      (studentSummary?['present'] as num?)?.toInt() ?? 0;
  int get studentLateCount =>
      (studentSummary?['late'] as num?)?.toInt() ?? 0;
  int get studentAbsentCount =>
      (studentSummary?['absent'] as num?)?.toInt() ?? 0;
  String get studentAttendanceRate =>
      studentSummary?['attendanceRate']?.toString() ?? '100.0';

  AttendanceRecord? getRecordForStudent(String studentId) {
    try {
      return records.firstWhere((r) => r.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  String getStudentStatus(String studentId) {
    return getRecordForStudent(studentId)?.status ?? 'unrecorded';
  }

  AttendanceState copyWith({
    AttendanceStatus? status,
    String? sessionDate,
    String? Function()? halaqaId,
    String? Function()? studentId,
    List<AttendanceRecord>? records,
    Map<String, dynamic>? Function()? studentSummary,
    Map<String, dynamic>? Function()? halaqaSessionStats,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      sessionDate: sessionDate ?? this.sessionDate,
      halaqaId: halaqaId != null ? halaqaId() : this.halaqaId,
      studentId: studentId != null ? studentId() : this.studentId,
      records: records ?? this.records,
      studentSummary:
          studentSummary != null ? studentSummary() : this.studentSummary,
      halaqaSessionStats: halaqaSessionStats != null
          ? halaqaSessionStats()
          : this.halaqaSessionStats,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        sessionDate,
        halaqaId,
        studentId,
        records,
        studentSummary,
        halaqaSessionStats,
        errorMessage,
        successMessage,
      ];
}
