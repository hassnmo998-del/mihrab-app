class Competition {
  final String id;
  final String mosqueId;
  String title;
  String description;
  DateTime startDate;
  DateTime endDate;
  bool countQuran;
  bool countHadith;
  bool countAttendance;
  int bonusPoints;
  final String genderBranch; // 'male' or 'female' - isolated

  Competition({
    required this.id,
    this.mosqueId = '',
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.countQuran = true,
    this.countHadith = true,
    this.countAttendance = true,
    this.bonusPoints = 0,
    required this.genderBranch,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate.subtract(const Duration(days: 1))) && now.isBefore(endDate.add(const Duration(days: 1)));
  }

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : DateTime.now().add(const Duration(days: 30)),
      countQuran: json['count_quran'] ?? json['countQuran'] ?? true,
      countHadith: json['count_hadith'] ?? json['countHadith'] ?? true,
      countAttendance: json['count_attendance'] ?? json['countAttendance'] ?? true,
      bonusPoints: json['bonus_points'] ?? json['bonusPoints'] ?? 0,
      genderBranch: json['gender_branch'] ?? json['genderBranch'] ?? 'male',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'title': title,
    'description': description,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'count_quran': countQuran,
    'count_hadith': countHadith,
    'count_attendance': countAttendance,
    'bonus_points': bonusPoints,
    'gender_branch': genderBranch,
  };
}
