import '../../models/models.dart';

/// Contract for Intensive Courses and smart timing detection (±30m window).
abstract class CoursesRepository {
  List<IntensiveCourse> getIntensiveCourses({String? mosqueId, String? sheikhId});
  IntensiveCourse addIntensiveCourse({
    required String mosqueId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    List<String> sheikhIds = const [],
    List<String> halaqaIds = const [],
    List<String> studentIds = const [],
    List<int> daysOfWeek = const [6, 1, 3],
    String? startTime,
    String? endTime,
    bool countsTowardsQuranProgress = true,
  });
  void updateIntensiveCourse(IntensiveCourse course);
  void deleteIntensiveCourse(String courseId);
  Map<String, dynamic> detectSessionTimingMode({
    required String halaqaId,
    String? studentId,
    DateTime? currentTime,
  });
}
