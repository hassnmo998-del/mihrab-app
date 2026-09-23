class Halaqa {
  final String id;
  final String mosqueId;
  String? sheikhId;
  List<String> coSheikhIds;
  String name;
  String? description;
  int ageGroupMin;
  int ageGroupMax;
  String schedule;
  List<int> daysOfWeek; // DateTime weekdays: 1: Mon, 2: Tue, 3: Wed, 4: Thu, 5: Fri, 6: Sat, 7: Sun
  String timingType; // 'prayer_linked', 'custom'
  String? prayerName; // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  String prayerRelation; // 'after', 'before', 'between_adhan_iqama'
  String? customTime;

  Halaqa({
    required this.id,
    required this.mosqueId,
    this.sheikhId,
    this.coSheikhIds = const [],
    required this.name,
    this.description,
    this.ageGroupMin = 6,
    this.ageGroupMax = 18,
    this.schedule = 'السبت - الإثنين - الأربعاء (عصراً)',
    this.daysOfWeek = const [6, 1, 3], // Sat, Mon, Wed by default
    this.timingType = 'prayer_linked',
    this.prayerName = 'asr',
    this.prayerRelation = 'after',
    this.customTime,
  });

  bool isSheikhAssigned(String sId) {
    if (sheikhId == sId) return true;
    return coSheikhIds.contains(sId);
  }

  bool isScheduledToday() {
    final todayWeekday = DateTime.now().weekday;
    return daysOfWeek.contains(todayWeekday);
  }

  bool isScheduledAt(DateTime dt, {int bufferMinutes = 30}) {
    if (!daysOfWeek.contains(dt.weekday)) return false;

    int startHour = 16;
    int startMin = 0;
    if (customTime != null && customTime!.contains(':')) {
      final parts = customTime!.split(':');
      startHour = int.tryParse(parts[0]) ?? 16;
      startMin = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    } else if (prayerName != null) {
      switch (prayerName) {
        case 'fajr': startHour = 5; break;
        case 'dhuhr': startHour = 12; startMin = 30; break;
        case 'asr': startHour = 16; break;
        case 'maghrib': startHour = 18; startMin = 45; break;
        case 'isha': startHour = 20; break;
      }
    }

    final startDt = DateTime(dt.year, dt.month, dt.day, startHour, startMin).subtract(Duration(minutes: bufferMinutes));
    final endDt = DateTime(dt.year, dt.month, dt.day, startHour + 2, startMin).add(Duration(minutes: bufferMinutes));

    return !dt.isBefore(startDt) && !dt.isAfter(endDt);
  }

  static String dayName(int weekday) {
    switch (weekday) {
      case 6: return 'السبت';
      case 7: return 'الأحد';
      case 1: return 'الإثنين';
      case 2: return 'الثلاثاء';
      case 3: return 'الأربعاء';
      case 4: return 'الخميس';
      case 5: return 'الجمعة';
      default: return '';
    }
  }

  String get formattedDays => daysOfWeek.map(dayName).where((s) => s.isNotEmpty).join(' - ');

  factory Halaqa.fromJson(Map<String, dynamic> json) {
    List<String> coList = [];
    if (json['co_sheikh_ids'] != null && json['co_sheikh_ids'] is List) {
      coList = (json['co_sheikh_ids'] as List).map((e) => e.toString()).toList();
    }
    List<int> days = [6, 1, 3];
    if (json['days_of_week'] != null && json['days_of_week'] is List) {
      days = (json['days_of_week'] as List).map((e) => int.tryParse(e.toString()) ?? 1).toList();
    }
    return Halaqa(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
      coSheikhIds: coList,
      name: json['name'] ?? '',
      description: json['description'],
      ageGroupMin: json['age_group_min'] ?? json['ageGroupMin'] ?? 6,
      ageGroupMax: json['age_group_max'] ?? json['ageGroupMax'] ?? 18,
      schedule: json['schedule'] ?? 'السبت - الإثنين - الأربعاء (عصراً)',
      daysOfWeek: days,
      timingType: json['timing_type'] ?? 'prayer_linked',
      prayerName: json['prayer_name'] ?? 'asr',
      prayerRelation: json['prayer_relation'] ?? 'after',
      customTime: json['custom_time'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'sheikh_id': sheikhId,
    'co_sheikh_ids': coSheikhIds,
    'name': name,
    'description': description,
    'age_group_min': ageGroupMin,
    'age_group_max': ageGroupMax,
    'schedule': schedule,
    'days_of_week': daysOfWeek,
    'timing_type': timingType,
    'prayer_name': prayerName,
    'prayer_relation': prayerRelation,
    'custom_time': customTime,
  };
}
