import '../../models/models.dart';

/// Contract for App Messages and Inquiries.
abstract class MessagesRepository {
  List<AppMessage> getStudentMessages(String studentId);
  List<AppMessage> getHalaqaMessages(String halaqaId);
  void sendMessage({
    required String studentId,
    required String halaqaId,
    required String senderType,
    required String senderName,
    required String content,
    String messageType = 'general',
  });
}
