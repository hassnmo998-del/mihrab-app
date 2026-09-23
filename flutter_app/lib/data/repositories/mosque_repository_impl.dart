import '../../domain/repositories/mosque_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';
import 'attendance_repository_impl.dart';
import 'auth_session_repository_impl.dart';
import 'community_events_repository_impl.dart';
import 'competitions_repository_impl.dart';
import 'courses_repository_impl.dart';
import 'executive_overview_repository_impl.dart';
import 'halaqat_repository_impl.dart';
import 'messages_repository_impl.dart';
import 'mosques_repository_impl.dart';
import 'recitation_repository_impl.dart';
import 'recitation_tracks_repository_impl.dart';
import 'rewards_repository_impl.dart';
import 'sheikhs_repository_impl.dart';
import 'students_repository_impl.dart';
import 'trips_repository_impl.dart';

part 'mosque_repo_auth_part.dart';
part 'mosque_repo_core_administration_part.dart';
part 'mosque_repo_students_attendance_part.dart';
part 'mosque_repo_recitation_part.dart';
part 'mosque_repo_courses_trips_part.dart';
part 'mosque_repo_rewards_competitions_part.dart';
part 'mosque_repo_community_overview_part.dart';
part 'mosque_repo_resolver_part.dart';

/// Aggregated Clean Architecture implementation of [MosqueRepository].
/// Directly composes and delegates to the 15 underlying concrete repositories
/// without depending on presentation or service facades.
class MosqueRepositoryImpl
    with
        MosqueRepoAuthMixin,
        MosqueRepoCoreAdministrationMixin,
        MosqueRepoStudentsAttendanceMixin,
        MosqueRepoRecitationMixin,
        MosqueRepoCoursesTripsMixin,
        MosqueRepoRewardsCompetitionsMixin,
        MosqueRepoCommunityOverviewMixin
    implements MosqueRepository {
  @override
  final AuthSessionRepositoryImpl authSessionRepository;

  @override
  final MosquesRepositoryImpl mosquesRepository;

  @override
  final SheikhsRepositoryImpl sheikhsRepository;

  @override
  final HalaqatRepositoryImpl halaqatRepository;

  @override
  final StudentsRepositoryImpl studentsRepository;

  @override
  final AttendanceRepositoryImpl attendanceRepository;

  @override
  final RecitationRepositoryImpl recitationRepository;

  @override
  final RecitationTracksRepositoryImpl recitationTracksRepository;

  @override
  final CoursesRepositoryImpl coursesRepository;

  @override
  final TripsRepositoryImpl tripsRepository;

  @override
  final RewardsRepositoryImpl rewardsRepository;

  @override
  final CompetitionsRepositoryImpl competitionsRepository;

  @override
  final CommunityEventsRepositoryImpl communityEventsRepository;

  @override
  final MessagesRepositoryImpl messagesRepository;

  @override
  final ExecutiveOverviewRepositoryImpl executiveOverviewRepository;

  final LocalStorageDataSource? _localDataSource;
  final SupabaseRemoteDataSource? _remoteDataSource;

  const MosqueRepositoryImpl._raw({
    required this.authSessionRepository,
    required this.mosquesRepository,
    required this.sheikhsRepository,
    required this.halaqatRepository,
    required this.studentsRepository,
    required this.attendanceRepository,
    required this.recitationRepository,
    required this.recitationTracksRepository,
    required this.coursesRepository,
    required this.tripsRepository,
    required this.rewardsRepository,
    required this.competitionsRepository,
    required this.communityEventsRepository,
    required this.messagesRepository,
    required this.executiveOverviewRepository,
    LocalStorageDataSource? localDataSource,
    SupabaseRemoteDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Explicit repository composition constructor.
  factory MosqueRepositoryImpl.fromRepositories({
    required AuthSessionRepositoryImpl authSessionRepository,
    required MosquesRepositoryImpl mosquesRepository,
    required SheikhsRepositoryImpl sheikhsRepository,
    required HalaqatRepositoryImpl halaqatRepository,
    required StudentsRepositoryImpl studentsRepository,
    required AttendanceRepositoryImpl attendanceRepository,
    required RecitationRepositoryImpl recitationRepository,
    required RecitationTracksRepositoryImpl recitationTracksRepository,
    required CoursesRepositoryImpl coursesRepository,
    required TripsRepositoryImpl tripsRepository,
    required RewardsRepositoryImpl rewardsRepository,
    required CompetitionsRepositoryImpl competitionsRepository,
    required CommunityEventsRepositoryImpl communityEventsRepository,
    required MessagesRepositoryImpl messagesRepository,
    required ExecutiveOverviewRepositoryImpl executiveOverviewRepository,
    LocalStorageDataSource? localDataSource,
    SupabaseRemoteDataSource? remoteDataSource,
  }) {
    return MosqueRepositoryImpl._raw(
      authSessionRepository: authSessionRepository,
      mosquesRepository: mosquesRepository,
      sheikhsRepository: sheikhsRepository,
      halaqatRepository: halaqatRepository,
      studentsRepository: studentsRepository,
      attendanceRepository: attendanceRepository,
      recitationRepository: recitationRepository,
      recitationTracksRepository: recitationTracksRepository,
      coursesRepository: coursesRepository,
      tripsRepository: tripsRepository,
      rewardsRepository: rewardsRepository,
      competitionsRepository: competitionsRepository,
      communityEventsRepository: communityEventsRepository,
      messagesRepository: messagesRepository,
      executiveOverviewRepository: executiveOverviewRepository,
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
    );
  }

  /// Default constructor resolving the 15 underlying repositories directly.
  factory MosqueRepositoryImpl([
    Object? sourceOrAuth,
    MosquesRepositoryImpl? mosquesRepo,
    SheikhsRepositoryImpl? sheikhsRepo,
    HalaqatRepositoryImpl? halaqatRepo,
    StudentsRepositoryImpl? studentsRepo,
    AttendanceRepositoryImpl? attendanceRepo,
    RecitationRepositoryImpl? recitationRepo,
    RecitationTracksRepositoryImpl? recitationTracksRepo,
    CoursesRepositoryImpl? coursesRepo,
    TripsRepositoryImpl? tripsRepo,
    RewardsRepositoryImpl? rewardsRepo,
    CompetitionsRepositoryImpl? competitionsRepo,
    CommunityEventsRepositoryImpl? communityEventsRepo,
    MessagesRepositoryImpl? messagesRepo,
    ExecutiveOverviewRepositoryImpl? executiveOverviewRepo,
    LocalStorageDataSource? localDataSource,
    SupabaseRemoteDataSource? remoteDataSource,
    OfflineSyncQueueManager? syncQueueManager,
  ]) {
    return _MosqueRepoResolver.resolve(
      sourceOrAuth: sourceOrAuth,
      mosquesRepo: mosquesRepo,
      sheikhsRepo: sheikhsRepo,
      halaqatRepo: halaqatRepo,
      studentsRepo: studentsRepo,
      attendanceRepo: attendanceRepo,
      recitationRepo: recitationRepo,
      recitationTracksRepo: recitationTracksRepo,
      coursesRepo: coursesRepo,
      tripsRepo: tripsRepo,
      rewardsRepo: rewardsRepo,
      competitionsRepo: competitionsRepo,
      communityEventsRepo: communityEventsRepo,
      messagesRepo: messagesRepo,
      executiveOverviewRepo: executiveOverviewRepo,
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncQueueManager: syncQueueManager,
    );
  }

  // ==========================================
  // Cloud Synchronization
  // ==========================================
  @override
  Future<void> syncWithSupabase() async {
    final remote = _remoteDataSource;
    final local = _localDataSource;
    if (remote == null || local == null) return;

    try {
      final remoteMosques = await remote.fetchMosquesForSync();
      if (remoteMosques != null && remoteMosques.isNotEmpty) {
        final localMap = {for (var m in local.mosques) m.id: m};
        local.mosques.clear();
        for (var item in remoteMosques) {
          final remoteM = Mosque.fromJson(item);
          final localM = localMap[remoteM.id];
          if (localM != null) {
            final merged = remoteM.copyWith(
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
            local.mosques.add(merged);
          } else {
            local.mosques.add(remoteM);
          }
        }
      }

      final remoteSheikhs = await remote.fetchTable('sheikhs');
      if (remoteSheikhs != null && remoteSheikhs.isNotEmpty) {
        local.sheikhs.clear();
        for (var item in remoteSheikhs) {
          local.sheikhs.add(Sheikh.fromJson(item));
        }
      }

      final remoteHalaqat = await remote.fetchTable('halaqat');
      if (remoteHalaqat != null && remoteHalaqat.isNotEmpty) {
        local.halaqat.clear();
        for (var item in remoteHalaqat) {
          local.halaqat.add(Halaqa.fromJson(item));
        }
      }

      final remoteStudents = await remote.fetchTable('students');
      if (remoteStudents != null && remoteStudents.isNotEmpty) {
        local.students.clear();
        for (var item in remoteStudents) {
          local.students.add(Student.fromJson(item));
        }
      }

      // مزج ذكي للأحداث المجتمعية - لا نحذف البيانات المحلية المعلقة
      final remoteEvents = await remote.fetchTable('community_events');
      if (remoteEvents != null && remoteEvents.isNotEmpty) {
        final localEventMap = {for (var e in local.communityEvents) e.id: e};
        final remoteEventMap = {for (var item in remoteEvents) CommunityEvent.fromJson(item).id: CommunityEvent.fromJson(item)};

        local.communityEvents.clear();
        // إضافة جميع الأحداث البعيدة
        local.communityEvents.addAll(remoteEventMap.values);

        // إضافة الأحداث المحلية المعلقة التي لم تُرسل بعد
        for (var localEvent in localEventMap.values) {
          if (!remoteEventMap.containsKey(localEvent.id)) {
            // هذا حدث محلي لم يُرسل بعد، حافظ عليه
            local.communityEvents.add(localEvent);
          }
        }
      }

      final remoteMem = await remote.fetchTable('memorization_records');
      if (remoteMem != null && remoteMem.isNotEmpty) {
        local.memorizationRecords.clear();
        for (var item in remoteMem) {
          local.memorizationRecords.add(MemorizationRecord.fromJson(item));
        }
      }

      final remoteAtt = await remote.fetchTable('attendance');
      if (remoteAtt != null && remoteAtt.isNotEmpty) {
        local.attendanceRecords.clear();
        for (var item in remoteAtt) {
          local.attendanceRecords.add(AttendanceRecord.fromJson(item));
        }
      }

      final remoteMsgs = await remote.fetchTable('messages');
      if (remoteMsgs != null && remoteMsgs.isNotEmpty) {
        local.messages.clear();
        for (var item in remoteMsgs) {
          local.messages.add(AppMessage.fromJson(item));
        }
      }

      await local.saveToStorage();
    } catch (_) {
      // Offline fallback
    }
  }
}
