class IntensiveCourse {
  final String id;
  final String mosqueId;
  String name;
  String? description;
  DateTime startDate;
  DateTime endDate;
  List<String> sheikhIds;
  List<String> halaqaIds;
  List<String> studentIds;
  List<int> daysOfWeek; // DateTime weekdays (1=Mon, ..., 7=Sun)
  String? startTime; // "HH:mm" e.g., "16:00"
  String? endTime; // "HH:mm" e.g., "18:00"
  bool countsTowardsQuranProgress;
  final DateTime createdAt;

  IntensiveCourse({
    required this.id,
    required this.mosqueId,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    this.sheikhIds = const [],
    this.halaqaIds = const [],
    this.studentIds = const [],
    this.daysOfWeek = const [6, 1, 3],
    this.startTime,
    this.endTime,
    this.countsTowardsQuranProgress = true,
    required this.createdAt,
  });

  IntensiveCourse copyWith({
    String? id,
    String? mosqueId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? sheikhIds,
    List<String>? halaqaIds,
    List<String>? studentIds,
    List<int>? daysOfWeek,
    String? startTime,
    String? endTime,
    bool? countsTowardsQuranProgress,
    DateTime? createdAt,
  }) =>
      IntensiveCourse(
        id: id ?? this.id,
        mosqueId: mosqueId ?? this.mosqueId,
        name: name ?? this.name,
        description: description ?? this.description,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        sheikhIds: sheikhIds ?? this.sheikhIds,
        halaqaIds: halaqaIds ?? this.halaqaIds,
        studentIds: studentIds ?? this.studentIds,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        countsTowardsQuranProgress:
            countsTowardsQuranProgress ?? this.countsTowardsQuranProgress,
        createdAt: createdAt ?? this.createdAt,
      );

  bool isStudentEnrolled(String stId) {
    if (studentIds.isEmpty) return true; // if empty, applies to all students in linked halaqat
    return studentIds.contains(stId);
  }

  bool isScheduledAt(DateTime dt, {int bufferMinutes = 30}) {
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    if (dateOnly.isBefore(startOnly) || dateOnly.isAfter(endOnly)) {
      return false;
    }

    if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(dt.weekday)) {
      return false;
    }

    if (startTime != null && startTime!.isNotEmpty) {
      final startParts = startTime!.split(':');
      final sH = int.tryParse(startParts[0]) ?? 16;
      final sM = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
      final startDt = DateTime(dt.year, dt.month, dt.day, sH, sM).subtract(Duration(minutes: bufferMinutes));

      DateTime endDt;
      if (endTime != null && endTime!.isNotEmpty) {
        final endParts = endTime!.split(':');
        final eH = int.tryParse(endParts[0]) ?? (sH + 2);
        final eM = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;
        endDt = DateTime(dt.year, dt.month, dt.day, eH, eM).add(Duration(minutes: bufferMinutes));
      } else {
        endDt = DateTime(dt.year, dt.month, dt.day, sH + 2, sM).add(Duration(minutes: bufferMinutes));
      }

      if (dt.isBefore(startDt) || dt.isAfter(endDt)) {
        return false;
      }
    }

    return true;
  }

  factory IntensiveCourse.fromJson(Map<String, dynamic> json) {
    List<int> days = [6, 1, 3];
    if (json['days_of_week'] != null && json['days_of_week'] is List) {
      days = (json['days_of_week'] as List).map((e) => int.tryParse(e.toString()) ?? 1).toList();
    }

    return IntensiveCourse(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : DateTime.now().add(const Duration(days: 30)),
      sheikhIds: (json['sheikh_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      halaqaIds: (json['halaqa_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      studentIds: (json['student_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      daysOfWeek: days,
      startTime: json['start_time'] ?? json['startTime'],
      endTime: json['end_time'] ?? json['endTime'],
      countsTowardsQuranProgress: json['counts_towards_quran_progress'] ?? json['countsTowardsQuranProgress'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'name': name,
    'description': description,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'sheikh_ids': sheikhIds,
    'halaqa_ids': halaqaIds,
    'student_ids': studentIds,
    'days_of_week': daysOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'counts_towards_quran_progress': countsTowardsQuranProgress,
    'created_at': createdAt.toIso8601String(),
  };
}
