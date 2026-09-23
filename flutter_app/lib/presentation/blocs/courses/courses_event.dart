import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class CoursesEvent extends Equatable {
  const CoursesEvent();

  @override
  List<Object?> get props => [];
}

/// Load intensive courses list
class LoadCoursesEvent extends CoursesEvent {
  final String? mosqueId;
  final String? sheikhId;
  final String? studentId;

  const LoadCoursesEvent({
    this.mosqueId,
    this.sheikhId,
    this.studentId,
  });

  @override
  List<Object?> get props => [mosqueId, sheikhId, studentId];
}

/// Add an intensive course with schedule, enrolled students/halaqat and Quran counting toggle
class AddCourseEvent extends CoursesEvent {
  final String mosqueId;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> sheikhIds;
  final List<String> halaqaIds;
  final List<String> studentIds;
  final List<int> daysOfWeek; // DateTime weekdays (1=Mon, ..., 7=Sun)
  final String? startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final bool countsTowardsQuranProgress;

  const AddCourseEvent({
    required this.mosqueId,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    this.sheikhIds = const [],
    this.halaqaIds = const [],
    this.studentIds = const [],
    this.daysOfWeek = const [6, 1, 3],
    this.startTime,
    this.endTime,
    this.countsTowardsQuranProgress = true,
  });

  @override
  List<Object?> get props => [
        mosqueId,
        name,
        description,
        startDate,
        endDate,
        sheikhIds,
        halaqaIds,
        studentIds,
        daysOfWeek,
        startTime,
        endTime,
        countsTowardsQuranProgress,
      ];
}

/// Update full course details
class UpdateCourseEvent extends CoursesEvent {
  final IntensiveCourse course;

  const UpdateCourseEvent(this.course);

  @override
  List<Object?> get props => [course];
}

/// Toggle whether recitation in this course counts towards official Quran progress
class ToggleCourseQuranCountingEvent extends CoursesEvent {
  final String courseId;
  final bool countsTowardsQuranProgress;

  const ToggleCourseQuranCountingEvent({
    required this.courseId,
    required this.countsTowardsQuranProgress,
  });

  @override
  List<Object?> get props => [courseId, countsTowardsQuranProgress];
}

/// Enroll a student into a course
class EnrollStudentInCourseEvent extends CoursesEvent {
  final String courseId;
  final String studentId;

  const EnrollStudentInCourseEvent({
    required this.courseId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [courseId, studentId];
}

/// Remove a student from a course
class UnenrollStudentFromCourseEvent extends CoursesEvent {
  final String courseId;
  final String studentId;

  const UnenrollStudentFromCourseEvent({
    required this.courseId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [courseId, studentId];
}

/// Check if a course is currently in active session (±30m buffer)
class CheckCourseScheduleEvent extends CoursesEvent {
  final String courseId;
  final DateTime dateTime;
  final int bufferMinutes;

  const CheckCourseScheduleEvent({
    required this.courseId,
    required this.dateTime,
    this.bufferMinutes = 30,
  });

  @override
  List<Object?> get props => [courseId, dateTime, bufferMinutes];
}

/// Delete a course
class DeleteCourseEvent extends CoursesEvent {
  final String courseId;

  const DeleteCourseEvent(this.courseId);

  @override
  List<Object?> get props => [courseId];
}
