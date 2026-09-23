import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for querying intensive courses filtered by mosque or sheikh.
class GetCoursesUseCase {
  final MosqueRepository _repository;

  const GetCoursesUseCase(this._repository);

  List<IntensiveCourse> call({String? mosqueId, String? sheikhId}) {
    return _repository.getIntensiveCourses(
      mosqueId: mosqueId,
      sheikhId: sheikhId,
    );
  }
}

/// Use case for adding a new intensive course.
class AddCourseUseCase {
  final MosqueRepository _repository;

  const AddCourseUseCase(this._repository);

  IntensiveCourse call({
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
  }) {
    return _repository.addIntensiveCourse(
      mosqueId: mosqueId,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      sheikhIds: sheikhIds,
      halaqaIds: halaqaIds,
      studentIds: studentIds,
      daysOfWeek: daysOfWeek,
      startTime: startTime,
      endTime: endTime,
      countsTowardsQuranProgress: countsTowardsQuranProgress,
    );
  }
}

/// Use case for updating an existing intensive course.
class UpdateCourseUseCase {
  final MosqueRepository _repository;

  const UpdateCourseUseCase(this._repository);

  void call(IntensiveCourse course) => _repository.updateIntensiveCourse(course);
}

/// Use case for deleting an intensive course.
class DeleteCourseUseCase {
  final MosqueRepository _repository;

  const DeleteCourseUseCase(this._repository);

  void call(String courseId) => _repository.deleteIntensiveCourse(courseId);
}
