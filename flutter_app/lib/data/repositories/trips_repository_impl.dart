import '../../domain/repositories/trips_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [TripsRepository] managing mosque trips,
/// student eligibility targeting, baggage checklist, and background sync.
class TripsRepositoryImpl implements TripsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  TripsRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<Trip> getTrips({String? mosqueId, String? studentId, String? halaqaId}) {
    var list = _localDataSource.trips;
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      list = list.where((t) => t.mosqueId == mosqueId).toList();
    }
    if (studentId != null && studentId.isNotEmpty) {
      final student = _localDataSource.students.firstWhere(
        (s) => s.id == studentId,
        orElse: () => Student(
            id: '',
            mosqueId: '',
            halaqaId: '',
            fullName: '',
            gender: 'male',
            phone: '',
            code: ''),
      );
      list = list.where((t) => t.isStudentTargeted(student)).toList();
    }
    if (halaqaId != null && halaqaId.isNotEmpty && halaqaId != 'all') {
      list = list
          .where((t) =>
              t.targetHalaqaIds.isEmpty || t.targetHalaqaIds.contains(halaqaId))
          .toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Trip addTrip({
    required String mosqueId,
    required String title,
    required String destination,
    required DateTime tripDate,
    String meetingTime = '08:00 صباحاً',
    DateTime? deadlineDate,
    String? description,
    String requiredItems = 'لباس مريح، مصحف جيب، مياه وطعام خفيف',
    List<String> targetHalaqaIds = const [],
    List<String> targetStudentIds = const [],
    int costPoints = 0,
  }) {
    final trip = Trip(
      id: LocalStorageDataSource.genId('trp'),
      mosqueId: mosqueId,
      title: title.trim(),
      destination: destination.trim(),
      tripDate: tripDate,
      meetingTime: meetingTime.trim(),
      deadlineDate: deadlineDate,
      description: description?.trim(),
      requiredItems: requiredItems.trim(),
      targetHalaqaIds: targetHalaqaIds,
      targetStudentIds: targetStudentIds,
      costPoints: costPoints,
      status: 'upcoming',
      createdAt: DateTime.now(),
    );

    _localDataSource.trips.insert(0, trip);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'trips',
      action: 'upsert',
      data: trip.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return trip;
  }

  @override
  void updateTrip(Trip trip) {
    final idx = _localDataSource.trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      _localDataSource.trips[idx] = trip;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'trips',
        action: 'upsert',
        data: trip.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteTrip(String tripId) {
    _localDataSource.trips.removeWhere((t) => t.id == tripId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'trips',
      action: 'delete',
      data: {},
      id: tripId,
      remoteDataSource: _remoteDataSource,
    );
  }
}
