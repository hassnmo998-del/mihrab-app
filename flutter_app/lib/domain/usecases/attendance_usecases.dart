import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for recording student attendance in a halaqa session.
class RecordAttendanceUseCase {
  final MosqueRepository _repository;

  const RecordAttendanceUseCase(this._repository);

  void call({
    required String studentId,
    required String halaqaId,
    required String sessionDate,
    required String status,
    int pointsEarned = 0,
    String? notes,
  }) {
    _repository.recordAttendance(
      studentId: studentId,
      halaqaId: halaqaId,
      sessionDate: sessionDate,
      status: status,
      pointsEarned: pointsEarned,
      notes: notes,
    );
  }
}

/// Use case for retrieving student attendance summary statistics and date-filtered records.
class GetAttendanceSummaryUseCase {
  final MosqueRepository _repository;

  const GetAttendanceSummaryUseCase(this._repository);

  Map<String, dynamic> call(String studentId) {
    return _repository.getStudentAttendanceSummary(studentId);
  }

  List<AttendanceRecord> getForDate(String halaqaId, String sessionDate) {
    return _repository.getAttendanceForDate(halaqaId, sessionDate);
  }
}
