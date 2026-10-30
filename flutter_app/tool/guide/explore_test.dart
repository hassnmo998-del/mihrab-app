// ignore_for_file: invalid_use_of_visible_for_testing_member
// استكشاف: يفتح نوافذ التطبيق الحقيقية ويطبع ما فيها من نصوص وحقول وأزرار، لتُكتب خطوات التصوير على نصوصها الفعلية.
//   GUIDE_EXPLORE="admin:الحلقات القرآنية>إضافة حلقة جديدة;sheikh:..." flutter test tool/guide/explore_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/main.dart' show MainShell;
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';

import 'demo_story.dart';
import 'harness.dart';

void dump(String title) {
  final dialog = find.byType(Dialog).evaluate().isNotEmpty
      ? find.byType(Dialog)
      : (find.byType(BottomSheet).evaluate().isNotEmpty ? find.byType(BottomSheet) : null);
  Finder within(Finder f) => dialog == null ? f : find.descendant(of: dialog, matching: f);
  final texts = <String>[];
  for (final e in within(find.byType(Text)).evaluate()) {
    final w = e.widget as Text;
    final d = w.data ?? w.textSpan?.toPlainText();
    if (d != null && d.trim().isNotEmpty) texts.add(d.trim().replaceAll('\n', ' '));
  }
  final fields = <String>[];
  for (final e in within(find.byType(TextField)).evaluate()) {
    final w = e.widget as TextField;
    fields.add('${w.decoration?.labelText ?? ''}|${w.decoration?.hintText ?? ''}');
  }
  final tips = <String>[];
  for (final e in within(find.byType(Tooltip)).evaluate()) {
    final m = (e.widget as Tooltip).message;
    if (m != null) tips.add(m);
  }
  stdout.writeln('==== $title\nTEXTS: ${texts.toSet().join(' ¦ ')}\nFIELDS: ${fields.join(' ¦ ')}\nTIPS: ${tips.toSet().join(' ¦ ')}');
}

void main() {
  testWidgets('explore', (tester) async {
    GuideNetworkPolicy.install();
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    await initInjection();
    final data = sl<DataService>();
    await data.completeOnboarding('personal');
    final story = seedDemoStory(data);
    final s = Shooter(tester, size: const Size(412, 892));
    await s.setUpView();
    addTearDown(tester.view.reset);
    await tester.pumpWidget(s.wrap(const GuideApp()));
    await s.settle(6);

    ActiveSession sess(String role) {
      switch (role) {
        case 'admin':
          return ActiveSession(role: 'mosque_admin', name: 'مدير', code: story.mosque.accessCode, mosqueId: story.mosque.id, mosqueName: story.mosque.name);
        case 'sheikh':
          return ActiveSession(role: 'sheikh', name: story.ahmad.fullName, code: story.ahmad.code, mosqueId: story.mosque.id, mosqueName: story.mosque.name, sheikhId: story.ahmad.id);
        case 'student':
          return ActiveSession(role: 'student', name: story.omar.fullName, code: story.omar.code, mosqueId: story.mosque.id, mosqueName: story.mosque.name, studentId: story.omar.id, halaqaId: story.omar.halaqaId);
        default:
          return ActiveSession(role: 'cashier', name: 'أبو أحمد', code: story.mosque.effectiveCashierCode, mosqueId: story.mosque.id, mosqueName: story.mosque.name);
      }
    }

    final plan = (Platform.environment['GUIDE_EXPLORE'] ?? '').split(';').where((e) => e.trim().isNotEmpty);
    for (final item in plan) {
      for (var i = 0; i < 4 && (find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty); i++) {
        await s.closeTop();
      }
      final role = item.split(':').first.trim();
      final chain = item.substring(item.indexOf(':') + 1).split('>');
      final tab = {'admin': 'mosque_admin', 'sheikh': 'sheikh', 'student': 'student', 'cashier': 'cashier'}[role]!;
      for (final r in ['mosque_admin', 'sheikh', 'student', 'cashier']) {
        data.disconnectRole(r);
      }
      data.setRoleSession(sess(role));
      MainShell.targetTabNotifier.value = tab;
      await s.settle(6);
      try {
        for (final step in chain) {
          final x = step.trim();
          if (x.startsWith('tip=')) {
            await s.tapTooltip(x.substring(4));
          } else if (x.startsWith('icon=')) {
            final name = x.substring(5);
            final icon = {
              'qr': Icons.qr_code_2, 'qr_code': Icons.qr_code, 'edit': Icons.edit_outlined, 'settings': Icons.settings, 'add': Icons.add,
              'qr_scanner': Icons.qr_code_scanner, 'star': Icons.stars, 'print': Icons.print_outlined,
            }[name]!;
            await s.tapIcon(icon);
          } else if (x.startsWith('type=')) {
            final parts = x.substring(5).split('|');
            await s.typeInto(parts[0], parts[1].replaceAll('@mosque', story.mosque.accessCode).replaceAll('@omar', story.omar.code).replaceAll('@saeed', story.saeed.code).replaceAll('@abdullah', story.abdullah.code).replaceAll('@other', story.otherMosque.accessCode));
          } else if (x == 'dump') {
            dump('$role / ${chain.join(' > ')}');
          } else if (x == 'back') {
            await s.closeTop();
          } else if (x.isNotEmpty) {
            await s.scrollToTop();
            await s.tapText(x);
          }
        }
        dump('$role: ${chain.join(' > ')}');
      } catch (e) {
        stdout.writeln('✗ explore failed [$item]: $e');
        stdout.writeln('tabs=${find.byType(Tab).evaluate().length} dialogs=${find.byType(Dialog).evaluate().length} sheets=${find.byType(BottomSheet).evaluate().length} routes=${find.byType(ModalBarrier).evaluate().length}');
        dump('FAILSTATE');
      }
    }
  });
}
