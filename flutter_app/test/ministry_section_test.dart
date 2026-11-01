import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/screens/super_admin/ministry_mosques_section.dart';
import 'package:flutter_app/services/data_service.dart';

/// قسم المساجد في لوحة المشرف العام على مستوى الدولة: الأرقام والقائمة من الخادم بصفحات،
/// والبحث والمدينة يُرسلان للخادم، والرجوع إلى القائمة المحلية حين لا ترقية فيه.

class _FakeMinistry extends MinistryRemote {
  _FakeMinistry() : super(SupabaseRemoteDataSource());

  MinistryResult<MinistryOverview> overviewResult = const MinistryResult(MinistryStatus.ok, MinistryOverview(
    mosquesMen: 1200,
    mosquesWomen: 30,
    students: 90210,
    sheikhs: 3100,
    halaqat: 4100,
    attendanceToday: 777,
    activeMosques7d: 998,
    newMosques30d: 12,
    cities: [MinistryCity('دمشق', 400), MinistryCity('حلب', 300)],
  ));

  /// يُعاد بالترتيب لكل استدعاء `mosques`؛ أو يُحسب من [builder] إن وُجد.
  final List<Future<MinistryResult<MinistryPage>> Function()> pages = [];
  final List<({String search, String? city, int offset})> calls = [];

  @override
  Future<MinistryResult<MinistryOverview>> overview() async => overviewResult;

  @override
  Future<MinistryResult<MinistryPage>> mosques({
    String search = '',
    String? city,
    int limit = 40,
    int offset = 0,
  }) {
    calls.add((search: search.trim(), city: city, offset: offset));
    return pages.removeAt(0)();
  }
}

MinistryMosqueRow _row(String id, {String name = '', String gender = 'male', String? code}) =>
    MinistryMosqueRow(
      id: id,
      name: name.isEmpty ? 'جامع $id' : name,
      city: 'دمشق',
      gender: gender,
      accessCode: gender == 'female' ? null : (code ?? 'MSQ-$id'),
      halaqatCount: 2,
      sheikhsCount: 3,
      studentsCount: 45,
      lastActivity: DateTime.utc(2026, 10, 30, 12),
    );

Future<MinistryResult<MinistryPage>> _ok(int total, List<MinistryMosqueRow> rows) async =>
    MinistryResult(MinistryStatus.ok, MinistryPage(total, rows));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeMinistry fake;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = _FakeMinistry();
  });

  Future<void> pumpSection(WidgetTester tester, {Listenable? refresh}) async {
    tester.view.physicalSize = const Size(360 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: DataService(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: MinistryMosquesSection(
                history: const [],
                remote: fake,
                refresh: refresh,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('أرقام المنصة من الخادم والصفحة الأولى ثم تحميل المزيد بلا تكرار', (tester) async {
    fake.pages
      ..add(() => _ok(3, [_row('a'), _row('b')]))
      ..add(() => _ok(3, [_row('b'), _row('c')])); // ‏b مكرر: لا يظهر مرتين
    await pumpSection(tester);

    expect(find.text('90210'), findsOneWidget, reason: 'عدد الطلاب من الخادم لا من الجهاز');
    expect(find.text('777'), findsOneWidget);
    expect(find.text('المساجد المسجلة في المنصة (3)'), findsOneWidget);
    expect(find.text('جامع a'), findsOneWidget);
    expect(find.text('جامع b'), findsOneWidget);
    expect(find.text('جامع c'), findsNothing);
    expect(tester.takeException(), isNull, reason: 'لا فيض على عرض هاتف 360');

    final more = find.text('تحميل المزيد (1 متبقٍ)');
    await tester.scrollUntilVisible(more, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(more);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.calls.last.offset, 2);
    expect(find.text('جامع b'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('جامع c'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('جامع c'), findsOneWidget);
    expect(find.textContaining('تحميل المزيد'), findsNothing, reason: 'اكتمل العدد');
  });

  testWidgets('البحث يصل الخادم بعد تأخير قصير، لا مع كل حرف', (tester) async {
    fake.pages
      ..add(() => _ok(2, [_row('a'), _row('b')]))
      ..add(() => _ok(1, [_row('b', name: 'جامع الرحمن')]));
    await pumpSection(tester);

    await tester.enterText(find.byType(TextField), 'رح');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'رحمن');
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.calls, hasLength(1), reason: 'لم ينتهِ التأخير بعد');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.calls, hasLength(2));
    expect(fake.calls.last.search, 'رحمن');
    expect(find.text('جامع الرحمن'), findsOneWidget);
    expect(find.text('جامع a'), findsNothing);
  });

  testWidgets('نقر مدينة في الملخص يرسلها للخادم كمرشّح', (tester) async {
    fake.pages
      ..add(() => _ok(2, [_row('a'), _row('b')]))
      ..add(() => _ok(1, [_row('a')]));
    await pumpSection(tester);

    await tester.tap(find.text('حلب (300)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.calls.last.city, 'حلب');
    expect(find.text('المدينة: حلب ✕'), findsOneWidget);
  });

  testWidgets('ردّ متأخر لطلب قديم لا يكتب فوق نتيجة أحدث', (tester) async {
    final slow = Completer<MinistryResult<MinistryPage>>();
    fake.pages
      ..add(() => _ok(1, [_row('first')]))
      ..add(() => slow.future) // بحث بطيء
      ..add(() => _ok(1, [_row('newest')])); // بحث أحدث وأسرع
    await pumpSection(tester);

    await tester.enterText(find.byType(TextField), 'أ');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'ب');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('جامع newest'), findsOneWidget);

    slow.complete(MinistryResult(MinistryStatus.ok, MinistryPage(1, [_row('stale')])));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('جامع stale'), findsNothing);
    expect(find.text('جامع newest'), findsOneWidget);
  });

  testWidgets('القسم النسائي: لا كود ولا زر نسخ للمشرف العام', (tester) async {
    fake.pages.add(() => _ok(2, [
          _row('men', code: 'MSQ-SECRET-MEN'),
          _row('women', gender: 'female'),
        ]));
    await pumpSection(tester);

    expect(find.text('MSQ-SECRET-MEN'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('فرع نسائي'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('كود هذا القسم عند إدارته وحدها، ولا يُعرض هنا.'), findsOneWidget);
  });

  testWidgets('حساب غير مسجَّل مشرفاً عاماً: رسالة واضحة لا أرقام', (tester) async {
    fake.overviewResult = const MinistryResult(MinistryStatus.unauthorized);
    fake.pages.add(() async => const MinistryResult(MinistryStatus.unauthorized));
    await pumpSection(tester);
    expect(find.textContaining('غير مسجَّل كمشرف عام'), findsOneWidget);
    expect(find.text('90210'), findsNothing);
  });

  testWidgets('تعذّر الخادم (لا إنترنت): القائمة المحلية تبقى ظاهرة مع شريط إعادة المحاولة',
      (tester) async {
    fake.overviewResult = const MinistryResult(MinistryStatus.failed);
    fake.pages.add(() async => const MinistryResult(MinistryStatus.failed));
    await pumpSection(tester);
    expect(find.textContaining('تعذّر جلب أرقام المنصة'), findsOneWidget);
    expect(find.textContaining('المساجد المسجلة في المنصة'), findsOneWidget,
        reason: 'القائمة المحلية لا تختفي');
    expect(find.text('90210'), findsNothing);

    fake.overviewResult = MinistryResult(MinistryStatus.ok, const MinistryOverview(students: 5));
    fake.pages.add(() => _ok(1, [_row('a')]));
    await tester.tap(find.text('أعد المحاولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('جامع a'), findsOneWidget);
    expect(find.textContaining('تعذّر جلب أرقام المنصة'), findsNothing);
  });

  testWidgets('الخادم بلا الترقية: القائمة المحلية القديمة كما كانت', (tester) async {
    fake.overviewResult = const MinistryResult(MinistryStatus.unsupported);
    fake.pages.add(() async => const MinistryResult(MinistryStatus.unsupported));
    await pumpSection(tester);

    // لا أرقام خادم ولا زر «تحميل المزيد»؛ عنوان القائمة المحلية (فارغة هنا)
    expect(find.text('90210'), findsNothing);
    expect(find.textContaining('المساجد المسجلة في المنصة'), findsOneWidget);
    expect(find.text('لا توجد مساجد مسجلة في المنصة حالياً'), findsOneWidget);
  });

  testWidgets('السحب للتحديث في الشاشة الأم يعيد الجلب من الخادم', (tester) async {
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    fake.pages
      ..add(() => _ok(1, [_row('old')]))
      ..add(() => _ok(1, [_row('fresh')]));
    await pumpSection(tester, refresh: tick);
    expect(find.text('جامع old'), findsOneWidget);

    tick.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('جامع fresh'), findsOneWidget);
    expect(find.text('جامع old'), findsNothing);
  });
}
