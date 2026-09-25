import '../../core/utils/access_code_generator.dart';
import '../../domain/repositories/community_events_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [CommunityEventsRepository] managing community events,
/// gender branch privacy filtering, and tap-based attendance counters.
class CommunityEventsRepositoryImpl implements CommunityEventsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  CommunityEventsRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<CommunityEvent> getCommunityEvents({String? gender, String? mosqueId}) {
    var list = _localDataSource.communityEvents
        .where((e) => e.eventType != 'system_donation_config')
        .toList();
    if (gender != null) {
      if (gender == 'female') {
        list = list
            .where((e) =>
                e.targetAudience == 'female' || e.targetAudience == 'general')
            .toList();
      } else {
        list = list
            .where((e) =>
                e.targetAudience == 'male' || e.targetAudience == 'general')
            .toList();
      }
    }
    if (mosqueId != null) {
      list = list.where((e) => e.mosqueId == mosqueId).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  CommunityEvent addCommunityEvent({
    required String mosqueId,
    required String title,
    required String description,
    required String eventType,
    String? customTypeName,
    String timingType = 'prayer_linked',
    String? prayerName,
    String prayerRelation = 'after',
    required String targetAudience,
    required DateTime eventDateTime,
    required String organizerType,
    required String organizerName,
    int durationMinutes = 60,
    bool isRecurring = true,
    String? recurringDays,
    bool isQaEnabled = false,
    int maxQuestions = 10,
    String? sheikhId,
    String lessonFormat = 'single',
    List<String> sheikhIds = const [],
  }) {
    // كل شيخ مذكور (الأساسي والمشاركون) يجب أن يكون معتمداً في نفس المسجد.
    for (final id in {if (sheikhId != null && sheikhId.isNotEmpty) sheikhId, ...sheikhIds}) {
      final sheikh = _localDataSource.sheikhs.where((s) => s.id == id).firstOrNull;
      if (sheikh == null || sheikh.mosqueId != mosqueId) {
        throw StateError('الشيخ غير معتمد أو غير مسجل في هذا المسجد');
      }
    }

    final mosque = _localDataSource.mosques.where((m) => m.id == mosqueId).firstOrNull;

    final event = CommunityEvent(
      // معرّف مقاوم للتصادم: الطابع الزمني وحده كان يمنح درسين أُنشئا في نفس
      // الملي ثانية نفس المعرّف، فتُكتب تسجيلات درس على درس آخر.
      id: AccessCodeGenerator.entityId('event'),
      mosqueId: mosqueId,
      title: title.trim(),
      description: description.trim(),
      eventType: eventType,
      customTypeName: customTypeName?.trim(),
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      targetAudience: targetAudience,
      eventDateTime: eventDateTime,
      durationMinutes: durationMinutes,
      organizerType: organizerType,
      organizerName: organizerName,
      attendanceCount: 0,
      latitude: mosque?.latitude ?? 33.5138,
      longitude: mosque?.longitude ?? 36.2765,
      isRecurring: isRecurring,
      recurringDays: recurringDays,
      isQaEnabled: isQaEnabled,
      maxQuestions: maxQuestions,
      sheikhId: sheikhId,
      lessonFormat: lessonFormat,
      sheikhIds: lessonFormat == 'group' ? sheikhIds : const [],
    );

    _localDataSource.communityEvents.insert(0, event);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'community_events',
      action: 'upsert',
      data: event.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    // محاولة الإرسال الفوري إلى Supabase
    if (_remoteDataSource != null) {
      Future.microtask(() {
        _syncQueueManager.processQueue(_remoteDataSource);
      });
    }

    return event;
  }

  @override
  void updateCommunityEvent({
    required String eventId,
    required String title,
    required String description,
    required String eventType,
    String? customTypeName,
    String? timingType,
    String? prayerName,
    String? prayerRelation,
    String? targetAudience,
    String? organizerName,
    DateTime? eventDateTime,
    int? durationMinutes,
    bool? isRecurring,
    String? recurringDays,
    bool? isQaEnabled,
    int? maxQuestions,
    String? sheikhId,
    String? eventStatus,
    String? audioRecordUrl,
    bool? isActive,
    String? lessonFormat,
    List<String>? sheikhIds,
  }) {
    final idx =
        _localDataSource.communityEvents.indexWhere((e) => e.id == eventId);
    if (idx != -1) {
      final old = _localDataSource.communityEvents[idx];
      final updated = CommunityEvent(
        id: old.id,
        mosqueId: old.mosqueId,
        title: title.trim(),
        description: description.trim(),
        eventType: eventType,
        customTypeName: customTypeName ?? old.customTypeName,
        timingType: timingType ?? old.timingType,
        prayerName: prayerName ?? old.prayerName,
        prayerRelation: prayerRelation ?? old.prayerRelation,
        targetAudience: targetAudience ?? old.targetAudience,
        latitude: old.latitude,
        longitude: old.longitude,
        eventDateTime: eventDateTime ?? old.eventDateTime,
        durationMinutes: durationMinutes ?? old.durationMinutes,
        organizerType: old.organizerType,
        organizerName: organizerName ?? old.organizerName,
        attendanceCount: old.attendanceCount,
        hasTapped: old.hasTapped,
        isActive: isActive ?? old.isActive,
        isRecurring: isRecurring ?? old.isRecurring,
        recurringDays: recurringDays ?? old.recurringDays,
        isQaEnabled: isQaEnabled ?? old.isQaEnabled,
        maxQuestions: maxQuestions ?? old.maxQuestions,
        eventStatus: eventStatus ?? old.eventStatus,
        audioRecordUrl: audioRecordUrl ?? old.audioRecordUrl,
        // Editing used to rebuild the event without its attachment and drop it.
        videoRecordUrl: old.videoRecordUrl,
        sheikhId: sheikhId ?? old.sheikhId,
        lessonFormat: lessonFormat ?? old.lessonFormat,
        sheikhIds: (lessonFormat ?? old.lessonFormat) == 'group'
            ? (sheikhIds ?? old.sheikhIds)
            : const [],
      );

      _localDataSource.communityEvents[idx] = updated;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: updated.toJson(),
        remoteDataSource: _remoteDataSource,
      );

      // محاولة الإرسال الفوري إلى Supabase
      if (_remoteDataSource != null) {
        Future.microtask(() {
          _syncQueueManager.processQueue(_remoteDataSource);
        });
      }
    }
  }

  @override
  void toggleEventStatus(String eventId) {
    final idx =
        _localDataSource.communityEvents.indexWhere((e) => e.id == eventId);
    if (idx != -1) {
      final ev = _localDataSource.communityEvents[idx];
      ev.isActive = !ev.isActive;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: ev.toJson(),
        id: eventId,
        remoteDataSource: _remoteDataSource,
      );

      // محاولة الإرسال الفوري إلى Supabase
      if (_remoteDataSource != null) {
        Future.microtask(() {
          _syncQueueManager.processQueue(_remoteDataSource);
        });
      }
    }
  }

  @override
  void deleteCommunityEvent(String eventId) {
    _localDataSource.communityEvents.removeWhere((e) => e.id == eventId);
    _localDataSource.recordDeletedId(eventId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'community_events',
      action: 'delete',
      data: {},
      id: eventId,
      remoteDataSource: _remoteDataSource,
    );

    // محاولة الإرسال الفوري والمباشر إلى Supabase
    if (_remoteDataSource != null) {
      _remoteDataSource.delete('community_events', matchingColumn: 'id', matchingValue: eventId).catchError((_) {});
      Future.microtask(() {
        _syncQueueManager.processQueue(_remoteDataSource);
      });
    }
  }

  @override
  void tapAttendance(String eventId) {
    final idx =
        _localDataSource.communityEvents.indexWhere((e) => e.id == eventId);
    if (idx != -1) {
      final event = _localDataSource.communityEvents[idx];
      if (event.hasTapped) {
        // Toggle off: decrement
        event.attendanceCount = (event.attendanceCount - 1).clamp(0, 999999);
        event.hasTapped = false;
      } else {
        // Toggle on: increment
        event.attendanceCount++;
        event.hasTapped = true;
      }

      _localDataSource.saveToStorage();

      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: event.toJson(),
        id: eventId,
        remoteDataSource: _remoteDataSource,
      );

      // محاولة الإرسال الفوري إلى Supabase
      if (_remoteDataSource != null) {
        Future.microtask(() {
          _syncQueueManager.processQueue(_remoteDataSource);
        });
      }
    }
  }
}
