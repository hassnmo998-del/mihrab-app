import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/cashier/cashier_records_screen.dart';
import 'package:flutter_app/screens/cashier/widgets/cashier_history_section.dart';
import 'package:flutter_app/screens/cashier_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';

/// شاشة الصراف الأولى للصرف وحده: عدد الجوامع، المسح أو كتابة الكود، إضافة جامع.
/// السجلات والفلاتر في شاشة داخلية، والفلاتر خلف زر «تصفية» واحد.
void main() {
  late DataService data;
  late Mosque mosque;
  late Student student;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ar', null);
    SharedPreferences.setMockInitialValues({});
    data = DataService();
    await data.init();
  });

  setUp(() {
    for (final role in ['mosque_admin', 'sheikh', 'cashier', 'student']) {
      data.disconnectRole(role);
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    mosque = data.addMosque(name: 'جامع الصراف $stamp', address: '', city: 'دمشق', gender: 'male');
    final sheikh = data.addSheikh(mosque.id, 'الشيخ', '0999');
    final halaqa = data.addHalaqa(mosqueId: mosque.id, name: 'حلقة نافع', sheikhId: sheikh.id);
    student = data.addStudent(
      mosqueId: mosque.id,
      halaqaId: halaqa.id,
      fullName: 'أنس الطالب',
      gender: 'male',
      phone: '0500',
      welcomePoints: 500,
    );
    final bag = data.addReward(mosqueId: mosque.id, title: 'حقيبة', pointsCost: 50);
    final pen = data.addReward(mosqueId: mosque.id, title: 'قلم', pointsCost: 20);
    // جائزة سُلّمت وأخرى ما زالت قسيمتها معلّقة
    data.sellReward(studentId: student.id, rewardId: bag.id, cashierName: 'أبو أحمد');
    data.claimReward(studentId: student.id, rewardId: pen.id);

    data.setRoleSession(ActiveSession(
      role: 'cashier',
      name: 'أبو أحمد',
      code: 'CSH-HOME',
      mosqueId: mosque.id,
      mosqueName: mosque.name,
    ));
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const CashierScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('عدد الجوامع بصيغته العربية', () {
    expect(CashierScreenState.mosqueCountLabel(1), 'جامع واحد');
    expect(CashierScreenState.mosqueCountLabel(2), 'جامعان');
    expect(CashierScreenState.mosqueCountLabel(3), '3 جوامع');
    expect(CashierScreenState.mosqueCountLabel(10), '10 جوامع');
    expect(CashierScreenState.mosqueCountLabel(11), '11 جامعاً');
  });

  test('طلب كمية من الجائزة: لكل قسيمة معرّف وكود لا يتكرران', () {
    final reward = data.getRewards(mosqueId: mosque.id).firstWhere((r) => r.title == 'قلم');
    final claimed = [
      for (var i = 0; i < 5; i++) data.claimReward(studentId: student.id, rewardId: reward.id)!,
    ];

    expect(claimed.map((r) => r.id).toSet(), hasLength(5));
    expect(claimed.map((r) => r.redemptionCode).toSet(), hasLength(5));
    expect(claimed.every((r) => RegExp(r'^VCH-\d{4}$').hasMatch(r.redemptionCode)), isTrue);
  });

  for (final size in const [Size(320, 640), Size(390, 844), Size(1366, 768)]) {
    testWidgets('الشاشة الأولى على ${size.width.toInt()}: صرف فقط بلا سجلات ولا فلاتر', (tester) async {
      await pumpHome(tester, size);

      expect(find.text('مسجّل عندك: جامع واحد'), findsOneWidget);
      expect(find.text('إضافة جامع'), findsOneWidget);
      expect(find.text('مسح باركود الطالب'), findsOneWidget);
      expect(find.text('أو اكتب الكود'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('صرف'), findsOneWidget);
      expect(find.text('السجلات والكشوف'), findsOneWidget);
      expect(find.text('هذا الشهر: 1 جائزة • 50 نقطة'), findsOneWidget);

      // لا سجل ولا فلاتر ولا كشف إدارة في الشاشة الأولى
      expect(find.byType(CashierHistorySection), findsNothing);
      expect(find.text('سجل الصرف والمستحقات'), findsNothing);
      expect(find.text('السجل الكامل للإدارة 📋'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('«إضافة جامع» تضيف ولا تستبدل: كود صراف جامع ثانٍ يُبقي الأول', () async {
    final second = data.addMosque(name: 'جامع النور', address: '', city: 'دمشق', gender: 'male');
    data.disconnectRole('cashier');

    final first = await data.verifyCode(mosque.effectiveCashierCode);
    final added = await data.verifyCode(second.effectiveCashierCode);
    expect(first!.role, 'cashier');
    expect(added!.role, 'cashier');

    final cashiers = data.savedSessions.where((s) => s.role == 'cashier').toList();
    expect(cashiers.map((s) => s.mosqueId), unorderedEquals([mosque.id, second.id]));

    // إعادة مسح كود الجامع نفسه لا تكرّره
    await data.verifyCode(second.effectiveCashierCode);
    expect(data.savedSessions.where((s) => s.role == 'cashier'), hasLength(2));

    data.disconnectRole('cashier');
    expect(data.savedSessions.where((s) => s.role == 'cashier'), isEmpty);
  });

  testWidgets('ثلاثة جوامع للصراف نفسه: «3 جوامع» وثلاث شرائح', (tester) async {
    data.disconnectRole('cashier');
    final names = <String>[];
    for (final name in ['جامع الأول', 'جامع الثاني', 'جامع الثالث']) {
      final m = data.addMosque(name: name, address: '', city: 'دمشق', gender: 'male');
      names.add(m.name);
      data.setRoleSession(ActiveSession(
        role: 'cashier',
        name: 'أبو أحمد',
        code: m.effectiveCashierCode,
        mosqueId: m.id,
        mosqueName: m.name,
      ));
    }

    await pumpHome(tester, const Size(390, 844));

    expect(find.text('مسجّل عندك: 3 جوامع'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    for (final name in names) {
      expect(find.widgetWithText(ChoiceChip, name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('أكثر من جامع: العدد وشرائح التبديل، والضغط يبدّل الجامع النشط', (tester) async {
    final second = data.addMosque(name: 'جامع الروضة', address: '', city: 'دمشق', gender: 'male');
    data.setRoleSession(ActiveSession(
      role: 'mosque_admin',
      name: 'مدير',
      code: 'ADM-2',
      mosqueId: second.id,
      mosqueName: second.name,
    ));

    await pumpHome(tester, const Size(390, 844));

    expect(find.text('مسجّل عندك: جامعان'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, mosque.name));
    await tester.pumpAndSettle();
    expect(find.text('الصرف الآن لطلاب: ${mosque.name}'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'جامع الروضة'));
    await tester.pumpAndSettle();
    expect(find.text('الصرف الآن لطلاب: جامع الروضة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('كتابة كود الطالب ثم «صرف» تفتح قائمة جوائزه', (tester) async {
    await pumpHome(tester, const Size(390, 844));

    await tester.enterText(find.byType(TextField), student.code);
    await tester.tap(find.text('صرف'));
    await tester.pumpAndSettle();

    expect(find.text('الجوائز المتاحة لهذا الطالب:'), findsOneWidget);
    expect(find.text(student.fullName), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(1366, 768)]) {
    testWidgets('السجلات على ${size.width.toInt()}: شاشة داخلية بالسجل وكشف الإدارة وزر تصفية واحد',
        (tester) async {
      await pumpHome(tester, size);

      await tester.ensureVisible(find.text('السجلات والكشوف'));
      await tester.tap(find.text('السجلات والكشوف'));
      await tester.pumpAndSettle();

      expect(find.byType(CashierRecordsScreen), findsOneWidget);
      expect(find.text('كود النقطة: CSH-HOME • ${mosque.name}'), findsOneWidget);
      expect(find.text('السجل الكامل للإدارة 📋'), findsOneWidget);
      expect(find.text('سجل الصرف والمستحقات'), findsOneWidget);
      expect(find.text('كل العمليات: 2'), findsOneWidget);

      // الظاهر: البحث والفترة. الحالة والحلقة والترتيب مطوية خلف «تصفية»
      expect(find.text('هذا الشهر'), findsOneWidget);
      expect(find.text('تصفية'), findsOneWidget);
      expect(find.text('حالة الجائزة'), findsNothing);
      expect(find.text('الترتيب'), findsNothing);

      await tester.ensureVisible(find.text('تصفية'));
      await tester.tap(find.text('تصفية'));
      await tester.pumpAndSettle();

      expect(find.text('حالة الجائزة'), findsOneWidget);
      expect(find.text('الترتيب'), findsOneWidget);
      // صراف جامع واحد لا يُسأل عن الجامع
      expect(find.text('كل الجوامع المعتمدة'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'قيد الانتظار'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'قيد الانتظار'));
      await tester.pumpAndSettle();

      expect(find.text('تصفية (1)'), findsOneWidget);
      expect(find.text('النتيجة: 1 من 2 عملية'), findsOneWidget);

      await tester.ensureVisible(find.text('إعادة الضبط'));
      await tester.tap(find.text('إعادة الضبط'));
      await tester.pumpAndSettle();

      expect(find.text('تصفية'), findsOneWidget);
      expect(find.text('كل العمليات: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('بحث بلا نتيجة يعرض زر «عرض كل العمليات» ويعيدها', (tester) async {
    await pumpHome(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('السجلات والكشوف'));
    await tester.tap(find.text('السجلات والكشوف'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'لا أحد بهذا الاسم');
    await tester.pumpAndSettle();
    expect(find.text('النتيجة: 0 من 2 عملية'), findsOneWidget);
    expect(find.text('لا توجد عمليات مطابقة للفلاتر المختارة'), findsOneWidget);

    await tester.ensureVisible(find.text('عرض كل العمليات'));
    await tester.tap(find.text('عرض كل العمليات'));
    await tester.pumpAndSettle();
    expect(find.text('كل العمليات: 2'), findsOneWidget);
  });
}
