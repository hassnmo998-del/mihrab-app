import 'package:get_it/get_it.dart';

import '../../data/repositories/mosque_repository_impl.dart';
import '../../domain/repositories/mosque_repository.dart';
import '../../domain/usecases/attendance_usecases.dart';
import '../../domain/usecases/courses_usecases.dart';
import '../../domain/usecases/recitation_usecases.dart';
import '../../domain/usecases/rewards_usecases.dart';
import '../../domain/usecases/session_usecases.dart';
import '../../domain/usecases/trips_usecases.dart';
import '../../presentation/blocs/attendance/attendance_bloc.dart';
import '../../presentation/blocs/competitions/competitions_bloc.dart';
import '../../presentation/blocs/courses/courses_bloc.dart';
import '../../presentation/blocs/recitation/recitation_bloc.dart';
import '../../presentation/blocs/rewards/rewards_bloc.dart';
import '../../presentation/blocs/session/session_bloc.dart';
import '../../presentation/blocs/theme/theme_cubit.dart';
import '../../presentation/blocs/trips/trips_bloc.dart';
import '../../services/data_service.dart';

/// Global Service Locator instance
final GetIt sl = GetIt.instance;

/// Initializes GetIt dependency injection and registers all dependencies
/// across Core, Data, Domain, and Presentation layers.
Future<void> initInjection() async {
  if (sl.isRegistered<DataService>()) {
    return; // Already initialized
  }

  // ==========================================
  // Core & Data Services
  // ==========================================
  final dataService = DataService();
  sl.registerLazySingleton<DataService>(() => dataService);

  // ==========================================
  // Repositories
  // ==========================================
  sl.registerLazySingleton<MosqueRepository>(
    () => MosqueRepositoryImpl(sl<DataService>()),
  );

  // ==========================================
  // Use Cases: Sessions & Auth
  // ==========================================
  sl.registerLazySingleton<GetSessionsUseCase>(
    () => GetSessionsUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<SetSessionUseCase>(
    () => SetSessionUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<DisconnectSessionUseCase>(
    () => DisconnectSessionUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<VerifyAccessCodeUseCase>(
    () => VerifyAccessCodeUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Use Cases: Recitation & Quran Memorization
  // ==========================================
  sl.registerLazySingleton<RecordSubjectRecitationUseCase>(
    () => RecordSubjectRecitationUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<GetStudentProgressUseCase>(
    () => GetStudentProgressUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<DetectTimingModeUseCase>(
    () => DetectTimingModeUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<RecordMemorizationUseCase>(
    () => RecordMemorizationUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<RecordRecitationBatchUseCase>(
    () => RecordRecitationBatchUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Use Cases: Attendance
  // ==========================================
  sl.registerLazySingleton<RecordAttendanceUseCase>(
    () => RecordAttendanceUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<GetAttendanceSummaryUseCase>(
    () => GetAttendanceSummaryUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Use Cases: Trips & Outings
  // ==========================================
  sl.registerLazySingleton<GetTripsUseCase>(
    () => GetTripsUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<AddTripUseCase>(
    () => AddTripUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<UpdateTripUseCase>(
    () => UpdateTripUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<DeleteTripUseCase>(
    () => DeleteTripUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Use Cases: Intensive Courses
  // ==========================================
  sl.registerLazySingleton<GetCoursesUseCase>(
    () => GetCoursesUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<AddCourseUseCase>(
    () => AddCourseUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<UpdateCourseUseCase>(
    () => UpdateCourseUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<DeleteCourseUseCase>(
    () => DeleteCourseUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Use Cases: Rewards & Cashier
  // ==========================================
  sl.registerLazySingleton<GetRewardsUseCase>(
    () => GetRewardsUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<RedeemRewardUseCase>(
    () => RedeemRewardUseCase(sl<MosqueRepository>()),
  );
  sl.registerLazySingleton<DispenseRewardUseCase>(
    () => DispenseRewardUseCase(sl<MosqueRepository>()),
  );

  // ==========================================
  // Presentation: BLoCs & Cubits (Factory for state lifecycle)
  // ==========================================
  sl.registerFactory<SessionBloc>(
    () => SessionBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<ThemeCubit>(
    () => ThemeCubit(dataService: sl<DataService>()),
  );
  sl.registerFactory<RecitationBloc>(
    () => RecitationBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<AttendanceBloc>(
    () => AttendanceBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<CoursesBloc>(
    () => CoursesBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<RewardsBloc>(
    () => RewardsBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<TripsBloc>(
    () => TripsBloc(dataService: sl<DataService>()),
  );
  sl.registerFactory<CompetitionsBloc>(
    () => CompetitionsBloc(dataService: sl<DataService>()),
  );
}

/// Helper method to reset injection container (useful for testing)
Future<void> resetInjection() async {
  await sl.reset();
}
