import '../../domain/repositories/courses_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [CoursesRepository] managing intensive courses CRUD,
/// and smart recitation timing detection (±30m window).
class CoursesRepositoryImpl implements CoursesRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  CoursesRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<IntensiveCourse> getIntensiveCourses(
      {String? mosqueId, String? sheikhId}) {
    var list = _localDataSource.intensiveCourses;
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      list = list.where((c) => c.mosqueId == mosqueId).toList();
    }
    if (sheikhId != null && sheikhId.isNotEmpty) {
      list = list
          .where((c) => c.sheikhIds.isEmpty || c.sheikhIds.contains(sheikhId))
          .toList();
    }
    return List.unmodifiable(list);
  }

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
  }) {
    final course = IntensiveCourse(
      id: LocalStorageDataSource.genId('crs'),
      mosqueId: mosqueId,
      name: name.trim(),
      description: description?.trim(),
      startDate: startDate,
      endDate: endDate,
      sheikhIds: sheikhIds,
      halaqaIds: halaqaIds,
      studentIds: studentIds,
      daysOfWeek: daysOfWeek,
      startTime: startTime,
      endTime: endTime,
      countsTowardsQuranProgress: countsTowardsQuranProgress,
      createdAt: DateTime.now(),
    );

    _localDataSource.intensiveCourses.insert(0, course);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'intensive_courses',
      action: 'upsert',
      data: course.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return course;
  }

  @override
  void updateIntensiveCourse(IntensiveCourse course) {
    final idx = _localDataSource.intensiveCourses
        .indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      _localDataSource.intensiveCourses[idx] = course;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'intensive_courses',
        action: 'upsert',
        data: course.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteIntensiveCourse(String courseId) {
    _localDataSource.intensiveCourses.removeWhere((c) => c.id == courseId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'intensive_courses',
      action: 'delete',
      data: {},
      id: courseId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  Map<String, dynamic> detectSessionTimingMode({
    required String halaqaId,
    String? studentId,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final halaqa = _localDataSource.halaqat.firstWhere(
      (h) => h.id == halaqaId,
      orElse: () => Halaqa(id: '', mosqueId: '', name: ''),
    );

    // 1. Check if now matches any active Intensive Course linked to this halaqa or student (±30 mins)
    for (final course in _localDataSource.intensiveCourses) {
      if (course.mosqueId == halaqa.mosqueId) {
        final isHalaqaLinked =
            course.halaqaIds.isEmpty || course.halaqaIds.contains(halaqaId);
        final isStudentLinked =
            studentId == null || course.isStudentEnrolled(studentId);

        if (isHalaqaLinked && isStudentLinked) {
          if (course.isScheduledAt(now, bufferMinutes: 30)) {
            return {
              'mode': 'course',
              'courseId': course.id,
              'course': course,
              'label': 'دورة: ${course.name}',
              'reason': 'ضمن موعد جلسات الدورة الاستثنائية الحالية',
              'countsTowardsQuran': course.countsTowardsQuranProgress,
            };
          }
        }
      }
    }

    // 2. Check if now matches the regular Halaqa schedule (±30 mins)
    if (halaqa.id.isNotEmpty && halaqa.isScheduledAt(now, bufferMinutes: 30)) {
      return {
        'mode': 'normal',
        'courseId': null,
        'course': null,
        'label': 'جلسة الحلقة الاعتيادية (${halaqa.name})',
        'reason': 'ضمن الموعد المجدول لجلسات الحلقة القرآنية الاعتيادية',
        'countsTowardsQuran': true,
      };
    }

    // 3. Outside both scheduled times -> Custom timing
    return {
      'mode': 'custom',
      'courseId': null,
      'course': null,
      'label': 'تسميع بوقت مخصص (خارج الجلسات المعتادة)',
      'reason':
          'الوقت الحالي خارج أوقات الجلسات والدورات المجدولة (تم تفعيل وضع التسميع المخصص)',
      'countsTowardsQuran': true,
    };
  }
}
