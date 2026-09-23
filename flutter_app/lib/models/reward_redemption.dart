class RewardRedemption {
  final String id;
  final String studentId;
  final String studentName;
  final String mosqueId;
  final String mosqueName;
  final String rewardId;
  final String rewardTitle;
  final int pointsSpent;
  final String redemptionCode;
  String status; // 'pending', 'dispensed', 'cancelled'
  final DateTime redeemedAt;
  DateTime? dispensedAt;
  String? cashierName;

  RewardRedemption({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.mosqueId,
    required this.mosqueName,
    required this.rewardId,
    required this.rewardTitle,
    required this.pointsSpent,
    required this.redemptionCode,
    this.status = 'pending',
    required this.redeemedAt,
    this.dispensedAt,
    this.cashierName,
  });

  bool get isDispensed => status == 'dispensed';
  bool get isPending => status == 'pending';

  factory RewardRedemption.fromJson(Map<String, dynamic> json) => RewardRedemption(
    id: json['id']?.toString() ?? '',
    studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
    studentName: json['student_name'] ?? json['studentName'] ?? '',
    mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
    mosqueName: json['mosque_name'] ?? json['mosqueName'] ?? '',
    rewardId: json['reward_id']?.toString() ?? json['rewardId']?.toString() ?? '',
    rewardTitle: json['reward_title'] ?? json['rewardTitle'] ?? '',
    pointsSpent: json['points_spent'] ?? json['pointsSpent'] ?? 0,
    redemptionCode: json['redemption_code'] ?? json['redemptionCode'] ?? '',
    status: json['status'] ?? 'pending',
    redeemedAt: json['redeemed_at'] != null ? DateTime.parse(json['redeemed_at']) : DateTime.now(),
    dispensedAt: json['dispensed_at'] != null ? DateTime.parse(json['dispensed_at']) : null,
    cashierName: json['cashier_name'] ?? json['cashierName'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'student_name': studentName,
    'mosque_id': mosqueId,
    'mosque_name': mosqueName,
    'reward_id': rewardId,
    'reward_title': rewardTitle,
    'points_spent': pointsSpent,
    'redemption_code': redemptionCode,
    'status': status,
    'redeemed_at': redeemedAt.toIso8601String(),
    'dispensed_at': dispensedAt?.toIso8601String(),
    'cashier_name': cashierName,
  };
}
