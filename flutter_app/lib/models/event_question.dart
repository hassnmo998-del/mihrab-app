import '../core/utils/wall_clock.dart';

class EventQuestion {
  final String id;
  final String eventId;
  final String content;
  final DateTime createdAt;
  bool isAnswered;

  EventQuestion({
    required this.id,
    required this.eventId,
    required this.content,
    required this.createdAt,
    this.isAnswered = false,
  });

  factory EventQuestion.fromJson(Map<String, dynamic> json) {
    return EventQuestion(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? json['eventId']?.toString() ?? '',
      content: json['content'] ?? '',
      createdAt: parseWallClock(json['created_at']),
      isAnswered: json['is_answered'] ?? json['isAnswered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'is_answered': isAnswered,
  };
}