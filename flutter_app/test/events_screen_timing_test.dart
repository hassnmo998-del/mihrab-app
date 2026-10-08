import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/discover/widgets/discover_event_management_view.dart';
import 'package:flutter_app/screens/discover_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/lesson_schedule.dart';

/// شاشة الفعاليات وقائمة الإدارة: ما يظهر وما يختفي، الترتيب، وموعد الجلسة القادمة.
void main() {
  late DataService data;
  late Mosque mosque;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
    data = sl<DataService>();
  });

  setUp(() {
    for (final role in ['mosque_admin', 'sheikh', 'cashier', 'student']) {
      data.disconnectRole(role);
    }
    mosque = data.addMosque(
        name: 'جامع المواعيد ${DateTime.now().microsecondsSinceEpoch}', address: '', city: 'دمشق', gender: 'male');
  });

  CommunityEvent add(String title, DateTime when, {bool recurring = false, String? days}) => data.addCommunityEvent(
        mosqueId: mosque.id,
        title: title,
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: when,
        organizerType: 'mosque',
        organizerName: 'إدارة المسجد',
        isRecurring: recurring,
        recurringDays: days,
      );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  double y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

  testWidgets('القائمة العامة: الأقرب أولاً، المنتهي والمباشر العالق يختفيان، وموعد الجلسة القادمة ظاهر',
      (tester) async {
    final now = DateTime.now();
    final later = add('درس بعد ثلاث ساعات', now.add(const Duration(hours: 3)));
    final soon = add('درس بعد ساعة', now.add(const Duration(hours: 1)));
    add('درس انتهى أمس', now.subtract(const Duration(days: 1)));
    final stuck = add('درس سُجّل أمس وبقي مباشراً', now.subtract(const Duration(days: 1)));
    data.changeEventStatus(stuck.id, 'live');

    await pump(tester, DiscoverScreen(onOpenScanner: () {}));

    expect(find.text('درس انتهى أمس'), findsNothing);
    expect(find.text('درس سُجّل أمس وبقي مباشراً'), findsNothing);
    expect(find.text('مباشر الآن 🔴'), findsNothing);
    expect(y(tester, 'درس بعد ساعة'), lessThan(y(tester, 'درس بعد ثلاث ساعات')));

    for (final e in [soon, later]) {
      final badge = find.byKey(ValueKey('nextSession-${e.id}'));
      expect(badge, findsOneWidget);
      expect(find.descendant(of: badge, matching: find.text(LessonSchedule.sessionLabel(e, DateTime.now())!)),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('درس انتهى اليوم: يبقى في آخر القائمة بشارة «مضى موعده» بلا «أنوي الحضور» ولا أسئلة',
      (tester) async {
    // الساعة الثالثة عصراً من اليوم، أياً كان وقت تشغيل الاختبار
    final today = DateTime.now();
    final threePm = DateTime(today.year, today.month, today.day, 15);
    LessonSchedule.clock = () => threePm;
    addTearDown(() => LessonSchedule.clock = DateTime.now);

    final past = data.addCommunityEvent(
      mosqueId: mosque.id,
      title: 'درس الظهر المنتهي',
      description: '',
      eventType: 'lesson',
      timingType: 'custom_time',
      targetAudience: 'general',
      eventDateTime: DateTime(today.year, today.month, today.day, 12),
      organizerType: 'mosque',
      organizerName: 'إدارة المسجد',
      isRecurring: false,
      isQaEnabled: true,
    );
    add('درس العصر القادم', DateTime(today.year, today.month, today.day, 15, 30));

    await pump(tester, DiscoverScreen(onOpenScanner: () {}));

    expect(find.text('درس الظهر المنتهي'), findsOneWidget);
    expect(y(tester, 'درس الظهر المنتهي'), greaterThan(y(tester, 'درس العصر القادم')));
    final badge = find.byKey(ValueKey('nextSession-${past.id}'));
    expect(find.descendant(of: badge, matching: find.text('مضى موعده • اليوم 12:00 م')), findsOneWidget);
    expect(find.text('🔒 انتهى الدرس فأُغلق باب الأسئلة'), findsOneWidget);

    // «أنوي الحضور» على كل درس ظاهر إلا ما مضى موعده
    final listed = data
        .getCommunityEvents()
        .where((e) => e.isActive && e.eventStatus != 'archived' && LessonSchedule.isListed(e, threePm))
        .toList();
    final pastCount = listed.where((e) => LessonSchedule.hasEnded(e, threePm)).length;
    expect(pastCount, greaterThanOrEqualTo(1));
    expect(find.text('أنوي الحضور'), findsNWidgets(listed.length - pastCount));

    // وفي قائمة الإدارة: «ظاهر للجمهور حتى نهاية اليوم»
    final session = ActiveSession(
        role: 'mosque_admin', code: mosque.accessCode, mosqueId: mosque.id, mosqueName: mosque.name, gender: 'male');
    await pump(tester, DiscoverEventManagementView(session: session, isDark: false));
    expect(find.text('مضى موعده • ظاهر للجمهور حتى نهاية اليوم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('درس يُسجَّل الآن: «مباشر الآن» وأول القائمة', (tester) async {
    final now = DateTime.now();
    add('درس العشاء بعد ساعة', now.add(const Duration(hours: 1)));
    final live = add('درس جارٍ', now.subtract(const Duration(minutes: 10)));
    data.changeEventStatus(live.id, 'live');

    await pump(tester, DiscoverScreen(onOpenScanner: () {}));

    expect(find.text('مباشر الآن 🔴'), findsOneWidget);
    expect(y(tester, 'درس جارٍ'), lessThan(y(tester, 'درس العشاء بعد ساعة')));
    expect(y(tester, 'درس جارٍ'), lessThan(y(tester, 'درس بعد ساعة')));
  });

  testWidgets('قائمة الإدارة: القادم أولاً، والمنتهي آخراً بشارة «انتهى» وحدها بلا «منشور للجمهور»',
      (tester) async {
    final now = DateTime.now();
    add('درس منتهٍ', now.subtract(const Duration(days: 2)));
    add('درس قادم', now.add(const Duration(hours: 5)));
    add('درس أسبوعي', now.subtract(const Duration(days: 20)), recurring: true, days: 'السبت, الثلاثاء');

    final session = ActiveSession(
        role: 'mosque_admin', code: mosque.accessCode, mosqueId: mosque.id, mosqueName: mosque.name, gender: 'male');
    await pump(tester, DiscoverEventManagementView(session: session, isDark: false));

    expect(y(tester, 'درس منتهٍ'), greaterThan(y(tester, 'درس قادم')));
    expect(y(tester, 'درس منتهٍ'), greaterThan(y(tester, 'درس أسبوعي')));
    expect(find.text('مضى موعده ولا يظهر للجمهور'), findsOneWidget);
    // لكل درس قائم شارة «منشور»، والمنتهي بلا شارة متناقضة
    expect(find.text('منشور للجمهور'), findsNWidgets(2));
    // الأسبوعي يعرض أيامه بلا تاريخ إعلانه القديم
    expect(find.textContaining('كل السبت، الثلاثاء •'), findsOneWidget);
    expect(find.textContaining('القادم:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
