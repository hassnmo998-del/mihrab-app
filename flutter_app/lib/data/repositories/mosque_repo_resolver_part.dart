part of 'mosque_repository_impl.dart';

/// Internal resolver for concrete repository dependencies.
class _MosqueRepoResolver {
  static MosqueRepositoryImpl resolve({
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
  }) {
    LocalStorageDataSource? local = localDataSource;
    SupabaseRemoteDataSource? remote = remoteDataSource;
    OfflineSyncQueueManager? sync = syncQueueManager;

    if (sourceOrAuth != null && sourceOrAuth is! AuthSessionRepositoryImpl) {
      try {
        final dyn = sourceOrAuth as dynamic;
        local ??= dyn.localDataSource as LocalStorageDataSource?;
        remote ??= dyn.remoteDataSource as SupabaseRemoteDataSource?;
        sync ??= dyn.syncQueueManager as OfflineSyncQueueManager?;
      } catch (_) {}
    }

    local ??= LocalStorageDataSource();
    sync ??= OfflineSyncQueueManager();

    AuthSessionRepositoryImpl? auth;
    if (sourceOrAuth is AuthSessionRepositoryImpl) {
      auth = sourceOrAuth;
    } else if (sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).authSessionRepository;
        if (r is AuthSessionRepositoryImpl) auth = r;
      } catch (_) {}
    }
    auth ??= AuthSessionRepositoryImpl(local);

    MosquesRepositoryImpl? mosques = mosquesRepo;
    if (mosques == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).mosquesRepository;
        if (r is MosquesRepositoryImpl) mosques = r;
      } catch (_) {}
    }
    mosques ??= MosquesRepositoryImpl(local, sync, remoteDataSource: remote);

    SheikhsRepositoryImpl? sheikhs = sheikhsRepo;
    if (sheikhs == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).sheikhsRepository;
        if (r is SheikhsRepositoryImpl) sheikhs = r;
      } catch (_) {}
    }
    sheikhs ??= SheikhsRepositoryImpl(local, sync, remoteDataSource: remote);

    HalaqatRepositoryImpl? halaqat = halaqatRepo;
    if (halaqat == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).halaqatRepository;
        if (r is HalaqatRepositoryImpl) halaqat = r;
      } catch (_) {}
    }
    halaqat ??= HalaqatRepositoryImpl(local, sync, remoteDataSource: remote);

    StudentsRepositoryImpl? students = studentsRepo;
    if (students == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).studentsRepository;
        if (r is StudentsRepositoryImpl) students = r;
      } catch (_) {}
    }
    students ??= StudentsRepositoryImpl(local, sync, remoteDataSource: remote);

    AttendanceRepositoryImpl? attendance = attendanceRepo;
    if (attendance == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).attendanceRepository;
        if (r is AttendanceRepositoryImpl) attendance = r;
      } catch (_) {}
    }
    attendance ??=
        AttendanceRepositoryImpl(local, sync, remoteDataSource: remote);

    RecitationRepositoryImpl? recitation = recitationRepo;
    if (recitation == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).recitationRepository;
        if (r is RecitationRepositoryImpl) recitation = r;
      } catch (_) {}
    }
    recitation ??=
        RecitationRepositoryImpl(local, sync, remoteDataSource: remote);

    RecitationTracksRepositoryImpl? tracks = recitationTracksRepo;
    if (tracks == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).recitationTracksRepository;
        if (r is RecitationTracksRepositoryImpl) tracks = r;
      } catch (_) {}
    }
    tracks ??=
        RecitationTracksRepositoryImpl(local, sync, remoteDataSource: remote);

    CoursesRepositoryImpl? courses = coursesRepo;
    if (courses == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).coursesRepository;
        if (r is CoursesRepositoryImpl) courses = r;
      } catch (_) {}
    }
    courses ??= CoursesRepositoryImpl(local, sync, remoteDataSource: remote);

    TripsRepositoryImpl? trips = tripsRepo;
    if (trips == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).tripsRepository;
        if (r is TripsRepositoryImpl) trips = r;
      } catch (_) {}
    }
    trips ??= TripsRepositoryImpl(local, sync, remoteDataSource: remote);

    RewardsRepositoryImpl? rewards = rewardsRepo;
    if (rewards == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).rewardsRepository;
        if (r is RewardsRepositoryImpl) rewards = r;
      } catch (_) {}
    }
    rewards ??= RewardsRepositoryImpl(local, sync, remoteDataSource: remote);

    CompetitionsRepositoryImpl? competitions = competitionsRepo;
    if (competitions == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).competitionsRepository;
        if (r is CompetitionsRepositoryImpl) competitions = r;
      } catch (_) {}
    }
    competitions ??= CompetitionsRepositoryImpl(
      local,
      syncQueueManager: sync,
      remoteDataSource: remote,
    );

    CommunityEventsRepositoryImpl? events = communityEventsRepo;
    if (events == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).communityEventsRepository;
        if (r is CommunityEventsRepositoryImpl) events = r;
      } catch (_) {}
    }
    events ??=
        CommunityEventsRepositoryImpl(local, sync, remoteDataSource: remote);

    MessagesRepositoryImpl? messages = messagesRepo;
    if (messages == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).messagesRepository;
        if (r is MessagesRepositoryImpl) messages = r;
      } catch (_) {}
    }
    messages ??= MessagesRepositoryImpl(local, sync, remoteDataSource: remote);

    ExecutiveOverviewRepositoryImpl? overview = executiveOverviewRepo;
    if (overview == null && sourceOrAuth != null) {
      try {
        final r = (sourceOrAuth as dynamic).executiveOverviewRepository;
        if (r is ExecutiveOverviewRepositoryImpl) overview = r;
      } catch (_) {}
    }
    overview ??= ExecutiveOverviewRepositoryImpl(local, recitation);

    return MosqueRepositoryImpl._raw(
      authSessionRepository: auth,
      mosquesRepository: mosques,
      sheikhsRepository: sheikhs,
      halaqatRepository: halaqat,
      studentsRepository: students,
      attendanceRepository: attendance,
      recitationRepository: recitation,
      recitationTracksRepository: tracks,
      coursesRepository: courses,
      tripsRepository: trips,
      rewardsRepository: rewards,
      competitionsRepository: competitions,
      communityEventsRepository: events,
      messagesRepository: messages,
      executiveOverviewRepository: overview,
      localDataSource: local,
      remoteDataSource: remote,
    );
  }
}
