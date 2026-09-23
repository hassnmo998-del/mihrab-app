import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/qr_dialogs.dart';

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
import 'package:flutter_app/screens/admin/tabs/admin_design_studio_tab.dart';
import 'package:flutter_app/screens/admin/tabs/admin_messages_tab.dart';

import 'package:flutter_app/screens/sheikh_screen.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_attendance_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_memorization_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_tracks_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_trips_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_overview_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_students_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_messages_tab.dart';

import 'package:flutter_app/screens/student_screen.dart';
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
  late Mosque mosque;
  late Sheikh sheikh;
  late Halaqa halaqa1;
  late Halaqa halaqa2;
  late Student student1;
  late Student student2;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
    await dataService.init();

    mosque = dataService.addMosque(
      name: 'جامع بني أمية الكبير',
      address: 'دمشق القديمة',
      city: 'دمشق',
      gender: 'male',
    );
    sheikh = dataService.addSheikh(mosque.id, 'الشيخ نور الدين', '0999000111');
    halaqa1 = dataService.addHalaqa(mosqueId: mosque.id, name: 'حلقة الإمام الشاطبي', sheikhId: sheikh.id);
    halaqa2 = dataService.addHalaqa(mosqueId: mosque.id, name: 'حلقة الإمام الجزري', sheikhId: sheikh.id);

    student1 = dataService.addStudent(
      mosqueId: mosque.id,
      halaqaId: halaqa1.id,
      sheikhId: sheikh.id,
      fullName: 'أنس بن مالك',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: 120,
    );
    student2 = dataService.addStudent(
      mosqueId: mosque.id,
      halaqaId: halaqa2.id,
      sheikhId: sheikh.id,
      fullName: 'بلال بن رباح',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: 80,
    );

    dataService.addRecitationTrack(
      mosqueId: mosque.id,
      name: 'الأربعون النووية',
      category: 'hadith',
      unitLabel: 'حديث',
      totalUnits: 42,
      pointsPerUnit: 3,
      sheikhId: sheikh.id,
    );

    dataService.addReward(
      mosqueId: mosque.id,
      title: 'مصحف مذهب فاخر',
      description: 'طبعة مجمع الملك فهد',
      pointsCost: 50,
    );
  });

  Widget buildApp(Widget child, {Size surfaceSize = const Size(1280, 1600)}) {
    return ChangeNotifierProvider<DataService>.value(
      value: dataService,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// شريط التبويبات قابل للتمرير أفقياً، والتبويب البعيد قد لا يكون مرئياً ولا
  /// قابلاً للضغط. نتحقق أولاً أن العنوان موجود فعلاً في الشريط ثم ننتقل إليه
  /// عبر متحكّم التبويبات — نفس ما يفعله الضغط، لكن بلا اعتماد على موضع التمرير.
  Future<void> tapTab(WidgetTester tester, String label) async {
    // شريط التبويبات داخل NestedScrollView قد يخرج من الشجرة بعد التمرير داخل
    // محتوى التبويب، فنعيده للأعلى قبل البحث عنه.
    if (find.byType(TabBar).evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, 800));
        await tester.pumpAndSettle();
      }
    }
    final tabBar = tester.widgetList<TabBar>(find.byType(TabBar)).first;
    final index =
        tabBar.tabs.indexWhere((t) => t is Tab && t.text == label);
    expect(index, greaterThanOrEqualTo(0),
        reason: 'لا يوجد تبويب بعنوان: $label');
    tabBar.controller!.animateTo(index);
    await tester.pumpAndSettle();
  }

  /// ضغط عنصر داخل محتوى التبويب (زر أو بطاقة) لا عنصر في شريط التبويبات.
  Future<void> tapInBody(WidgetTester tester, String label) async {
    final target = find.text(label).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('Adversarial Tab Controller Stress Tests across Coordinators', () {
    testWidgets('MosqueAdminScreen switches across all 11 tabs without error', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'mosque_admin',
        name: mosque.name,
        code: mosque.accessCode,
        mosqueId: mosque.id,
        mosqueName: mosque.name,
      ));

      await tester.pumpWidget(buildApp(const MosqueAdminScreen()));
      await tester.pumpAndSettle();

      // Tab 0: Sheikhs
      expect(find.byType(AdminSheikhsTab), findsOneWidget);

      // Tap Tab 1: Halaqat
      await tapTab(tester, 'الحلقات القرآنية');
      expect(find.byType(AdminHalaqatTab), findsOneWidget);

      // Tap Tab 2: Students
      await tapTab(tester, 'إدارة الطلاب');
      expect(find.byType(AdminStudentsTab), findsOneWidget);

      // Tap Tab 3: Courses
      await tapTab(tester, 'الدورات الاستثنائية');
      expect(find.byType(AdminCoursesTab), findsOneWidget);

      // Tap Tab 4: Trips
      await tapTab(tester, 'رحلات وأنشطة المسجد');
      expect(find.byType(AdminTripsTab), findsOneWidget);

      // Tap Tab 5: Tracks
      await tapTab(tester, 'المناهج والمتون');
      expect(find.byType(AdminTracksTab), findsOneWidget);

      // Tap Tab 6: Rewards
      await tapTab(tester, 'بنك الجوائز');
      expect(find.byType(AdminRewardsTab), findsOneWidget);

      // Tap Tab 7: Overview
      await tapTab(tester, 'لوحة المتابعة الشاملة');
      expect(find.byType(AdminOverviewTab), findsOneWidget);

      // Tap Tab 8: Events
      await tapTab(tester, 'الفعاليات ومجالس العلم');
      expect(find.byType(AdminEventsTab), findsOneWidget);

      // Tap Tab 9: Messages
      await tapTab(tester, 'رسائل وتواصل الطلاب');
      expect(find.byType(AdminMessagesTab), findsOneWidget);

      // Tap Tab 10: Design Studio
      await tapTab(tester, 'مركز التصاميم والطباعة');
      expect(find.byType(AdminDesignStudioTab), findsOneWidget);
    });

    testWidgets('SheikhScreen switches across all 7 tabs and onReciteTrack navigates to tab 1', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'sheikh',
        name: sheikh.fullName,
        code: sheikh.code,
        mosqueId: mosque.id,
        sheikhId: sheikh.id,
        mosqueName: mosque.name,
      ));

      await tester.pumpWidget(buildApp(const SheikhScreen()));
      await tester.pumpAndSettle();

      // Tab 0: Attendance
      expect(find.byType(SheikhAttendanceTab), findsOneWidget);

      // Tab 1: Memorization
      await tapTab(tester, 'رصد التسميع والقرآن');
      expect(find.byType(SheikhMemorizationTab), findsOneWidget);

      // Tab 2: Tracks
      await tapTab(tester, 'المناهج والمتون');
      expect(find.byType(SheikhTracksTab), findsOneWidget);

      // Test onReciteTrack in SheikhTracksTab switches to Tab 1 (Memorization)
      expect(find.text('رصد تسميع'), findsOneWidget);
      await tapInBody(tester, 'رصد تسميع');
      expect(find.byType(SheikhMemorizationTab), findsOneWidget);

      // Tab 3: Trips
      await tapTab(tester, 'رحلات وأنشطة الحلقة');
      expect(find.byType(SheikhTripsTab), findsOneWidget);

      // Tab 4: Overview
      await tapTab(tester, 'لوحة المتابعة الشاملة');
      expect(find.byType(SheikhOverviewTab), findsOneWidget);

      // Tab 5: Students
      await tapTab(tester, 'طلاب الحلقة والـ QR');
      expect(find.byType(SheikhStudentsTab), findsOneWidget);

      // Tab 6: Messages
      await tapTab(tester, 'رسائل وتواصل الأهل');
      expect(find.byType(SheikhMessagesTab), findsOneWidget);
    });

    testWidgets('StudentScreen switches across all 7 tabs cleanly', (tester) async {
      configureViewport(tester);
      dataService.setRoleSession(ActiveSession(
        role: 'student',
        name: student1.fullName,
        code: student1.code,
        studentId: student1.id,
        mosqueId: mosque.id,
        halaqaId: halaqa1.id,
        sheikhId: sheikh.id,
        mosqueName: mosque.name,
      ));

      await tester.pumpWidget(buildApp(const StudentScreen()));
      await tester.pumpAndSettle();

      // Tab 0: Progress
      expect(find.byType(StudentProgressTab), findsOneWidget);

      // Tab 1: Attendance
      await tapTab(tester, 'سجل الحضور والالتزام');
      expect(find.byType(StudentAttendanceTab), findsOneWidget);

      // Tab 2: Trips
      await tapTab(tester, 'رحلاتي وأنشطتي');
      expect(find.byType(StudentTripsTab), findsOneWidget);

      // Tab 3: Rewards
      await tapTab(tester, 'متجر الجوائز');
      expect(find.byType(StudentRewardsTab), findsOneWidget);

      // Tab 4: Points
      await tapTab(tester, 'سجل النقاط ');
      expect(find.byType(StudentPointsTab), findsOneWidget);

      // Tab 5: Contact
      await tapTab(tester, 'تواصل مع الشيخ');
      expect(find.byType(StudentContactTab), findsOneWidget);

      // Tab 6: Rankings
      await tapTab(tester, 'ترتيب الطالب');
      expect(find.byType(StudentRankingsTab), findsOneWidget);
    });
  });

  group('Adversarial Filter & Search Verification', () {
    testWidgets('AdminStudentsTab search query and halaqa dropdown filter correctly', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildApp(
        AdminStudentsTab(
          mosque: mosque,
          students: [student1, student2],
          halaqat: [halaqa1, halaqa2],
        ),
      ));
      await tester.pumpAndSettle();

      // Initially both students are present
      expect(find.text('أنس بن مالك'), findsOneWidget);
      expect(find.text('بلال بن رباح'), findsOneWidget);

      // Search by partial name: "أنس"
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'أنس');
      await tester.pumpAndSettle();

      expect(find.text('أنس بن مالك'), findsOneWidget);
      expect(find.text('بلال بن رباح'), findsNothing);

      // Search non-existent name: "عمر" -> empty state message
      await tester.enterText(searchField, 'عمر');
      await tester.pumpAndSettle();

      expect(find.text('أنس بن مالك'), findsNothing);
      expect(find.text('بلال بن رباح'), findsNothing);
      expect(find.text('لم يتم العثور على طلاب مطابقين للمعايير'), findsOneWidget);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('أنس بن مالك'), findsOneWidget);
      expect(find.text('بلال بن رباح'), findsOneWidget);

      // Dropdown filter: Select halaqa2 (حلقة الإمام الجزري)
      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('حلقة الإمام الجزري').last);
      await tester.pumpAndSettle();

      expect(find.text('بلال بن رباح'), findsOneWidget);
      expect(find.text('أنس بن مالك'), findsNothing);
    });

    testWidgets('AdminOverviewTab and SheikhOverviewTab search and filters function properly', (tester) async {
      configureViewport(tester);
      // Test AdminOverviewTab
      await tester.pumpWidget(buildApp(
        AdminOverviewTab(mosque: mosque),
      ));
      await tester.pumpAndSettle();

      expect(find.text('أنس بن مالك'), findsOneWidget);
      expect(find.text('بلال بن رباح'), findsOneWidget);

      // Search for Bilal
      final overviewSearch = find.byType(TextField).first;
      await tester.enterText(overviewSearch, 'بلال');
      await tester.pumpAndSettle();

      expect(find.text('بلال بن رباح'), findsOneWidget);
      expect(find.text('أنس بن مالك'), findsNothing);

      // Test SheikhOverviewTab
      await tester.pumpWidget(buildApp(
        SheikhOverviewTab(
          sheikh: sheikh,
          halaqat: [halaqa1, halaqa2],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('أنس بن مالك'), findsOneWidget);
      expect(find.text('بلال بن رباح'), findsOneWidget);
    });
  });

  group('Cross-Screen State Management & Live Reactivity Tests', () {
    testWidgets('Attendance marked by sheikh updates student attendance summary and overview live', (tester) async {
      configureViewport(tester);
      // 1. Mark attendance in SheikhAttendanceTab
      await tester.pumpWidget(buildApp(
        SheikhAttendanceTab(
          sheikh: sheikh,
          students: [student1],
          halaqat: [halaqa1],
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Click "حاضر" for student1
      await tester.tap(find.widgetWithText(ElevatedButton, 'حاضر'));
      await tester.pumpAndSettle();

      // 2. Verify in StudentAttendanceTab
      await tester.pumpWidget(buildApp(
        StudentAttendanceTab(student: student1, isDark: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('100.0% نسبة الالتزام'), findsOneWidget);
      // الحالة تظهر في عنوان اليوم وفي شريط الحالة معاً
      expect(find.text('حاضر ✅'), findsWidgets);
    });

    testWidgets(
        'Student reward QR leads to cashier direct sale that deducts points',
        (tester) async {
      configureViewport(tester);
      // Set student session
      dataService.setRoleSession(ActiveSession(
        role: 'student',
        name: student1.fullName,
        code: student1.code,
        studentId: student1.id,
        mosqueId: mosque.id,
        halaqaId: halaqa1.id,
        sheikhId: sheikh.id,
        mosqueName: mosque.name,
      ));

      // 1. Open StudentRewardsTab
      await tester.pumpWidget(buildApp(
        StudentRewardsTab(student: student1, isDark: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('120 نقطة'), findsOneWidget);
      expect(find.text('مصحف مذهب فاخر'), findsOneWidget);

      // الطالب يعرض رمز الجائزة للصراف (لم تُخصم نقاط بعد)
      await tester.tap(find.text('استبدال الجائزة'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentRedemptionQrDialog), findsOneWidget);

      expect(
        dataService.getStudents().firstWhere((s) => s.id == student1.id).totalPoints,
        120,
      );
      expect(dataService.getRedemptions(studentId: student1.id), isEmpty);

      await tester.tap(find.text('إغلاق').first);
      await tester.pumpAndSettle();

      // 2. الصراف يصرف الجائزة مباشرة بعد مسح رمز الطالب
      final reward = dataService
          .getRewards(mosqueId: mosque.id)
          .firstWhere((r) => r.title == 'مصحف مذهب فاخر');
      final res = dataService.sellReward(
        studentId: student1.id,
        rewardId: reward.id,
        cashierName: 'صراف المسجد',
      );
      expect(res['success'], true);

      final dispensed = dataService.getRedemptions(studentId: student1.id);
      expect(dispensed.length, 1);
      expect(dispensed.first.status, 'dispensed');
      expect(dispensed.first.pointsSpent, 50);

      // 3. النقاط تُخصم عند التسليم: 120 - 50 = 70
      final after =
          dataService.getStudents().firstWhere((s) => s.id == student1.id);
      expect(after.totalPoints, 70);

      // وتظهر في سجل النقاط كعملية صرف
      final logs = dataService.getStudentPointsLog(student1.id);
      expect(logs.any((l) => l.points == -50 && l.category == 'reward'), true);
    });
  });
}
