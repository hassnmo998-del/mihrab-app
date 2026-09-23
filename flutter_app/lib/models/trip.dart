import 'student.dart';

class Trip {
  final String id;
  final String mosqueId;
  String title;
  String destination;
  DateTime tripDate;
  String meetingTime;
  DateTime? deadlineDate;
  String? description;
  String requiredItems; // ما يلزم إحضاره مع الطالب
  List<String> targetHalaqaIds;
  List<String> targetStudentIds;
  int costPoints;
  String status; // 'upcoming', 'completed', 'cancelled'
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.mosqueId,
    required this.title,
    required this.destination,
    required this.tripDate,
    required this.meetingTime,
    this.deadlineDate,
    this.description,
    this.requiredItems = 'لباس مريح، مصحف جيب، مياه وطعام خفيف',
    this.targetHalaqaIds = const [],
    this.targetStudentIds = const [],
    this.costPoints = 0,
    this.status = 'upcoming',
    required this.createdAt,
  });

  bool get isUpcoming => status == 'upcoming' && !tripDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  String get requirements => requiredItems;
  DateTime get registrationDeadline => deadlineDate ?? tripDate;
  List<String> get studentIds => targetStudentIds;
  List<String> get halaqaIds => targetHalaqaIds;
  String? get leaderName => description?.contains('المشرف:') == true
      ? description!.split('المشرف:').last.split('-').first.trim()
      : null;
  String? get leaderPhone => description?.contains('هاتف:') == true
      ? description!.split('هاتف:').last.trim()
      : null;

  Trip copyWith({
    String? id,
    String? mosqueId,
    String? title,
    String? destination,
    DateTime? tripDate,
    String? meetingTime,
    DateTime? deadlineDate,
    String? description,
    String? requiredItems,
    List<String>? targetHalaqaIds,
    List<String>? targetStudentIds,
    int? costPoints,
    String? status,
    DateTime? createdAt,
  }) => Trip(
    id: id ?? this.id,
    mosqueId: mosqueId ?? this.mosqueId,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    tripDate: tripDate ?? this.tripDate,
    meetingTime: meetingTime ?? this.meetingTime,
    deadlineDate: deadlineDate ?? this.deadlineDate,
    description: description ?? this.description,
    requiredItems: requiredItems ?? this.requiredItems,
    targetHalaqaIds: targetHalaqaIds ?? this.targetHalaqaIds,
    targetStudentIds: targetStudentIds ?? this.targetStudentIds,
    costPoints: costPoints ?? this.costPoints,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );

  bool isStudentTargeted(Student s) {
    if (targetStudentIds.contains(s.id)) return true;
    if (targetHalaqaIds.contains(s.halaqaId)) return true;
    return targetStudentIds.isEmpty && targetHalaqaIds.isEmpty;
  }

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id']?.toString() ?? '',
    mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
    title: json['title'] ?? '',
    destination: json['destination'] ?? '',
    tripDate: json['trip_date'] != null ? DateTime.parse(json['trip_date']) : DateTime.now(),
    meetingTime: json['meeting_time'] ?? '08:00 صباحاً',
    deadlineDate: json['deadline_date'] != null ? DateTime.parse(json['deadline_date']) : null,
    description: json['description'],
    requiredItems: json['required_items'] ?? json['requiredItems'] ?? 'لباس مريح، مصحف جيب، مياه وطعام خفيف',
    targetHalaqaIds: (json['target_halaqa_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    targetStudentIds: (json['target_student_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    costPoints: json['cost_points'] ?? json['costPoints'] ?? 0,
    status: json['status'] ?? 'upcoming',
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'title': title,
    'destination': destination,
    'trip_date': tripDate.toIso8601String(),
    'meeting_time': meetingTime,
    'deadline_date': deadlineDate?.toIso8601String(),
    'description': description,
    'required_items': requiredItems,
    'target_halaqa_ids': targetHalaqaIds,
    'target_student_ids': targetStudentIds,
    'cost_points': costPoints,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}
