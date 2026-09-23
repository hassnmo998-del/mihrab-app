class Student {
  final String id;
  final String mosqueId;
  String halaqaId; // Required: student belongs strictly to a halaqa
  String? sheikhId; // derived from halaqa
  String fullName;
  String? birthDate;
  final String gender;
  String phone;
  String? notes;
  int totalPoints;
  final String code;
  String? profileImageUrl; // الحقل الجديد للصورة

  Student({
    required this.id,
    required this.mosqueId,
    required this.halaqaId,
    this.sheikhId,
    required this.fullName,
    this.birthDate,
    required this.gender,
    required this.phone,
    this.notes,
    this.totalPoints = 50,
    required this.code,
    this.profileImageUrl,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      halaqaId: json['halaqa_id']?.toString() ?? json['halaqaId']?.toString() ?? '',
      sheikhId: json['sheikh_id']?.toString() ?? json['sheikhId']?.toString(),
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      birthDate: json['birth_date'] ?? json['birthDate'],
      gender: json['gender'] ?? 'male',
      phone: json['phone'] ?? '',
      notes: json['notes'],
      totalPoints: json['total_points'] ?? json['totalPoints'] ?? 50,
      code: json['code'] ?? 'STD-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
      profileImageUrl: json['profile_image_url']?.toString() ?? json['profileImageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'halaqa_id': halaqaId,
    'sheikh_id': sheikhId,
    'full_name': fullName,
    'birth_date': birthDate,
    'gender': gender,
    'phone': phone,
    'notes': notes,
    'total_points': totalPoints,
    'code': code,
    'profile_image_url': profileImageUrl,
  };

  Student copyWith({
    String? id,
    String? mosqueId,
    String? halaqaId,
    String? sheikhId,
    String? fullName,
    String? birthDate,
    String? gender,
    String? phone,
    String? notes,
    int? totalPoints,
    String? code,
    String? profileImageUrl,
  }) {
    return Student(
      id: id ?? this.id,
      mosqueId: mosqueId ?? this.mosqueId,
      halaqaId: halaqaId ?? this.halaqaId,
      sheikhId: sheikhId ?? this.sheikhId,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      totalPoints: totalPoints ?? this.totalPoints,
      code: code ?? this.code,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}