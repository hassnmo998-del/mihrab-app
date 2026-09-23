import '../../core/utils/access_code_generator.dart';
import '../../domain/repositories/mosques_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [MosquesRepository] managing mosque CRUD,
/// women's-branch provisioning, local persistence, and cloud synchronization.
class MosquesRepositoryImpl implements MosquesRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  MosquesRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<Mosque> getMosques({String? gender}) {
    if (gender == null) return List.unmodifiable(_localDataSource.mosques);
    return _localDataSource.mosques.where((m) => m.gender == gender).toList();
  }

  @override
  List<Mosque> getMosquesForViewer(String viewerBranch) {
    if (viewerBranch == 'female') {
      return List.unmodifiable(_localDataSource.mosques);
    }
    return _localDataSource.mosques.where((m) => !m.isWomenSection).toList();
  }

  @override
  Mosque? getMosqueById(String id) {
    try {
      return _localDataSource.mosques.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Mosque addMosque({
    required String name,
    required String address,
    required String city,
    required String gender,
    String? phone,
    double? latitude,
    double? longitude,
    String? parentMosqueId,
  }) {
    final mosque = Mosque(
      id: AccessCodeGenerator.entityId('mosque'),
      name: name.trim(),
      city: city.trim().isNotEmpty ? city.trim() : 'دمشق',
      address: address.trim(),
      phone: phone?.trim(),
      gender: gender,
      accessCode: _mintUniqueMosqueCode(),
      cashierAccessCode: AccessCodeGenerator.cashierCode(),
      parentMosqueId: parentMosqueId,
      latitude: latitude ?? 33.5138,
      longitude: longitude ?? 36.2765,
    );

    _localDataSource.mosques.insert(0, mosque);
    _localDataSource.saveToStorage();
    _queueMosque(mosque);

    return mosque;
  }

  @override
  void updateMosque({
    required String id,
    required String name,
    required String address,
    required String city,
    String? phone,
    double? latitude,
    double? longitude,
  }) {
    final idx = _localDataSource.mosques.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final old = _localDataSource.mosques[idx];
      final updated = old.copyWith(
        name: name.trim(),
        city: city.trim(),
        address: address.trim(),
        phone: phone?.trim(),
        latitude: latitude ?? old.latitude,
        longitude: longitude ?? old.longitude,
      );
      _localDataSource.mosques[idx] = updated;
      _localDataSource.saveToStorage();
      _patchMosque(updated.id, {
        'name': updated.name,
        'city': updated.city,
        'address': updated.address,
        'phone': updated.phone,
        'latitude': updated.latitude,
        'longitude': updated.longitude,
      });
    }
  }

  @override
  void deleteMosque(String mosqueId) {
    final target = getMosqueById(mosqueId);

    _localDataSource.mosques.removeWhere((m) => m.id == mosqueId);
    _localDataSource.sheikhs.removeWhere((s) => s.mosqueId == mosqueId);
    _localDataSource.halaqat.removeWhere((h) => h.mosqueId == mosqueId);

    // Deleting a women's branch releases the parent so a fresh branch can be
    // provisioned later; the parent must never be left pointing at a ghost.
    final parentId = target?.parentMosqueId;
    if (parentId != null && parentId.isNotEmpty) {
      final pIdx = _localDataSource.mosques.indexWhere((m) => m.id == parentId);
      if (pIdx != -1 &&
          _localDataSource.mosques[pIdx].womenBranchId == mosqueId) {
        final released = _localDataSource.mosques[pIdx].copyWith(
          clearWomenBranch: true,
          clearWomenAccessCode: true,
        );
        _localDataSource.mosques[pIdx] = released;
        _patchMosque(released.id, {
          'women_branch_id': null,
          'women_access_code': null,
        });
      }
    }

    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'mosques',
      action: 'delete',
      data: {},
      id: mosqueId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  String? issueWomenProvisionToken(String mosqueId) {
    final idx = _localDataSource.mosques.indexWhere((m) => m.id == mosqueId);
    if (idx == -1) return null;

    final mosque = _localDataSource.mosques[idx];
    // A women's branch cannot provision another branch beneath itself.
    if (mosque.isWomenSection) return null;

    final token = _mintUniqueProvisionToken();
    final updated = mosque.copyWith(womenAccessCode: token);
    _localDataSource.mosques[idx] = updated;
    _localDataSource.saveToStorage();
    _patchMosque(updated.id, {'women_access_code': token});

    return token;
  }

  @override
  Mosque? findMosqueByProvisionToken(String token) {
    final clean = token.trim().toUpperCase();
    if (!AccessCodeGenerator.isWomenProvisionToken(clean)) return null;
    for (final m in _localDataSource.mosques) {
      if (m.womenProvisionToken == clean && !m.isWomenSection) return m;
    }
    return null;
  }

  @override
  Mosque? createWomenBranch({
    required String parentMosqueId,
    required String token,
    required String name,
    required String city,
    required String address,
    String? phone,
    double? latitude,
    double? longitude,
  }) {
    final clean = token.trim().toUpperCase();
    final pIdx = _localDataSource.mosques.indexWhere(
      (m) => m.id == parentMosqueId,
    );
    if (pIdx == -1) return null;

    final parent = _localDataSource.mosques[pIdx];
    if (parent.isWomenSection) return null;
    if (parent.womenProvisionToken != clean) return null;
    if (parent.hasWomenBranch) return null;

    final branch = Mosque(
      id: AccessCodeGenerator.entityId('mosque'),
      name: name.trim().isNotEmpty
          ? name.trim()
          : 'القسم النسائي - ${parent.name}',
      city: city.trim().isNotEmpty ? city.trim() : parent.city,
      address: address.trim().isNotEmpty ? address.trim() : parent.address,
      phone: phone?.trim(),
      gender: 'female',
      accessCode: _mintUniqueMosqueCode(),
      cashierAccessCode: AccessCodeGenerator.cashierCode(),
      parentMosqueId: parent.id,
      latitude: latitude ?? parent.latitude,
      longitude: longitude ?? parent.longitude,
    );

    // The token is consumed in the same step that records the branch, so a
    // second device replaying the same QR finds nothing to redeem.
    final linkedParent = parent.copyWith(
      womenBranchId: branch.id,
      clearWomenAccessCode: true,
    );

    _localDataSource.mosques[pIdx] = linkedParent;
    _localDataSource.mosques.insert(0, branch);
    _localDataSource.saveToStorage();
    _queueMosque(branch);
    _patchMosque(linkedParent.id, {
      'women_branch_id': branch.id,
      'women_access_code': null,
    });

    return branch;
  }

  @override
  Mosque? consumeProvisionTokenForExistingBranch({
    required String parentMosqueId,
    required String token,
  }) {
    final clean = token.trim().toUpperCase();
    final pIdx = _localDataSource.mosques.indexWhere(
      (m) => m.id == parentMosqueId,
    );
    if (pIdx == -1) return null;

    final parent = _localDataSource.mosques[pIdx];
    if (parent.womenProvisionToken != clean) return null;

    final branchId = parent.womenBranchId;
    if (branchId == null || branchId.isEmpty) return null;

    final branch = getMosqueById(branchId);
    if (branch == null) return null;

    final consumed = parent.copyWith(clearWomenAccessCode: true);
    _localDataSource.mosques[pIdx] = consumed;
    _localDataSource.saveToStorage();
    _patchMosque(consumed.id, {'women_access_code': null});

    return branch;
  }

  /// Whole-row write, used only when a mosque row is first created.
  void _queueMosque(Mosque mosque) {
    _syncQueueManager.queueSync(
      table: 'mosques',
      action: 'upsert',
      data: mosque.toJson(),
      remoteDataSource: _remoteDataSource,
    );
  }

  /// Column-scoped write for an existing row. A whole-row upsert from a device
  /// holding a stale copy could otherwise put back a consumed handover token or
  /// clear a branch link that another device had just written.
  void _patchMosque(String id, Map<String, dynamic> fields) {
    _syncQueueManager.queueSync(
      table: 'mosques',
      action: 'patch',
      id: id,
      data: fields,
      remoteDataSource: _remoteDataSource,
    );
  }

  String _mintUniqueMosqueCode() {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = AccessCodeGenerator.mosqueCode();
      final taken =
          _localDataSource.mosques.any(
            (m) => m.accessCode.toUpperCase() == code,
          ) ||
          _localDataSource.sheikhs.any((s) => s.code.toUpperCase() == code) ||
          _localDataSource.students.any((s) => s.code.toUpperCase() == code);
      if (!taken) return code;
    }
    return AccessCodeGenerator.mosqueCode();
  }

  String _mintUniqueProvisionToken() {
    for (var attempt = 0; attempt < 12; attempt++) {
      final token = AccessCodeGenerator.womenProvisionToken();
      final taken = _localDataSource.mosques.any(
        (m) => m.womenProvisionToken == token,
      );
      if (!taken) return token;
    }
    return AccessCodeGenerator.womenProvisionToken();
  }
}
