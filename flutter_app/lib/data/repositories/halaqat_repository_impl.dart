import '../../domain/repositories/halaqat_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [HalaqatRepository] managing halaqat CRUD,
/// multi-sheikh co-supervision, and student cascades.
class HalaqatRepositoryImpl implements HalaqatRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  HalaqatRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<Halaqa> getHalaqat({String? mosqueId, String? sheikhId}) {
    var list = _localDataSource.halaqat;
    if (mosqueId != null && mosqueId != 'all' && mosqueId.isNotEmpty) {
      list = list.where((h) => h.mosqueId == mosqueId).toList();
    }
    if (sheikhId != null) {
      list = list.where((h) => h.isSheikhAssigned(sheikhId)).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Halaqa? getHalaqaById(String id) {
    try {
      return _localDataSource.halaqat.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Halaqa addHalaqa({
    required String mosqueId,
    String? sheikhId,
    List<String> coSheikhIds = const [],
    required String name,
    String? description,
    int ageGroupMin = 6,
    int ageGroupMax = 18,
    String schedule = 'السبت - الإثنين - الأربعاء (عصراً)',
    List<int> daysOfWeek = const [6, 1, 3],
    String timingType = 'prayer_linked',
    String? prayerName = 'asr',
    String prayerRelation = 'after',
    String? customTime,
  }) {
    final halaqa = Halaqa(
      id: LocalStorageDataSource.genId('halaqa'),
      mosqueId: mosqueId,
      sheikhId: sheikhId,
      coSheikhIds: coSheikhIds,
      name: name.trim(),
      description: description?.trim(),
      ageGroupMin: ageGroupMin,
      ageGroupMax: ageGroupMax,
      schedule: schedule.trim(),
      daysOfWeek: daysOfWeek,
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      customTime: customTime,
    );

    _localDataSource.halaqat.insert(0, halaqa);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'halaqat',
      action: 'upsert',
      data: halaqa.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return halaqa;
  }

  @override
  void updateHalaqa({
    required String id,
    required String name,
    String? description,
    String? sheikhId,
    List<String>? coSheikhIds,
    int? ageGroupMin,
    int? ageGroupMax,
    String? schedule,
    List<int>? daysOfWeek,
    String? timingType,
    String? prayerName,
    String? prayerRelation,
    String? customTime,
  }) {
    final idx = _localDataSource.halaqat.indexWhere((h) => h.id == id);
    if (idx != -1) {
      _localDataSource.halaqat[idx].name = name.trim();
      if (description != null) {
        _localDataSource.halaqat[idx].description = description.trim();
      }
      _localDataSource.halaqat[idx].sheikhId = sheikhId;
      if (coSheikhIds != null) {
        _localDataSource.halaqat[idx].coSheikhIds = coSheikhIds;
      }
      if (ageGroupMin != null) {
        _localDataSource.halaqat[idx].ageGroupMin = ageGroupMin;
      }
      if (ageGroupMax != null) {
        _localDataSource.halaqat[idx].ageGroupMax = ageGroupMax;
      }
      if (schedule != null) {
        _localDataSource.halaqat[idx].schedule = schedule.trim();
      }
      if (daysOfWeek != null) {
        _localDataSource.halaqat[idx].daysOfWeek = daysOfWeek;
      }
      if (timingType != null) {
        _localDataSource.halaqat[idx].timingType = timingType;
      }
      if (prayerName != null) {
        _localDataSource.halaqat[idx].prayerName = prayerName;
      }
      if (prayerRelation != null) {
        _localDataSource.halaqat[idx].prayerRelation = prayerRelation;
      }
      if (customTime != null) {
        _localDataSource.halaqat[idx].customTime = customTime;
      }

      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'halaqat',
        action: 'upsert',
        data: _localDataSource.halaqat[idx].toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteHalaqa(String halaqaId) {
    _localDataSource.halaqat.removeWhere((h) => h.id == halaqaId);
    _localDataSource.students.removeWhere((s) => s.halaqaId == halaqaId);
    _localDataSource.saveToStorage();

    _syncQueueManager.queueSync(
      table: 'halaqat',
      action: 'delete',
      data: {},
      id: halaqaId,
      remoteDataSource: _remoteDataSource,
    );
  }
}
