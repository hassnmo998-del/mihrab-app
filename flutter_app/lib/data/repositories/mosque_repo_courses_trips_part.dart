part of 'mosque_repository_impl.dart';

/// Intensive Courses and Trips & Outings delegation mixin.
mixin MosqueRepoCoursesTripsMixin implements CoursesRepository, TripsRepository {
  CoursesRepositoryImpl get coursesRepository;
  TripsRepositoryImpl get tripsRepository;

  // Intensive Courses
  @override
  List<IntensiveCourse> getIntensiveCourses(
          {String? mosqueId, String? sheikhId}) =>
      coursesRepository.getIntensiveCourses(
        mosqueId: mosqueId,
        sheikhId: sheikhId,
      );

  @override
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
  }) =>
      coursesRepository.addIntensiveCourse(
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

  @override
  void updateIntensiveCourse(IntensiveCourse course) =>
      coursesRepository.updateIntensiveCourse(course);

  @override
  void deleteIntensiveCourse(String courseId) =>
      coursesRepository.deleteIntensiveCourse(courseId);

  @override
  Map<String, dynamic> detectSessionTimingMode({
    required String halaqaId,
    String? studentId,
    DateTime? currentTime,
  }) =>
      coursesRepository.detectSessionTimingMode(
        halaqaId: halaqaId,
        studentId: studentId,
        currentTime: currentTime,
      );

  // Trips & Outings
  @override
  List<Trip> getTrips(
          {String? mosqueId, String? studentId, String? halaqaId}) =>
      tripsRepository.getTrips(
        mosqueId: mosqueId,
        studentId: studentId,
        halaqaId: halaqaId,
      );

  @override
  Trip addTrip({
    required String mosqueId,
    required String title,
    required String destination,
    required DateTime tripDate,
    String meetingTime = '08:00 صباحاً',
    DateTime? deadlineDate,
    String? description,
    String requiredItems = 'لباس مريح، مصحف جيب، مياه وطعام خفيف',
    List<String> targetHalaqaIds = const [],
    List<String> targetStudentIds = const [],
    int costPoints = 0,
  }) =>
      tripsRepository.addTrip(
        mosqueId: mosqueId,
        title: title,
        destination: destination,
        tripDate: tripDate,
        meetingTime: meetingTime,
        deadlineDate: deadlineDate,
        description: description,
        requiredItems: requiredItems,
        targetHalaqaIds: targetHalaqaIds,
        targetStudentIds: targetStudentIds,
        costPoints: costPoints,
      );

  @override
  void updateTrip(Trip trip) => tripsRepository.updateTrip(trip);

  @override
  void deleteTrip(String tripId) => tripsRepository.deleteTrip(tripId);
}
