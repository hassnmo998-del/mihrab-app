class RecitationTrack {
  final String id;
  final String mosqueId;
  String name;
  String get title => name;
  String category; // 'quran', 'hadith', 'matn', 'pages', 'custom'
  String unitLabel; // 'آية', 'حديث', 'بيت', 'صفحة', 'درس'
  int totalUnits; // e.g. 42 (Arbaeen), 61 (Jazariyyah), 100 (Pages)
  int pointsPerUnit;
  bool isActive;
  bool isDefaultQuran;
  List<String> targetHalaqaIds; // empty = all halaqat in the mosque
  String? sheikhId;
  final DateTime createdAt;

  RecitationTrack({
    required this.id,
    required this.mosqueId,
    required this.name,
    this.category = 'custom',
    this.unitLabel = 'حديث',
    this.totalUnits = 40,
    this.pointsPerUnit = 2,
    this.isActive = true,
    this.isDefaultQuran = false,
    this.targetHalaqaIds = const [],
    this.sheikhId,
    required this.createdAt,
  });

  factory RecitationTrack.fromJson(Map<String, dynamic> json) => RecitationTrack(
    id: json['id']?.toString() ?? '',
    mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
    name: json['name'] ?? '',
    category: json['category'] ?? 'custom',
    unitLabel: json['unit_label'] ?? json['unitLabel'] ?? 'حديث',
    totalUnits: json['total_units'] ?? json['totalUnits'] ?? 40,
    pointsPerUnit: json['points_per_unit'] ?? json['pointsPerUnit'] ?? 2,
    isActive: json['is_active'] ?? json['isActive'] ?? true,
    isDefaultQuran: json['is_default_quran'] ?? json['isDefaultQuran'] ?? false,
    targetHalaqaIds: json['target_halaqa_ids'] != null
        ? (json['target_halaqa_ids'] as List).map((e) => e.toString()).toList()
        : (json['targetHalaqaIds'] != null ? (json['targetHalaqaIds'] as List).map((e) => e.toString()).toList() : const []),
    sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'name': name,
    'category': category,
    'unit_label': unitLabel,
    'total_units': totalUnits,
    'points_per_unit': pointsPerUnit,
    'is_active': isActive,
    'is_default_quran': isDefaultQuran,
    'target_halaqa_ids': targetHalaqaIds,
    'sheikh_id': sheikhId,
    'created_at': createdAt.toIso8601String(),
  };
}
