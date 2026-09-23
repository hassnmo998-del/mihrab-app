import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/screens/mosque_admin_screen.dart';
import 'package:flutter_app/screens/sheikh_screen.dart';
import 'package:flutter_app/screens/student_screen.dart';
import 'package:flutter_app/screens/admin/tabs/admin_sheikhs_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_halaqat_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_students_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_courses_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_trips_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_tracks_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_rewards_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_overview_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_events_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_attendance_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_memorization_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_tracks_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_trips_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_overview_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_students_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_messages_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_progress_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_attendance_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_trips_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_rewards_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_points_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_contact_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_rankings_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataService dataService;
  late Mosque testMosque;
  late Sheikh testSheikh;
  late Halaqa testHalaqa;
  late Student testStudent;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
    await dataService.init();

    testMosque = dataService.addMosque(
      name: 'مسجد الإيمان',
      city: 'الرياض',
      gender: 'male',
      address: 'حي الورود',
    );

    testSheikh = dataService.addSheikh(
      testMosque.id,
      'الشيخ أحمد',
      '0501234567',
    );

    testHalaqa = dataService.addHalaqa(
      mosqueId: testMosque.id,
      sheikhId: testSheikh.id,
      name: 'حلقة أبي بكر',
    );

    testStudent = dataService.addStudent(
      mosqueId: testMosque.id,
      halaqaId: testHalaqa.id,
      sheikhId: testSheikh.id,
      fullName: 'عبدالله محمد',
      gender: 'male',
      welcomePoints: 100,
    );
  });

  Widget wrapWithThemeAndData(Widget child) {
    return ChangeNotifierProvider<DataService>.value(
      value: dataService,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Presentation Screen Modular Tabs Forensic Tests', () {
    testWidgets('MosqueAdminScreen pumps locked view and unlocked view cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithThemeAndData(const MosqueAdminScreen()));
      await tester.pump();
      expect(find.byType(MosqueAdminScreen), findsOneWidget);

      final adminSession = ActiveSession(
        role: 'mosque_admin',
        name: 'مدير المسجد',
        code: testMosque.accessCode,
        mosqueId: testMosque.id,
        mosqueName: testMosque.name,
      );
      dataService.setRoleSession(adminSession);

      await tester.pumpWidget(wrapWithThemeAndData(MosqueAdminScreen(session: adminSession)));
      await tester.pump();
      expect(find.byType(MosqueAdminScreen), findsOneWidget);
    });

    testWidgets('SheikhScreen pumps locked view and unlocked view cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithThemeAndData(const SheikhScreen()));
      await tester.pump();
      expect(find.byType(SheikhScreen), findsOneWidget);

      final sheikhSession = ActiveSession(
        role: 'sheikh',
        name: testSheikh.fullName,
        code: testSheikh.code,
        sheikhId: testSheikh.id,
        mosqueId: testMosque.id,
        mosqueName: testMosque.name,
      );
      dataService.setRoleSession(sheikhSession);

      await tester.pumpWidget(wrapWithThemeAndData(SheikhScreen(session: sheikhSession)));
      await tester.pump();
      expect(find.byType(SheikhScreen), findsOneWidget);
    });

    testWidgets('StudentScreen pumps locked view and unlocked view cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithThemeAndData(const StudentScreen()));
      await tester.pump();
      expect(find.byType(StudentScreen), findsOneWidget);

      final studentSession = ActiveSession(
        role: 'student',
        name: testStudent.fullName,
        code: testStudent.code,
        studentId: testStudent.id,
        mosqueId: testMosque.id,
      );
      dataService.setRoleSession(studentSession);

      await tester.pumpWidget(wrapWithThemeAndData(StudentScreen(session: studentSession)));
      await tester.pump();
      expect(find.byType(StudentScreen), findsOneWidget);
    });

    testWidgets('All 9 Admin Tabs pump directly without errors', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tabs = [
        AdminSheikhsTab(mosque: testMosque, sheikhs: [testSheikh], isDark: false),
        AdminHalaqatTab(mosque: testMosque, halaqat: [testHalaqa], sheikhs: [testSheikh], isDark: false),
        AdminStudentsTab(mosque: testMosque, students: [testStudent], halaqat: [testHalaqa], isDark: false),
        AdminCoursesTab(mosque: testMosque, sheikhs: [testSheikh], halaqat: [testHalaqa], allStudents: [testStudent], isDark: false),
        AdminTripsTab(mosque: testMosque, halaqat: [testHalaqa], students: [testStudent], isDark: false),
        AdminTracksTab(mosque: testMosque, isDark: false),
        AdminRewardsTab(mosque: testMosque, isDark: false),
        AdminOverviewTab(mosque: testMosque, isDark: false),
        AdminEventsTab(mosque: testMosque, isDark: false),
      ];

      for (final tab in tabs) {
        await tester.pumpWidget(wrapWithThemeAndData(tab));
        await tester.pump();
        expect(find.byWidget(tab), findsOneWidget);
      }
    });

    testWidgets('All 7 Sheikh Tabs pump directly without errors', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tabs = [
        SheikhAttendanceTab(sheikh: testSheikh, students: [testStudent], halaqat: [testHalaqa], isDark: false),
        SheikhMemorizationTab(sheikh: testSheikh, students: [testStudent], halaqat: [testHalaqa], isDark: false),
        SheikhTracksTab(sheikh: testSheikh, halaqat: [testHalaqa], isDark: false),
        SheikhTripsTab(sheikh: testSheikh, students: [testStudent], halaqat: [testHalaqa], isDark: false),
        SheikhOverviewTab(sheikh: testSheikh, halaqat: [testHalaqa], isDark: false),
        SheikhStudentsTab(sheikh: testSheikh, students: [testStudent], halaqat: [testHalaqa], isDark: false),
        SheikhMessagesTab(sheikh: testSheikh, halaqat: [testHalaqa], isDark: false),
      ];

      for (final tab in tabs) {
        await tester.pumpWidget(wrapWithThemeAndData(tab));
        await tester.pump();
        expect(find.byWidget(tab), findsOneWidget);
      }
    });

    testWidgets('All 7 Student Tabs pump directly without errors', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tabs = [
        StudentProgressTab(student: testStudent, logs: const [], isDark: false),
        StudentAttendanceTab(student: testStudent, isDark: false),
        StudentTripsTab(student: testStudent, isDark: false),
        StudentRewardsTab(student: testStudent, isDark: false),
        const StudentPointsTab(logs: [], isDark: false),
        StudentContactTab(student: testStudent, sheikh: testSheikh, halaqa: testHalaqa, isDark: false),
        StudentRankingsTab(student: testStudent, isDark: false),
      ];

      for (final tab in tabs) {
        await tester.pumpWidget(wrapWithThemeAndData(tab));
        await tester.pump();
        expect(find.byWidget(tab), findsOneWidget);
      }
    });
  });
}
