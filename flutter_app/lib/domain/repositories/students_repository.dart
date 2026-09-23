import '../../models/models.dart';

/// Contract for Students and Points Log management.
abstract class StudentsRepository {
  List<Student> getStudents({
    String? halaqaId,
    String? sheikhId,
    String? mosqueId,
    String? gender,
  });

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
    String? profileImageUrl, // الحقل الجديد
  });

  void updateStudent({
    required String studentId,
    required String fullName,
    required String halaqaId,
    required String phone,
    String? birthDate,
    String? notes,
    String? profileImageUrl, // الحقل الجديد
  });

  void deleteStudent(String studentId);
  List<PointsLog> getStudentPointsLog(String studentId);

  /// تعديل يدوي لرصيد نقاط الطالب (إضافة عند [delta] موجب، خصم عند [delta] سالب).
  ///
  /// يسجل الحركة في سجل النقاط بتصنيف `manual` ويدرجها في طابور المزامنة.
  /// يمنع هبوط الرصيد إلى ما دون الصفر، ويعيد خريطة نتيجة تحتوي:
  /// `success`, `message`, `applied`, `requested`, `previousTotal`, `total`, `clamped`.
  Map<String, dynamic> adjustStudentPoints({
    required String studentId,
    required int delta,
    String? reason,
    String? actorName,
  });
}