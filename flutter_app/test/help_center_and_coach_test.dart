import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/data/help_videos_data.dart';
import 'package:flutter_app/screens/help/help_center_screen.dart';
import 'package:flutter_app/screens/management_portal/management_portal_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/developer_chat_service.dart';
import 'package:flutter_app/services/help_state.dart';
import 'package:flutter_app/widgets/help_app_bar_button.dart';
import 'package:flutter_app/widgets/help_coach_overlay.dart';

/// شاشة التعلّم، زر «؟»، نافذة التعريف الأولى، وأزرار فيديو الرتب في بوابة الإدارة.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HelpState.instance.resetForTest();
    HelpCoachOverlay.dismissForTest();
    DeveloperChatService.rpc = (fn, body) async => throw Exception('offline');
  });

  Widget app(Widget home) => MaterialApp(
        locale: const Locale('ar'),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: home,
      );

  testWidgets('شاشة التعلّم: قسمان بكروتهما، لكل كرت عنوان ووصف وفيديو في مكانه', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const HelpCenterScreen()));
    await tester.pump();

    expect(find.text('تعلّم استخدام التطبيق'), findsOneWidget);
    expect(find.text('تعرّف على محراب'), findsOneWidget);
    for (final v in HelpVideos.general) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('helpCard_${v.id}')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text(v.title), findsWidgets);
      expect(find.text(v.description), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('دليل الإدارات والرتب'), 300, scrollable: find.byType(Scrollable).first);
    for (final v in HelpVideos.admin) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('helpCard_${v.id}')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text(v.description), findsOneWidget);
    }
    // فتح الشاشة يوقف وميض الزر
    expect(HelpState.instance.opened, isTrue);
  });

  testWidgets('فيديو لا يُشغَّل على جهاز بلا مشغّل: رسالة واضحة لا انهيار', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const HelpCenterScreen()));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('helpVideoPoster')).first);
    await tester.tap(find.byKey(const ValueKey('helpVideoPoster')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('تعذّر تشغيل الفيديو'), findsOneWidget);
  });

  testWidgets('فتح الشاشة على تبويب التواصل مباشرة (من الإعدادات)', (tester) async {
    await tester.pumpWidget(app(const HelpCenterScreen(initialTab: 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // لا خادم في الاختبار: تظهر حالة الانقطاع بدل المحادثة
    expect(find.byKey(const ValueKey('devChatUnavailable')), findsOneWidget);
  });

  testWidgets('زر «؟» يفتح شاشة التعلّم، ويومض قبل أن تُفتح فقط', (tester) async {
    HelpState.instance.resetForTest(loaded: true);
    expect(HelpState.instance.shouldPulse, isTrue);
    await tester.pumpWidget(app(Scaffold(appBar: AppBar(actions: const [HelpAppBarButton()]))));
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterScreen), findsOneWidget);
    expect(HelpState.instance.opened, isTrue);
    expect(HelpState.instance.shouldPulse, isFalse);
  });

  testWidgets('ردّ جديد من المطوّر يُظهر نقطة حمراء على الزر ويعيد الوميض', (tester) async {
    HelpState.instance.resetForTest(loaded: true, opened: true, unreadReply: true);
    await tester.pumpWidget(app(Scaffold(appBar: AppBar(actions: const [HelpAppBarButton()]))));
    expect(HelpState.instance.shouldPulse, isTrue);
    expect(find.byTooltip('تعلّم الاستخدام (لديك ردّ جديد من المطوّر)'), findsOneWidget);
  });

  testWidgets('نافذة التعريف الأولى: تظهر مرة واحدة، تخطّيها يحفظها، وفتحها يذهب إلى التعلّم', (tester) async {
    HelpState.instance.resetForTest(loaded: true);
    final anchor = GlobalKey();
    late BuildContext ctx;
    await tester.pumpWidget(app(Builder(builder: (c) {
      ctx = c;
      return Scaffold(appBar: AppBar(actions: [IconButton(key: anchor, icon: const Icon(Icons.help_outline_rounded), onPressed: () {})]));
    })));

    HelpCoachOverlay.showIfNeeded(ctx, anchor);
    await tester.pump();
    expect(find.byKey(const ValueKey('helpCoachSkip')), findsOneWidget);
    expect(find.text('اضغط على علامة «؟» لتشاهد فيديوهات قصيرة تشرح كل شيء، ولتتواصل معي إن احتجت أي مساعدة.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('helpCoachSkip')));
    await tester.pump();
    expect(find.byKey(const ValueKey('helpCoachSkip')), findsNothing);
    expect(HelpState.instance.coachSeen, isTrue);

    HelpCoachOverlay.showIfNeeded(ctx, anchor);
    await tester.pump();
    expect(find.byKey(const ValueKey('helpCoachSkip')), findsNothing, reason: 'لا تظهر ثانية');
  });

  testWidgets('زر «أرِني الفيديوهات» في نافذة التعريف يفتح شاشة التعلّم', (tester) async {
    HelpState.instance.resetForTest(loaded: true);
    final anchor = GlobalKey();
    late BuildContext ctx;
    await tester.pumpWidget(app(Builder(builder: (c) {
      ctx = c;
      return Scaffold(appBar: AppBar(actions: [IconButton(key: anchor, icon: const Icon(Icons.help_outline_rounded), onPressed: () {})]));
    })));
    HelpCoachOverlay.showIfNeeded(ctx, anchor);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('helpCoachOpen')));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterScreen), findsOneWidget);
    expect(HelpState.instance.coachSeen, isTrue);
  });

  testWidgets('قبل تحميل حالة الجهاز لا تظهر نافذة التعريف ولا وميض', (tester) async {
    final anchor = GlobalKey();
    late BuildContext ctx;
    await tester.pumpWidget(app(Builder(builder: (c) {
      ctx = c;
      return Scaffold(appBar: AppBar(actions: [IconButton(key: anchor, icon: const Icon(Icons.help_outline_rounded), onPressed: () {})]));
    })));
    HelpCoachOverlay.showIfNeeded(ctx, anchor);
    await tester.pump();
    expect(find.byKey(const ValueKey('helpCoachSkip')), findsNothing);
    expect(HelpState.instance.shouldPulse, isFalse);
  });

  testWidgets('بوابة الإدارة: لا إعلان «قيد التفعيل»، ولكل رتبة زر فيديو يفتح مشغّلها فوراً', (tester) async {
    await initInjection();
    final data = sl<DataService>();
    tester.view.physicalSize = const Size(1000, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<DataService>.value(
      value: data,
      child: app(const ManagementPortalScreen()),
    ));
    await tester.pump();

    expect(find.textContaining('قيد التفعيل'), findsNothing);
    for (final id in [HelpVideoIds.mosqueAdmin, HelpVideoIds.sheikh, HelpVideoIds.parent, HelpVideoIds.cashier, HelpVideoIds.women]) {
      expect(find.byKey(ValueKey('portalVideo_$id')), findsOneWidget, reason: id);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('portalVideo_${HelpVideoIds.sheikh}')));
    await tester.tap(find.byKey(const ValueKey('portalVideo_${HelpVideoIds.sheikh}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final sheikh = HelpVideos.byId(HelpVideoIds.sheikh)!;
    expect(find.text(sheikh.title), findsOneWidget);
    expect(find.text('كل الفيديوهات التعليمية'), findsOneWidget);
  });
}
