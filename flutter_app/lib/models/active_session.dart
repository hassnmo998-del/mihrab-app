class ActiveSession {
  final String role; // 'visitor', 'mosque_admin', 'sheikh', 'student'
  final String code;
  final String? rawName;
  final String? mosqueId;
  final String? mosqueName;
  final String? gender;
  final String? sheikhId;
  final String? studentId;
  final String? halaqaId;
  final String? profileImageUrl; // الحقل الجديد للصورة

  ActiveSession({
    required this.role,
    required this.code,
    String? name,
    this.mosqueId,
    this.mosqueName,
    this.gender,
    this.sheikhId,
    this.studentId,
    this.halaqaId,
    this.profileImageUrl,
  }) : rawName = name;

  String get name => rawName ?? (role == 'mosque_admin' ? 'مدير المسجد' : 'مستخدم المنظومة');
  String get accessCode => code;
  String get genderBranch => gender ?? 'male';

  String get roleLabel {
    switch (role) {
      case 'mosque_admin':
        return 'مدير المسجد';
      case 'sheikh':
        return 'الشيخ المحفظ';
      case 'student':
        return 'طالب / ولي أمر';
      case 'cashier':
        return 'صراف الجوائز المعتمد';
      case 'super_admin':
        return 'المشرف العام (Super Admin)';
      default:
        return 'زائر عام';
    }
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'code': code,
    'name': name,
    'mosqueId': mosqueId,
    'mosqueName': mosqueName,
    'gender': gender,
    'sheikhId': sheikhId,
    'studentId': studentId,
    'halaqaId': halaqaId,
    'profileImageUrl': profileImageUrl,
  };

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      role: json['role'] ?? 'visitor',
      code: json['code'] ?? '',
      name: json['name'],
      mosqueId: json['mosqueId'],
      mosqueName: json['mosqueName'],
      gender: json['gender'],
      sheikhId: json['sheikhId'],
      studentId: json['studentId'],
      halaqaId: json['halaqaId'],
      profileImageUrl: json['profileImageUrl'] ?? json['profile_image_url'],
    );
  }

  ActiveSession copyWith({
    String? role,
    String? code,
    String? name,
    String? mosqueId,
    String? mosqueName,
    String? gender,
    String? sheikhId,
    String? studentId,
    String? halaqaId,
    String? profileImageUrl,
  }) {
    return ActiveSession(
      role: role ?? this.role,
      code: code ?? this.code,
      name: name ?? rawName,
      mosqueId: mosqueId ?? this.mosqueId,
      mosqueName: mosqueName ?? this.mosqueName,
      gender: gender ?? this.gender,
      sheikhId: sheikhId ?? this.sheikhId,
      studentId: studentId ?? this.studentId,
      halaqaId: halaqaId ?? this.halaqaId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}