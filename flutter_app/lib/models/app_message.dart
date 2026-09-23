class AppMessage {
  final String id;
  final String studentId;
  final String halaqaId;
  final String senderType; // 'sheikh', 'parent', 'mosque_admin'
  final String senderName;
  final String content;
  final String messageType; // 'note', 'alert', 'praise', 'inquiry', 'general'
  final bool isRead;
  final DateTime createdAt;

  AppMessage({
    required this.id,
    required this.studentId,
    required this.halaqaId,
    required this.senderType,
    required this.senderName,
    required this.content,
    this.messageType = 'general',
    this.isRead = false,
    required this.createdAt,
  });

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      halaqaId: json['halaqa_id']?.toString() ?? json['halaqaId']?.toString() ?? '',
      senderType: json['sender_type'] ?? json['senderType'] ?? 'parent',
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? json['messageType'] ?? 'general',
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'halaqa_id': halaqaId,
    'sender_type': senderType,
    'sender_name': senderName,
    'content': content,
    'message_type': messageType,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };
}
