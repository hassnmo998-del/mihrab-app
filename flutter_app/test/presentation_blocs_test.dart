import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/presentation/blocs/blocs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataService dataService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
    await dataService.init();

    for (final s in List.from(dataService.savedSessions)) {
      dataService.disconnectRole(s.role);
    }
    dataService.clearSession();

    // Seed mock mosque, sheikh, halaqa, student
    final mosque = dataService.addMosque(
      name: 'جامع النور',
      address: 'الميدان',
      city: 'دمشق',
      gender: 'male',
    );

    final sheikh = dataService.addSheikh(mosque.id, 'الشيخ أحمد', '0999111222');

    final halaqa = dataService.addHalaqa(
      mosqueId: mosque.id,
      sheikhId: sheikh.id,
      name: 'حلقة الإتقان',
      schedule: 'السبت - الإثنين - الأربعاء (عصراً)',
      daysOfWeek: [6, 1, 3],
      timingType: 'prayer_linked',
      prayerName: 'asr',
    );

    dataService.addStudent(
      mosqueId: mosque.id,
      halaqaId: halaqa.id,
      sheikhId: sheikh.id,
      fullName: 'عمر الفاروق',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: 50,
    );
  });

  group('SessionBloc Tests', () {
    test('Initial state reflects visitor if no session active', () async {
      final bloc = SessionBloc(dataService: dataService);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.isVisitor, isTrue);
      expect(bloc.state.role, equals('visitor'));
      expect(bloc.state.savedSessions, isEmpty);
    });

    test('Verify valid mosque code unlocks admin session and saves it', () async {
      final bloc = SessionBloc(dataService: dataService);
      final mosque = dataService.getMosques().first;

      bloc.add(VerifyAccessCodeEvent(mosque.accessCode));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.isAdmin, isTrue);
      expect(bloc.state.activeMosqueId, equals(mosque.id));
      expect(bloc.state.savedSessions.length, equals(1));
    });

    test('Multi-role session switching without auto-logout', () async {
      final bloc = SessionBloc(dataService: dataService);
      final mosque = dataService.getMosques().first;
      final student = dataService.getStudents().first;

      // 1. Authenticate admin
      bloc.add(VerifyAccessCodeEvent(mosque.accessCode));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.isAdmin, isTrue);

      // 2. Authenticate student
      bloc.add(VerifyAccessCodeEvent(student.code));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.isStudent, isTrue);

      // Both sessions must be preserved on device without auto-logout!
      expect(bloc.state.hasMultipleRoles, isTrue);
      expect(bloc.state.savedSessions.length, equals(2));

      // 3. Switch back to admin without re-entering code
      final adminSession = bloc.state.getSessionForRole('mosque_admin')!;
      bloc.add(SwitchSessionEvent(adminSession));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isAdmin, isTrue);

      // 4. Disconnect student role only
      bloc.add(const DisconnectRoleEvent('student'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isAdmin, isTrue); // admin session remains active
      expect(bloc.state.savedSessions.length, equals(1));
    });
  });

  group('RecitationBloc & Smart Timing Tests', () {
    test('Records Quran recitation, calculates progress and updates points', () async {
      final bloc = RecitationBloc(dataService: dataService);
      final student = dataService.getStudents().first;

      bloc.add(LoadStudentRecitationEvent(studentId: student.id));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.memorizedAyahsCount, equals(0));

      // Record Surah Al-Fatihah (1-7)
      bloc.add(RecordQuranRecitationEvent(
        studentId: student.id,
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'new_memorization',
        points: 20,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.memorizedAyahsCount, equals(7));
      expect(student.totalPoints, equals(70)); // 50 welcome + 20 recitation
    });

    test('Smart timing detection identifies course, halaqa, and custom timing', () async {
      final bloc = RecitationBloc(dataService: dataService);
      final halaqa = dataService.getHalaqat().first;
      final student = dataService.getStudents().first;

      // Regular halaqa: prayer 'asr' -> ~16:00 on Saturday (weekday 6)
      // Sat 2026-09-12 at 16:15 (within ±30m)
      final duringSession = DateTime(2026, 9, 12, 16, 15);
      bloc.add(DetectRecitationTimingEvent(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: duringSession,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.timingMode, equals('normal'));
      expect(bloc.state.isScheduledTiming, isTrue);

      // Outside regular session (e.g. at 23:00)
      final outsideSession = DateTime(2026, 9, 12, 23, 0);
      bloc.add(DetectRecitationTimingEvent(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: outsideSession,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.timingMode, equals('custom'));
    });
  });

  group('TripsBloc Tests', () {
    test('Adds trip with baggage requirements (🎒) and filters target students', () async {
      final bloc = TripsBloc(dataService: dataService);
      final mosque = dataService.getMosques().first;
      final student = dataService.getStudents().first;

      bloc.add(AddTripEvent(
        mosqueId: mosque.id,
        title: 'رحلة الربيع القرآنية',
        destination: 'حديقة تشرين',
        tripDate: DateTime.now().add(const Duration(days: 7)),
        meetingTime: '08:30 صباحاً',
        requiredItems: '🎒 حقيبة ظهر، مصحف، وجبة خفيفة ومطرة ماء',
        targetStudentIds: [student.id],
        costPoints: 15,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.allTrips.length, equals(1));
      expect(bloc.state.allTrips.first.requiredItems, contains('🎒'));

      // Filter by student
      bloc.add(FilterTripsEvent(studentId: student.id));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.filteredTrips.length, equals(1));
    });
  });

  group('CoursesBloc Tests', () {
    test('Manages courses, enrollments, schedule check, and Quran counting toggle', () async {
      final bloc = CoursesBloc(dataService: dataService);
      final mosque = dataService.getMosques().first;
      final student = dataService.getStudents().first;

      bloc.add(AddCourseEvent(
        mosqueId: mosque.id,
        name: 'دورة النخبة المكثفة',
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        daysOfWeek: [DateTime.now().weekday],
        startTime: '10:00',
        endTime: '12:00',
        studentIds: [student.id],
        countsTowardsQuranProgress: true,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.courses.length, equals(1));
      final course = bloc.state.courses.first;
      expect(course.countsTowardsQuranProgress, isTrue);

      // Toggle Quran progress counting
      bloc.add(ToggleCourseQuranCountingEvent(
        courseId: course.id,
        countsTowardsQuranProgress: false,
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectedCourse?.countsTowardsQuranProgress, isFalse);
    });
  });

  group('AttendanceBloc Tests', () {
    test('Records student attendance and computes halaqa statistics', () async {
      final bloc = AttendanceBloc(dataService: dataService);
      final halaqa = dataService.getHalaqat().first;
      final student = dataService.getStudents().first;

      bloc.add(MarkStudentAttendanceEvent(
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionDate: '2026-09-12',
        status: 'present',
        pointsEarned: 5,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.records.length, equals(1));
      expect(bloc.state.presentCount, equals(1));
      expect(bloc.state.attendancePercentage, equals(100.0));

      // Student summary
      bloc.add(LoadStudentAttendanceSummaryEvent(student.id));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.studentPresentCount, equals(1));
      expect(bloc.state.studentAttendanceRate, equals('100.0'));
    });
  });

  group('ThemeCubit Tests', () {
    test('Toggles light and dark theme mode', () async {
      final cubit = ThemeCubit(dataService: dataService);

      expect(cubit.state.isDark, isFalse);
      expect(cubit.state.themeMode, equals(ThemeMode.light));

      cubit.toggleTheme();
      expect(cubit.state.isDark, isTrue);
      expect(cubit.state.themeMode, equals(ThemeMode.dark));

      cubit.toggleTheme();
      expect(cubit.state.isDark, isFalse);
    });
  });
}
