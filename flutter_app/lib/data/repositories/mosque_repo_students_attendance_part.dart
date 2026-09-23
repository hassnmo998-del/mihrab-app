part of 'mosque_repository_impl.dart';

/// Students management and attendance tracking delegation mixin.
mixin MosqueRepoStudentsAttendanceMixin
implements StudentsRepository, AttendanceRepository {
  StudentsRepositoryImpl get studentsRepository;
  AttendanceRepositoryImpl get attendanceRepository;

  // Students Management
  @override
  List<Student> getStudents({
    String? halaqaId,
    String? sheikhId,
    String? mosqueId,
    String? gender,
  }) =>
      studentsRepository.getStudents(
        halaqaId: halaqaId,
        sheikhId: sheikhId,
        mosqueId: mosqueId,
        gender: gender,
      );

  @override
  Student addStudent({
    required String mosqueId,
    required String halaqaId,
    String? sheikhId,
    required String fullName,
    required String gender,
    required String phone,
    String? notes,
    String? birthDate,
    int welcomePoints = 0,
    String? profileImageUrl,
  }) =>
      studentsRepository.addStudent(
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        sheikhId: sheikhId,
        fullName: fullName,
        gender: gender,
        phone: phone,
        notes: notes,
        birthDate: birthDate,
        welcomePoints: welcomePoints,
        profileImageUrl: profileImageUrl,
      );

  @override
  void updateStudent({
    required String studentId,
    required String fullName,
    required String halaqaId,
    required String phone,
    String? birthDate,
    String? notes,
    String? profileImageUrl,
  }) =>
      studentsRepository.updateStudent(
        studentId: studentId,
        fullName: fullName,
        halaqaId: halaqaId,
        phone: phone,
        birthDate: birthDate,
        notes: notes,
        profileImageUrl: profileImageUrl,
      );

  @override
  void deleteStudent(String studentId) =>
      studentsRepository.deleteStudent(studentId);

  @override
  List<PointsLog> getStudentPointsLog(String studentId) =>
      studentsRepository.getStudentPointsLog(studentId);

  @override
  Map<String, dynamic> adjustStudentPoints({
    required String studentId,
    required int delta,
    String? reason,
    String? actorName,
  }) =>
      studentsRepository.adjustStudentPoints(
        studentId: studentId,
        delta: delta,
        reason: reason,
        actorName: actorName,
      );

  // Attendance Management
  @override
  List<AttendanceRecord> getAttendanceForDate(
      String halaqaId, String sessionDate) =>
      attendanceRepository.getAttendanceForDate(halaqaId, sessionDate);

  @override
  void recordAttendance({
    required String studentId,
    required String halaqaId,
    required String sessionDate,
    required String status,
    int pointsEarned = 0,
    String? notes,
  }) =>
      attendanceRepository.recordAttendance(
        studentId: studentId,
        halaqaId: halaqaId,
        sessionDate: sessionDate,
        status: status,
        pointsEarned: pointsEarned,
        notes: notes,
      );

  @override
  Map<String, dynamic> getStudentAttendanceSummary(String studentId) =>
      attendanceRepository.getStudentAttendanceSummary(studentId);
}