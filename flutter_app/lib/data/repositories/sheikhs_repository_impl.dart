import '../../core/utils/access_code_generator.dart';
import '../../domain/repositories/sheikhs_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [SheikhsRepository] managing sheikhs CRUD,
/// halaqa relationship updates, and background cloud synchronization.
class SheikhsRepositoryImpl implements SheikhsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  SheikhsRepositoryImpl(
      this._localDataSource,
      this._syncQueueManager, {
        SupabaseRemoteDataSource? remoteDataSource,
      }) : _remoteDataSource = remoteDataSource;

  @override
  List<Sheikh> getSheikhs({String? mosqueId, String? gender}) {
    var list = _localDataSource.sheikhs;
    if (mosqueId != null) {
      list = list.where((s) => s.mosqueId == mosqueId).toList();
    }
    if (gender != null) {
      final mosqueIds = _localDataSource.mosques
          .where((m) => m.gender == gender)
          .map((m) => m.id)
          .toSet();
      list = list.where((s) => mosqueIds.contains(s.mosqueId)).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Sheikh addSheikh(
      String mosqueId,
      String fullName,
      String? phone, {
        String? profileImageUrl,
      }) {
    final suffix =
    (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final code = 'SHK-$suffix';
    final sheikh = Sheikh(
      // Collision-safe: a bare timestamp gave two sheikhs added in the same
      // millisecond the same id (and merged them in group lessons).
      id: AccessCodeGenerator.entityId('sheikh'),
      mosqueId: mosqueId,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      code: code,
      profileImageUrl: profileImageUrl,
    );

    _localDataSource.sheikhs.insert(0, sheikh);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'sheikhs',
      action: 'upsert',
      data: sheikh.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return sheikh;
  }

  @override
  void updateSheikh({
    required String sheikhId,
    required String fullName,
    String? phone,
    String? profileImageUrl,
    int? defaultAttendancePoints,
  }) {
    final idx = _localDataSource.sheikhs.indexWhere((s) => s.id == sheikhId);
    if (idx != -1) {
      _localDataSource.sheikhs[idx].fullName = fullName.trim();
      if (phone != null) {
        _localDataSource.sheikhs[idx].phone = phone.trim();
      }
      _localDataSource.sheikhs[idx].profileImageUrl = profileImageUrl;
      if (defaultAttendancePoints != null) {
        _localDataSource.sheikhs[idx].defaultAttendancePoints = defaultAttendancePoints;
      }

      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'sheikhs',
        action: 'upsert',
        data: _localDataSource.sheikhs[idx].toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteSheikh(String sheikhId) {
    _localDataSource.sheikhs.removeWhere((s) => s.id == sheikhId);
    for (var h in _localDataSource.halaqat) {
      if (h.sheikhId == sheikhId) h.sheikhId = null;
      h.coSheikhIds = h.coSheikhIds.where((id) => id != sheikhId).toList();
    }
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'sheikhs',
      action: 'delete',
      data: {},
      id: sheikhId,
      remoteDataSource: _remoteDataSource,
    );
  }
}