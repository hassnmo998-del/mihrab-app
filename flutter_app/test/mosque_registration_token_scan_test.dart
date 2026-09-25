import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/utils/access_code_generator.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/admin/widgets/new_mosque_registration_form.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/code_scanner_dialog.dart';

/// الخلل الذي تحرسه هذه الاختبارات: باركود المشرف العام (`REG-`) كان يُمرَّر
/// في الماسح العام إلى `verifyCode` فيُبحث عنه في المساجد والمشايخ والطلاب
/// فقط، فيُرفض دائماً بـ"الكود غير صحيح" ولا تُفتح لوحة إنشاء الجامع.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  late DataService dataService;
  ActiveSession? unlockedSession;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataService = DataService();
    await dataService.init();
    unlockedSession = null;
  });

  Future<void> openScannerAndSubmit(WidgetTester tester, String code) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: dataService,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => CodeScannerDialog(
                      onSessionUnlocked: (s) => unlockedSession = s,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('تأكيد الدخول المعتمد'));
    await tester.pumpAndSettle();
  }

  test('بادئة REG- تُعرَّف كباركود تسجيل وليس كود دخول', () {
    expect(AccessCodeGenerator.isRegistrationToken('REG-123456-3'), isTrue);
    expect(AccessCodeGenerator.isRegistrationToken(' reg-123456-3 '), isTrue);
    expect(AccessCodeGenerator.isRegistrationToken('MSQ-ABCD2345'), isFalse);
  });

  testWidgets('مسح باركود التسجيل من الماسح العام يفتح لوحة إنشاء الجامع ويسجله', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final token = await dataService.generateRegistrationToken();
      expect(dataService.getRegistrationTokens(), contains(token));

      await openScannerAndSubmit(tester, token);

      expect(find.byType(NewMosqueRegistrationScreen), findsOneWidget);
      expect(find.text('الكود غير صحيح أو لم يتم العثور على صاحب هذا الرمز في المنظومة'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'اسم المسجد *'), 'جامع التوبة');
      await tester.tap(find.text('اعتماد المسجد والبدء في الإدارة فوراً'));
      await tester.pumpAndSettle();

      expect(find.byType(NewMosqueRegistrationScreen), findsNothing);
      expect(unlockedSession?.role, 'mosque_admin');
      expect(unlockedSession?.mosqueName, 'جامع التوبة');

      // يظهر عند المشرف العام: الكود خرج من النشطة ودخل السجل مع الجامع وكوده
      expect(dataService.getRegistrationTokens(), isNot(contains(token)));
      final entry = dataService.getTokenUsageHistory().firstWhere((h) => h['token'] == token);
      expect(entry['mosqueName'], 'جامع التوبة');
      expect(entry['mosqueAccessCode'], unlockedSession?.code);

      // ترك مؤقت الـ SnackBar ينتهي قبل إغلاق الاختبار
      await tester.pump(const Duration(seconds: 5));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('باركود تسجيل غير موجود يعرض سبباً واضحاً بدل خطأ الدخول العام', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await openScannerAndSubmit(tester, 'REG-000000-99');

      expect(find.byType(NewMosqueRegistrationScreen), findsNothing);
      expect(find.byType(CodeScannerDialog), findsOneWidget);
      expect(find.textContaining('باركود التسجيل'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
