part of 'mosque_repository_impl.dart';

/// Community events, messages, and executive overview delegation mixin.
mixin MosqueRepoCommunityOverviewMixin
    implements
        CommunityEventsRepository,
        MessagesRepository,
        ExecutiveOverviewRepository {
  CommunityEventsRepositoryImpl get communityEventsRepository;
  MessagesRepositoryImpl get messagesRepository;
  ExecutiveOverviewRepositoryImpl get executiveOverviewRepository;

  // Community Events
  @override
  List<CommunityEvent> getCommunityEvents(
          {String? gender, String? mosqueId}) =>
      communityEventsRepository.getCommunityEvents(
        gender: gender,
        mosqueId: mosqueId,
      );

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
  }) =>
      communityEventsRepository.addCommunityEvent(
        mosqueId: mosqueId,
        title: title,
        description: description,
        eventType: eventType,
        customTypeName: customTypeName,
        timingType: timingType,
        prayerName: prayerName,
        prayerRelation: prayerRelation,
        targetAudience: targetAudience,
        eventDateTime: eventDateTime,
        organizerType: organizerType,
        organizerName: organizerName,
        durationMinutes: durationMinutes,
        isRecurring: isRecurring,
        recurringDays: recurringDays,
        isQaEnabled: isQaEnabled,
        maxQuestions: maxQuestions,
        sheikhId: sheikhId,
        lessonFormat: lessonFormat,
        sheikhIds: sheikhIds,
      );

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
  }) =>
      communityEventsRepository.updateCommunityEvent(
        eventId: eventId,
        title: title,
        description: description,
        eventType: eventType,
        customTypeName: customTypeName,
        timingType: timingType,
        prayerName: prayerName,
        prayerRelation: prayerRelation,
        targetAudience: targetAudience,
        organizerName: organizerName,
        eventDateTime: eventDateTime,
        durationMinutes: durationMinutes,
        isRecurring: isRecurring,
        recurringDays: recurringDays,
        isQaEnabled: isQaEnabled,
        maxQuestions: maxQuestions,
        sheikhId: sheikhId,
        eventStatus: eventStatus,
        audioRecordUrl: audioRecordUrl,
        isActive: isActive,
        lessonFormat: lessonFormat,
        sheikhIds: sheikhIds,
      );

  @override
  void deleteCommunityEvent(String eventId) =>
      communityEventsRepository.deleteCommunityEvent(eventId);

  @override
  void toggleEventStatus(String eventId) =>
      communityEventsRepository.toggleEventStatus(eventId);

  @override
  void tapAttendance(String eventId) =>
      communityEventsRepository.tapAttendance(eventId);

  // Messages & Inquiries
  @override
  List<AppMessage> getStudentMessages(String studentId) =>
      messagesRepository.getStudentMessages(studentId);

  @override
  List<AppMessage> getHalaqaMessages(String halaqaId) =>
      messagesRepository.getHalaqaMessages(halaqaId);

  @override
  void sendMessage({
    required String studentId,
    required String halaqaId,
    required String senderType,
    required String senderName,
    required String content,
    String messageType = 'general',
  }) =>
      messagesRepository.sendMessage(
        studentId: studentId,
        halaqaId: halaqaId,
        senderType: senderType,
        senderName: senderName,
        content: content,
        messageType: messageType,
      );

  // Executive Overview
  @override
  List<Map<String, dynamic>> getExecutiveOverview({
    String? mosqueId,
    String? sheikhId,
    String? halaqaId,
    String? searchQuery,
    DateTime? date,
  }) =>
      executiveOverviewRepository.getExecutiveOverview(
        mosqueId: mosqueId,
        sheikhId: sheikhId,
        halaqaId: halaqaId,
        searchQuery: searchQuery,
        date: date,
      );
}
