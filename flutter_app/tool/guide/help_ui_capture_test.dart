// ignore_for_file: invalid_use_of_visible_for_testing_member
// يصوّر شاشات «تعلّم الاستخدام» الجديدة بالواجهة الحقيقية (نفس الخطوط والثيم) للتحقق البصري قبل البناء:
//   GUIDE_OUT=... flutter test tool/guide/help_ui_capture_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/core/navigation/navigator_key.dart';
import 'package:flutter_app/data/help_videos_data.dart';
import 'package:flutter_app/main.dart' show MainShell;
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/settings_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/developer_chat_service.dart';
import 'package:flutter_app/services/help_state.dart';
import 'package:flutter_app/widgets/help_coach_overlay.dart';

import 'harness.dart';

void main() {
  testWidgets('help ui', (tester) async {
    GuideNetworkPolicy.install();
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = d.exceptionAsString();
      if (m.contains('overflowed') || m.contains("deactivated widget's ancestor")) {
        stdout.writeln('! ${m.split("\n").first}');
        return;
      }
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    await initInjection();
    final data = sl<DataService>();
    await data.completeOnboarding('personal');
    HelpState.instance.resetForTest(loaded: true);
    DeveloperChatService.rpc = (fn, body) async {
      if (fn == 'dev_msg_thread') {
        return {
          'remaining': 2,
          'messages': [
            {'id': 1, 'from_dev': false, 'body': 'السلام عليكم، لا تظهر لي حلقة ابني بعد مسح بطاقته', 'at': '2026-10-29T10:00:00+03:00'},
            {'id': 2, 'from_dev': true, 'body': 'وعليكم السلام ورحمة الله. تأكد أن الجهاز متصل بالإنترنت لدقيقة ثم اسحب للتحديث، وأخبرني إن بقيت المشكلة.', 'at': '2026-10-29T11:00:00+03:00'},
          ],
        };
      }
      return {};
    };

    final s = Shooter(tester, size: const Size(412, 892));
    await s.setUpView();
    addTearDown(tester.view.reset);
    await tester.pumpWidget(s.wrap(const GuideApp()));
    await s.settle(8);
    final nav = appNavigatorKey;

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        stdout.writeln('√ $name');
      } catch (e) {
        stdout.writeln('X $name: $e');
        await s.closeAll();
      }
    }

    await step('home with help button', () => s.snap('ui_01_home'));
    await step('help center', () async {
      await s.tapTooltip('تعلّم استخدام التطبيق');
      await s.snap('ui_02_help_top');
      await s.scrollBy(-520);
      await s.snap('ui_03_help_scrolled');
      await s.scrollBy(-1500);
      await s.snap('ui_04_help_admin_cards');
    });
    await step('chat tab', () async {
      await s.scrollToTop();
      await s.tapText('تواصل مع المطوّر');
      await s.snap('ui_05_chat');
    });
    await step('settings', () async {
      await s.closeAll();
      nav.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      await s.settle(6);
      await s.snap('ui_06_settings');
    });
    await step('role video dialog', () async {
      await s.closeAll();
      data.setRoleSession(ActiveSession(role: 'student', name: 'عمر', code: 'STD-1', mosqueId: 'm', mosqueName: 'ج', studentId: 's'));
      MainShell.targetTabNotifier.value = 'portal';
      await s.settle(8);
      await s.snap('ui_07_portal');
      await s.scrollBy(-620);
      await s.snap('ui_08_portal_cards');
      await s.tapText('شاهد فيديو شرح هذه الرتبة', index: 1);
      await s.snap('ui_09_role_video_dialog');
      await s.closeAll();
    });
    await step('coach overlay', () async {
      await s.closeAll();
      HelpState.instance.resetForTest(loaded: true);
      final anchor = find.byTooltip('تعلّم استخدام التطبيق');
      final box = tester.renderObject<RenderBox>(anchor);
      final key = GlobalKey();
      // نفس الأداة على شريط تجريبي في الموضع نفسه
      await tester.pumpWidget(s.wrap(MaterialApp(
        locale: const Locale('ar'),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Builder(builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) => HelpCoachOverlay.showIfNeeded(ctx, key));
          return Scaffold(
            appBar: AppBar(title: const Text('منصة محراب'), actions: [IconButton(key: key, icon: const Icon(Icons.help_outline_rounded), onPressed: () {}), const SizedBox(width: 90)]),
            body: ListView(children: [for (var i = 0; i < 12; i++) ListTile(title: Text('عنصر ${i + 1} من الشاشة الرئيسية'))]),
          );
        }),
      )));
      await s.settle(6);
      stdout.writeln('anchor ${box.size}');
      await s.snap('ui_10_coach');
      HelpCoachOverlay.dismissForTest();
    });
    stdout.writeln('videos: ${HelpVideos.all.length}');
  });
}
