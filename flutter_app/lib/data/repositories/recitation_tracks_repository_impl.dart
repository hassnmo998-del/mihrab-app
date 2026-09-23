import '../../domain/repositories/recitation_tracks_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [RecitationTracksRepository] managing custom recitation curricula,
/// unit progress deduplication, points awarding, and background sync.
class RecitationTracksRepositoryImpl implements RecitationTracksRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  RecitationTracksRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<RecitationTrack> getRecitationTracks({
    String? mosqueId,
    String? halaqaId,
    bool activeOnly = true,
  }) {
    var list = _localDataSource.recitationTracks;
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      list = list
          .where((t) => t.mosqueId == mosqueId || t.isDefaultQuran)
          .toList();
    }
    if (halaqaId != null && halaqaId.isNotEmpty && halaqaId != 'all') {
      list = list
          .where((t) =>
              t.targetHalaqaIds.isEmpty || t.targetHalaqaIds.contains(halaqaId))
          .toList();
    }
    if (activeOnly) {
      list = list.where((t) => t.isActive).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  RecitationTrack addRecitationTrack({
    required String mosqueId,
    required String name,
    String category = 'custom',
    String unitLabel = 'حديث',
    int totalUnits = 40,
    int pointsPerUnit = 2,
    bool isActive = true,
    List<String> targetHalaqaIds = const [],
    String? sheikhId,
  }) {
    final track = RecitationTrack(
      id: LocalStorageDataSource.genId('trk'),
      mosqueId: mosqueId,
      name: name.trim(),
      category: category,
      unitLabel: unitLabel.trim(),
      totalUnits: totalUnits,
      pointsPerUnit: pointsPerUnit,
      isActive: isActive,
      targetHalaqaIds: targetHalaqaIds,
      sheikhId: sheikhId,
      createdAt: DateTime.now(),
    );

    _localDataSource.recitationTracks.insert(0, track);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'recitation_tracks',
      action: 'upsert',
      data: track.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return track;
  }

  @override
  void updateRecitationTrack(RecitationTrack track) {
    final idx = _localDataSource.recitationTracks
        .indexWhere((t) => t.id == track.id);
    if (idx != -1) {
      _localDataSource.recitationTracks[idx] = track;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'recitation_tracks',
        action: 'upsert',
        data: track.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteRecitationTrack(String trackId) {
    _localDataSource.recitationTracks.removeWhere((t) => t.id == trackId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'recitation_tracks',
      action: 'delete',
      data: {},
      id: trackId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  SubjectRecitationRecord recordSubjectRecitation({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    required String trackId,
    required String trackName,
    required int fromUnit,
    required int toUnit,
    required int pointsEarned,
    String? courseId,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    final count = (toUnit - fromUnit + 1).abs();
    final rec = SubjectRecitationRecord(
      id: LocalStorageDataSource.genId('srec'),
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      trackId: trackId,
      trackName: trackName,
      fromUnit: fromUnit,
      toUnit: toUnit,
      unitsCount: count,
      pointsEarned: pointsEarned,
      courseId: courseId,
      notes: notes?.trim(),
      countsTowardsStatistics: countsTowardsStatistics,
      recordedAt: DateTime.now(),
    );

    _localDataSource.subjectRecitationRecords.insert(0, rec);

    // Add points to student and points_logs if counted towards statistics
    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (studentIdx != -1) {
      if (countsTowardsStatistics) {
        _localDataSource.students[studentIdx].totalPoints += pointsEarned;
      }
      String reason =
          'تسميع $trackName: من $fromUnit إلى $toUnit ($count وحدة)';
      if (!countsTowardsStatistics) {
        reason += ' (سجل خاص - غير محسوب بالإحصائيات العامة)';
      }
      final log = PointsLog(
        id: 'pts-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        points: countsTowardsStatistics ? pointsEarned : 0,
        reason: reason,
        category: 'recitation',
        createdAt: DateTime.now(),
      );
      _localDataSource.pointsLogs.insert(0, log);
      _syncQueueManager.queueSync(
        table: 'points_logs',
        action: 'upsert',
        data: log.toJson(),
        remoteDataSource: _remoteDataSource,
      );
      _syncQueueManager.queueSync(
        table: 'students',
        action: 'upsert',
        data: _localDataSource.students[studentIdx].toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }

    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'subject_recitation_records',
      action: 'upsert',
      data: rec.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return rec;
  }

  @override
  Map<String, dynamic> getStudentSubjectProgress(
      String studentId, String trackId) {
    final track = _localDataSource.recitationTracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => RecitationTrack(
          id: trackId,
          mosqueId: '',
          name: 'المسار',
          totalUnits: 40,
          createdAt: DateTime.now()),
    );

    final records = _localDataSource.subjectRecitationRecords
        .where((r) =>
            r.studentId == studentId &&
            r.trackId == trackId &&
            r.countsTowardsStatistics)
        .toList();
    final Set<int> uniqueUnits = {};
    for (var r in records) {
      final start = r.fromUnit <= r.toUnit ? r.fromUnit : r.toUnit;
      final end = r.fromUnit <= r.toUnit ? r.toUnit : r.fromUnit;
      for (int i = start; i <= end; i++) {
        if (i <= track.totalUnits) {
          uniqueUnits.add(i);
        }
      }
    }

    final total = track.totalUnits > 0 ? track.totalUnits : 1;
    final progress = (uniqueUnits.length / total).clamp(0.0, 1.0);

    return {
      'track': track,
      'uniqueUnitsCount': uniqueUnits.length,
      'totalUnits': track.totalUnits,
      'unitLabel': track.unitLabel,
      'progress': progress,
      'records': records,
      'isCompleted': uniqueUnits.length >= track.totalUnits,
    };
  }

  @override
  List<Map<String, dynamic>> getAllStudentSubjectProgresses(String studentId) {
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
    final activeTracks = _localDataSource.recitationTracks
        .where((t) =>
            (t.mosqueId == student.mosqueId || t.mosqueId.isEmpty) &&
            t.isActive)
        .toList();
    final recordedTrackIds = _localDataSource.subjectRecitationRecords
        .where((r) => r.studentId == studentId)
        .map((r) => r.trackId)
        .toSet();

    final allTargetTrackIds = {
      ...activeTracks.map((t) => t.id),
      ...recordedTrackIds
    };
    return allTargetTrackIds
        .map((tid) => getStudentSubjectProgress(studentId, tid))
        .toList();
  }
}
