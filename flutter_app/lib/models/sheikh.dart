class Sheikh {
  final String id;
  final String mosqueId;
  String fullName;
  String? phone;
  final String code;
  String? profileImageUrl; // الحقل الجديد للصورة
  int defaultAttendancePoints;

  Sheikh({
    required this.id,
    required this.mosqueId,
    required this.fullName,
    this.phone,
    required this.code,
    this.profileImageUrl,
    this.defaultAttendancePoints = 5,
  });

  factory Sheikh.fromJson(Map<String, dynamic> json) {
    return Sheikh(
      id: json['id']?.toString() ?? '',
      mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phone: json['phone'],
      code: json['code'] ?? 'SHK-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
      profileImageUrl: json['profile_image_url']?.toString() ?? json['profileImageUrl']?.toString(),
      defaultAttendancePoints: json['default_attendance_points'] is int
          ? json['default_attendance_points']
          : int.tryParse(json['default_attendance_points']?.toString() ?? '') ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'full_name': fullName,
    'phone': phone,
    'code': code,
    'profile_image_url': profileImageUrl,
    'default_attendance_points': defaultAttendancePoints,
  };

  Sheikh copyWith({
    String? id,
    String? mosqueId,
    String? fullName,
    String? phone,
    String? code,
    String? profileImageUrl,
    int? defaultAttendancePoints,
  }) {
    return Sheikh(
      id: id ?? this.id,
      mosqueId: mosqueId ?? this.mosqueId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      defaultAttendancePoints: defaultAttendancePoints ?? this.defaultAttendancePoints,
    );
  }
}