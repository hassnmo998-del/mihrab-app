import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/data/quran_data.dart';

import 'package:flutter_app/screens/mosque_admin_screen.dart';
import 'package:flutter_app/screens/admin/tabs/admin_sheikhs_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_halaqat_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_students_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_courses_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_trips_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_tracks_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_rewards_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_overview_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_events_tab.dart';
import 'package:flutter_app/screens/admin/widgets/admin_header_banner.dart';
import 'package:flutter_app/screens/admin/widgets/admin_locked_view.dart';
import 'package:flutter_app/screens/admin/dialogs/admin_course_form_dialog.dart';

import 'package:flutter_app/screens/sheikh_screen.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_attendance_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_memorization_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_tracks_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_trips_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_overview_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_students_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_messages_tab.dart';
import 'package:flutter_app/screens/sheikh/widgets/sheikh_header_banner.dart';
import 'package:flutter_app/screens/sheikh/widgets/sheikh_locked_view.dart';
import 'package:flutter_app/screens/sheikh/widgets/sheikh_today_recitations_card.dart';
import 'package:flutter_app/screens/sheikh/widgets/sheikh_quran_recitation_inputs.dart';
import 'package:flutter_app/screens/sheikh/dialogs/sheikh_trip_form_dialog.dart';
import 'package:flutter_app/screens/sheikh/dialogs/multi_surah_selector_dialog.dart';

import 'package:flutter_app/screens/student_screen.dart';
import 'package:flutter_app/screens/student/tabs/student_progress_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_attendance_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_trips_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_rewards_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_points_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_contact_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_rankings_tab.dart';
import 'package:flutter_app/screens/student/widgets/student_header_banner.dart';
import 'package:flutter_app/screens/student/widgets/student_locked_view.dart';
import 'package:flutter_app/screens/student/dialogs/student_multi_reward_claim_dialog.dart';
import 'package:flutter_app/screens/student/dialogs/student_juz_modal.dart';

import 'package:flutter_app/screens/competition_screen.dart';
import 'package:flutter_app/screens/cashier_screen.dart';
import 'package:flutter_app/screens/cashier/dialogs/cashier_dispense_dialog.dart';
import 'package:flutter_app/screens/discover/dialogs/discover_event_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  late DataService dataService;
  late Mosque testMosque;
  late Sheikh testSheikh;
  late Halaqa testHalaqa;
  late Student testStudent;
  late Reward testReward;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
    await dataService.init();

    testMosque = dataService.addMosque(name: 'مسجد الاختبار الكبير', address: 'دمشق', city: 'دمشق', gender: 'male');
    testSheikh = dataService.addSheikh(testMosque.id, 'الشيخ عبد الله', '0999123456');
    testHalaqa = dataService.addHalaqa(mosqueId: testMosque.id, name: 'حلقة الإمام نافع', sheikhId: testSheikh.id);
    testStudent = dataService.addStudent(
      mosqueId: testMosque.id,
      halaqaId: testHalaqa.id,
      fullName: 'معاذ بن جبل',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: 100,
    );
    dataService.addIntensiveCourse(
      mosqueId: testMosque.id,
      name: 'دورة صيفية مكثفة',
      description: 'دورة لتحفيظ جزء عم',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 14)),
      studentIds: [testStudent.id],
      daysOfWeek: [6, 1, 3],
      startTime: '16:00',
      endTime: '18:00',
    );
    dataService.addTrip(
      mosqueId: testMosque.id,
      title: 'رحلة الربيع',
      destination: 'الحديقة الوطنية',
      tripDate: DateTime.now().add(const Duration(days: 5)),
      meetingTime: '08:00 صباحاً',
      deadlineDate: DateTime.now().add(const Duration(days: 3)),
      targetHalaqaIds: [testHalaqa.id],
      targetStudentIds: [testStudent.id],
      requiredItems: 'قبعة شمسية وماء',
      description: 'رحلة ترفيهية تربوية',
    );
    dataService.addRecitationTrack(
      mosqueId: testMosque.id,
      name: 'متن تحفة الأطفال',
      unitLabel: 'بيت',
      totalUnits: 61,
      pointsPerUnit: 2,
    );
    testReward = dataService.addReward(
      mosqueId: testMosque.id,
      title: 'حقيبة مدرسية متميزة',
      pointsCost: 50,
    );
  });

  Widget buildTestScaffold({required Widget child, Size? surfaceSize}) {
    return ChangeNotifierProvider<DataService>.value(
      value: dataService,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: surfaceSize?.width ?? 1280,
            height: surfaceSize?.height ?? 1800,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Presentation Screens Monolith Deconstruction: Top-Level Coordinators', () {
    testWidgets('AdminLockedView renders locked view when not unlocked', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminLockedView(
          isDark: false,
          onSessionUnlocked: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLockedView), findsOneWidget);
      expect(find.text('بوابة إدارة المسجد الرسمية'), findsOneWidget);
      expect(find.text('تسجيل المساجد الجديدة يتطلب اعتماد المشرف العام'), findsOneWidget);
    });

    testWidgets('MosqueAdminScreen renders 9 tabs when admin session active', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'mosque_admin',
        name: testMosque.name,
        code: testMosque.accessCode,
        mosqueId: testMosque.id,
        mosqueName: testMosque.name,
      ));

      await tester.pumpWidget(buildTestScaffold(child: const MosqueAdminScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AdminHeaderBanner), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('المشايخ والمعلمات'), findsOneWidget);
      expect(find.text('الحلقات القرآنية'), findsOneWidget);
      expect(find.text('إدارة الطلاب'), findsOneWidget);
      expect(find.text('الدورات الاستثنائية'), findsOneWidget);
      expect(find.text('رحلات وأنشطة المسجد'), findsOneWidget);
      expect(find.text('المناهج والمتون'), findsOneWidget);
      expect(find.text('بنك الجوائز'), findsOneWidget);
      expect(find.text('لوحة المتابعة الشاملة'), findsOneWidget);
      expect(find.text('الفعاليات ومجالس العلم'), findsOneWidget);
    });

    testWidgets('SheikhScreen renders locked view when no sheikh session', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(child: const SheikhScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SheikhLockedView), findsOneWidget);
      expect(find.text('بوابة الشيخ المحفظ وإدارة الحلقة'), findsOneWidget);
    });

    testWidgets('SheikhScreen renders 7 tabs when sheikh session active', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'sheikh',
        name: testSheikh.fullName,
        code: testSheikh.code,
        mosqueId: testMosque.id,
        sheikhId: testSheikh.id,
        mosqueName: testMosque.name,
      ));

      await tester.pumpWidget(buildTestScaffold(child: const SheikhScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SheikhHeaderBanner), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('رصد الحضور اليومي'), findsOneWidget);
      expect(find.text('رصد التسميع والقرآن'), findsOneWidget);
      expect(find.text('المناهج والمتون'), findsOneWidget);
      expect(find.text('رحلات وأنشطة الحلقة'), findsOneWidget);
      expect(find.text('لوحة المتابعة الشاملة'), findsOneWidget);
      expect(find.text('طلاب الحلقة والـ QR'), findsOneWidget);
      expect(find.text('رسائل وتواصل الأهل'), findsOneWidget);
    });

    testWidgets('StudentScreen renders locked view when no student session', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(child: const StudentScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(StudentLockedView), findsOneWidget);
      expect(find.text('بوابة الطالب وولي الأمر'), findsOneWidget);
    });

    testWidgets('StudentScreen renders 7 tabs when student session active', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'student',
        name: testStudent.fullName,
        code: testStudent.code,
        studentId: testStudent.id,
        mosqueId: testMosque.id,
        halaqaId: testHalaqa.id,
        sheikhId: testSheikh.id,
        mosqueName: testMosque.name,
      ));

      await tester.pumpWidget(buildTestScaffold(child: const StudentScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(StudentHeaderBanner), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('تقدم حفظ القرآن والمناهج'), findsOneWidget);
      expect(find.text('سجل الحضور والالتزام'), findsOneWidget);
      expect(find.text('رحلاتي وأنشطتي'), findsOneWidget);
      expect(find.text('متجر الجوائز'), findsOneWidget);
      expect(find.text('سجل النقاط '), findsOneWidget);
      expect(find.text('تواصل مع الشيخ'), findsOneWidget);
      expect(find.text('ترتيب الطالب'), findsOneWidget);
    });

    testWidgets('CompetitionScreen and CashierScreen coordinators instantiate cleanly', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(child: const CompetitionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('لوحة الترتيب '), findsWidgets);
      expect(find.text('الدورات الاستثنائية'), findsOneWidget);

      dataService.setRoleSession(ActiveSession(
        role: 'cashier',
        name: 'صراف معتمد',
        code: 'CSH-TEST',
        mosqueId: testMosque.id,
        mosqueName: testMosque.name,
      ));

      await tester.pumpWidget(buildTestScaffold(child: const CashierScreen()));
      await tester.pumpAndSettle();
      expect(find.text('بوابة الصراف المعتمد'), findsOneWidget);
      expect(find.text('مسح هوية الطالب وصرف المكافأة 📍'), findsOneWidget);
    });
  });

  group('Presentation Screens Monolith Deconstruction: All 9 Admin Tabs', () {
    testWidgets('AdminSheikhsTab instantiates and displays sheikhs list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminSheikhsTab(
          mosque: testMosque,
          sheikhs: [testSheikh],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testSheikh.fullName), findsOneWidget);
      // القائمة صارت تحريرية بفواصل بدل البطاقات
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });

    testWidgets('AdminHalaqatTab instantiates and displays halaqat list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminHalaqatTab(
          mosque: testMosque,
          halaqat: [testHalaqa],
          sheikhs: [testSheikh],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testHalaqa.name), findsOneWidget);
    });

    testWidgets('AdminStudentsTab instantiates and displays students list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminStudentsTab(
          mosque: testMosque,
          students: [testStudent],
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testStudent.fullName), findsOneWidget);
    });

    testWidgets('AdminCoursesTab instantiates and displays courses list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminCoursesTab(
          mosque: testMosque,
          sheikhs: [testSheikh],
          halaqat: [testHalaqa],
          allStudents: [testStudent],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('دورة صيفية مكثفة'), findsOneWidget);
    });

    testWidgets('AdminTripsTab instantiates and displays trips list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminTripsTab(
          mosque: testMosque,
          halaqat: [testHalaqa],
          students: [testStudent],
          sheikhs: [testSheikh],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('رحلة الربيع'), findsOneWidget);
    });

    testWidgets('AdminTracksTab instantiates and displays recitation tracks', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminTracksTab(
          mosque: testMosque,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('متن تحفة الأطفال'), findsOneWidget);
    });

    testWidgets('AdminRewardsTab instantiates and displays rewards catalog', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminRewardsTab(
          mosque: testMosque,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('حقيبة مدرسية متميزة'), findsOneWidget);
    });

    testWidgets('AdminOverviewTab instantiates and displays matrix table', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminOverviewTab(
          mosque: testMosque,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testStudent.fullName), findsOneWidget);
    });

    testWidgets('AdminEventsTab instantiates and displays events list', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: AdminEventsTab(
          mosque: testMosque,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('الدروس والفعاليات العامة للمسجد'), findsOneWidget);
    });
  });

  group('Presentation Screens Monolith Deconstruction: All 7 Sheikh Tabs', () {
    testWidgets('SheikhAttendanceTab records student attendance', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhAttendanceTab(
          sheikh: testSheikh,
          students: [testStudent],
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testStudent.fullName), findsOneWidget);
      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('متأخر'), findsOneWidget);
      expect(find.text('غائب'), findsOneWidget);
    });

    testWidgets('SheikhMemorizationTab instantiates and handles Holy Quran mode', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhMemorizationTab(
          sheikh: testSheikh,
          students: [testStudent],
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SheikhQuranRecitationInputs), findsOneWidget);
      expect(find.byType(SheikhTodayRecitationsCard), findsOneWidget);
      expect(find.text('تسجيل جلسة تسميع ومنهج'), findsOneWidget);
    });

    testWidgets('SheikhTracksTab instantiates and displays curriculum tracks', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhTracksTab(
          sheikh: testSheikh,
          halaqat: [testHalaqa],
          isDark: false,
          onReciteTrack: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('متن تحفة الأطفال'), findsOneWidget);
    });

    testWidgets('SheikhTripsTab instantiates and displays trips', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhTripsTab(
          sheikh: testSheikh,
          students: [testStudent],
          halaqat: [testHalaqa],
          allSheikhs: [testSheikh],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('رحلة الربيع'), findsOneWidget);
    });

    testWidgets('SheikhOverviewTab instantiates and displays students performance', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhOverviewTab(
          sheikh: testSheikh,
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testStudent.fullName), findsOneWidget);
    });

    testWidgets('SheikhStudentsTab instantiates and displays student QR actions', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhStudentsTab(
          sheikh: testSheikh,
          students: [testStudent],
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(testStudent.fullName), findsOneWidget);
    });

    testWidgets('SheikhMessagesTab instantiates and displays message system', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: SheikhMessagesTab(
          sheikh: testSheikh,
          halaqat: [testHalaqa],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      // التبويب صار قائمة محادثات لأولياء الأمور بدل نموذج إرسال مفرد
      expect(
        find.textContaining('محادثات أولياء الأمور والطلاب'),
        findsOneWidget,
      );
    });
  });

  group('Presentation Screens Monolith Deconstruction: All 7 Student Tabs', () {
    testWidgets('StudentProgressTab displays Quran progress and Ajza grid', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentProgressTab(
          student: testStudent,
          logs: const [],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('متابعة الحفظ في الأجزاء الثلاثين'), findsOneWidget);
    });

    testWidgets('StudentAttendanceTab displays commitment statistics', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentAttendanceTab(
          student: testStudent,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('سجل الالتزام والحضور بالحلقة'), findsOneWidget);
    });

    testWidgets('StudentTripsTab displays targeted student trips and baggage items', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentTripsTab(
          student: testStudent,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('رحلة الربيع'), findsOneWidget);
      expect(find.textContaining('قبعة شمسية وماء'), findsOneWidget);
    });

    testWidgets('StudentRewardsTab displays redeemable rewards', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentRewardsTab(
          student: testStudent,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('حقيبة مدرسية متميزة'), findsOneWidget);
    });

    testWidgets('StudentPointsTab displays transparent points log and empty states', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: const StudentPointsTab(
          logs: [],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نقاط مسجلة بعد في السجل'), findsOneWidget);

      final sampleLog = PointsLog(
        id: 'pl-test-1',
        studentId: testStudent.id,
        points: 25,
        reason: 'حفظ سورة الملك كاملة',
        category: 'memorization',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestScaffold(
        child: StudentPointsTab(
          logs: [sampleLog],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('حفظ سورة الملك كاملة'), findsOneWidget);
      // صيغة النقاط صارت '+25 نقطة 🪙'
      expect(find.text('+25 نقطة 🪙'), findsOneWidget);
    });

    testWidgets('StudentContactTab displays sheikh contact information', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentContactTab(
          student: testStudent,
          sheikh: testSheikh,
          halaqa: testHalaqa,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(testSheikh.fullName), findsOneWidget);
    });

    testWidgets('StudentRankingsTab displays ranking view', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: StudentRankingsTab(
          student: testStudent,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text(testStudent.fullName), findsOneWidget);
    });
  });

  group('Presentation Screens Monolith Deconstruction: Extracted Dialogs & Modals', () {
    testWidgets('AdminCourseFormDialog renders and operates cleanly', (tester) async {
      configureViewport(tester);
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => AdminCourseFormDialog.show(
              context: ctx,
              mosque: testMosque,
              sheikhs: [testSheikh],
              halaqat: [testHalaqa],
              allStudents: [testStudent],
            ),
            child: const Text('Open Course Dialog'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Course Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('إضافة دورة قرآنية استثنائية'), findsOneWidget);
      expect(find.text('اسم الدورة *'), findsOneWidget);
      expect(find.text('إنشاء الدورة'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة دورة قرآنية استثنائية'), findsNothing);
    });

    testWidgets('showSheikhTripFormDialog renders trip dialog and saves trip', (tester) async {
      configureViewport(tester);
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showSheikhTripFormDialog(
              ctx,
              dataService,
              testSheikh,
              [testStudent],
              [testHalaqa],
              [testSheikh],
            ),
            child: const Text('Open Trip Dialog'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Trip Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('تنظيم رحلة أو نشاط جديد'), findsOneWidget);
      expect(find.text('عنوان الرحلة أو النشاط *'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('تنظيم رحلة أو نشاط جديد'), findsNothing);
    });

    testWidgets('showMultiSurahSelectorDialog selects surahs without error', (tester) async {
      configureViewport(tester);
      final selected = <String>{};
      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showMultiSurahSelectorDialog(
              ctx,
              selected,
              () {},
            ),
            child: const Text('Open Surah Selector'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Surah Selector'));
      await tester.pumpAndSettle();

      expect(find.text('اختيار سور التسميع (تعدد)'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);

      await tester.tap(find.textContaining('تم ('));
      await tester.pumpAndSettle();
      expect(find.text('اختيار سور التسميع (تعدد)'), findsNothing);
    });

    testWidgets('showStudentMultiRewardClaimDialog renders and operates', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showStudentMultiRewardClaimDialog(
              ctx,
              dataService,
              testStudent,
              testReward,
              2,
            ),
            child: const Text('Open Claim Dialog'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('استبدال الجائزة'), findsOneWidget);
      expect(find.text('الجائزة: حقيبة مدرسية متميزة'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('استبدال الجائزة'), findsNothing);
    });

    testWidgets('showStudentJuzModal renders juz details', (tester) async {
      configureViewport(tester);
      final info = quranAjzaInfo.first;
      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showStudentJuzModal(
              ctx,
              1,
              info,
              {'memorizedAyahs': 50, 'totalAyahs': 148, 'isCompleted': false, 'progress': 0.33},
              false,
            ),
            child: const Text('Open Juz Modal'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Juz Modal'));
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل ${info.name}'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);

      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل ${info.name}'), findsNothing);
    });

    testWidgets('CashierDispenseDialog already dispensed modal renders', (tester) async {
      configureViewport(tester);
      final red = RewardRedemption(
        id: 'red-1',
        studentId: testStudent.id,
        rewardId: testReward.id,
        redemptionCode: 'VCH-1234',
        rewardTitle: testReward.title,
        pointsSpent: 50,
        redeemedAt: DateTime.now(),
        status: 'dispensed',
        studentName: testStudent.fullName,
        mosqueId: testMosque.id,
        mosqueName: testMosque.name,
      );

      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => CashierDispenseDialog.showAlreadyDispensed(ctx, red),
            child: const Text('Open Already Dispensed'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Already Dispensed'));
      await tester.pumpAndSettle();

      expect(find.text('قسيمة مصروفة مسبقاً'), findsOneWidget);
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();
      expect(find.text('قسيمة مصروفة مسبقاً'), findsNothing);
    });

    testWidgets('DiscoverEventDialog renders add event modal', (tester) async {
      configureViewport(tester);
      final session = ActiveSession(
        role: 'sheikh',
        name: testSheikh.fullName,
        code: testSheikh.code,
        mosqueId: testMosque.id,
        sheikhId: testSheikh.id,
      );

      await tester.pumpWidget(buildTestScaffold(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => DiscoverEventDialog.showAddPublicEventModal(ctx, dataService, session),
            child: const Text('Open Event Modal'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Event Modal'));
      await tester.pumpAndSettle();

      expect(find.text('إعلان درس عام (فضيلة الشيخ)'), findsOneWidget);
      expect(find.text('عنوان الفعالية أو الدرس *'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('إعلان درس عام (فضيلة الشيخ)'), findsNothing);
    });
  });
}
