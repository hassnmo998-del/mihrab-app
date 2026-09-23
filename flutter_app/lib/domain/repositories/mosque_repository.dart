import 'auth_session_repository.dart';
import 'mosques_repository.dart';
import 'sheikhs_repository.dart';
import 'halaqat_repository.dart';
import 'students_repository.dart';
import 'attendance_repository.dart';
import 'recitation_repository.dart';
import 'recitation_tracks_repository.dart';
import 'courses_repository.dart';
import 'trips_repository.dart';
import 'rewards_repository.dart';
import 'competitions_repository.dart';
import 'community_events_repository.dart';
import 'messages_repository.dart';
import 'executive_overview_repository.dart';

export 'auth_session_repository.dart';
export 'mosques_repository.dart';
export 'sheikhs_repository.dart';
export 'halaqat_repository.dart';
export 'students_repository.dart';
export 'attendance_repository.dart';
export 'recitation_repository.dart';
export 'recitation_tracks_repository.dart';
export 'courses_repository.dart';
export 'trips_repository.dart';
export 'rewards_repository.dart';
export 'competitions_repository.dart';
export 'community_events_repository.dart';
export 'events_repository.dart';
export 'messages_repository.dart';
export 'executive_overview_repository.dart';

/// Aggregated umbrella contract for all mosque operations.
/// Extends all modular domain repository interfaces for 100% backwards compatibility
/// with existing use cases, BLoCs, and automated tests.
abstract class MosqueRepository
    implements
        AuthSessionRepository,
        MosquesRepository,
        SheikhsRepository,
        HalaqatRepository,
        StudentsRepository,
        AttendanceRepository,
        RecitationRepository,
        RecitationTracksRepository,
        CoursesRepository,
        TripsRepository,
        RewardsRepository,
        CompetitionsRepository,
        CommunityEventsRepository,
        MessagesRepository,
        ExecutiveOverviewRepository {
  /// Remote Cloud synchronization
  Future<void> syncWithSupabase();
}
