import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/screens/help/widgets/developer_chat_tab.dart';
import 'package:flutter_app/services/developer_chat_service.dart';
import 'package:flutter_app/services/help_state.dart';
import 'package:flutter_app/services/install_presence.dart';

/// التواصل مع المطوّر: الخادم يفرض القواعد (٣ رسائل + واحدة مع كل ردّ)، والتطبيق يعرض الحالة ويفسّر الأخطاء.
void main() {
  late List<(String, Map<String, dynamic>)> calls;
  final thread = {
    'remaining': 2,
    'messages': [
      {'id': 1, 'from_dev': false, 'body': 'مرحباً، عندي مشكلة', 'at': '2026-10-29T10:00:00+00:00'},
      {'id': 2, 'from_dev': true, 'body': 'أهلاً بك، تفضّل', 'at': '2026-10-29T11:00:00+00:00'},
    ],
  };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({InstallPresence.idPrefsKey: 'a' * 32});
    HelpState.instance.resetForTest();
    calls = [];
    DeveloperChatService.rpc = (fn, body) async {
      calls.add((fn, body));
      switch (fn) {
        case 'dev_msg_thread':
          return thread;
        case 'dev_msg_send':
          return {'ok': true, 'remaining': 1};
        case 'dev_msg_unread':
          return {'count': 1};
      }
      return {};
    };
  });

  test('يقرأ المحادثة ويحسب ما بقي ومعرّف آخر ردّ', () async {
    final t = await DeveloperChatService.loadThread();
    expect(t.remaining, 2);
    expect(t.messages.length, 2);
    expect(t.messages.first.fromDev, isFalse);
    expect(t.lastDevId, 2);
    expect(calls.single.$2['p_install_id'], 'a' * 32);
  });

  test('الإرسال يمرّر المعرّف والمنصة والإصدار ثم يعيد المحادثة', () async {
    await DeveloperChatService.send('  رسالتي  ');
    final send = calls.firstWhere((c) => c.$1 == 'dev_msg_send').$2;
    expect(send['p_body'], 'رسالتي');
    expect(send['p_install_id'], 'a' * 32);
    expect(send['p_platform'], isNotEmpty);
    expect(calls.last.$1, 'dev_msg_thread');
  });

  test('رسالة فارغة أو أطول من الحدّ لا تصل الخادم', () async {
    await expectLater(DeveloperChatService.send('   '), throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.empty)));
    await expectLater(
      DeveloperChatService.send('ا' * (DeveloperChatService.maxLength + 1)),
      throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.tooLong)),
    );
    expect(calls, isEmpty);
  });

  test('ردّ الخادم بـ limit و busy يصير خطأ مفهوماً', () async {
    DeveloperChatService.rpc = (fn, body) async => {'error': 'limit', 'remaining': 0};
    await expectLater(DeveloperChatService.send('x'), throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.limit)));
    DeveloperChatService.rpc = (fn, body) async => {'error': 'busy'};
    await expectLater(DeveloperChatService.send('x'), throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.busy)));
  });

  test('انقطاع الشبكة أو غياب الدالة على الخادم = unavailable', () async {
    DeveloperChatService.rpc = (fn, body) async => throw Exception('HTTP 404');
    await expectLater(DeveloperChatService.loadThread(), throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.unavailable)));
  });

  test('ردّ جديد يرفع وميض زر «؟»، وقراءة المحادثة تطفئه وتحفظ آخر ردّ قرأه', () async {
    HelpState.instance.resetForTest(loaded: true, opened: true);
    await DeveloperChatService.refreshUnread();
    expect(HelpState.instance.unreadReply, isTrue);
    expect(HelpState.instance.shouldPulse, isTrue);

    final t = await DeveloperChatService.loadThread();
    await DeveloperChatService.markRead(t);
    expect(HelpState.instance.unreadReply, isFalse);
    expect((await SharedPreferences.getInstance()).getInt(DeveloperChatService.seenKey), 2);
    // وبعد القراءة يسأل الخادم عمّا بعد ٢ فقط
    await DeveloperChatService.refreshUnread();
    expect(calls.last.$2['p_after'], 2);
  });

  test('ردّ المطوّر: كلمة السر تُنظَّف كما في شاشة الأرقام', () async {
    DeveloperChatService.rpc = (fn, body) async {
      calls.add((fn, body));
      return {'ok': true};
    };
    await DeveloperChatService.adminReply('Ab-Cd 12', 'b' * 32, 'تفضّل');
    expect(calls.single.$1, 'dev_msg_admin_reply');
    expect(calls.single.$2['p_secret'], 'abcd12');
    DeveloperChatService.rpc = (fn, body) async => {'error': 'wrong_secret'};
    await expectLater(DeveloperChatService.adminInbox('x'), throwsA(isA<DevChatException>().having((e) => e.error, 'error', DevChatError.wrongSecret)));
  });

  Future<void> pumpTab(WidgetTester tester, {Future<DevThread> Function()? load, Future<DevThread> Function(String)? send}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(body: DeveloperChatTab(load: load, send: send)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  DevThread fake(int remaining, [List<DevMessage> m = const []]) => DevThread(messages: m, remaining: remaining);

  testWidgets('الشاشة تعرض الرسائل والمتبقي وتسمح بالكتابة', (tester) async {
    final msgs = [
      DevMessage(id: 1, fromDev: false, body: 'سؤالي الأول', at: DateTime(2026, 10, 29, 10)),
      DevMessage(id: 2, fromDev: true, body: 'جوابي', at: DateTime(2026, 10, 29, 11)),
    ];
    String? sent;
    await pumpTab(tester, load: () async => fake(2, msgs), send: (t) async {
      sent = t;
      return fake(1, msgs);
    });
    expect(find.text('سؤالي الأول'), findsOneWidget);
    expect(find.text('جوابي'), findsOneWidget);
    expect(find.text('المطوّر'), findsOneWidget);
    expect(find.text('المتبقي لك: 2 رسالتان'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('devChatInput')), 'رسالة جديدة');
    await tester.tap(find.byKey(const ValueKey('devChatSend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(sent, 'رسالة جديدة');
    expect(find.text('المتبقي لك: 1 رسالة'), findsOneWidget);
  });

  testWidgets('حين تنفد الرسائل يُعطَّل الإدخال ويُشرح السبب', (tester) async {
    await pumpTab(tester, load: () async => fake(0, [DevMessage(id: 1, fromDev: false, body: 'x', at: DateTime(2026))]));
    expect(find.textContaining('استنفدت رسائلك'), findsOneWidget);
    final input = tester.widget<TextField>(find.byKey(const ValueKey('devChatInput')));
    expect(input.enabled, isFalse);
    final send = tester.widget<IconButton>(find.byKey(const ValueKey('devChatSend')));
    expect(send.onPressed, isNull);
  });

  testWidgets('بلا خادم: رسالة واضحة وزر إعادة المحاولة', (tester) async {
    await pumpTab(tester, load: () async => throw const DevChatException(DevChatError.unavailable));
    expect(find.byKey(const ValueKey('devChatUnavailable')), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
