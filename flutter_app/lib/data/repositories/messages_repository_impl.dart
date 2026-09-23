import '../../domain/repositories/messages_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [MessagesRepository] managing app notifications,
/// inquiries, and announcements with background sync.
class MessagesRepositoryImpl implements MessagesRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  MessagesRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<AppMessage> getStudentMessages(String studentId) {
    return _localDataSource.messages
        .where((m) => m.studentId == studentId)
        .toList();
  }

  @override
  List<AppMessage> getHalaqaMessages(String halaqaId) {
    return _localDataSource.messages
        .where((m) => m.halaqaId == halaqaId)
        .toList();
  }

  @override
  void sendMessage({
    required String studentId,
    required String halaqaId,
    required String senderType, // 'sheikh', 'parent', 'mosque_admin'
    required String senderName,
    required String content,
    String messageType = 'general',
  }) {
    final msg = AppMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      halaqaId: halaqaId,
      senderType: senderType,
      senderName: senderName,
      content: content.trim(),
      messageType: messageType,
      createdAt: DateTime.now(),
    );

    _localDataSource.messages.insert(0, msg);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'messages',
      action: 'upsert',
      data: msg.toJson(),
      remoteDataSource: _remoteDataSource,
    );
  }
}
