import 'package:equatable/equatable.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

/// Helper input model for batch marking attendance
class AttendanceItemInput extends Equatable {
  final String studentId;
  final String status; // 'present', 'late', 'absent', 'excused'
  final int pointsEarned;
  final String? notes;

  const AttendanceItemInput({
    required this.studentId,
    required this.status,
    this.pointsEarned = 0,
    this.notes,
  });

  @override
  List<Object?> get props => [studentId, status, pointsEarned, notes];
}

/// Load attendance records and stats for a halaqa on a specific session date
class LoadHalaqaAttendanceEvent extends AttendanceEvent {
  final String halaqaId;
  final String sessionDate; // 'YYYY-MM-DD'

  const LoadHalaqaAttendanceEvent({
    required this.halaqaId,
    required this.sessionDate,
  });

  @override
  List<Object?> get props => [halaqaId, sessionDate];
}

/// Mark or update attendance for an individual student (حاضر / متأخر / غائب / معذور)
class MarkStudentAttendanceEvent extends AttendanceEvent {
  final String studentId;
  final String halaqaId;
  final String sessionDate; // 'YYYY-MM-DD'
  final String status; // 'present', 'late', 'absent', 'excused'
  final int pointsEarned;
  final String? notes;

  const MarkStudentAttendanceEvent({
    required this.studentId,
    required this.halaqaId,
    required this.sessionDate,
    required this.status,
    this.pointsEarned = 0,
    this.notes,
  });

  @override
  List<Object?> get props => [
        studentId,
        halaqaId,
        sessionDate,
        status,
        pointsEarned,
        notes,
      ];
}

/// Batch mark attendance for multiple students in a halaqa
class BatchMarkAttendanceEvent extends AttendanceEvent {
  final String halaqaId;
  final String sessionDate;
  final List<AttendanceItemInput> items;

  const BatchMarkAttendanceEvent({
    required this.halaqaId,
    required this.sessionDate,
    required this.items,
  });

  @override
  List<Object?> get props => [halaqaId, sessionDate, items];
}

/// Load comprehensive attendance history and percentage stats for a student
class LoadStudentAttendanceSummaryEvent extends AttendanceEvent {
  final String studentId;

  const LoadStudentAttendanceSummaryEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// Change currently active session date and reload attendance
class ChangeAttendanceDateEvent extends AttendanceEvent {
  final String newDate; // 'YYYY-MM-DD'

  const ChangeAttendanceDateEvent(this.newDate);

  @override
  List<Object?> get props => [newDate];
}
