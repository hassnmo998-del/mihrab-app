import '../../models/models.dart';

/// Contract for Community Events management.
abstract class CommunityEventsRepository {
  List<CommunityEvent> getCommunityEvents({String? gender, String? mosqueId});
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
  });
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
  });
  void deleteCommunityEvent(String eventId);
  void toggleEventStatus(String eventId);
  void tapAttendance(String eventId);
}
