import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/admin/tabs/admin_events_tab.dart';
import 'package:flutter_app/screens/discover/dialogs/discover_event_dialog.dart';
import 'package:flutter_app/screens/discover_screen.dart';
import 'package:flutter_app/screens/sheikh/tabs/sheikh_events_tab.dart';
import 'package:flutter_app/services/data_service.dart';

/// شاشة الفعاليات: الحالة النسائية بلا زر «إعلان درس عام»، ودرس المرة الواحدة
/// يختفي حين ينقضي موعده، والأرشيف بلا فلتر الفيديو.
void main() {
  late DataService data;

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
  });

  Future<void> pumpEvents(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: MaterialApp(home: Scaffold(body: DiscoverScreen(onOpenScanner: () {}))),
      ),
    );
    await tester.pump();
  }

  Mosque newMosque(String name) => data.addMosque(name: name, address: '', city: 'دمشق', gender: 'male');

  CommunityEvent lessonAt(Mosque mosque, String title, DateTime when) => data.addCommunityEvent(
        mosqueId: mosque.id,
        title: title,
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: when,
        organizerType: 'mosque',
        organizerName: 'إدارة المسجد',
        isRecurring: false,
      );

  testWidgets('زائر عادي: زر «إعلان درس عام» موجود', (tester) async {
    await pumpEvents(tester);

    expect(find.text('إعلان درس عام'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحالة النسائية: لا زر «إعلان درس عام»، والأرشيف باقٍ', (tester) async {
    final parent = newMosque('جامع شاشة الفعاليات');
    final token = data.issueWomenProvisionToken(parent.id)!;
    await tester.runAsync(() async {
      final offer = await data.inspectWomenProvisionToken(token);
      await data.redeemWomenProvisionToken(offer: offer!, name: 'القسم النسائي', city: '', address: '');
    });
    expect(data.isWomenMode, isTrue);

    await pumpEvents(tester);

    expect(find.text('إعلان درس عام'), findsNothing);
    // تبويب مكتبة الدروس (الأرشيف) يبقى متاحاً للاستماع
    expect(find.textContaining('مكتبة الدروس'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  Future<Mosque> womenBranchOf(WidgetTester tester, Mosque parent) async {
    final token = data.issueWomenProvisionToken(parent.id)!;
    late Mosque branch;
    await tester.runAsync(() async {
      final offer = await data.inspectWomenProvisionToken(token);
      branch = (await data.redeemWomenProvisionToken(
        offer: offer!,
        name: 'القسم النسائي - ${parent.name}',
        city: '',
        address: '',
      ))!;
    });
    return branch;
  }

  Future<void> pumpTab(WidgetTester tester, Widget tab) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: MaterialApp(home: Scaffold(body: tab)),
      ),
    );
    await tester.pump();
  }

  testWidgets('تبويب دروس الإدارة: الزر موجود لمسجد الرجال ومحذوف للقسم النسائي', (tester) async {
    final parent = newMosque('جامع تبويب الإدارة');
    await pumpTab(tester, AdminEventsTab(mosque: parent));
    expect(find.text('إعلان عن درس / مجلس'), findsOneWidget);

    final branch = await womenBranchOf(tester, parent);
    await pumpTab(tester, AdminEventsTab(mosque: branch));

    expect(find.text('إعلان عن درس / مجلس'), findsNothing);
    expect(find.textContaining('القسم النسائي لا يعلن دروساً عامة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('تبويب دروس المعلمة: لا زر «إعلان درس جديد» في القسم النسائي، وهو موجود للشيخ', (tester) async {
    final parent = newMosque('جامع تبويب المعلمة');
    final sheikh = data.addSheikh(parent.id, 'الشيخ سعيد', '0911');
    data.setRoleSession(ActiveSession(
      role: 'sheikh',
      name: sheikh.fullName,
      code: sheikh.code,
      mosqueId: parent.id,
      sheikhId: sheikh.id,
      gender: 'male',
    ));
    await pumpTab(tester, SheikhEventsTab(sheikh: sheikh));
    expect(find.text('إعلان درس جديد'), findsOneWidget);

    final branch = await womenBranchOf(tester, parent);
    final teacher = data.addSheikh(branch.id, 'المعلمة فاطمة', '0922');
    data.setRoleSession(ActiveSession(
      role: 'sheikh',
      name: teacher.fullName,
      code: teacher.code,
      mosqueId: branch.id,
      sheikhId: teacher.id,
      gender: 'female',
    ));
    await pumpTab(tester, SheikhEventsTab(sheikh: teacher));

    expect(find.text('إعلان درس جديد'), findsNothing);
    expect(find.textContaining('القسم النسائي لا يعلن دروساً عامة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('نافذة الإعلان نفسها لا تُفتح لجلسة قسم نسائي من أي مدخل', (tester) async {
    final parent = newMosque('جامع الحاجز');
    final branch = await womenBranchOf(tester, parent);
    final womenAdmin = data.getSessionForRole('mosque_admin')!;
    expect(womenAdmin.mosqueId, branch.id);
    final teacher = data.addSheikh(branch.id, 'المعلمة زينب', '0933');
    final teacherSession = ActiveSession(
      role: 'sheikh',
      name: teacher.fullName,
      code: teacher.code,
      mosqueId: branch.id,
      sheikhId: teacher.id,
      gender: 'female',
    );
    final menAdmin = ActiveSession(
      role: 'mosque_admin',
      name: 'مدير',
      code: parent.accessCode,
      mosqueId: parent.id,
      gender: 'male',
    );

    late BuildContext ctx;
    await pumpTab(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }));

    DiscoverEventDialog.showAdminAddPublicEventModal(ctx, data, womenAdmin);
    await tester.pump();
    expect(find.text('إعلان درس أو مجلس (إدارة المسجد)'), findsNothing);
    expect(find.textContaining('القسم النسائي لا يعلن دروساً عامة'), findsOneWidget);

    DiscoverEventDialog.showSheikhAddPublicEventModal(ctx, data, teacherSession);
    await tester.pump();
    expect(find.text('إعلان درس عام (فضيلة الشيخ)'), findsNothing);

    // إدارة مسجد الرجال تفتحها كما كانت
    DiscoverEventDialog.showAdminAddPublicEventModal(ctx, data, menAdmin);
    await tester.pumpAndSettle();
    expect(find.text('إعلان درس أو مجلس (إدارة المسجد)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('درس المرة الواحدة يظهر قبل موعده ويختفي بعد انقضائه', (tester) async {
    final mosque = newMosque('جامع المواعيد');
    lessonAt(mosque, 'درس قادم بعد ساعتين', DateTime.now().add(const Duration(hours: 2)));
    lessonAt(mosque, 'درس انقضى أمس', DateTime.now().subtract(const Duration(days: 1)));
    // انتهى قبل ربع ساعة: ما زال في مهلة نصف الساعة
    lessonAt(mosque, 'درس انتهى للتو', DateTime.now().subtract(const Duration(minutes: 75)));

    await pumpEvents(tester);

    expect(find.text('درس قادم بعد ساعتين'), findsOneWidget);
    expect(find.text('درس انتهى للتو'), findsOneWidget);
    expect(find.text('درس انقضى أمس'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
