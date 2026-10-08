import '../core/utils/arabic_time.dart';
import '../core/utils/wall_clock.dart';

class CommunityEvent {
  final String id;
  final String mosqueId;
  String title;
  String description;
  String eventType;
  String? customTypeName;
  String timingType;
  String? prayerName;
  String? prayerRelation;
  String targetAudience;
  final double latitude;
  final double longitude;
  DateTime eventDateTime;
  int durationMinutes;
  final String organizerType;
  final String organizerName;
  int attendanceCount;
  bool hasTapped;
  bool isActive;
  double? distanceMeters;
  bool isRecurring;
  String? recurringDays; // الأيام المحددة للتكرار مثل: 'السبت, الاثنين, الخميس'
  String? sheikhId; // الحقل الجديد لربط الدرس بالشيخ

  /// 'single' (شيخ واحد) أو 'group' (درس جماعي يلقيه عدة شيوخ).
  String lessonFormat;

  /// كل الشيوخ المشاركين في الدرس الجماعي؛ [sheikhId] هو الشيخ الأساسي بينهم.
  List<String> sheikhIds;

  // --- الحقول الجديدة للأسئلة والتسجيل الصوتي والمرئي ---
  bool isQaEnabled;
  int maxQuestions;
  String? audioRecordUrl;
  String? videoRecordUrl;
  String eventStatus; // 'upcoming', 'live', 'archived'

  CommunityEvent({
    required this.id,
    required this.mosqueId,
    required this.title,
    required this.description,
    required this.eventType,
    this.customTypeName,
    this.timingType = 'prayer_linked',
    this.prayerName,
    this.prayerRelation = 'after',
    required this.targetAudience,
    this.latitude = 33.5138,
    this.longitude = 36.2765,
    required this.eventDateTime,
    this.durationMinutes = 60,
    required this.organizerType,
    required this.organizerName,
    this.attendanceCount = 0,
    this.hasTapped = false,
    this.isActive = true,
    this.distanceMeters,
    this.isRecurring = true,
    this.recurringDays,
    this.isQaEnabled = false,
    this.maxQuestions = 10,
    this.audioRecordUrl,
    this.videoRecordUrl,
    this.eventStatus = 'upcoming',
    this.sheikhId,
    this.lessonFormat = 'single',
    this.sheikhIds = const [],
  });

  bool get isGroupLesson => lessonFormat == 'group' && allSheikhIds.length > 1;

  /// الشيخ الأساسي أولاً ثم بقية المشاركين، بلا تكرار.
  List<String> get allSheikhIds => {
        if (sheikhId != null && sheikhId!.isNotEmpty) sheikhId!,
        ...sheikhIds.where((id) => id.isNotEmpty),
      }.toList();

  /// هل يلقي هذا الشيخ الدرس (منفرداً أو مشاركاً)؟ المطابقة بالمعرّف أولاً، والاسم
  /// احتياطاً للدروس القديمة التي لم يُحفظ فيها معرّف الشيخ.
  bool involvesSheikh({String? sheikhId, String? name}) {
    if (sheikhId != null && sheikhId.isNotEmpty && allSheikhIds.contains(sheikhId)) {
      return true;
    }
    return name != null && name.trim().isNotEmpty && organizerName.trim() == name.trim();
  }

  bool get hasMedia => (audioRecordUrl != null && audioRecordUrl!.isNotEmpty) || (videoRecordUrl != null && videoRecordUrl!.isNotEmpty);
  bool get hasVideo => videoRecordUrl != null && videoRecordUrl!.isNotEmpty;
  bool get hasAudio => audioRecordUrl != null && audioRecordUrl!.isNotEmpty;

  String get displayCategory {
    if (eventType == 'custom' && (customTypeName?.isNotEmpty ?? false)) {
      return customTypeName!;
    }
    switch (eventType) {
      case 'lesson':
        return 'دروس فقه وعلم 📖';
      case 'mawlid':
        return 'مجالس صلاة على النبي ﷺ 💚';
      case 'tajweed':
        return 'دورات تجويد 🎙️';
      case 'dhikr_circle':
        return 'مجالس ذكر وتلاوة 📿';
      default:
        return customTypeName?.isNotEmpty == true ? customTypeName! : 'نشاط مجتمعي';
    }
  }

  /// قاعدة الموعد بلا تاريخ اليوم: «كل السبت، الاثنين • 6:00 م»، «مباشرة بعد صلاة العصر»،
  /// «الأربعاء 2026/10/07 • 6:00 م». الجلسة القادمة نفسها من `LessonSchedule.sessionLabel`.
  ///
  /// الدرس المتكرر لا يُذكر معه تاريخ: كان يُعرض تاريخ أول جلسة («كل السبت • 2026/09/01
  /// الساعة 18:00») ولو مضى عليها شهر.
  String get timingDescription {
    if (timingType == 'prayer_linked' && prayerName != null) {
      final prayerAr = {
        'fajr': 'صلاة الفجر',
        'dhuhr': 'صلاة الظهر',
        'asr': 'صلاة العصر',
        'maghrib': 'صلاة المغرب',
        'isha': 'صلاة العشاء',
        'jumua': 'صلاة الجمعة',
      }[prayerName] ?? 'الصلاة';

      final relAr = {
        'after': 'مباشرة بعد',
        'between_adhan_iqama': 'بين أذان وإقامة',
        'before': 'قبل أذان',
      }[prayerRelation] ?? 'بعد';

      final base = '$relAr $prayerAr';
      if (!isRecurring) return base;
      // صلاة الجمعة يوم الجمعة وحده، أياً كانت الأيام المختارة
      if (prayerName == 'jumua') return 'كل جمعة • $base';
      return '$_recurrenceText • $base';
    }

    final clock = ArabicTime.clock(eventDateTime);
    if (isRecurring) return '$_recurrenceText • $clock';
    return '${ArabicTime.weekday(eventDateTime)} ${ArabicTime.date(eventDateTime)} • $clock';
  }

  String get _recurrenceText {
    final days = ArabicTime.orderedDays(recurringDays);
    if (days.isEmpty || days.length == ArabicTime.weekOrder.length) return 'يومياً';
    return 'كل ${days.join('، ')}';
  }

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      eventType: json['event_type'] ?? json['eventType'] ?? 'lesson',
      customTypeName: json['custom_type_name'] ?? json['customTypeName'],
      timingType: json['timing_type'] ?? json['timingType'] ?? 'prayer_linked',
      prayerName: json['prayer_name'] ?? json['prayerName'],
      prayerRelation: json['prayer_relation'] ?? json['prayerRelation'] ?? 'after',
      targetAudience: json['target_audience'] ?? json['targetAudience'] ?? 'general',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 33.5138,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 36.2765,
      eventDateTime: parseWallClock(json['event_datetime']),
      durationMinutes: json['duration_minutes'] ?? json['durationMinutes'] ?? 60,
      organizerType: json['organizer_type'] ?? json['organizerType'] ?? 'sheikh',
      organizerName: json['organizer_name'] ?? json['organizerName'] ?? '',
      attendanceCount: json['attendance_count'] ?? json['attendanceCount'] ?? 0,
      hasTapped: json['has_tapped'] ?? false,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      isRecurring: json['is_recurring'] ?? json['isRecurring'] ?? true,
      recurringDays: json['recurring_days']?.toString() ?? json['recurringDays']?.toString(),
      isQaEnabled: json['is_qa_enabled'] ?? json['isQaEnabled'] ?? false,
      maxQuestions: json['max_questions'] ?? json['maxQuestions'] ?? 10,
      audioRecordUrl: json['audio_record_url'] ?? json['audioRecordUrl'],
      videoRecordUrl: json['video_record_url'] ?? json['videoRecordUrl'],
      eventStatus: json['event_status'] ?? json['eventStatus'] ?? 'upcoming',
      sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
      lessonFormat: json['lesson_format'] ?? json['lessonFormat'] ?? 'single',
      sheikhIds: ((json['sheikh_ids'] ?? json['sheikhIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'title': title,
    'description': description,
    'event_type': eventType,
    'custom_type_name': customTypeName,
    'timing_type': timingType,
    'prayer_name': prayerName,
    'prayer_relation': prayerRelation,
    'target_audience': targetAudience,
    'latitude': latitude,
    'longitude': longitude,
    'event_datetime': wallClockJson(eventDateTime),
    'duration_minutes': durationMinutes,
    'organizer_type': organizerType,
    'organizer_name': organizerName,
    'attendance_count': attendanceCount,
    'is_active': isActive,
    'is_recurring': isRecurring,
    'recurring_days': recurringDays,
    'is_qa_enabled': isQaEnabled,
    'max_questions': maxQuestions,
    'audio_record_url': audioRecordUrl,
    'video_record_url': videoRecordUrl,
    'event_status': eventStatus,
    'sheikh_id': sheikhId,
    'lesson_format': lessonFormat,
    'sheikh_ids': sheikhIds,
  };
}
