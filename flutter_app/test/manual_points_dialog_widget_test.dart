import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/manual_points_dialog.dart';
import 'package:flutter_app/screens/admin/tabs/admin_students_tab.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_students_tab.dart';

/// Verifies the manual points mode (± buttons) is reachable and functional from
/// both the admin students page and the halaqa management (sheikh) students page.
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

    testMosque = dataService.addMosque(
      name: 'مسجد الاختبار',
      address: 'دمشق',
      city: 'دمشق',
      gender: 'male',
    );
    testSheikh = dataService.addSheikh(testMosque.id, 'الشيخ عبد الله', '0999123456');
    testHalaqa = dataService.addHalaqa(
      mosqueId: testMosque.id,
      name: 'حلقة الإمام نافع',
      sheikhId: testSheikh.id,
    );
    testStudent = dataService.addStudent(
      mosqueId: testMosque.id,
      halaqaId: testHalaqa.id,
      fullName: 'معاذ بن جبل',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: 100,
    );
  });

  Widget buildTestScaffold({required Widget child}) {
    return ChangeNotifierProvider<DataService>.value(
      value: dataService,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(width: 1280, height: 1800, child: child),
        ),
      ),
    );
  }

  int livePoints() =>
      dataService.getStudents().firstWhere((s) => s.id == testStudent.id).totalPoints;

  // ElevatedButton.icon ينتج نوعاً فرعياً خاصاً، فنبحث بالمفتاح ثم بمطابقة النوع الأساسي
  final addButtonFinder = find.byKey(const ValueKey('manualPointsAddButton'));
  final deductButtonFinder = find.byKey(const ValueKey('manualPointsDeductButton'));
  final amountFieldFinder = find.byKey(const ValueKey('manualPointsAmountField'));

  ElevatedButton resolveButton(WidgetTester tester, Finder wrapper) =>
      tester.widget<ElevatedButton>(find.descendant(
        of: wrapper,
        matching: find.byWidgetPredicate((w) => w is ElevatedButton),
      ));

  group('Manual points dialog in both students pages', () {
    testWidgets('AdminStudentsTab exposes the manual points button and applies +/-',
        (tester) async {
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

      final manualButton = find.byTooltip('وضع نقاط يدوي (إضافة / خصم)');
      expect(manualButton, findsOneWidget);

      await tester.tap(manualButton);
      await tester.pumpAndSettle();

      expect(find.byType(ManualPointsDialog), findsOneWidget);
      expect(find.text('الوضع اليدوي للنقاط'), findsOneWidget);
      expect(find.text('الرصيد: 100'), findsOneWidget);

      // الزر الزائد: إضافة المقدار الافتراضي (5)
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();
      expect(livePoints(), 105);
      expect(find.text('الرصيد: 105'), findsOneWidget);
      expect(find.byKey(const ValueKey('manualPointsStatus')), findsOneWidget);
      expect(find.textContaining('تمت إضافة 5 نقطة'), findsOneWidget);

      // الزر الناقص: خصم نفس المقدار
      await tester.tap(deductButtonFinder);
      await tester.pumpAndSettle();
      expect(livePoints(), 100);
      expect(find.text('الرصيد: 100'), findsOneWidget);
      expect(find.textContaining('تم خصم 5 نقطة'), findsOneWidget);

      // توثيق الحركتين في سجل النقاط بتصنيف manual وباسم الجهة المنفذة
      final manualLogs = dataService
          .getStudentPointsLog(testStudent.id)
          .where((l) => l.category == 'manual' && l.points.abs() == 5)
          .toList();
      expect(manualLogs.length, 2);
      expect(manualLogs.any((l) => l.points == 5), isTrue);
      expect(manualLogs.any((l) => l.points == -5), isTrue);
      expect(manualLogs.first.reason, contains(testMosque.name));

      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualPointsDialog), findsNothing);
    });

    testWidgets('SheikhStudentsTab exposes the manual points button with a preset amount',
        (tester) async {
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

      final manualButton = find.byTooltip('وضع نقاط يدوي (إضافة / خصم)');
      expect(manualButton, findsOneWidget);

      await tester.tap(manualButton);
      await tester.pumpAndSettle();

      expect(find.byType(ManualPointsDialog), findsOneWidget);

      // اختيار مقدار سريع (25) ثم الخصم
      await tester.tap(find.widgetWithText(ChoiceChip, '25'));
      await tester.pumpAndSettle();

      await tester.tap(deductButtonFinder);
      await tester.pumpAndSettle();

      expect(livePoints(), 75);
      expect(find.text('الرصيد: 75'), findsOneWidget);

      final log = dataService
          .getStudentPointsLog(testStudent.id)
          .firstWhere((l) => l.points == -25);
      expect(log.category, 'manual');
      expect(log.reason, contains(testSheikh.fullName));
    });

    testWidgets('Deduction is capped at the available balance, never negative',
        (tester) async {
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

      await tester.tap(find.byTooltip('وضع نقاط يدوي (إضافة / خصم)'));
      await tester.pumpAndSettle();

      // إدخال مقدار أكبر من الرصيد المتاح (100)
      await tester.enterText(amountFieldFinder, '400');
      await tester.pumpAndSettle();

      await tester.tap(deductButtonFinder);
      await tester.pumpAndSettle();

      expect(livePoints(), 0);
      expect(find.text('الرصيد: 0'), findsOneWidget);

      // محاولة خصم إضافية من رصيد صفري لا تُنفَّذ ولا تُسجَّل
      final logsBefore = dataService.getStudentPointsLog(testStudent.id).length;
      await tester.tap(deductButtonFinder);
      await tester.pumpAndSettle();

      expect(livePoints(), 0);
      expect(dataService.getStudentPointsLog(testStudent.id).length, logsBefore);
      expect(find.textContaining('رصيد الطالب صفر'), findsOneWidget);
    });

    testWidgets('A zero amount disables both action buttons', (tester) async {
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

      await tester.tap(find.byTooltip('وضع نقاط يدوي (إضافة / خصم)'));
      await tester.pumpAndSettle();

      await tester.enterText(amountFieldFinder, '0');
      await tester.pumpAndSettle();

      expect(resolveButton(tester, addButtonFinder).onPressed, isNull);
      expect(resolveButton(tester, deductButtonFinder).onPressed, isNull);
      expect(livePoints(), 100);
    });
  });
}
