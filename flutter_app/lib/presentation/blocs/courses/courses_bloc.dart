import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import 'courses_event.dart';
import 'courses_state.dart';

class CoursesBloc extends Bloc<CoursesEvent, CoursesState> {
  final DataService _dataService;

  CoursesBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(CoursesState.initial()) {
    on<LoadCoursesEvent>(_onLoadCourses);
    on<AddCourseEvent>(_onAddCourse);
    on<UpdateCourseEvent>(_onUpdateCourse);
    on<ToggleCourseQuranCountingEvent>(_onToggleCourseQuranCounting);
    on<EnrollStudentInCourseEvent>(_onEnrollStudentInCourse);
    on<UnenrollStudentFromCourseEvent>(_onUnenrollStudentFromCourse);
    on<CheckCourseScheduleEvent>(_onCheckCourseSchedule);
    on<DeleteCourseEvent>(_onDeleteCourse);
  }

  void _onLoadCourses(LoadCoursesEvent event, Emitter<CoursesState> emit) {
    emit(state.copyWith(status: CoursesStatus.loading));

    try {
      var courses = _dataService.getIntensiveCourses(
        mosqueId: event.mosqueId,
        sheikhId: event.sheikhId,
      );

      if (event.studentId != null && event.studentId!.isNotEmpty) {
        courses = courses
            .where((c) => c.isStudentEnrolled(event.studentId!))
            .toList();
      }

      emit(state.copyWith(
        status: CoursesStatus.loaded,
        courses: courses,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في تحميل الدورات المكثفة: ${e.toString()}',
      ));
    }
  }

  void _onAddCourse(AddCourseEvent event, Emitter<CoursesState> emit) {
    try {
      final course = _dataService.addIntensiveCourse(
        mosqueId: event.mosqueId,
        name: event.name,
        description: event.description,
        startDate: event.startDate,
        endDate: event.endDate,
        sheikhIds: event.sheikhIds,
        halaqaIds: event.halaqaIds,
        studentIds: event.studentIds,
        daysOfWeek: event.daysOfWeek,
        startTime: event.startTime,
        endTime: event.endTime,
        countsTowardsQuranProgress: event.countsTowardsQuranProgress,
      );

      final courses = _dataService.getIntensiveCourses();
      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: courses,
        selectedCourse: () => course,
        successMessage: () => 'تمت إضافة دورة "${course.name}" بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في إضافة الدورة: ${e.toString()}',
      ));
    }
  }

  void _onUpdateCourse(UpdateCourseEvent event, Emitter<CoursesState> emit) {
    try {
      _dataService.updateIntensiveCourse(event.course);
      final courses = _dataService.getIntensiveCourses();

      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: courses,
        selectedCourse: () => event.course,
        successMessage: () => 'تم تحديث بيانات الدورة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في تحديث بيانات الدورة: ${e.toString()}',
      ));
    }
  }

  void _onToggleCourseQuranCounting(
      ToggleCourseQuranCountingEvent event, Emitter<CoursesState> emit) {
    try {
      final course = state.courses.firstWhere((c) => c.id == event.courseId);
      final updated = IntensiveCourse(
        id: course.id,
        mosqueId: course.mosqueId,
        name: course.name,
        description: course.description,
        startDate: course.startDate,
        endDate: course.endDate,
        sheikhIds: course.sheikhIds,
        halaqaIds: course.halaqaIds,
        studentIds: course.studentIds,
        daysOfWeek: course.daysOfWeek,
        startTime: course.startTime,
        endTime: course.endTime,
        countsTowardsQuranProgress: event.countsTowardsQuranProgress,
        createdAt: course.createdAt,
      );

      _dataService.updateIntensiveCourse(updated);
      final courses = _dataService.getIntensiveCourses();

      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: courses,
        selectedCourse: () => updated,
        successMessage: () => event.countsTowardsQuranProgress
            ? 'تم تفعيل احتساب تسميع الدورة ضمن الختمة القرآنية الرسمية للطالب'
            : 'تم إيقاف احتساب تسميع الدورة ضمن الختمة الرسمية (دورة مراجعة/تثبيت مستقلة)',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في تغيير إعداد احتساب القرآن: ${e.toString()}',
      ));
    }
  }

  void _onEnrollStudentInCourse(
      EnrollStudentInCourseEvent event, Emitter<CoursesState> emit) {
    try {
      final course = state.courses.firstWhere((c) => c.id == event.courseId);
      if (!course.studentIds.contains(event.studentId)) {
        final newStudentIds = List<String>.from(course.studentIds)..add(event.studentId);
        final updated = IntensiveCourse(
          id: course.id,
          mosqueId: course.mosqueId,
          name: course.name,
          description: course.description,
          startDate: course.startDate,
          endDate: course.endDate,
          sheikhIds: course.sheikhIds,
          halaqaIds: course.halaqaIds,
          studentIds: newStudentIds,
          daysOfWeek: course.daysOfWeek,
          startTime: course.startTime,
          endTime: course.endTime,
          countsTowardsQuranProgress: course.countsTowardsQuranProgress,
          createdAt: course.createdAt,
        );

        _dataService.updateIntensiveCourse(updated);
        final courses = _dataService.getIntensiveCourses();

        emit(state.copyWith(
          status: CoursesStatus.success,
          courses: courses,
          selectedCourse: () => updated,
          successMessage: () => 'تم تسجيل الطالب في الدورة بنجاح',
          errorMessage: () => null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في تسجيل الطالب في الدورة: ${e.toString()}',
      ));
    }
  }

  void _onUnenrollStudentFromCourse(
      UnenrollStudentFromCourseEvent event, Emitter<CoursesState> emit) {
    try {
      final course = state.courses.firstWhere((c) => c.id == event.courseId);
      final newStudentIds = List<String>.from(course.studentIds)..remove(event.studentId);
      final updated = IntensiveCourse(
        id: course.id,
        mosqueId: course.mosqueId,
        name: course.name,
        description: course.description,
        startDate: course.startDate,
        endDate: course.endDate,
        sheikhIds: course.sheikhIds,
        halaqaIds: course.halaqaIds,
        studentIds: newStudentIds,
        daysOfWeek: course.daysOfWeek,
        startTime: course.startTime,
        endTime: course.endTime,
        countsTowardsQuranProgress: course.countsTowardsQuranProgress,
        createdAt: course.createdAt,
      );

      _dataService.updateIntensiveCourse(updated);
      final courses = _dataService.getIntensiveCourses();

      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: courses,
        selectedCourse: () => updated,
        successMessage: () => 'تم إلغاء تسجيل الطالب من الدورة',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في إلغاء تسجيل الطالب: ${e.toString()}',
      ));
    }
  }

  void _onCheckCourseSchedule(
      CheckCourseScheduleEvent event, Emitter<CoursesState> emit) {
    try {
      final course = state.courses.firstWhere((c) => c.id == event.courseId);
      final isScheduled = course.isScheduledAt(
        event.dateTime,
        bufferMinutes: event.bufferMinutes,
      );

      emit(state.copyWith(
        isScheduledAtCheck: () => isScheduled,
      ));
    } catch (_) {
      emit(state.copyWith(
        isScheduledAtCheck: () => false,
      ));
    }
  }

  void _onDeleteCourse(DeleteCourseEvent event, Emitter<CoursesState> emit) {
    try {
      _dataService.deleteIntensiveCourse(event.courseId);
      final courses = _dataService.getIntensiveCourses();

      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: courses,
        successMessage: () => 'تم حذف الدورة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.error,
        errorMessage: () => 'فشل في حذف الدورة: ${e.toString()}',
      ));
    }
  }
}
