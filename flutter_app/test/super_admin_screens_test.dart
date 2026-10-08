import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/screens/super_admin_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/widgets/super_admin_login_dialog.dart';

/// شاشة المشرف العام ونافذة دخوله على عرض الهاتف: لا شيء يفيض خارج البطاقة، وخانة كلمة
/// المرور ليست ملتصقة بخانة البريد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longName = 'جامع الإمام محمد بن إدريس الشافعي الكبير في حي الميدان الوسطاني';

  group('نافذة دخول المشرف العام', () {
    Future<bool?> open(
      WidgetTester tester, {
      required Size size,
      required Future<SuperAdminLoginResult> Function(String, String) onLogin,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await showDialog<bool>(
                    context: context,
                    builder: (_) => SuperAdminLoginDialog(onLogin: onLogin),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      addTearDown(() => result);
      return result;
    }

    final email = find.byKey(const ValueKey('superAdminEmail'));
    final password = find.byKey(const ValueKey('superAdminPassword'));
    final button = find.byKey(const ValueKey('superAdminLoginButton'));

    for (final size in const [Size(320, 568), Size(390, 844), Size(1280, 800)]) {
      testWidgets('على ${size.width.toInt()}: الخانتان متباعدتان ولا شيء يفيض', (tester) async {
        await open(tester, size: size, onLogin: (_, __) async => SuperAdminLoginResult.invalidCredentials);

        expect(tester.takeException(), isNull);
        expect(find.text('دخول المشرف العام'), findsOneWidget);
        final gap = tester.getTopLeft(password).dy - tester.getBottomLeft(email).dy;
        expect(gap, greaterThanOrEqualTo(14));
        // النافذة كلها داخل الشاشة
        final dialog = tester.getRect(find.byType(AlertDialog));
        expect(dialog.left, greaterThanOrEqualTo(0));
        expect(dialog.right, lessThanOrEqualTo(size.width));
      });
    }

    testWidgets('خانتان فارغتان: رسالة داخل النافذة ولا يُستدعى الخادم', (tester) async {
      var calls = 0;
      await open(tester, size: const Size(390, 844), onLogin: (_, __) async {
        calls++;
        return SuperAdminLoginResult.success;
      });

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.text('أدخل البريد الإلكتروني وكلمة المرور'), findsOneWidget);
      expect(find.byType(SuperAdminLoginDialog), findsOneWidget);
    });

    testWidgets('بيانات خاطئة: الخطأ يظهر داخل النافذة وتبقى مفتوحة', (tester) async {
      await open(tester, size: const Size(390, 844), onLogin: (_, __) async => SuperAdminLoginResult.invalidCredentials);

      await tester.enterText(email, 'admin@example.org');
      await tester.enterText(password, 'wrong');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('superAdminLoginError')), findsOneWidget);
      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(find.byType(SuperAdminLoginDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('لا إنترنت وحساب بلا صلاحية: لكلٍّ رسالته', (tester) async {
      var result = SuperAdminLoginResult.unavailable;
      await open(tester, size: const Size(390, 844), onLogin: (_, __) async => result);

      await tester.enterText(email, 'a@b.c');
      await tester.enterText(password, 'x');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذر الوصول لخادم المصادقة'), findsOneWidget);

      result = SuperAdminLoginResult.notAuthorized;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('هذا الحساب لا يملك صلاحية المشرف العام'), findsOneWidget);
    });

    testWidgets('دخول صحيح بزر الإدخال من خانة كلمة المرور: تُغلق النافذة بنجاح', (tester) async {
      String? sentEmail, sentPassword;
      await open(tester, size: const Size(390, 844), onLogin: (e, p) async {
        sentEmail = e;
        sentPassword = p;
        return SuperAdminLoginResult.success;
      });

      await tester.enterText(email, 'admin@example.org');
      await tester.enterText(password, 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(sentEmail, 'admin@example.org');
      expect(sentPassword, 'secret');
      expect(find.byType(SuperAdminLoginDialog), findsNothing);
    });

    testWidgets('زر العين يُظهر كلمة المرور ويخفيها', (tester) async {
      await open(tester, size: const Size(390, 844), onLogin: (_, __) async => SuperAdminLoginResult.invalidCredentials);

      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
    });
  });

  group('لوحة المشرف العام', () {
    late DataService data;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({
        'token_usage_history': jsonEncode([
          {
            'token': 'REG-ABCD2345',
            'mosqueName': longName,
            'mosqueAccessCode': '',
            'timestamp': '2026-09-15T10:30:00.000',
          },
          {
            'token': 'REG-OLDTOKEN9',
            'mosqueName': 'جامع قديم حُذف من المنصة وبقي سجل تسجيله محفوظاً هنا',
            'mosqueAccessCode': 'MSQ-GONE2345',
            'timestamp': '2026-08-01T08:00:00.000',
          },
        ]),
        'registration_tokens': ['REG-WAITING22', 'REG-WAITING33'],
      });
      data = DataService();
      await data.init();
      final big = data.addMosque(
        name: longName,
        address: 'شارع الثورة، مقابل الحديقة العامة، بناء رقم 12 الطابق الأرضي',
        city: 'دمشق',
        gender: 'male',
        phone: '0911000000',
      );
      data.addMosque(name: 'جامع الروضة', address: '', city: 'حلب', gender: 'male');
      final sheikh = data.addSheikh(big.id, 'الشيخ', '0999');
      final halaqa = data.addHalaqa(mosqueId: big.id, name: 'حلقة', sheikhId: sheikh.id);
      for (var i = 0; i < 3; i++) {
        data.addStudent(mosqueId: big.id, halaqaId: halaqa.id, fullName: 'طالب $i', gender: 'male', phone: '');
      }
      final token = data.issueWomenProvisionToken(big.id)!;
      final offer = await data.inspectWomenProvisionToken(token);
      await data.redeemWomenProvisionToken(
          offer: offer!, name: 'القسم النسائي - $longName', city: 'دمشق', address: '');
    });

    for (final size in const [Size(320, 2600), Size(360, 2600), Size(412, 2600), Size(1280, 1800)]) {
      testWidgets('على ${size.width.toInt()}: بطاقات المساجد وأكوادها لا تفيض', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ChangeNotifierProvider<DataService>.value(
            value: data,
            child: const MaterialApp(
              home: Directionality(textDirection: TextDirection.rtl, child: SuperAdminScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        // أرقام الأجهزة ليست هنا: للمنصة أكثر من مشرف، والأرقام لصاحبها بكلمة سر
        expect(find.text('الأجهزة التي عليها التطبيق'), findsNothing);
        expect(find.text(longName), findsOneWidget);
        expect(find.textContaining('المساجد المسجلة في المنصة'), findsOneWidget);
        expect(find.text('REG-ABCD2345'), findsOneWidget);
        expect(find.text('سُجّل في 2026-09-15'), findsOneWidget);
        expect(find.text('حذف الجامع بالكامل'), findsWidgets);
        expect(find.text('3 طلاب'), findsOneWidget);
        // القسم النسائي بلا كود
        expect(find.text('كود هذا القسم عند إدارته وحدها، ولا يُعرض هنا.'), findsOneWidget);

        // كل بطاقة داخل عرض الشاشة
        final deleteButtons = find.text('حذف الجامع بالكامل');
        for (var i = 0; i < deleteButtons.evaluate().length; i++) {
          final rect = tester.getRect(deleteButtons.at(i));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }

        // كود تسجيل منتظر يُعرض مع زر نسخه دون أن يفيض
        await tester.tap(find.text('REG-WAITING22'));
        await tester.pump();
        expect(find.text('نسخ كود الباركود'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
