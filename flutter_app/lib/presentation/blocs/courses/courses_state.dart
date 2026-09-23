import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum CoursesStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class CoursesState extends Equatable {
  final CoursesStatus status;
  final List<IntensiveCourse> courses;
  final IntensiveCourse? selectedCourse;
  final bool? isScheduledAtCheck;
  final String? errorMessage;
  final String? successMessage;

  const CoursesState({
    this.status = CoursesStatus.initial,
    this.courses = const [],
    this.selectedCourse,
    this.isScheduledAtCheck,
    this.errorMessage,
    this.successMessage,
  });

  factory CoursesState.initial() => const CoursesState();

  // Active / Upcoming / Completed Filter Getters
  List<IntensiveCourse> get activeCourses {
    final now = DateTime.now();
    return courses.where((c) {
      final start = DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
      final end = DateTime(c.endDate.year, c.endDate.month, c.endDate.day, 23, 59, 59);
      return !now.isBefore(start) && !now.isAfter(end);
    }).toList();
  }

  List<IntensiveCourse> get upcomingCourses {
    final now = DateTime.now();
    return courses.where((c) {
      final start = DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
      return now.isBefore(start);
    }).toList();
  }

  List<IntensiveCourse> get completedCourses {
    final now = DateTime.now();
    return courses.where((c) {
      final end = DateTime(c.endDate.year, c.endDate.month, c.endDate.day, 23, 59, 59);
      return now.isAfter(end);
    }).toList();
  }

  List<IntensiveCourse> get quranCountingCourses =>
      courses.where((c) => c.countsTowardsQuranProgress).toList();

  int get totalCount => courses.length;
  int get activeCount => activeCourses.length;

  CoursesState copyWith({
    CoursesStatus? status,
    List<IntensiveCourse>? courses,
    IntensiveCourse? Function()? selectedCourse,
    bool? Function()? isScheduledAtCheck,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return CoursesState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      selectedCourse:
          selectedCourse != null ? selectedCourse() : this.selectedCourse,
      isScheduledAtCheck: isScheduledAtCheck != null
          ? isScheduledAtCheck()
          : this.isScheduledAtCheck,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        courses,
        selectedCourse,
        isScheduledAtCheck,
        errorMessage,
        successMessage,
      ];
}
