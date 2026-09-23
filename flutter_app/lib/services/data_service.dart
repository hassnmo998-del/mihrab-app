import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/access_code_generator.dart';
import '../data/datasources/datasources.dart';
import '../data/repositories/repositories.dart';
import '../models/models.dart';
import 'audio_upload_queue_manager.dart';

/// نتيجة محاولة دخول المشرف العام — تفصل بين "بيانات خاطئة" و"لا صلاحية"
/// و"تعذر الوصول للخادم" حتى تعرض الواجهة رسالة دقيقة لكل حالة.
enum SuperAdminLoginResult {
  success,
  invalidCredentials,
  notAuthorized,
  unavailable,
}

/// نتيجة فحص كود تسجيل مسجد — تفصل أسباب الفشل حتى يعرف المستخدم
/// ما إذا كان الكود خاطئاً أم مستخدماً أم أن الجهاز لم يصل للسحابة أصلاً.
enum RegistrationTokenCheck {
  valid,
  alreadyUsed,
  notFound,
  unreachable,
}

/// Central backwards-compatible Facade adapter extending [ChangeNotifier].
/// Delegates all storage, remote sync, and business calculations to modular
/// dedicated DataSources and Clean Architecture Repositories.
class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;

  static const String supabaseUrl =
      SupabaseRemoteDataSource.defaultSupabaseUrl;
  static const String supabaseAnonKey =
      SupabaseRemoteDataSource.defaultSupabaseAnonKey;

  // Data Sources
  late final LocalStorageDataSource _localDataSource;
  late final SupabaseRemoteDataSource _remoteDataSource;
  late final OfflineSyncQueueManager _syncQueueManager;

  // Domain Repositories
  late final AuthSessionRepositoryImpl _authSessionRepo;
  late final MosquesRepositoryImpl _mosquesRepo;
  late final SheikhsRepositoryImpl _sheikhsRepo;
  late final HalaqatRepositoryImpl _halaqatRepo;
  late final StudentsRepositoryImpl _studentsRepo;
  late final AttendanceRepositoryImpl _attendanceRepo;
  late final RecitationRepositoryImpl _recitationRepo;
  late final RecitationTracksRepositoryImpl _tracksRepo;
  late final CoursesRepositoryImpl _coursesRepo;
  late final TripsRepositoryImpl _tripsRepo;
  late final RewardsRepositoryImpl _rewardsRepo;
  late final CompetitionsRepositoryImpl _competitionsRepo;
  late final CommunityEventsRepositoryImpl _eventsRepo;
  late final MessagesRepositoryImpl _messagesRepo;
  late final ExecutiveOverviewRepositoryImpl _overviewRepo;

  final AudioUploadQueueManager audioUploadQueue = AudioUploadQueueManager();

  DataService._internal() {
    _localDataSource = LocalStorageDataSource();
    _remoteDataSource = SupabaseRemoteDataSource();
    _syncQueueManager = OfflineSyncQueueManager();

    _authSessionRepo = AuthSessionRepositoryImpl(_localDataSource, remoteDataSource: _remoteDataSource);
    _mosquesRepo = MosquesRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _sheikhsRepo = SheikhsRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _halaqatRepo = HalaqatRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _studentsRepo = StudentsRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _attendanceRepo = AttendanceRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _recitationRepo = RecitationRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _tracksRepo = RecitationTracksRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _coursesRepo = CoursesRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _tripsRepo = TripsRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _rewardsRepo = RewardsRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _competitionsRepo = CompetitionsRepositoryImpl(
      _localDataSource,
      syncQueueManager: _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _eventsRepo = CommunityEventsRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _messagesRepo = MessagesRepositoryImpl(
      _localDataSource,
      _syncQueueManager,
      remoteDataSource: _remoteDataSource,
    );
    _overviewRepo = ExecutiveOverviewRepositoryImpl(
      _localDataSource,
      _recitationRepo,
    );

    audioUploadQueue.setOnMediaUploadSuccess((eventId, mediaUrl, isVideo) {
      if (isVideo) {
        setEventVideoUrl(eventId, mediaUrl);
      } else {
        setEventAudioUrl(eventId, mediaUrl);
      }
    });
  }

  // ==========================================
  // Getters for Modular Architecture Components
  // ==========================================
  LocalStorageDataSource get localDataSource => _localDataSource;
  SupabaseRemoteDataSource get remoteDataSource => _remoteDataSource;
  OfflineSyncQueueManager get syncQueueManager => _syncQueueManager;

  AuthSessionRepositoryImpl get authSessionRepository => _authSessionRepo;
  MosquesRepositoryImpl get mosquesRepository => _mosquesRepo;
  SheikhsRepositoryImpl get sheikhsRepository => _sheikhsRepo;
  HalaqatRepositoryImpl get halaqatRepository => _halaqatRepo;
  StudentsRepositoryImpl get studentsRepository => _studentsRepo;
  AttendanceRepositoryImpl get attendanceRepository => _attendanceRepo;
  RecitationRepositoryImpl get recitationRepository => _recitationRepo;
  RecitationTracksRepositoryImpl get recitationTracksRepository => _tracksRepo;
  CoursesRepositoryImpl get coursesRepository => _coursesRepo;
  TripsRepositoryImpl get tripsRepository => _tripsRepo;
  RewardsRepositoryImpl get rewardsRepository => _rewardsRepo;
  CompetitionsRepositoryImpl get competitionsRepository => _competitionsRepo;
  CommunityEventsRepositoryImpl get communityEventsRepository => _eventsRepo;
  MessagesRepositoryImpl get messagesRepository => _messagesRepo;
  ExecutiveOverviewRepositoryImpl get executiveOverviewRepository => _overviewRepo;

  // ==========================================
  // Client & State Accessors
  // ==========================================
  SupabaseClient? get supabase => _remoteDataSource.client;

  bool get isDarkMode => _localDataSource.isDarkMode;

  void toggleTheme() {
    _localDataSource.isDarkMode = !_localDataSource.isDarkMode;
    _localDataSource.saveThemeMode();
    notifyListeners();
  }

  String get appMode => _localDataSource.appMode;
  bool get hasCompletedOnboarding => _localDataSource.hasCompletedOnboarding;

  Future<void> setAppMode(String mode) async {
    await _localDataSource.saveAppMode(mode);
    notifyListeners();
  }

  Future<void> completeOnboarding(String mode) async {
    await _localDataSource.completeOnboarding(mode);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    await _localDataSource.resetOnboarding();
    notifyListeners();
  }

  ActiveSession? get currentSession => _authSessionRepo.currentSession;
  List<ActiveSession> get savedSessions => _authSessionRepo.savedSessions;

  // ==========================================
  // Initialization & Cloud Sync
  // ==========================================
  Future<void> init() async {
    await _remoteDataSource.initialize();
    await audioUploadQueue.init();

    // 1. Instant cold-start load from local storage (0ms latency)
    await _localDataSource.loadAllFromStorage();
    await _restoreSavedDonations();
    await _syncQueueManager.loadQueue();
    // استعادة جلسة السوبر أدمن إذا كان الجهاز مصادقاً مسبقاً.
    // لا ننتظرها كي لا يتأخر إقلاع التطبيق: تُفعّل الجلسة وتُخطر الواجهة
    // بنفسها حالما ينتهي استرجاع جلسة Supabase المحفوظة.
    unawaited(restoreSuperAdminSessionIfNeeded());
// تنظيف تلقائي: تصفير أي بث مباشر معلق بالخطأ عند بدء التطبيق
    for (var ev in _localDataSource.communityEvents) {
      if (ev.eventStatus == 'live') {
        ev.eventStatus = 'upcoming';
      }
    }
    // 2. Non-blocking background sync queue processing
    _syncQueueManager.processQueue(_remoteDataSource);

    // 3. Sync remote tables with local cache
    await syncWithSupabase();

    // 4. Start Supabase Realtime subscription for multi-device sync
    startRealtimeSubscription();

    // 5. Start lightweight auto-sync heartbeat timer (every 12 seconds) to catch missed drops and ensure community events appear quickly
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      syncWithSupabase();
    });

    // 6. رفع تلقائي إذا كانت قاعدة بيانات Supabase جديدة ولدينا بيانات محلية
    if (_localDataSource.mosques.isNotEmpty) {
      final checkRemote = await _remoteDataSource.fetchTable('mosques');
      if (checkRemote != null && checkRemote.isEmpty) {
        debugPrint('☁️ Supabase is connected but empty, auto-pushing local data...');
        await pushAllLocalToSupabase();
      }
    }

    notifyListeners();
  }

  /// رفع كافة البيانات المخزنة محلياً إلى سحابة Supabase فوراً
  Future<int> pushAllLocalToSupabase() async {
    final client = _remoteDataSource.client;
    if (client == null) return 0;
    int pushedCount = 0;

    try {
      for (final m in _localDataSource.mosques) {
        await _remoteDataSource.upsert('mosques', m.toJson());
        pushedCount++;
      }
      for (final s in _localDataSource.sheikhs) {
        await _remoteDataSource.upsert('sheikhs', s.toJson());
        pushedCount++;
      }
      for (final h in _localDataSource.halaqat) {
        await _remoteDataSource.upsert('halaqat', h.toJson());
        pushedCount++;
      }
      for (final st in _localDataSource.students) {
        await _remoteDataSource.upsert('students', st.toJson());
        pushedCount++;
      }
      for (final ev in _localDataSource.communityEvents) {
        await _remoteDataSource.upsert('community_events', ev.toJson());
        pushedCount++;
      }
      for (final mem in _localDataSource.memorizationRecords) {
        await _remoteDataSource.upsert('memorization_records', mem.toJson());
        pushedCount++;
      }
      for (final att in _localDataSource.attendanceRecords) {
        await _remoteDataSource.upsert('attendance', att.toJson());
        pushedCount++;
      }
      for (final msg in _localDataSource.messages) {
        await _remoteDataSource.upsert('messages', msg.toJson());
        pushedCount++;
      }
      for (final comp in _localDataSource.competitions) {
        await _remoteDataSource.upsert('competitions', comp.toJson());
        pushedCount++;
      }
      for (final course in _localDataSource.intensiveCourses) {
        await _remoteDataSource.upsert('intensive_courses', course.toJson());
        pushedCount++;
      }
      for (final trip in _localDataSource.trips) {
        await _remoteDataSource.upsert('trips', trip.toJson());
        pushedCount++;
      }
      for (final rew in _localDataSource.rewards) {
        await _remoteDataSource.upsert('rewards', rew.toJson());
        pushedCount++;
      }
      for (final rdm in _localDataSource.redemptions) {
        await _remoteDataSource.upsert('reward_redemptions', rdm.toJson());
        pushedCount++;
      }
      for (final track in _localDataSource.recitationTracks) {
        await _remoteDataSource.upsert('recitation_tracks', track.toJson());
        pushedCount++;
      }
      for (final srec in _localDataSource.subjectRecitationRecords) {
        await _remoteDataSource.upsert('subject_recitation_records', srec.toJson());
        pushedCount++;
      }
      for (final pts in _localDataSource.pointsLogs) {
        await _remoteDataSource.upsert('points_logs', pts.toJson());
        pushedCount++;
      }
      for (final eq in _localDataSource.eventQuestions) {
        await _remoteDataSource.upsert('event_questions', eq.toJson());
        pushedCount++;
      }

      _syncQueueManager.clearQueue();
      await _syncQueueManager.saveQueue();
      debugPrint('☁️ Successfully pushed $pushedCount items to Supabase.');
    } catch (e) {
      debugPrint('⚠️ Error pushing local data to Supabase: $e');
    }
    return pushedCount;
  }

  // ==========================================
  // Supabase Realtime Synchronization Engine
  // ==========================================
  RealtimeChannel? _realtimeChannel;
  Timer? _autoSyncTimer;

  /// Starts listening to Supabase Postgres Realtime changes across all tables
  void startRealtimeSubscription() {
    final client = _remoteDataSource.client;
    if (client == null) return;

    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client.channel('public:db-realtime-sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (PostgresChangePayload payload) => _handleRealtimePayload(payload),
        )
        .subscribe();
      debugPrint('📡 Supabase Realtime channel active for instantaneous multi-device sync.');
    } catch (e) {
      debugPrint('⚠️ Realtime subscription setup note: $e');
    }
  }

  /// Stops Realtime subscription and heartbeat timer when disposing
  void stopRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Dispatches realtime events (INSERT, UPDATE, DELETE) directly into local cache
  void _handleRealtimePayload(PostgresChangePayload payload) async {
    try {
      final table = payload.table;
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      debugPrint('⚡ Realtime notification received: $eventType on table $table');

      switch (table) {
        case 'mosques':
          if (eventType == PostgresChangeEvent.update || eventType == PostgresChangeEvent.insert) {
            // Merge donation settings: prefer local values if remote doesn't carry them
            final remoteM = Mosque.fromJson(newRecord);
            final localIdx = _localDataSource.mosques.indexWhere((m) => m.id == remoteM.id);
            final localM = localIdx != -1 ? _localDataSource.mosques[localIdx] : null;
            final merged = localM == null
                ? remoteM
                : remoteM.copyWith(
                    isDonationEnabled: remoteM.hasActiveDonation
                        ? remoteM.isDonationEnabled
                        : (localM.hasActiveDonation ? localM.isDonationEnabled : remoteM.isDonationEnabled),
                    donationAccountName: (remoteM.donationAccountName?.isNotEmpty ?? false)
                        ? remoteM.donationAccountName
                        : localM.donationAccountName,
                    donationAccountNumber: (remoteM.donationAccountNumber?.isNotEmpty ?? false)
                        ? remoteM.donationAccountNumber
                        : localM.donationAccountNumber,
                    donationDescription: (remoteM.donationDescription?.isNotEmpty ?? false)
                        ? remoteM.donationDescription
                        : localM.donationDescription,
                    donationImageUrl: (remoteM.donationImageUrl?.isNotEmpty ?? false)
                        ? remoteM.donationImageUrl
                        : localM.donationImageUrl,
                  );
            if (localIdx != -1) {
              _localDataSource.mosques[localIdx] = merged;
            } else if (eventType == PostgresChangeEvent.insert) {
              _localDataSource.mosques.insert(0, merged);
            }
          } else {
            _applyRealtimeChange<Mosque>(
              list: _localDataSource.mosques,
              eventType: eventType,
              oldRecord: oldRecord,
              newRecord: newRecord,
              getId: (m) => m.id,
              fromJson: (json) => Mosque.fromJson(json),
              table: 'mosques',
            );
          }
          break;

        case 'sheikhs':
          _applyRealtimeChange<Sheikh>(
            list: _localDataSource.sheikhs,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (s) => s.id,
            fromJson: (json) => Sheikh.fromJson(json),
            table: 'sheikhs',
          );
          break;
        case 'halaqat':
          _applyRealtimeChange<Halaqa>(
            list: _localDataSource.halaqat,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (h) => h.id,
            fromJson: (json) => Halaqa.fromJson(json),
            table: 'halaqat',
          );
          break;
        case 'students':
          _applyRealtimeChange<Student>(
            list: _localDataSource.students,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (s) => s.id,
            fromJson: (json) => Student.fromJson(json),
            table: 'students',
          );
          break;
        case 'community_events':
          if (newRecord['event_type'] == 'system_donation_config') {
            _applyDonationConfigFromRecord(newRecord);
          }
          _applyRealtimeChange<CommunityEvent>(
            list: _localDataSource.communityEvents,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (e) => e.id,
            fromJson: (json) => CommunityEvent.fromJson(json),
            table: 'community_events',
          );
          break;
        case 'memorization_records':
          _applyRealtimeChange<MemorizationRecord>(
            list: _localDataSource.memorizationRecords,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (m) => m.id,
            fromJson: (json) => MemorizationRecord.fromJson(json),
            table: 'memorization_records',
          );
          break;
        case 'attendance':
          _applyRealtimeChange<AttendanceRecord>(
            list: _localDataSource.attendanceRecords,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (a) => a.id,
            fromJson: (json) => AttendanceRecord.fromJson(json),
            table: 'attendance',
          );
          break;
        case 'messages':
          _applyRealtimeChange<AppMessage>(
            list: _localDataSource.messages,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (m) => m.id,
            fromJson: (json) => AppMessage.fromJson(json),
            table: 'messages',
          );
          break;
        case 'competitions':
          _applyRealtimeChange<Competition>(
            list: _localDataSource.competitions,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (c) => c.id,
            fromJson: (json) => Competition.fromJson(json),
            table: 'competitions',
          );
          break;
        case 'intensive_courses':
          _applyRealtimeChange<IntensiveCourse>(
            list: _localDataSource.intensiveCourses,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (c) => c.id,
            fromJson: (json) => IntensiveCourse.fromJson(json),
            table: 'intensive_courses',
          );
          break;
        case 'trips':
          _applyRealtimeChange<Trip>(
            list: _localDataSource.trips,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (t) => t.id,
            fromJson: (json) => Trip.fromJson(json),
            table: 'trips',
          );
          break;
        case 'rewards':
          _applyRealtimeChange<Reward>(
            list: _localDataSource.rewards,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (r) => r.id,
            fromJson: (json) => Reward.fromJson(json),
            table: 'rewards',
          );
          break;
        case 'reward_redemptions':
          _applyRealtimeChange<RewardRedemption>(
            list: _localDataSource.redemptions,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (r) => r.id,
            fromJson: (json) => RewardRedemption.fromJson(json),
            table: 'reward_redemptions',
          );
          break;
        case 'recitation_tracks':
          _applyRealtimeChange<RecitationTrack>(
            list: _localDataSource.recitationTracks,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (t) => t.id,
            fromJson: (json) => RecitationTrack.fromJson(json),
            table: 'recitation_tracks',
          );
          break;
        case 'subject_recitation_records':
          _applyRealtimeChange<SubjectRecitationRecord>(
            list: _localDataSource.subjectRecitationRecords,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (s) => s.id,
            fromJson: (json) => SubjectRecitationRecord.fromJson(json),
            table: 'subject_recitation_records',
          );
          break;
        case 'points_logs':
          _applyRealtimeChange<PointsLog>(
            list: _localDataSource.pointsLogs,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (p) => p.id,
            fromJson: (json) => PointsLog.fromJson(json),
            table: 'points_logs',
          );
          break;
        case 'event_questions':
          _applyRealtimeChange<EventQuestion>(
            list: _localDataSource.eventQuestions,
            eventType: eventType,
            oldRecord: oldRecord,
            newRecord: newRecord,
            getId: (q) => q.id,
            fromJson: (json) => EventQuestion.fromJson(json),
            table: 'event_questions',
          );
          break;
        case 'registration_tokens':
          await syncRegistrationTokens();
          break;
      }

      await _localDataSource.saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error processing realtime event: $e');
    }
  }

  // ==========================================
  // Tombstone Deletion Tracking
  // ==========================================
  final Map<String, DateTime> _recentlyDeletedIds = {};

  bool isRecentlyDeleted(String id) {
    _cleanupExpiredTombstones();
    return _recentlyDeletedIds.containsKey(id);
  }

  void recordDeletedId(String id) {
    if (id.isEmpty) return;
    _recentlyDeletedIds[id] = DateTime.now();
  }

  void _cleanupExpiredTombstones() {
    final now = DateTime.now();
    _recentlyDeletedIds.removeWhere((_, time) => now.difference(time).inMinutes > 5);
  }

  void validateActiveSessions() {
    _authSessionRepo.validateActiveSessions();
    notifyListeners();
  }

  void _applyRealtimeChange<T>({
    required List<T> list,
    required PostgresChangeEvent eventType,
    required Map<String, dynamic> oldRecord,
    required Map<String, dynamic> newRecord,
    required String Function(T) getId,
    required T Function(Map<String, dynamic>) fromJson,
    String? table,
  }) {
    if (eventType == PostgresChangeEvent.delete) {
      final id = (oldRecord['id'] ?? newRecord['id'])?.toString();
      if (id != null && id.isNotEmpty) {
        recordDeletedId(id);
        list.removeWhere((item) => getId(item) == id);

        // تطهير التبعيات محلياً على بقية الأجهزة عند استلام حدث حذف
        if (table == 'mosques') {
          _localDataSource.sheikhs.removeWhere((s) => s.mosqueId == id);
          _localDataSource.halaqat.removeWhere((h) => h.mosqueId == id);
          _localDataSource.students.removeWhere((st) => st.mosqueId == id);
        } else if (table == 'sheikhs') {
          for (var h in _localDataSource.halaqat) {
            if (h.sheikhId == id) h.sheikhId = null;
            h.coSheikhIds = h.coSheikhIds.where((cId) => cId != id).toList();
          }
        } else if (table == 'halaqat') {
          _localDataSource.students.removeWhere((st) => st.halaqaId == id);
        } else if (table == 'students') {
          _localDataSource.pointsLogs.removeWhere((p) => p.studentId == id);
          _localDataSource.memorizationRecords.removeWhere((m) => m.studentId == id);
          _localDataSource.attendanceRecords.removeWhere((a) => a.studentId == id);
          _localDataSource.messages.removeWhere((m) => m.studentId == id);
        } else if (table == 'community_events') {
          _localDataSource.eventQuestions.removeWhere((q) => q.eventId == id);
        }

        _authSessionRepo.validateActiveSessions();
      } else if (table != null && table.isNotEmpty) {
        // خط دفاع احتياطي فوري: إذا لم ترسل سوبابيز المعرف القديم أثناء الحذف (بسبب سياسات RLS أو هوية النسخ)
        // نقوم فوراً بإطلاق مزامنة لحظية مستهدفة لهذا الجدول لتطهير السجلات المحذوفة دون تأخير
        syncTable(table);
      }
    } else if (eventType == PostgresChangeEvent.insert) {
      final newItem = fromJson(newRecord);
      final newId = getId(newItem);
      if (isRecentlyDeleted(newId) || (table != null && _syncQueueManager.isPendingDelete(table, newId))) {
        return;
      }
      final existingIndex = list.indexWhere((item) => getId(item) == newId);
      if (existingIndex != -1) {
        list[existingIndex] = newItem;
      } else {
        list.insert(0, newItem);
      }
    } else if (eventType == PostgresChangeEvent.update) {
      final updatedItem = fromJson(newRecord);
      final updatedId = getId(updatedItem);
      if (isRecentlyDeleted(updatedId) || (table != null && _syncQueueManager.isPendingDelete(table, updatedId))) {
        return;
      }
      final existingIndex = list.indexWhere((item) => getId(item) == updatedId);
      if (existingIndex != -1) {
        list[existingIndex] = updatedItem;
      }
    }
  }

  /// دمج ذكي غير تدميري يضمن تحديث البيانات السحابية مع الحفاظ المطلق على البيانات المنشأة دون اتصال
  void _syncCollection<T>({
    required List<T> list,
    required List<Map<String, dynamic>> remoteData,
    required String table,
    required String Function(T) getId,
    required T Function(Map<String, dynamic>) fromJson,
    T Function(T local, T remote)? onMerge,
    bool Function(T local)? protectLocal, // 🔒 عناصر محلية محمية من الحذف التلقائي
  }) {
    final remoteMap = <String, Map<String, dynamic>>{};
    for (var item in remoteData) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) remoteMap[id] = item;
    }

    // 1. تحديث أو إضافة السجلات الواردة من السيرفر
    for (var entry in remoteMap.entries) {
      final id = entry.key;
      if (isRecentlyDeleted(id) || _syncQueueManager.isPendingDelete(table, id)) {
        continue;
      }
      final remoteItem = fromJson(entry.value);
      final localIdx = list.indexWhere((x) => getId(x) == id);
      if (localIdx != -1) {
        if (_syncQueueManager.isPendingUpsert(table, id)) {
          // الحفاظ على التعديل المحلي المعلق في الطابور
          continue;
        }
        if (onMerge != null) {
          list[localIdx] = onMerge(list[localIdx], remoteItem);
        } else {
          list[localIdx] = remoteItem;
        }
      } else {
        if (remoteItem is CommunityEvent && (remoteItem as CommunityEvent).eventType == 'system_donation_config') {
          _applyDonationConfigEvent(remoteItem as CommunityEvent);
        }
        list.add(remoteItem);
      }
    }

    // 2. حذف العناصر المحذوفة، مع الحفاظ الصارم على العناصر المنشأة محلياً المعلقة في الطابور
    list.removeWhere((item) {
      final id = getId(item);
      if (isRecentlyDeleted(id) || _syncQueueManager.isPendingDelete(table, id)) {
        return true;
      }
      if (!remoteMap.containsKey(id)) {
        if (_syncQueueManager.isPendingUpsert(table, id)) {
          return false;
        }
        // 🔒 حماية العناصر المحلية المحمية (مثل الأرشيف) من الحذف التلقائي
        if (protectLocal != null && protectLocal(item)) {
          // إعادة قيدها في طابور المزامنة لضمان رفعها لاحقاً
          _syncQueueManager.queueSync(
            table: table,
            action: 'upsert',
            data: (item as dynamic).toJson() as Map<String, dynamic>,
            remoteDataSource: _remoteDataSource,
          );
          return false;
        }
        return true;
      }
      return false;
    });
  }


  /// Cloud Synchronization with Supabase across all 17 collections
  Future<void> syncWithSupabase() async {
    try {
      // تفريغ طابور العمليات العالقة أولاً
      await _syncQueueManager.processQueue(_remoteDataSource);

      final remoteMosques = await _remoteDataSource.fetchMosquesForSync();
      if (remoteMosques != null) {
        _syncCollection<Mosque>(
          list: _localDataSource.mosques,
          remoteData: remoteMosques,
          table: 'mosques',
          getId: (m) => m.id,
          fromJson: (json) => Mosque.fromJson(json),
          onMerge: (localM, remoteM) {
            return remoteM.copyWith(
              // Codes and branch links are preserved from the local copy when
              // the remote row does not carry them: the branch-isolation
              // columns may not exist yet on an un-migrated database, and losing
              // the link would let a parent mint a second women's branch.
              accessCode: remoteM.accessCode.isNotEmpty
                  ? remoteM.accessCode
                  : localM.accessCode,
              cashierAccessCode:
                  remoteM.cashierAccessCode ?? localM.cashierAccessCode,
              womenBranchId: remoteM.womenBranchId ?? localM.womenBranchId,
              parentMosqueId: remoteM.parentMosqueId ?? localM.parentMosqueId,
              isDonationEnabled: remoteM.hasActiveDonation
                  ? remoteM.isDonationEnabled
                  : (localM.hasActiveDonation ? localM.isDonationEnabled : remoteM.isDonationEnabled),
              donationAccountName: (remoteM.donationAccountName?.isNotEmpty ?? false)
                  ? remoteM.donationAccountName
                  : localM.donationAccountName,
              donationAccountNumber: (remoteM.donationAccountNumber?.isNotEmpty ?? false)
                  ? remoteM.donationAccountNumber
                  : localM.donationAccountNumber,
              donationDescription: (remoteM.donationDescription?.isNotEmpty ?? false)
                  ? remoteM.donationDescription
                  : localM.donationDescription,
              donationImageUrl: (remoteM.donationImageUrl?.isNotEmpty ?? false)
                  ? remoteM.donationImageUrl
                  : localM.donationImageUrl,
            );
          },
        );
      }

      final remoteSheikhs = await _remoteDataSource.fetchTable('sheikhs');
      if (remoteSheikhs != null) {
        _syncCollection<Sheikh>(
          list: _localDataSource.sheikhs,
          remoteData: remoteSheikhs,
          table: 'sheikhs',
          getId: (s) => s.id,
          fromJson: (json) => Sheikh.fromJson(json),
        );
      }

      final remoteHalaqat = await _remoteDataSource.fetchTable('halaqat');
      if (remoteHalaqat != null) {
        _syncCollection<Halaqa>(
          list: _localDataSource.halaqat,
          remoteData: remoteHalaqat,
          table: 'halaqat',
          getId: (h) => h.id,
          fromJson: (json) => Halaqa.fromJson(json),
        );
      }

      final remoteStudents = await _remoteDataSource.fetchTable('students');
      if (remoteStudents != null) {
        _syncCollection<Student>(
          list: _localDataSource.students,
          remoteData: remoteStudents,
          table: 'students',
          getId: (s) => s.id,
          fromJson: (json) => Student.fromJson(json),
        );
      }

      final remoteEvents = await _remoteDataSource.fetchTable('community_events');
      if (remoteEvents != null) {
        _syncCollection<CommunityEvent>(
          list: _localDataSource.communityEvents,
          remoteData: remoteEvents,
          table: 'community_events',
          getId: (e) => e.id,
          fromJson: (json) => CommunityEvent.fromJson(json),
          protectLocal: (ev) => ev.eventStatus == 'archived', // 🔒 الأرشيف لا يُحذف تلقائياً أبداً
          onMerge: (localEv, remoteItem) {
            if (remoteItem.eventType == 'system_donation_config') {
              _applyDonationConfigEvent(remoteItem);
            }
            if ((remoteItem.audioRecordUrl == null || remoteItem.audioRecordUrl!.isEmpty) &&
                (localEv.audioRecordUrl != null && localEv.audioRecordUrl!.isNotEmpty)) {
              remoteItem.audioRecordUrl = localEv.audioRecordUrl;
            }
            if (localEv.distanceMeters != null) {
              remoteItem.distanceMeters = localEv.distanceMeters;
            }
            return remoteItem;
          },
        );
      }

      final remoteMem = await _remoteDataSource.fetchTable('memorization_records');
      if (remoteMem != null) {
        _syncCollection<MemorizationRecord>(
          list: _localDataSource.memorizationRecords,
          remoteData: remoteMem,
          table: 'memorization_records',
          getId: (m) => m.id,
          fromJson: (json) => MemorizationRecord.fromJson(json),
        );
      }

      final remoteAtt = await _remoteDataSource.fetchTable('attendance');
      if (remoteAtt != null) {
        _syncCollection<AttendanceRecord>(
          list: _localDataSource.attendanceRecords,
          remoteData: remoteAtt,
          table: 'attendance',
          getId: (a) => a.id,
          fromJson: (json) => AttendanceRecord.fromJson(json),
        );
      }

      final remoteMsgs = await _remoteDataSource.fetchTable('messages');
      if (remoteMsgs != null) {
        _syncCollection<AppMessage>(
          list: _localDataSource.messages,
          remoteData: remoteMsgs,
          table: 'messages',
          getId: (m) => m.id,
          fromJson: (json) => AppMessage.fromJson(json),
        );
      }

      final remoteComps = await _remoteDataSource.fetchTable('competitions');
      if (remoteComps != null) {
        _syncCollection<Competition>(
          list: _localDataSource.competitions,
          remoteData: remoteComps,
          table: 'competitions',
          getId: (c) => c.id,
          fromJson: (json) => Competition.fromJson(json),
        );
      }

      final remoteCourses = await _remoteDataSource.fetchTable('intensive_courses');
      if (remoteCourses != null) {
        _syncCollection<IntensiveCourse>(
          list: _localDataSource.intensiveCourses,
          remoteData: remoteCourses,
          table: 'intensive_courses',
          getId: (c) => c.id,
          fromJson: (json) => IntensiveCourse.fromJson(json),
        );
      }

      final remoteTrips = await _remoteDataSource.fetchTable('trips');
      if (remoteTrips != null) {
        _syncCollection<Trip>(
          list: _localDataSource.trips,
          remoteData: remoteTrips,
          table: 'trips',
          getId: (t) => t.id,
          fromJson: (json) => Trip.fromJson(json),
        );
      }

      final remoteRewards = await _remoteDataSource.fetchTable('rewards');
      if (remoteRewards != null) {
        _syncCollection<Reward>(
          list: _localDataSource.rewards,
          remoteData: remoteRewards,
          table: 'rewards',
          getId: (r) => r.id,
          fromJson: (json) => Reward.fromJson(json),
        );
      }

      final remoteRedemptions = await _remoteDataSource.fetchTable('reward_redemptions');
      if (remoteRedemptions != null) {
        _syncCollection<RewardRedemption>(
          list: _localDataSource.redemptions,
          remoteData: remoteRedemptions,
          table: 'reward_redemptions',
          getId: (r) => r.id,
          fromJson: (json) => RewardRedemption.fromJson(json),
        );
      }

      final remoteTracks = await _remoteDataSource.fetchTable('recitation_tracks');
      if (remoteTracks != null) {
        _syncCollection<RecitationTrack>(
          list: _localDataSource.recitationTracks,
          remoteData: remoteTracks,
          table: 'recitation_tracks',
          getId: (t) => t.id,
          fromJson: (json) => RecitationTrack.fromJson(json),
        );
      }

      final remoteSubjectRec = await _remoteDataSource.fetchTable('subject_recitation_records');
      if (remoteSubjectRec != null) {
        _syncCollection<SubjectRecitationRecord>(
          list: _localDataSource.subjectRecitationRecords,
          remoteData: remoteSubjectRec,
          table: 'subject_recitation_records',
          getId: (s) => s.id,
          fromJson: (json) => SubjectRecitationRecord.fromJson(json),
        );
      }

      final remotePoints = await _remoteDataSource.fetchTable('points_logs');
      if (remotePoints != null) {
        _syncCollection<PointsLog>(
          list: _localDataSource.pointsLogs,
          remoteData: remotePoints,
          table: 'points_logs',
          getId: (p) => p.id,
          fromJson: (json) => PointsLog.fromJson(json),
        );
      }

      final remoteQuestions = await _remoteDataSource.fetchTable('event_questions');
      if (remoteQuestions != null) {
        _syncCollection<EventQuestion>(
          list: _localDataSource.eventQuestions,
          remoteData: remoteQuestions,
          table: 'event_questions',
          getId: (q) => q.id,
          fromJson: (json) => EventQuestion.fromJson(json),
        );
      }

      await syncRegistrationTokens();

      // التحقق من صلاحية الجلسات النشطة بعد تحديث البيانات
      _authSessionRepo.validateActiveSessions();

      await _localDataSource.saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ SyncWithSupabase exception: $e');
    }
  }

  /// مزامنة فورية ومستهدفة لجدول محدد عند استلام أحداث الحذف أو التعديل لضمان الانعكاس اللحظي الفولاذي
  Future<void> syncTable(String table) async {
    try {
      final remoteData = await _remoteDataSource.fetchTable(table);
      if (remoteData == null) return;

      switch (table) {
        case 'mosques':
          _syncCollection<Mosque>(
            list: _localDataSource.mosques,
            remoteData: remoteData,
            table: 'mosques',
            getId: (m) => m.id,
            fromJson: (json) => Mosque.fromJson(json),
            onMerge: (localM, remoteM) {
              return remoteM.copyWith(
                isDonationEnabled: remoteM.hasActiveDonation
                    ? remoteM.isDonationEnabled
                    : (localM.hasActiveDonation ? localM.isDonationEnabled : remoteM.isDonationEnabled),
                donationAccountName: (remoteM.donationAccountName?.isNotEmpty ?? false)
                    ? remoteM.donationAccountName
                    : localM.donationAccountName,
                donationAccountNumber: (remoteM.donationAccountNumber?.isNotEmpty ?? false)
                    ? remoteM.donationAccountNumber
                    : localM.donationAccountNumber,
                donationDescription: (remoteM.donationDescription?.isNotEmpty ?? false)
                    ? remoteM.donationDescription
                    : localM.donationDescription,
                donationImageUrl: (remoteM.donationImageUrl?.isNotEmpty ?? false)
                    ? remoteM.donationImageUrl
                    : localM.donationImageUrl,
              );
            },
          );
          final mosqueIds = _localDataSource.mosques.map((m) => m.id).toSet();
          _localDataSource.sheikhs.removeWhere((s) => !mosqueIds.contains(s.mosqueId));
          _localDataSource.halaqat.removeWhere((h) => !mosqueIds.contains(h.mosqueId));
          _localDataSource.students.removeWhere((st) => !mosqueIds.contains(st.mosqueId));
          break;

        case 'sheikhs':
          _syncCollection<Sheikh>(
            list: _localDataSource.sheikhs,
            remoteData: remoteData,
            table: 'sheikhs',
            getId: (s) => s.id,
            fromJson: (json) => Sheikh.fromJson(json),
          );
          final sheikhIds = _localDataSource.sheikhs.map((s) => s.id).toSet();
          for (var h in _localDataSource.halaqat) {
            if (h.sheikhId != null && !sheikhIds.contains(h.sheikhId)) {
              h.sheikhId = null;
            }
            h.coSheikhIds = h.coSheikhIds.where((id) => sheikhIds.contains(id)).toList();
          }
          break;

        case 'halaqat':
          _syncCollection<Halaqa>(
            list: _localDataSource.halaqat,
            remoteData: remoteData,
            table: 'halaqat',
            getId: (h) => h.id,
            fromJson: (json) => Halaqa.fromJson(json),
          );
          final halaqaIds = _localDataSource.halaqat.map((h) => h.id).toSet();
          _localDataSource.students.removeWhere((st) => st.halaqaId.isNotEmpty && !halaqaIds.contains(st.halaqaId));
          break;

        case 'students':
          _syncCollection<Student>(
            list: _localDataSource.students,
            remoteData: remoteData,
            table: 'students',
            getId: (s) => s.id,
            fromJson: (json) => Student.fromJson(json),
          );
          final studentIds = _localDataSource.students.map((st) => st.id).toSet();
          _localDataSource.pointsLogs.removeWhere((p) => !studentIds.contains(p.studentId));
          _localDataSource.memorizationRecords.removeWhere((m) => !studentIds.contains(m.studentId));
          _localDataSource.attendanceRecords.removeWhere((a) => !studentIds.contains(a.studentId));
          _localDataSource.messages.removeWhere((m) => !studentIds.contains(m.studentId));
          break;

        case 'community_events':
          _syncCollection<CommunityEvent>(
            list: _localDataSource.communityEvents,
            remoteData: remoteData,
            table: 'community_events',
            getId: (e) => e.id,
            fromJson: (json) => CommunityEvent.fromJson(json),
            protectLocal: (ev) => ev.eventStatus == 'archived', // 🔒 الأرشيف محمي
            onMerge: (localEv, remoteItem) {
              if (remoteItem.eventType == 'system_donation_config') {
                _applyDonationConfigEvent(remoteItem);
              }
              if ((remoteItem.audioRecordUrl == null || remoteItem.audioRecordUrl!.isEmpty) &&
                  (localEv.audioRecordUrl != null && localEv.audioRecordUrl!.isNotEmpty)) {
                remoteItem.audioRecordUrl = localEv.audioRecordUrl;
              }
              if (localEv.distanceMeters != null) {
                remoteItem.distanceMeters = localEv.distanceMeters;
              }
              return remoteItem;
            },
          );
          final eventIds = _localDataSource.communityEvents.map((e) => e.id).toSet();
          _localDataSource.eventQuestions.removeWhere((q) => !eventIds.contains(q.eventId));
          break;

        case 'memorization_records':
          _syncCollection<MemorizationRecord>(
            list: _localDataSource.memorizationRecords,
            remoteData: remoteData,
            table: 'memorization_records',
            getId: (m) => m.id,
            fromJson: (json) => MemorizationRecord.fromJson(json),
          );
          break;

        case 'attendance':
          _syncCollection<AttendanceRecord>(
            list: _localDataSource.attendanceRecords,
            remoteData: remoteData,
            table: 'attendance',
            getId: (a) => a.id,
            fromJson: (json) => AttendanceRecord.fromJson(json),
          );
          break;

        case 'messages':
          _syncCollection<AppMessage>(
            list: _localDataSource.messages,
            remoteData: remoteData,
            table: 'messages',
            getId: (m) => m.id,
            fromJson: (json) => AppMessage.fromJson(json),
          );
          break;

        case 'competitions':
          _syncCollection<Competition>(
            list: _localDataSource.competitions,
            remoteData: remoteData,
            table: 'competitions',
            getId: (c) => c.id,
            fromJson: (json) => Competition.fromJson(json),
          );
          break;

        case 'intensive_courses':
          _syncCollection<IntensiveCourse>(
            list: _localDataSource.intensiveCourses,
            remoteData: remoteData,
            table: 'intensive_courses',
            getId: (c) => c.id,
            fromJson: (json) => IntensiveCourse.fromJson(json),
          );
          break;

        case 'trips':
          _syncCollection<Trip>(
            list: _localDataSource.trips,
            remoteData: remoteData,
            table: 'trips',
            getId: (t) => t.id,
            fromJson: (json) => Trip.fromJson(json),
          );
          break;

        case 'rewards':
          _syncCollection<Reward>(
            list: _localDataSource.rewards,
            remoteData: remoteData,
            table: 'rewards',
            getId: (r) => r.id,
            fromJson: (json) => Reward.fromJson(json),
          );
          break;

        case 'reward_redemptions':
          _syncCollection<RewardRedemption>(
            list: _localDataSource.redemptions,
            remoteData: remoteData,
            table: 'reward_redemptions',
            getId: (r) => r.id,
            fromJson: (json) => RewardRedemption.fromJson(json),
          );
          break;

        case 'recitation_tracks':
          _syncCollection<RecitationTrack>(
            list: _localDataSource.recitationTracks,
            remoteData: remoteData,
            table: 'recitation_tracks',
            getId: (t) => t.id,
            fromJson: (json) => RecitationTrack.fromJson(json),
          );
          break;

        case 'subject_recitation_records':
          _syncCollection<SubjectRecitationRecord>(
            list: _localDataSource.subjectRecitationRecords,
            remoteData: remoteData,
            table: 'subject_recitation_records',
            getId: (s) => s.id,
            fromJson: (json) => SubjectRecitationRecord.fromJson(json),
          );
          break;

        case 'points_logs':
          _syncCollection<PointsLog>(
            list: _localDataSource.pointsLogs,
            remoteData: remoteData,
            table: 'points_logs',
            getId: (p) => p.id,
            fromJson: (json) => PointsLog.fromJson(json),
          );
          break;

        case 'event_questions':
          _syncCollection<EventQuestion>(
            list: _localDataSource.eventQuestions,
            remoteData: remoteData,
            table: 'event_questions',
            getId: (q) => q.id,
            fromJson: (json) => EventQuestion.fromJson(json),
          );
          break;
      }

      _authSessionRepo.validateActiveSessions();
      await _localDataSource.saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Exception during targeted syncTable($table): $e');
    }
  }

  // ==========================================
  // Multi-Role Session Management
  // ==========================================
  void switchSession(ActiveSession session) {
    _authSessionRepo.switchSession(session);
    notifyListeners();
  }

  void setRoleSession(ActiveSession session) {
    _authSessionRepo.setRoleSession(session);
    notifyListeners();
  }

  ActiveSession? getSessionForRole(String role) =>
      _authSessionRepo.getSessionForRole(role);

  bool hasRole(String role) => _authSessionRepo.hasRole(role);

  void disconnectRole(String role) {
    if (role == 'super_admin') {
      _localDataSource.isSuperAdminAuthenticated = false;
      _localDataSource.saveToStorage();
      // إنهاء جلسة Supabase فعلياً، وإلا بقي التوكن صالحاً على الجهاز
      _remoteDataSource.client?.auth.signOut().catchError((Object e) {
        debugPrint('⚠️ تعذر تسجيل الخروج من Supabase: $e');
      });
    }
    _authSessionRepo.disconnectRole(role);
    notifyListeners();
  }

  void clearSession() {
    _authSessionRepo.clearSession();
    notifyListeners();
  }

  void logoutCompletely() {
    final current = currentSession;
    final isSuper = current?.role == 'super_admin';

    // الاحتفاظ بجلسة السوبر أدمن إذا كانت موجودة في السجلات المحفوظة
    final superAdminSession = _localDataSource.savedSessions.firstWhere(
      (s) => s.role == 'super_admin',
      orElse: () => ActiveSession(role: 'visitor', code: ''),
    );

    // إذا لم نكن سوبر أدمن حالياً، نصفر الجلسة النشطة
    if (!isSuper) {
      _authSessionRepo.clearSession();
    }

    // مسح كافة الرتب الأخرى المحفوظة
    _localDataSource.savedSessions.clear();
    
    // إعادة إضافة السوبر أدمن فقط للسجلات المحفوظة
    if (superAdminSession.role == 'super_admin') {
      _localDataSource.savedSessions.add(superAdminSession);
    }
    
    _localDataSource.saveToStorage();
    notifyListeners();
  }

  Future<ActiveSession?> verifyCode(String code) async {
    final session = await _authSessionRepo.verifyCode(code);
    if (session != null) {
      notifyListeners();
    }
    return session;
  }

  // ==========================================
  // Gender branch resolution
  // ==========================================

  /// Branch of a mosque record ('male' | 'female'), defaulting to 'male' for
  /// unknown ids so nothing leaks into the women's side by accident.
  String branchOfMosque(String? mosqueId) {
    if (mosqueId == null || mosqueId.isEmpty) return 'male';
    return getMosqueById(mosqueId)?.gender ?? 'male';
  }

  /// Branch the given session belongs to. The mosque record is authoritative:
  /// a stale `gender` stored on the session or on a student row never wins.
  String branchOfSession(ActiveSession? session) {
    if (session == null) return 'male';
    if (session.mosqueId != null && session.mosqueId!.isNotEmpty) {
      final mosque = getMosqueById(session.mosqueId!);
      if (mosque != null) return mosque.gender;
    }
    return session.genderBranch;
  }

  /// Branch used to filter public screens. Anonymous visitors are treated as
  /// the men's branch, so women's content is never shown without a session.
  String get viewerBranch => branchOfSession(currentSession);

  /// Women's branches publish and manage their own lessons but never produce
  /// archive recordings, so no women's audio or video can ever be stored.
  bool get canRecordArchive => viewerBranch != 'female';

  bool canSessionRecordArchive(ActiveSession? session) =>
      branchOfSession(session) != 'female';

  // ==========================================
  // Mosques Management
  // ==========================================
  List<Mosque> getMosques({String? gender}) =>
      _mosquesRepo.getMosques(gender: gender);

  /// Mosques the current viewer may see. Men and anonymous visitors never see a
  /// women's branch; use this everywhere a public list of mosques is rendered.
  List<Mosque> getVisibleMosques({String? viewerBranch}) =>
      _mosquesRepo.getMosquesForViewer(viewerBranch ?? this.viewerBranch);

  Mosque? getMosqueById(String id) => _mosquesRepo.getMosqueById(id);

  // ==========================================
  // Women's branch provisioning
  // ==========================================

  /// Mints the single-use QR token the men's administration hands over so the
  /// women's administration can create its own isolated branch.
  String? issueWomenProvisionToken(String mosqueId) {
    final token = _mosquesRepo.issueWomenProvisionToken(mosqueId);
    if (token != null) notifyListeners();
    return token;
  }

  /// Resolves a scanned token without granting anything. Looks locally first,
  /// then in Supabase so a brand-new device can redeem a token it has never
  /// cached. Returns null for any code that is not a live token.
  Future<WomenBranchProvisionOffer?> inspectWomenProvisionToken(
      String code) async {
    final clean = code.trim().toUpperCase();
    if (!AccessCodeGenerator.isWomenProvisionToken(clean)) return null;

    var parent = _mosquesRepo.findMosqueByProvisionToken(clean);

    if (parent == null) {
      final remote = await _remoteDataSource
          .resolveMosqueByCode(clean)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (remote != null) {
        final fetched = Mosque.fromJson(remote);
        // A women's branch may not provision another branch beneath itself.
        if (fetched.isWomenSection) return null;
        if (fetched.womenProvisionToken != clean) return null;
        final idx =
            _localDataSource.mosques.indexWhere((m) => m.id == fetched.id);
        if (idx >= 0) {
          _localDataSource.mosques[idx] = fetched;
        } else {
          _localDataSource.mosques.add(fetched);
        }
        await _localDataSource.saveToStorage();
        parent = fetched;
      }
    }

    if (parent == null) return null;

    return WomenBranchProvisionOffer(
      parentMosque: parent,
      token: clean,
      isHandover: parent.hasWomenBranch,
    );
  }

  /// Creates the women's branch (or hands over the existing one) and signs the
  /// device in as its administration. The resulting session carries the branch's
  /// own mosque id and access code, which is what keeps the two branches apart.
  Future<Mosque?> redeemWomenProvisionToken({
    required WomenBranchProvisionOffer offer,
    required String name,
    required String city,
    required String address,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    final branch = offer.isHandover
        ? _mosquesRepo.consumeProvisionTokenForExistingBranch(
            parentMosqueId: offer.parentMosque.id,
            token: offer.token,
          )
        : _mosquesRepo.createWomenBranch(
            parentMosqueId: offer.parentMosque.id,
            token: offer.token,
            name: name,
            city: city,
            address: address,
            phone: phone,
            latitude: latitude,
            longitude: longitude,
          );

    if (branch == null) return null;

    _authSessionRepo.setRoleSession(ActiveSession(
      role: 'mosque_admin',
      code: branch.accessCode,
      name: 'إدارة ${branch.name}',
      mosqueId: branch.id,
      mosqueName: branch.name,
      gender: 'female',
    ));

    await _localDataSource.saveToStorage();
    notifyListeners();
    return branch;
  }

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
    final mosque = _mosquesRepo.addMosque(
      name: name,
      address: address,
      city: city,
      gender: gender,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      parentMosqueId: parentMosqueId,
    );
    notifyListeners();
    return mosque;
  }

  void updateMosque({
    required String id,
    required String name,
    required String address,
    required String city,
    String? phone,
    double? latitude,
    double? longitude,
  }) {
    _mosquesRepo.updateMosque(
      id: id,
      name: name,
      address: address,
      city: city,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
    );
    notifyListeners();
  }

  void deleteMosque(String mosqueId) {
    recordDeletedId(mosqueId);
    _mosquesRepo.deleteMosque(mosqueId);
    _authSessionRepo.validateActiveSessions();
    notifyListeners();
  }


// ==========================================
  // Sheikhs Management
  // ==========================================
  List<Sheikh> getSheikhs({String? mosqueId, String? gender}) =>
      _sheikhsRepo.getSheikhs(mosqueId: mosqueId, gender: gender);

  Sheikh? getSheikhById(String id) =>
      _sheikhsRepo.getSheikhs().where((s) => s.id == id).firstOrNull;


  Sheikh addSheikh(
      String mosqueId,
      String fullName,
      String? phone, {
        String? profileImageUrl,
      }) {
    final sheikh = _sheikhsRepo.addSheikh(
      mosqueId,
      fullName,
      phone,
      profileImageUrl: profileImageUrl,
    );
    notifyListeners();
    return sheikh;
  }

  void updateSheikh({
    required String sheikhId,
    required String fullName,
    String? phone,
    String? profileImageUrl,
    int? defaultAttendancePoints,
  }) {
    _sheikhsRepo.updateSheikh(
      sheikhId: sheikhId,
      fullName: fullName,
      phone: phone,
      profileImageUrl: profileImageUrl,
      defaultAttendancePoints: defaultAttendancePoints,
    );
    notifyListeners();
  }

  void deleteSheikh(String sheikhId) {
    recordDeletedId(sheikhId);
    _sheikhsRepo.deleteSheikh(sheikhId);
    _authSessionRepo.validateActiveSessions();
    notifyListeners();
  }

  // ==========================================
  // Halaqat Management
  // ==========================================
  List<Halaqa> getHalaqat({String? mosqueId, String? sheikhId}) =>
      _halaqatRepo.getHalaqat(mosqueId: mosqueId, sheikhId: sheikhId);

  Halaqa? getHalaqaById(String id) => _halaqatRepo.getHalaqaById(id);

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
    final halaqa = _halaqatRepo.addHalaqa(
      mosqueId: mosqueId,
      sheikhId: sheikhId,
      coSheikhIds: coSheikhIds,
      name: name,
      description: description,
      ageGroupMin: ageGroupMin,
      ageGroupMax: ageGroupMax,
      schedule: schedule,
      daysOfWeek: daysOfWeek,
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      customTime: customTime,
    );
    notifyListeners();
    return halaqa;
  }

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
    _halaqatRepo.updateHalaqa(
      id: id,
      name: name,
      description: description,
      sheikhId: sheikhId,
      coSheikhIds: coSheikhIds,
      ageGroupMin: ageGroupMin,
      ageGroupMax: ageGroupMax,
      schedule: schedule,
      daysOfWeek: daysOfWeek,
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      customTime: customTime,
    );
    notifyListeners();
  }

  void deleteHalaqa(String halaqaId) {
    recordDeletedId(halaqaId);
    _halaqatRepo.deleteHalaqa(halaqaId);
    notifyListeners();
  }

  // ==========================================
  // Students Management
  // ==========================================
  List<Student> getStudents({
    String? halaqaId,
    String? sheikhId,
    String? mosqueId,
    String? gender,
  }) =>
      _studentsRepo.getStudents(
        halaqaId: halaqaId,
        sheikhId: sheikhId,
        mosqueId: mosqueId,
        gender: gender,
      );

  Student addStudent({
    required String mosqueId,
    required String halaqaId,
    String? sheikhId,
    required String fullName,
    required String gender,
    required String phone,
    String? notes,
    String? birthDate,
    int welcomePoints = 0,
    String? profileImageUrl,
  }) {
    final student = _studentsRepo.addStudent(
      mosqueId: mosqueId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      fullName: fullName,
      gender: gender,
      phone: phone,
      notes: notes,
      birthDate: birthDate,
      welcomePoints: welcomePoints,
      profileImageUrl: profileImageUrl,
    );
    notifyListeners();
    return student;
  }

  void updateStudent({
    required String studentId,
    required String fullName,
    required String halaqaId,
    required String phone,
    String? birthDate,
    String? notes,
    String? profileImageUrl,
  }) {
    _studentsRepo.updateStudent(
      studentId: studentId,
      fullName: fullName,
      halaqaId: halaqaId,
      phone: phone,
      birthDate: birthDate,
      notes: notes,
      profileImageUrl: profileImageUrl,
    );
    notifyListeners();
  }

  void deleteStudent(String studentId) {
    recordDeletedId(studentId);
    _studentsRepo.deleteStudent(studentId);
    _authSessionRepo.validateActiveSessions();
    notifyListeners();
  }

  List<PointsLog> getStudentPointsLog(String studentId) =>
      _studentsRepo.getStudentPointsLog(studentId);

  /// تعديل يدوي لرصيد نقاط الطالب (إضافة أو خصم) مع تسجيل الحركة ومزامنتها.
  Map<String, dynamic> adjustStudentPoints({
    required String studentId,
    required int delta,
    String? reason,
    String? actorName,
  }) {
    final result = _studentsRepo.adjustStudentPoints(
      studentId: studentId,
      delta: delta,
      reason: reason,
      actorName: actorName,
    );
    if (result['success'] == true) {
      notifyListeners();
    }
    return result;
  }

  // ==========================================
  // Attendance Management
  // ==========================================
  List<AttendanceRecord> getAttendanceForDate(
      String halaqaId, String sessionDate) =>
      _attendanceRepo.getAttendanceForDate(halaqaId, sessionDate);

  void recordAttendance({
    required String studentId,
    required String halaqaId,
    required String sessionDate,
    required String status,
    int pointsEarned = 0,
    String? notes,
  }) {
    _attendanceRepo.recordAttendance(
      studentId: studentId,
      halaqaId: halaqaId,
      sessionDate: sessionDate,
      status: status,
      pointsEarned: pointsEarned,
      notes: notes,
    );
    notifyListeners();
  }

  Map<String, dynamic> getStudentAttendanceSummary(String studentId) =>
      _attendanceRepo.getStudentAttendanceSummary(studentId);

  // ==========================================
  // Memorization Records (Authentic Quran Progress)
  // ==========================================
  List<MemorizationRecord> getStudentMemorizations(String studentId) =>
      _recitationRepo.getStudentMemorizations(studentId);

  List<MemorizationRecord> getTodayMemorizations(
      {String? halaqaId, String? sheikhId}) =>
      _recitationRepo.getTodayMemorizations(
        halaqaId: halaqaId,
        sheikhId: sheikhId,
      );

  void recordRecitationBatch({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    String? courseId,
    required List<Map<String, dynamic>> items,
    required String sessionType,
    required int points,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    _recitationRepo.recordRecitationBatch(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      courseId: courseId,
      items: items,
      sessionType: sessionType,
      points: points,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
    notifyListeners();
  }

  void recordMemorization({
    required String studentId,
    String? halaqaId,
    String? sheikhId,
    String? courseId,
    required String surahName,
    required int fromAyah,
    required int toAyah,
    required int juzNumber,
    required String sessionType,
    String qualityRating = 'excellent',
    required int points,
    String? notes,
    bool countsTowardsStatistics = true,
  }) {
    _recitationRepo.recordMemorization(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      courseId: courseId,
      surahName: surahName,
      fromAyah: fromAyah,
      toAyah: toAyah,
      juzNumber: juzNumber,
      sessionType: sessionType,
      qualityRating: qualityRating,
      points: points,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
    notifyListeners();
  }

  void recordHadith({
    required String studentId,
    String? halaqaId,
    required String hadithTitle,
    required int points,
  }) {
    _recitationRepo.recordHadith(
      studentId: studentId,
      halaqaId: halaqaId,
      hadithTitle: hadithTitle,
      points: points,
    );
    notifyListeners();
  }

  Set<String> getStudentMemorizedAyahKeys(String studentId) =>
      _recitationRepo.getStudentMemorizedAyahKeys(studentId);

  Map<String, dynamic> getStudentJuzProgress(
      String studentId, int juzNumber) =>
      _recitationRepo.getStudentJuzProgress(studentId, juzNumber);

  Map<String, dynamic> getStudentOverallQuranProgress(String studentId) =>
      _recitationRepo.getStudentOverallQuranProgress(studentId);

  Map<int, Map<String, dynamic>> getStudent30AjzaStatus(String studentId) =>
      _recitationRepo.getStudent30AjzaStatus(studentId);

  int getStudentCompletedAjzaCount(String studentId) =>
      _recitationRepo.getStudentCompletedAjzaCount(studentId);

  // ==========================================
  // Executive Oversight Matrix
  // ==========================================
  List<Map<String, dynamic>> getExecutiveOverview({
    String? mosqueId,
    String? sheikhId,
    String? halaqaId,
    String? searchQuery,
    DateTime? date,
  }) =>
      _overviewRepo.getExecutiveOverview(
        mosqueId: mosqueId,
        sheikhId: sheikhId,
        halaqaId: halaqaId,
        searchQuery: searchQuery,
        date: date,
      );

  // ==========================================
  // Messages & Notifications
  // ==========================================
  List<AppMessage> getStudentMessages(String studentId) =>
      _messagesRepo.getStudentMessages(studentId);

  List<AppMessage> getHalaqaMessages(String halaqaId) =>
      _messagesRepo.getHalaqaMessages(halaqaId);

  void sendMessage({
    required String studentId,
    required String halaqaId,
    required String senderType,
    required String senderName,
    required String content,
    String messageType = 'general',
  }) {
    _messagesRepo.sendMessage(
      studentId: studentId,
      halaqaId: halaqaId,
      senderType: senderType,
      senderName: senderName,
      content: content,
      messageType: messageType,
    );
    notifyListeners();
  }

  // ==========================================
  // Community Events
  // ==========================================
  List<CommunityEvent> getCommunityEvents({String? gender, String? mosqueId}) =>
      _eventsRepo.getCommunityEvents(gender: gender, mosqueId: mosqueId);

  CommunityEvent addCommunityEvent({
    required String mosqueId,
    required String title,
    required String description,
    required String eventType,
    String? customTypeName,
    String timingType = 'prayer_linked',
    String? prayerName,
    String prayerRelation = 'after',
    required String targetAudience,
    required DateTime eventDateTime,
    required String organizerType,
    required String organizerName,
    int durationMinutes = 60,
    bool isQaEnabled = false,
    int maxQuestions = 10,
    bool isRecurring = true,
    String? recurringDays,
    String? sheikhId,
    String lessonFormat = 'single',
    List<String> sheikhIds = const [],
  }) {
    final event = _eventsRepo.addCommunityEvent(
      mosqueId: mosqueId,
      title: title,
      description: description,
      eventType: eventType,
      customTypeName: customTypeName,
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      targetAudience: targetAudience,
      eventDateTime: eventDateTime,
      organizerType: organizerType,
      organizerName: organizerName,
      durationMinutes: durationMinutes,
      isRecurring: isRecurring,
      recurringDays: recurringDays,
      isQaEnabled: isQaEnabled,
      maxQuestions: maxQuestions,
      sheikhId: sheikhId,
      lessonFormat: lessonFormat,
      sheikhIds: sheikhIds,
    );

    notifyListeners();
    return event;
  }

  void updateCommunityEvent({
    required String eventId,
    required String title,
    required String description,
    required String eventType,
    String? customTypeName,
    String? timingType,
    String? prayerName,
    String? prayerRelation,
    String? targetAudience,
    String? organizerName,
    DateTime? eventDateTime,
    int? durationMinutes,
    bool? isQaEnabled,
    int? maxQuestions,
    bool? isRecurring,
    String? recurringDays,
    String? sheikhId,
    String? lessonFormat,
    List<String>? sheikhIds,
  }) {
    _eventsRepo.updateCommunityEvent(
      eventId: eventId,
      title: title,
      description: description,
      eventType: eventType,
      customTypeName: customTypeName,
      timingType: timingType,
      prayerName: prayerName,
      prayerRelation: prayerRelation,
      targetAudience: targetAudience,
      organizerName: organizerName,
      eventDateTime: eventDateTime,
      durationMinutes: durationMinutes,
      isQaEnabled: isQaEnabled,
      maxQuestions: maxQuestions,
      isRecurring: isRecurring,
      recurringDays: recurringDays,
      sheikhId: sheikhId,
      lessonFormat: lessonFormat,
      sheikhIds: sheikhIds,
    );

    notifyListeners();
  }

  void deleteCommunityEvent(String eventId) {
    recordDeletedId(eventId);
    _eventsRepo.deleteCommunityEvent(eventId);
    notifyListeners();
  }

  void toggleEventStatus(String eventId) {
    _eventsRepo.toggleEventStatus(eventId);
    notifyListeners();
  }

  void tapAttendance(String eventId) {
    _eventsRepo.tapAttendance(eventId);
    notifyListeners();
  }

  Sheikh? findSheikhByCode(String code) {
    final list = _sheikhsRepo.getSheikhs();
    return list.where((s) => s.code.trim().toUpperCase() == code.trim().toUpperCase()).firstOrNull;
  }

  // ==========================================
  // Community Events Q&A and Live Status
  // ==========================================

  List<EventQuestion> getEventQuestions(String eventId) {
    return _localDataSource.eventQuestions.where((q) => q.eventId == eventId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  EventQuestion submitEventQuestion(String eventId, String content) {
    final q = EventQuestion(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _localDataSource.eventQuestions.insert(0, q);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'event_questions',
      action: 'upsert',
      data: q.toJson(),
      remoteDataSource: _remoteDataSource,
    );
    notifyListeners();
    return q;
  }

  void toggleQuestionAnswered(String questionId) {
    final q = _localDataSource.eventQuestions.where((q) => q.id == questionId).firstOrNull;
    if (q != null) {
      q.isAnswered = !q.isAnswered;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'event_questions',
        action: 'upsert',
        data: q.toJson(),
        remoteDataSource: _remoteDataSource,
      );
      notifyListeners();
    }
  }

  void changeEventStatus(String eventId, String newStatus) {
    final ev = _localDataSource.communityEvents.where((e) => e.id == eventId).firstOrNull;
    if (ev != null) {
      ev.eventStatus = newStatus;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: ev.toJson(),
        remoteDataSource: _remoteDataSource,
      );
      notifyListeners();
    }
  }

  DateTime _calculateNextRecurrence(DateTime currentDateTime, String? recurringDays) {
    if (recurringDays == null || recurringDays.trim().isEmpty) {
      return currentDateTime.isBefore(DateTime.now())
          ? currentDateTime.add(const Duration(days: 1))
          : currentDateTime;
    }

    const dayMap = {
      'الاثنين': DateTime.monday,
      'الثلاثاء': DateTime.tuesday,
      'الأربعاء': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'الجمعة': DateTime.friday,
      'السبت': DateTime.saturday,
      'الأحد': DateTime.sunday,
    };

    final targetWeekdays = <int>{};
    for (var entry in dayMap.entries) {
      if (recurringDays.contains(entry.key)) {
        targetWeekdays.add(entry.value);
      }
    }

    if (targetWeekdays.isEmpty) {
      return currentDateTime.add(const Duration(days: 1));
    }

    DateTime candidate = DateTime.now().add(const Duration(days: 1));
    for (int i = 0; i < 7; i++) {
      if (targetWeekdays.contains(candidate.weekday)) {
        return DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          currentDateTime.hour,
          currentDateTime.minute,
        );
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return currentDateTime.add(const Duration(days: 1));
  }

  /// Last line of defence for the "no women's archive" rule: even if a UI path
  /// were missed, no recording can be attached or archived from a women's branch
  /// session, nor onto an event owned by a women's branch.
  bool _archiveWriteAllowed(String? eventMosqueId) {
    if (!canRecordArchive) {
      debugPrint('⛔ التسجيل والأرشفة غير متاحين للقسم النسائي.');
      return false;
    }
    if (eventMosqueId != null && branchOfMosque(eventMosqueId) == 'female') {
      debugPrint('⛔ لا يمكن أرشفة درس تابع للقسم النسائي.');
      return false;
    }
    return true;
  }

  void finalizeLiveSession(String eventId) {
    final ev = _localDataSource.communityEvents.where((e) => e.id == eventId).firstOrNull;
    if (ev == null) return;
    if (!_archiveWriteAllowed(ev.mosqueId)) return;

    if (ev.isRecurring) {
      // 1. إنشاء لقطة الأرشيف فوراً وبشكل دائم ومضمون
      final archivedSnapshot = CommunityEvent(
        id: 'archived-${ev.id}-${DateTime.now().millisecondsSinceEpoch}',
        mosqueId: ev.mosqueId,
        title: ev.title,
        description: ev.description,
        eventType: ev.eventType,
        customTypeName: ev.customTypeName,
        timingType: 'custom_time',
        eventDateTime: DateTime.now(), // وقت التسجيل الفعلي
        organizerType: ev.organizerType,
        organizerName: ev.organizerName,
        targetAudience: ev.targetAudience,
        latitude: ev.latitude,
        longitude: ev.longitude,
        durationMinutes: ev.durationMinutes,
        audioRecordUrl: ev.audioRecordUrl,
        videoRecordUrl: ev.videoRecordUrl,
        eventStatus: 'archived',
        isRecurring: false,
        sheikhId: ev.sheikhId,
        lessonFormat: ev.lessonFormat,
        sheikhIds: ev.sheikhIds,
      );
      _localDataSource.communityEvents.insert(0, archivedSnapshot);
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: archivedSnapshot.toJson(),
        remoteDataSource: _remoteDataSource,
      );

      // 2. إعادة الدرس الأصلي لحالة "قادم" فوراً وتحديث موعده القادم
      ev.eventStatus = 'upcoming';
      ev.audioRecordUrl = null;
      ev.videoRecordUrl = null;
      ev.eventDateTime = _calculateNextRecurrence(ev.eventDateTime, ev.recurringDays);

      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: ev.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    } else {
      // للدروس لمرة واحدة، نحوله لأرشيف فوراً ليختفي من قائمة القادم ويبقى في الأرشيف
      ev.eventStatus = 'archived';
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: ev.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }

    _localDataSource.saveToStorage();
    notifyListeners();
  }

  void setEventAudioUrl(String eventId, String audioUrl) {
    final owner = _localDataSource.communityEvents
        .where((e) => e.id == eventId)
        .firstOrNull;
    if (!_archiveWriteAllowed(owner?.mosqueId)) return;

    // 1. فحص إذا كان هناك لقطة أرشيف مرتبطة بهذا الدرس
    final archivedEv = _archivedSnapshotFor(eventId, owner);

    if (archivedEv != null) {
      archivedEv.audioRecordUrl = audioUrl;
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: archivedEv.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    } else {
      // للدروس لمرة واحدة
      final ev = _localDataSource.communityEvents.where((e) => e.id == eventId).firstOrNull;
      if (ev != null) {
        ev.audioRecordUrl = audioUrl;
        _syncQueueManager.queueSync(
          table: 'community_events',
          action: 'upsert',
          data: ev.toJson(),
          remoteDataSource: _remoteDataSource,
        );
      }
    }

    _localDataSource.saveToStorage();
    notifyListeners();
  }

  /// لقطة الأرشيف التابعة لهذا الدرس. المطابقة مقيَّدة بنفس المسجد حتى لا تُكتب
  /// تسجيلات درس على درس آخر (أو على فرع آخر) عند تشابه المعرّفات.
  CommunityEvent? _archivedSnapshotFor(String eventId, CommunityEvent? owner) {
    return _localDataSource.communityEvents
        .where((e) =>
            e.eventStatus == 'archived' &&
            (e.id == eventId || e.id.contains('archived-$eventId-')) &&
            (owner == null || e.mosqueId == owner.mosqueId))
        .firstOrNull;
  }

  void setEventVideoUrl(String eventId, String videoUrl) {
    final owner = _localDataSource.communityEvents
        .where((e) => e.id == eventId)
        .firstOrNull;
    if (!_archiveWriteAllowed(owner?.mosqueId)) return;

    final archivedEv = _archivedSnapshotFor(eventId, owner);

    if (archivedEv != null) {
      archivedEv.videoRecordUrl = videoUrl;
      _syncQueueManager.queueSync(
        table: 'community_events',
        action: 'upsert',
        data: archivedEv.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    } else {
      final ev = _localDataSource.communityEvents.where((e) => e.id == eventId).firstOrNull;
      if (ev != null) {
        ev.videoRecordUrl = videoUrl;
        _syncQueueManager.queueSync(
          table: 'community_events',
          action: 'upsert',
          data: ev.toJson(),
          remoteDataSource: _remoteDataSource,
        );
      }
    }

    _localDataSource.saveToStorage();
    notifyListeners();
  }

  void updateMosqueDonationSettings({
    required String mosqueId,
    required bool isEnabled,
    String? accountName,
    String? accountNumber,
    String? description,
    String? imageUrl,
  }) {
    final mosque = getMosqueById(mosqueId);
    if (mosque == null) return;

    final updated = mosque.copyWith(
      isDonationEnabled: isEnabled,
      donationAccountName: accountName,
      donationAccountNumber: accountNumber,
      donationDescription: description,
      donationImageUrl: imageUrl,
    );

    final idx = _localDataSource.mosques.indexWhere((m) => m.id == mosqueId);
    if (idx != -1) {
      _localDataSource.mosques[idx] = updated;
    }

    _persistMosqueDonationLocally(updated);

    // Broadcast donation configuration to all other users via community_events table
    final configEventId = 'donation_cfg_$mosqueId';
    final payload = jsonEncode({
      'is_enabled': isEnabled,
      'account_name': accountName,
      'account_number': accountNumber,
      'description': description,
      'image_url': imageUrl,
    });

    final donationEvent = CommunityEvent(
      id: configEventId,
      mosqueId: mosqueId,
      title: accountName ?? mosque.name,
      description: payload,
      eventType: 'system_donation_config',
      targetAudience: 'general',
      eventDateTime: DateTime.now(),
      organizerType: 'system',
      organizerName: 'نظام التبرع المعتمد',
      isActive: isEnabled,
    );

    final existingEvIdx = _localDataSource.communityEvents.indexWhere((e) => e.id == configEventId);
    if (existingEvIdx != -1) {
      _localDataSource.communityEvents[existingEvIdx] = donationEvent;
    } else {
      _localDataSource.communityEvents.insert(0, donationEvent);
    }

    _syncQueueManager.queueSync(
      table: 'community_events',
      action: 'upsert',
      data: donationEvent.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    // حقول التبرع وحدها: الحفظ الكامل للصف كان يعيد كتابة رمز تسليم القسم
    // النسائي وربط الفرع من نسخة محلية قد تكون قديمة.
    _syncQueueManager.queueSync(
      table: 'mosques',
      action: 'patch',
      id: updated.id,
      data: {
        'is_donation_enabled': updated.isDonationEnabled,
        'donation_account_name': updated.donationAccountName,
        'donation_account_number': updated.donationAccountNumber,
        'donation_description': updated.donationDescription,
        'donation_image_url': updated.donationImageUrl,
      },
      remoteDataSource: _remoteDataSource,
    );

    _localDataSource.saveToStorage();
    notifyListeners();
  }

  void _applyDonationConfigFromRecord(Map<String, dynamic> record) {
    try {
      final desc = record['description']?.toString() ?? '';
      if (desc.isEmpty) return;
      final config = jsonDecode(desc);
      final mosqueId = record['mosque_id']?.toString() ?? '';
      if (mosqueId.isEmpty) return;
      final idx = _localDataSource.mosques.indexWhere((m) => m.id == mosqueId);
      if (idx != -1) {
        final existing = _localDataSource.mosques[idx];
        final updated = existing.copyWith(
          isDonationEnabled: config['is_enabled'] ?? existing.isDonationEnabled,
          donationAccountName: (config['account_name']?.toString().isNotEmpty ?? false)
              ? config['account_name']
              : existing.donationAccountName,
          donationAccountNumber: (config['account_number']?.toString().isNotEmpty ?? false)
              ? config['account_number']
              : existing.donationAccountNumber,
          donationDescription: (config['description']?.toString().isNotEmpty ?? false)
              ? config['description']
              : existing.donationDescription,
          donationImageUrl: (config['image_url']?.toString().isNotEmpty ?? false)
              ? config['image_url']
              : existing.donationImageUrl,
        );
        _localDataSource.mosques[idx] = updated;
        _persistMosqueDonationLocally(updated);
      }
    } catch (e) {
      debugPrint('Error applying realtime donation config: $e');
    }
  }

  void _applyDonationConfigEvent(CommunityEvent event) {
    try {
      if (event.description.isEmpty) return;
      final config = jsonDecode(event.description);
      final mosqueId = event.mosqueId;
      final idx = _localDataSource.mosques.indexWhere((m) => m.id == mosqueId);
      if (idx != -1) {
        final existing = _localDataSource.mosques[idx];
        final updated = existing.copyWith(
          isDonationEnabled: config['is_enabled'] ?? existing.isDonationEnabled,
          donationAccountName: (config['account_name']?.toString().isNotEmpty ?? false)
              ? config['account_name']
              : existing.donationAccountName,
          donationAccountNumber: (config['account_number']?.toString().isNotEmpty ?? false)
              ? config['account_number']
              : existing.donationAccountNumber,
          donationDescription: (config['description']?.toString().isNotEmpty ?? false)
              ? config['description']
              : existing.donationDescription,
          donationImageUrl: (config['image_url']?.toString().isNotEmpty ?? false)
              ? config['image_url']
              : existing.donationImageUrl,
        );
        _localDataSource.mosques[idx] = updated;
        _persistMosqueDonationLocally(updated);
      }
    } catch (e) {
      debugPrint('Error applying donation config event: $e');
    }
  }

  void _persistMosqueDonationLocally(Mosque mosque) {
    SharedPreferences.getInstance().then((prefs) {
      final key = 'mosque_donation_${mosque.id}';
      final data = jsonEncode({
        'is_enabled': mosque.isDonationEnabled,
        'account_name': mosque.donationAccountName,
        'account_number': mosque.donationAccountNumber,
        'description': mosque.donationDescription,
        'image_url': mosque.donationImageUrl,
      });
      prefs.setString(key, data);
    }).catchError((_) {});
  }

  Future<void> _restoreSavedDonations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < _localDataSource.mosques.length; i++) {
        final m = _localDataSource.mosques[i];
        final key = 'mosque_donation_${m.id}';
        final jsonStr = prefs.getString(key);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final map = jsonDecode(jsonStr);
          _localDataSource.mosques[i] = m.copyWith(
            isDonationEnabled: map['is_enabled'] ?? true,
            donationAccountName: map['account_name'] ?? m.donationAccountName,
            donationAccountNumber: map['account_number'] ?? m.donationAccountNumber,
            donationDescription: map['description'] ?? m.donationDescription,
            donationImageUrl: map['image_url'] ?? m.donationImageUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Error restoring saved donations: $e');
    }
  }

  // ==========================================
  // Competitions & Leaderboards
  // ==========================================
  List<Competition> getCompetitions({String? gender, String? mosqueId}) =>
      _competitionsRepo.getCompetitions(gender: gender, mosqueId: mosqueId);

  Competition addCompetition({
    String mosqueId = '',
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    bool countQuran = true,
    bool countHadith = true,
    bool countAttendance = true,
    int bonusPoints = 0,
    required String genderBranch,
  }) {
    final comp = _competitionsRepo.addCompetition(
      mosqueId: mosqueId,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      countQuran: countQuran,
      countHadith: countHadith,
      countAttendance: countAttendance,
      bonusPoints: bonusPoints,
      genderBranch: genderBranch,
    );
    notifyListeners();
    return comp;
  }

  void updateCompetition(Competition comp) {
    _competitionsRepo.updateCompetition(comp);
    notifyListeners();
  }

  void deleteCompetition(String competitionId) {
    recordDeletedId(competitionId);
    _competitionsRepo.deleteCompetition(competitionId);
    notifyListeners();
  }

  List<Map<String, dynamic>> getRankings({
    String? competitionId,
    String? mosqueId,
    String? halaqaId,
    String? gender,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _competitionsRepo.getRankings(
        competitionId: competitionId,
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        gender: gender,
        courseId: courseId,
        startDate: startDate,
        endDate: endDate,
      );

  // ==========================================
  // Rewards & Cashier Portal
  // ==========================================
  List<Reward> getRewards({String? mosqueId}) =>
      _rewardsRepo.getRewards(mosqueId: mosqueId);

  Reward addReward({
    required String mosqueId,
    required String title,
    String? description,
    required int pointsCost,
    bool isActive = true,
  }) {
    final reward = _rewardsRepo.addReward(
      mosqueId: mosqueId,
      title: title,
      description: description,
      pointsCost: pointsCost,
      isActive: isActive,
    );
    notifyListeners();
    return reward;
  }

  void updateReward(Reward reward) {
    _rewardsRepo.updateReward(reward);
    notifyListeners();
  }

  void deleteReward(String rewardId) {
    recordDeletedId(rewardId);
    _rewardsRepo.deleteReward(rewardId);
    notifyListeners();
  }

  List<RewardRedemption> getRedemptions(
      {String? mosqueId, String? studentId, String? status}) =>
      _rewardsRepo.getRedemptions(
        mosqueId: mosqueId,
        studentId: studentId,
        status: status,
      );

  RewardRedemption? claimReward({
    required String studentId,
    required String rewardId,
  }) {
    final red = _rewardsRepo.claimReward(
      studentId: studentId,
      rewardId: rewardId,
    );
    if (red != null) {
      notifyListeners();
    }
    return red;
  }

  Map<String, dynamic> sellReward({
    required String studentId,
    required String rewardId,
    required String cashierName,
  }) {
    final res = _rewardsRepo.sellReward(
      studentId: studentId,
      rewardId: rewardId,
      cashierName: cashierName,
    );
    notifyListeners();
    return res;
  }

  Map<String, dynamic> dispenseReward({
    required String voucherCode,
    required String cashierName,
  }) {
    final res = _rewardsRepo.dispenseReward(
      voucherCode: voucherCode,
      cashierName: cashierName,
    );
    if (res['success'] == true) {
      notifyListeners();
    }
    return res;
  }

  // ==========================================
  // Intensive Courses
  // ==========================================
  List<IntensiveCourse> getIntensiveCourses(
      {String? mosqueId, String? sheikhId}) =>
      _coursesRepo.getIntensiveCourses(
        mosqueId: mosqueId,
        sheikhId: sheikhId,
      );

  IntensiveCourse addIntensiveCourse({
    required String mosqueId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    List<String> sheikhIds = const [],
    List<String> halaqaIds = const [],
    List<String> studentIds = const [],
    List<int> daysOfWeek = const [6, 1, 3],
    String? startTime,
    String? endTime,
    bool countsTowardsQuranProgress = true,
  }) {
    final course = _coursesRepo.addIntensiveCourse(
      mosqueId: mosqueId,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      sheikhIds: sheikhIds,
      halaqaIds: halaqaIds,
      studentIds: studentIds,
      daysOfWeek: daysOfWeek,
      startTime: startTime,
      endTime: endTime,
      countsTowardsQuranProgress: countsTowardsQuranProgress,
    );
    notifyListeners();
    return course;
  }

  void updateIntensiveCourse(IntensiveCourse course) {
    _coursesRepo.updateIntensiveCourse(course);
    notifyListeners();
  }

  void deleteIntensiveCourse(String courseId) {
    recordDeletedId(courseId);
    _coursesRepo.deleteIntensiveCourse(courseId);
    notifyListeners();
  }

  // ==========================================
  // Smart Session Timing Detection
  // ==========================================
  Map<String, dynamic> detectSessionTimingMode({
    required String halaqaId,
    String? studentId,
    DateTime? currentTime,
  }) =>
      _coursesRepo.detectSessionTimingMode(
        halaqaId: halaqaId,
        studentId: studentId,
        currentTime: currentTime,
      );

  // ==========================================
  // Trips & Outings Management
  // ==========================================
  List<Trip> getTrips({String? mosqueId, String? studentId, String? halaqaId}) =>
      _tripsRepo.getTrips(
        mosqueId: mosqueId,
        studentId: studentId,
        halaqaId: halaqaId,
      );

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
    final trip = _tripsRepo.addTrip(
      mosqueId: mosqueId,
      title: title,
      destination: destination,
      tripDate: tripDate,
      meetingTime: meetingTime,
      deadlineDate: deadlineDate,
      description: description,
      requiredItems: requiredItems,
      targetHalaqaIds: targetHalaqaIds,
      targetStudentIds: targetStudentIds,
      costPoints: costPoints,
    );
    notifyListeners();
    return trip;
  }

  void updateTrip(Trip trip) {
    _tripsRepo.updateTrip(trip);
    notifyListeners();
  }

  void deleteTrip(String tripId) {
    recordDeletedId(tripId);
    _tripsRepo.deleteTrip(tripId);
    notifyListeners();
  }

  // ==========================================
  // Recitation Tracks & Custom Subjects
  // ==========================================
  List<RecitationTrack> getRecitationTracks({
    String? mosqueId,
    String? halaqaId,
    bool activeOnly = true,
  }) =>
      _tracksRepo.getRecitationTracks(
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        activeOnly: activeOnly,
      );

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
    final track = _tracksRepo.addRecitationTrack(
      mosqueId: mosqueId,
      name: name,
      category: category,
      unitLabel: unitLabel,
      totalUnits: totalUnits,
      pointsPerUnit: pointsPerUnit,
      isActive: isActive,
      targetHalaqaIds: targetHalaqaIds,
      sheikhId: sheikhId,
    );
    notifyListeners();
    return track;
  }

  void updateRecitationTrack(RecitationTrack track) {
    _tracksRepo.updateRecitationTrack(track);
    notifyListeners();
  }

  void deleteRecitationTrack(String trackId) {
    recordDeletedId(trackId);
    _tracksRepo.deleteRecitationTrack(trackId);
    notifyListeners();
  }

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
    final rec = _tracksRepo.recordSubjectRecitation(
      studentId: studentId,
      halaqaId: halaqaId,
      sheikhId: sheikhId,
      trackId: trackId,
      trackName: trackName,
      fromUnit: fromUnit,
      toUnit: toUnit,
      pointsEarned: pointsEarned,
      courseId: courseId,
      notes: notes,
      countsTowardsStatistics: countsTowardsStatistics,
    );
    notifyListeners();
    return rec;
  }

  Map<String, dynamic> getStudentSubjectProgress(
      String studentId, String trackId) =>
      _tracksRepo.getStudentSubjectProgress(studentId, trackId);

  List<Map<String, dynamic>> getAllStudentSubjectProgresses(
      String studentId) =>
      _tracksRepo.getAllStudentSubjectProgresses(studentId);

  // ==========================================
  // Super Admin & Registration Management
  // ==========================================

  /// جدول الصلاحية: صف واحد لكل مشرف عام، محمي بـ RLS بحيث لا يقرأ المستخدم
  /// إلا صفه هو، ولا يستطيع أحد الكتابة فيه عبر واجهة الـ API إطلاقاً.
  static const String _superAdminsTable = 'super_admins';

  /// يتحقق أن المستخدم المسجَّل دخوله يملك فعلاً صلاحية المشرف العام.
  ///
  /// القرار يصدر من الخادم لا من التطبيق: سياسة RLS هي التي تحدد ما إذا كان
  /// الصف مرئياً، فلا ينفع تزوير أي شيء من جهة العميل.
  Future<bool> _verifySuperAdminRole(SupabaseClient client, String userId) async {
    final row = await client
        .from(_superAdminsTable)
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  void _activateSuperAdminSession() {
    final alreadyActive = _authSessionRepo.currentSession?.role == 'super_admin';
    if (!alreadyActive) {
      _authSessionRepo.setRoleSession(ActiveSession(
        role: 'super_admin',
        code: 'SUPER-ADMIN-ROOT',
        name: 'المشرف العام',
      ));
    }
  }

  /// يستعيد جلسة المشرف العام عند الإقلاع.
  ///
  /// العلامة المحلية وحدها لا تكفي: لا بد من جلسة Supabase صالحة ومحفوظة على
  /// الجهاز. بهذا يعمل التطبيق دون إنترنت بعد أول دخول، دون أن تتحول العلامة
  /// المحلية إلى باب خلفي يُفتح بتعديل التخزين المحلي.
  Future<void> restoreSuperAdminSessionIfNeeded() async {
    // نراقب تغيّر حالة المصادقة دائماً: هو ما يُسقط العلامة عند تسجيل خروج
    // حقيقي، وما يُفعّل الجلسة إن تأخر استرجاعها أو تأخر تجديد التوكن.
    _watchSuperAdminAuthState();

    if (!_localDataSource.isSuperAdminAuthenticated) return;

    // الانتظار ضروري: استرجاع الجلسة المحفوظة يجري في الخلفية بعد
    // `Supabase.initialize()`، وقراءة `currentSession` قبله تُرجع null دائماً
    await _remoteDataSource.waitForSessionRestore();

    if (_remoteDataSource.client?.auth.currentSession == null) {
      // لا نُسقط العلامة هنا: الغياب قد يكون انقطاع إنترنت أو تأخر تجديد،
      // وإسقاطها يعني إجبار المشرف على تسجيل دخول جديد بلا سبب.
      // الإسقاط يتم حصراً عند حدث تسجيل خروج مؤكَّد من الخادم.
      debugPrint('ℹ️ لم تُسترجع جلسة المشرف العام بعد؛ سيُفعّل الدخول حال توفرها');
      return;
    }

    _activateSuperAdminSession();
    notifyListeners();
  }

  StreamSubscription<AuthState>? _superAdminAuthSub;

  /// يربط جلسة المشرف العام بحالة المصادقة الحقيقية طوال عمر التطبيق.
  ///
  /// بهذا تُفعَّل الجلسة متى توفّرت (استرجاع متأخر أو تجديد توكن بعد عودة
  /// الإنترنت)، وتُسقط العلامة المحلية عند تسجيل خروج مؤكَّد فقط.
  void _watchSuperAdminAuthState() {
    final client = _remoteDataSource.client;
    if (client == null || _superAdminAuthSub != null) return;

    _superAdminAuthSub = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        if (!_localDataSource.isSuperAdminAuthenticated) return;
        _localDataSource.isSuperAdminAuthenticated = false;
        _localDataSource.saveToStorage();
        _authSessionRepo.disconnectRole('super_admin');
        notifyListeners();
        return;
      }

      if (state.session == null) return;
      if (!_localDataSource.isSuperAdminAuthenticated) return;
      if (_authSessionRepo.currentSession?.role == 'super_admin') return;

      _activateSuperAdminSession();
      notifyListeners();
    });
  }

  /// تسجيل دخول المشرف العام عبر Supabase Auth.
  ///
  /// كلمة السر لا تُخزَّن في التطبيق ولا تُقارَن محلياً: يتحقق منها خادم
  /// Supabase مقابل تجزئة مُملّحة، ثم تُفحص الصلاحية من جدول محمي بـ RLS.
  Future<SuperAdminLoginResult> superAdminLoginAsync(String email, String password) async {
    final client = _remoteDataSource.client;
    if (client == null) return SuperAdminLoginResult.unavailable;

    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) return SuperAdminLoginResult.invalidCredentials;

      if (!await _verifySuperAdminRole(client, user.id)) {
        // حساب صحيح لكنه لا يملك الصلاحية: لا نُبقي جلسته مفتوحة
        await client.auth.signOut();
        return SuperAdminLoginResult.notAuthorized;
      }

      _activateSuperAdminSession();
      _localDataSource.isSuperAdminAuthenticated = true;
      await _localDataSource.saveToStorage();
      notifyListeners();
      return SuperAdminLoginResult.success;
    } on AuthException catch (e) {
      debugPrint('⚠️ فشل دخول المشرف العام: ${e.message}');
      return SuperAdminLoginResult.invalidCredentials;
    } catch (e) {
      debugPrint('⚠️ تعذر الوصول لخادم المصادقة: $e');
      return SuperAdminLoginResult.unavailable;
    }
  }


  // ---- أكواد تسجيل المساجد: مخزّنة سحابياً ليراها كل أجهزة المشرف العام ----
  static const String _tokensTable = 'registration_tokens';

  /// يعيد بناء قائمتي الأكواد النشطة وسجل الاستخدام من صفوف Supabase
  void _applyRemoteTokens(List<Map<String, dynamic>> rows) {
    final active = <String>[];
    final history = <Map<String, dynamic>>[];

    for (final row in rows) {
      final token = (row['id'] ?? '').toString().trim();
      if (token.isEmpty) continue;

      if (row['is_used'] == true) {
        history.add({
          'token': token,
          'mosqueName': (row['mosque_name'] ?? 'مسجد جديد').toString(),
          'mosqueAddress': (row['mosque_address'] ?? '').toString(),
          'mosqueAccessCode': (row['mosque_access_code'] ?? '').toString(),
          'timestamp': (row['used_at'] ?? row['created_at'] ?? DateTime.now().toIso8601String()).toString(),
        });
      } else if (!_syncQueueManager.isPendingDelete(_tokensTable, token)) {
        active.add(token);
      }
    }

    // الإبقاء على الأكواد المولّدة محلياً والتي لم تُرفع بعد (وضع عدم الاتصال)
    for (final local in _localDataSource.registrationTokens) {
      if (!active.contains(local) && _syncQueueManager.isPendingUpsert(_tokensTable, local)) {
        active.add(local);
      }
    }

    history.sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));

    _localDataSource.registrationTokens
      ..clear()
      ..addAll(active);
    _localDataSource.tokenUsageHistory
      ..clear()
      ..addAll(history);
  }

  /// ترحيل الأكواد المحفوظة محلياً إلى السحابة عند إنشاء الجدول لأول مرة
  Future<void> _uploadLocalTokensToCloud() async {
    for (final t in _localDataSource.registrationTokens) {
      await _remoteDataSource.upsert(_tokensTable, {'id': t, 'is_used': false});
    }
    for (final h in _localDataSource.tokenUsageHistory) {
      final id = (h['token'] ?? '').toString();
      if (id.isEmpty) continue;
      await _remoteDataSource.upsert(_tokensTable, {
        'id': id,
        'is_used': true,
        'mosque_name': h['mosqueName'],
        'mosque_address': h['mosqueAddress'],
        'mosque_access_code': h['mosqueAccessCode'],
        'used_at': h['timestamp'],
      });
    }
  }

  /// يسحب أكواد التسجيل وسجلها من Supabase ليظهر نفس المحتوى على كل أجهزة المشرف العام
  Future<void> syncRegistrationTokens() async {
    try {
      final rows = await _remoteDataSource.fetchTable(_tokensTable);
      // الجدول غير منشأ أو لا يوجد اتصال: نُبقي النسخة المحلية كما هي
      if (rows == null) return;

      if (rows.isEmpty &&
          (_localDataSource.registrationTokens.isNotEmpty ||
              _localDataSource.tokenUsageHistory.isNotEmpty)) {
        await _uploadLocalTokensToCloud();
        final refreshed = await _remoteDataSource.fetchTable(_tokensTable);
        if (refreshed != null) _applyRemoteTokens(refreshed);
      } else {
        _applyRemoteTokens(rows);
      }

      await _localDataSource.saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ syncRegistrationTokens error: $e');
    }
  }

  Future<String> generateRegistrationToken() async {
    final token =
        'REG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-${_localDataSource.mosques.length + 1}';
    final row = {
      'id': token,
      'is_used': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    _localDataSource.registrationTokens.add(token);
    await _localDataSource.saveToStorage();
    notifyListeners();

    try {
      await _remoteDataSource.upsert(_tokensTable, row);
    } catch (_) {
      _syncQueueManager.queueSync(
        table: _tokensTable,
        action: 'upsert',
        data: row,
        id: token,
        remoteDataSource: _remoteDataSource,
      );
    }
    return token;
  }

  /// يتحقق من الكود عبر السحابة أولاً، حتى ينجح مسح باركود مولَّد على جهاز
  /// المشرف العام من جهاز مدير المسجد الجديد.
  ///
  /// يميّز بين أسباب الفشل بدل إرجاع `false` مبهم: "غير موجود" و"مستخدم"
  /// و"تعذر الاتصال" حالات مختلفة تماماً، وخلطها كان يُخفي السبب الحقيقي.
  Future<RegistrationTokenCheck> checkRegistrationToken(String token) async {
    final clean = token.trim().toUpperCase();
    if (clean.isEmpty) return RegistrationTokenCheck.notFound;

    final client = _remoteDataSource.client;
    if (client != null) {
      try {
        final row = await client
            .from(_tokensTable)
            .select('id, is_used')
            .eq('id', clean)
            .maybeSingle();

        if (row == null) return RegistrationTokenCheck.notFound;
        if (row['is_used'] == true) return RegistrationTokenCheck.alreadyUsed;

        if (!_localDataSource.registrationTokens.contains(clean)) {
          _localDataSource.registrationTokens.add(clean);
          await _localDataSource.saveToStorage();
          notifyListeners();
        }
        return RegistrationTokenCheck.valid;
      } catch (e) {
        // تعذر الوصول للسحابة: لا نحكم بأن الكود خاطئ، بل نجرّب النسخة المحلية
        debugPrint('⚠️ تعذر التحقق من الكود عبر السحابة: $e');
      }
    }

    // احتياطي دون اتصال: ينجح فقط إذا وُلّد الكود على هذا الجهاز نفسه
    if (_localDataSource.registrationTokens.contains(clean)) {
      return RegistrationTokenCheck.valid;
    }
    return RegistrationTokenCheck.unreachable;
  }

  /// غلاف منطقي مبسّط للاستدعاءات التي تحتاج نعم/لا فقط.
  Future<bool> verifyRegistrationToken(String token) async =>
      await checkRegistrationToken(token) == RegistrationTokenCheck.valid;

  Future<void> consumeRegistrationToken({
    required String token,
    required String mosqueName,
    required String mosqueAddress,
    required String mosqueAccessCode,
  }) async {
    final clean = token.trim().toUpperCase();
    final usedAt = DateTime.now().toIso8601String();

    _localDataSource.registrationTokens.remove(clean);
    _localDataSource.tokenUsageHistory.removeWhere((h) => h['token'] == clean);
    _localDataSource.tokenUsageHistory.add({
      'token': clean,
      'mosqueName': mosqueName,
      'mosqueAddress': mosqueAddress,
      'mosqueAccessCode': mosqueAccessCode,
      'timestamp': usedAt,
    });
    await _localDataSource.saveToStorage();
    notifyListeners();

    final row = {
      'id': clean,
      'is_used': true,
      'mosque_name': mosqueName,
      'mosque_address': mosqueAddress,
      'mosque_access_code': mosqueAccessCode,
      'used_at': usedAt,
    };
    try {
      await _remoteDataSource.upsert(_tokensTable, row);
    } catch (_) {
      _syncQueueManager.queueSync(
        table: _tokensTable,
        action: 'upsert',
        data: row,
        id: clean,
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  List<String> getRegistrationTokens() => _localDataSource.registrationTokens;

  List<Map<String, dynamic>> getTokenUsageHistory() => _localDataSource.tokenUsageHistory;

  Future<void> deleteRegistrationToken(String token) async {
    final clean = token.trim().toUpperCase();
    _localDataSource.registrationTokens.removeWhere((t) => t == token || t == clean);
    await _localDataSource.saveToStorage();
    notifyListeners();

    try {
      await _remoteDataSource.delete(_tokensTable, matchingColumn: 'id', matchingValue: clean);
    } catch (_) {
      _syncQueueManager.queueSync(
        table: _tokensTable,
        action: 'delete',
        data: {'id': clean},
        id: clean,
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  Future<void> deleteHistoryItem(int index) async {
    if (index < 0 || index >= _localDataSource.tokenUsageHistory.length) return;

    final removed = _localDataSource.tokenUsageHistory.removeAt(index);
    await _localDataSource.saveToStorage();
    notifyListeners();

    final id = (removed['token'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await _remoteDataSource.delete(_tokensTable, matchingColumn: 'id', matchingValue: id);
    } catch (_) {
      _syncQueueManager.queueSync(
        table: _tokensTable,
        action: 'delete',
        data: {'id': id},
        id: id,
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  Future<void> masterResetAllData() async {
    // 1. Clear Local Storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Complete wipe of all keys

    // 2. Clear In-Memory Cache
    _localDataSource.mosques.clear();
    _localDataSource.sheikhs.clear();
    _localDataSource.halaqat.clear();
    _localDataSource.students.clear();
    _localDataSource.communityEvents.clear();
    _localDataSource.pointsLogs.clear();
    _localDataSource.competitions.clear();
    _localDataSource.memorizationRecords.clear();
    _localDataSource.attendanceRecords.clear();
    _localDataSource.messages.clear();
    _localDataSource.rewards.clear();
    _localDataSource.redemptions.clear();
    _localDataSource.intensiveCourses.clear();
    _localDataSource.trips.clear();
    _localDataSource.recitationTracks.clear();
    _localDataSource.subjectRecitationRecords.clear();
    _localDataSource.registrationTokens.clear();
    _localDataSource.tokenUsageHistory.clear();
    _localDataSource.currentSession = null;
    _localDataSource.savedSessions.clear();

    // 3. Clear Remote Database (Supabase)
    final tables = [
      'mosques', 'sheikhs', 'halaqat', 'students', 'community_events',
      'memorization_records', 'attendance', 'messages', 'rewards',
      'redemptions', 'intensive_courses', 'trips', 'recitation_tracks',
      'subject_recitation_records', 'registration_tokens'
    ];

    for (final table in tables) {
      try {
        await _remoteDataSource.client?.from(table).delete().neq('id', '0');
      } catch (_) {}
    }

    notifyListeners();
  }
}
