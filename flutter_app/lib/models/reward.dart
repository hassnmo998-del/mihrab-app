import '../core/utils/wall_clock.dart';

class Reward {
  final String id;
  final String mosqueId;
  String title;
  String? description;
  int pointsCost;
  bool isActive;
  final DateTime createdAt;

  Reward({
    required this.id,
    required this.mosqueId,
    required this.title,
    this.description,
    required this.pointsCost,
    this.isActive = true,
    required this.createdAt,
  });

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
    id: json['id']?.toString() ?? '',
    mosqueId: json['mosque_id']?.toString() ?? json['mosqueId']?.toString() ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    pointsCost: json['points_cost'] ?? json['pointsCost'] ?? 100,
    isActive: json['is_active'] ?? json['isActive'] ?? true,
    createdAt: parseWallClock(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mosque_id': mosqueId,
    'title': title,
    'description': description,
    'points_cost': pointsCost,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };
}
