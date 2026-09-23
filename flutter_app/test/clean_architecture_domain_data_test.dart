import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/domain/repositories/mosque_repository.dart';
import 'package:flutter_app/data/repositories/mosque_repository_impl.dart';
import 'package:flutter_app/domain/usecases/session_usecases.dart';
import 'package:flutter_app/domain/usecases/recitation_usecases.dart';
import 'package:flutter_app/domain/usecases/attendance_usecases.dart';
import 'package:flutter_app/domain/usecases/trips_usecases.dart';
import 'package:flutter_app/domain/usecases/courses_usecases.dart';
import 'package:flutter_app/domain/usecases/rewards_usecases.dart';
import 'package:flutter_app/presentation/blocs/session/session_bloc.dart';
import 'package:flutter_app/presentation/blocs/theme/theme_cubit.dart';
import 'package:flutter_app/presentation/blocs/recitation/recitation_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetInjection();
    await initInjection();
  });

  tearDown(() async {
    await resetInjection();
  });

  group('Clean Architecture DI (get_it) Tests', () {
    test('All core, data, domain usecases, and blocs are registered and resolvable', () {
      expect(sl.isRegistered<DataService>(), isTrue);
      expect(sl.isRegistered<MosqueRepository>(), isTrue);

      // Session use cases
      expect(sl.isRegistered<GetSessionsUseCase>(), isTrue);
      expect(sl.isRegistered<SetSessionUseCase>(), isTrue);
      expect(sl.isRegistered<DisconnectSessionUseCase>(), isTrue);
      expect(sl.isRegistered<VerifyAccessCodeUseCase>(), isTrue);

      // Recitation use cases
      expect(sl.isRegistered<RecordSubjectRecitationUseCase>(), isTrue);
      expect(sl.isRegistered<GetStudentProgressUseCase>(), isTrue);
      expect(sl.isRegistered<DetectTimingModeUseCase>(), isTrue);
      expect(sl.isRegistered<RecordMemorizationUseCase>(), isTrue);
      expect(sl.isRegistered<RecordRecitationBatchUseCase>(), isTrue);

      // Attendance use cases
      expect(sl.isRegistered<RecordAttendanceUseCase>(), isTrue);
      expect(sl.isRegistered<GetAttendanceSummaryUseCase>(), isTrue);

      // Trips use cases
      expect(sl.isRegistered<GetTripsUseCase>(), isTrue);
      expect(sl.isRegistered<AddTripUseCase>(), isTrue);
      expect(sl.isRegistered<UpdateTripUseCase>(), isTrue);
      expect(sl.isRegistered<DeleteTripUseCase>(), isTrue);

      // Courses use cases
      expect(sl.isRegistered<GetCoursesUseCase>(), isTrue);
      expect(sl.isRegistered<AddCourseUseCase>(), isTrue);
      expect(sl.isRegistered<UpdateCourseUseCase>(), isTrue);
      expect(sl.isRegistered<DeleteCourseUseCase>(), isTrue);

      // Rewards use cases
      expect(sl.isRegistered<GetRewardsUseCase>(), isTrue);
      expect(sl.isRegistered<RedeemRewardUseCase>(), isTrue);
      expect(sl.isRegistered<DispenseRewardUseCase>(), isTrue);

      // BLoCs
      expect(sl.isRegistered<SessionBloc>(), isTrue);
      expect(sl.isRegistered<ThemeCubit>(), isTrue);
      expect(sl.isRegistered<RecitationBloc>(), isTrue);

      // Resolving works without errors
      final repo = sl<MosqueRepository>();
      expect(repo, isA<MosqueRepositoryImpl>());
      expect(sl<SessionBloc>(), isA<SessionBloc>());
      expect(sl<ThemeCubit>(), isA<ThemeCubit>());
      expect(sl<RecitationBloc>(), isA<RecitationBloc>());
    });
  });

  group('Session Use Cases & Repository Delegation Tests', () {
    test('Set, Get, Switch, and Disconnect sessions', () async {
      final setSessionUseCase = sl<SetSessionUseCase>();
      final getSessionsUseCase = sl<GetSessionsUseCase>();
      final disconnectSessionUseCase = sl<DisconnectSessionUseCase>();

      final session = ActiveSession(
        role: 'mosque_admin',
        code: 'MSQ-1234',
        name: 'مدير المسجد',
        mosqueId: 'm-1',
        mosqueName: 'جامع الإيمان',
      );

      setSessionUseCase(session);

      expect(getSessionsUseCase.currentSession?.code, equals('MSQ-1234'));
      expect(getSessionsUseCase().any((s) => s.code == 'MSQ-1234'), isTrue);
      expect(getSessionsUseCase.hasRole('mosque_admin'), isTrue);
      expect(getSessionsUseCase.getSessionForRole('mosque_admin')?.name, equals('مدير المسجد'));

      disconnectSessionUseCase('mosque_admin');
      expect(getSessionsUseCase.hasRole('mosque_admin'), isFalse);
    });
  });

  group('Recitation & Timing Use Cases Tests', () {
    test('Record subject recitation, get progress, and detect timing mode', () async {
      final repo = sl<MosqueRepository>();
      final recordRecitation = sl<RecordSubjectRecitationUseCase>();
      final getProgress = sl<GetStudentProgressUseCase>();
      final detectTiming = sl<DetectTimingModeUseCase>();

      final mosque = repo.addMosque(name: 'مسجد الفاروق', address: 'دمشق', city: 'دمشق', gender: 'male');
      final halaqa = repo.addHalaqa(
        mosqueId: mosque.id,
        name: 'حلقة الحديث',
        daysOfWeek: [1, 3],
        timingType: 'custom_time',
        customTime: '18:00',
      );
      final student = repo.addStudent(
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        fullName: 'أنس بن مالك',
        gender: 'male',
        phone: '0500000000',
      );

      final track = repo.addRecitationTrack(
        mosqueId: mosque.id,
        name: 'عمدة الأحكام',
        totalUnits: 50,
      );

      // Record recitation
      final record = recordRecitation(
        studentId: student.id,
        trackId: track.id,
        trackName: track.name,
        fromUnit: 1,
        toUnit: 10,
        pointsEarned: 20,
      );

      expect(record.unitsCount, equals(10));
      expect(record.pointsEarned, equals(20));

      final progress = getProgress(student.id, trackId: track.id);
      expect(progress['uniqueUnitsCount'], equals(10));
      expect(progress['totalUnits'], equals(50));
      expect(progress['progress'], closeTo(0.2, 0.01));

      // Smart timing detection
      final now = DateTime.now();
      DateTime monDate = now;
      while (monDate.weekday != 1) {
        monDate = monDate.add(const Duration(days: 1));
      }
      final testTime = DateTime(monDate.year, monDate.month, monDate.day, 18, 10);
      final timing = detectTiming(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: testTime,
      );
      expect(timing['mode'], equals('normal'));
    });
  });

  group('Attendance Use Cases Tests', () {
    test('Record attendance and retrieve attendance summary', () {
      final repo = sl<MosqueRepository>();
      final recordAttendance = sl<RecordAttendanceUseCase>();
      final getAttendanceSummary = sl<GetAttendanceSummaryUseCase>();

      final mosque = repo.addMosque(name: 'جامع الصالحين', address: 'دمشق', city: 'دمشق', gender: 'male');
      final halaqa = repo.addHalaqa(mosqueId: mosque.id, name: 'حلقة النور');
      final student = repo.addStudent(mosqueId: mosque.id, halaqaId: halaqa.id, fullName: 'سلمان', gender: 'male', phone: '0500000000');

      recordAttendance(
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionDate: '2026-09-12',
        status: 'present',
        pointsEarned: 10,
      );

      final summary = getAttendanceSummary(student.id);
      expect(summary['total'], equals(1));
      expect(summary['present'], equals(1));
      expect(summary['attendanceRate'], equals('100.0'));
    });
  });

  group('Trips Use Cases Tests', () {
    test('Add, Get, Update, and Delete trips', () {
      final repo = sl<MosqueRepository>();
      final addTrip = sl<AddTripUseCase>();
      final getTrips = sl<GetTripsUseCase>();
      final updateTrip = sl<UpdateTripUseCase>();
      final deleteTrip = sl<DeleteTripUseCase>();

      final mosque = repo.addMosque(name: 'جامع الإيمان', address: 'دمشق', city: 'دمشق', gender: 'male');

      final trip = addTrip(
        mosqueId: mosque.id,
        title: 'رحلة جبل قاسيون',
        destination: 'قاسيون',
        tripDate: DateTime.now().add(const Duration(days: 7)),
      );

      var trips = getTrips(mosqueId: mosque.id);
      expect(trips.length, equals(1));
      expect(trips.first.title, equals('رحلة جبل قاسيون'));

      final updated = trip.copyWith(title: 'رحلة قاسيون الثقافية');
      updateTrip(updated);
      trips = getTrips(mosqueId: mosque.id);
      expect(trips.first.title, equals('رحلة قاسيون الثقافية'));

      deleteTrip(trip.id);
      trips = getTrips(mosqueId: mosque.id);
      expect(trips.isEmpty, isTrue);
    });
  });

  group('Courses Use Cases Tests', () {
    test('Add, Get, Update, and Delete intensive courses', () {
      final repo = sl<MosqueRepository>();
      final addCourse = sl<AddCourseUseCase>();
      final getCourses = sl<GetCoursesUseCase>();
      final updateCourse = sl<UpdateCourseUseCase>();
      final deleteCourse = sl<DeleteCourseUseCase>();

      final mosque = repo.addMosque(name: 'جامع الهدى', address: 'دمشق', city: 'دمشق', gender: 'male');
      final now = DateTime.now();

      final course = addCourse(
        mosqueId: mosque.id,
        name: 'دورة حفظ سورة البقرة',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );

      var courses = getCourses(mosqueId: mosque.id);
      expect(courses.length, equals(1));
      expect(courses.first.name, equals('دورة حفظ سورة البقرة'));

      final updated = course.copyWith(name: 'دورة إتقان سورة البقرة');
      updateCourse(updated);
      courses = getCourses(mosqueId: mosque.id);
      expect(courses.first.name, equals('دورة إتقان سورة البقرة'));

      deleteCourse(course.id);
      courses = getCourses(mosqueId: mosque.id);
      expect(courses.isEmpty, isTrue);
    });
  });

  group('Rewards Use Cases Tests', () {
    test('Add, Get, Redeem, and Dispense rewards', () {
      final repo = sl<MosqueRepository>();
      final getRewards = sl<GetRewardsUseCase>();
      final redeemReward = sl<RedeemRewardUseCase>();
      final dispenseReward = sl<DispenseRewardUseCase>();

      final mosque = repo.addMosque(name: 'جامع النصر', address: 'دمشق', city: 'دمشق', gender: 'male');
      final halaqa = repo.addHalaqa(mosqueId: mosque.id, name: 'حلقة التميز');
      final student = repo.addStudent(
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        fullName: 'حمزة بن عبد المطلب',
        gender: 'male',
        phone: '0500000000',
        welcomePoints: 100,
      );

      final reward = repo.addReward(
        mosqueId: mosque.id,
        title: 'قلم فاخر',
        pointsCost: 60,
      );

      final rewards = getRewards(mosqueId: mosque.id);
      expect(rewards.length, equals(1));

      final redemption = redeemReward(
        studentId: student.id,
        rewardId: reward.id,
      );
      expect(redemption, isNotNull);
      expect(redemption!.status, equals('pending'));

      final result = dispenseReward(
        voucherCode: redemption.redemptionCode,
        cashierName: 'أمين المستودع',
      );
      expect(result['success'], isTrue);
      expect(result['remainingPoints'], equals(40));
    });
  });
}
