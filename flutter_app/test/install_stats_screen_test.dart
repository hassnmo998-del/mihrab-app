import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/models/install_stats.dart';
import 'package:flutter_app/screens/install_stats/install_stats_screen.dart';
import 'package:flutter_app/services/install_presence.dart';
import 'package:flutter_app/widgets/secret_tap_target.dart';

/// أرقام التطبيق لصاحب المشروع وحده: مدخل مخفي، وكلمة سر يفحصها الخادم، تُحفظ على
/// الجهاز بعد أول دخول ويمسحها زر القفل.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secret = 'test-only-not-real';
  final today = DateTime(2026, 10, 8);
  final stats = InstallStats(
    today: today,
    countingSince: today.subtract(const Duration(days: 3)),
    installed: 57,
    total: 60,
    openedToday: 21,
    opened7d: 50,
    new7d: 9,
    byPlatform: const [InstallCount('android', 40), InstallCount('windows', 17)],
    byVersion: const [InstallCount('1.0.15', 57)],
    daily: [for (var i = 3; i >= 0; i--) InstallDay(today.subtract(Duration(days: i)), 50, 20 + i)],
  );

  late List<String> tried;

  /// خادم مزيّف: كلمة السر نفسها بأي كتابة (أحرف كبيرة، مسافات، شرطات) تُقبل.
  Future<InstallStats> server(String sent) async {
    tried.add(sent);
    if (InstallPresence.normalizeSecret(sent) != InstallPresence.normalizeSecret(secret)) {
      throw const InstallStatsException(InstallStatsError.wrongSecret);
    }
    return stats;
  }

  Future<void> open(WidgetTester tester, {Future<InstallStats> Function(String)? load}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: InstallStatsScreen(load: load ?? server),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final field = find.byKey(const ValueKey('installStatsSecret'));
  final unlock = find.byKey(const ValueKey('installStatsUnlock'));
  final error = find.byKey(const ValueKey('installStatsSecretError'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tried = [];
  });

  testWidgets('مقفلة أولاً: لا رقم قبل كلمة السر', (tester) async {
    await open(tester);
    expect(find.text('هذه الصفحة بكلمة سر'), findsOneWidget);
    expect(find.text('57'), findsNothing);
    expect(tried, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('كلمة سر خاطئة: رسالة وتبقى مقفلة ولا تُحفظ', (tester) async {
    await open(tester);
    await tester.enterText(field, 'guess-1234');
    await tester.tap(unlock);
    await tester.pumpAndSettle();

    expect(find.text('كلمة السر غير صحيحة'), findsOneWidget);
    expect(find.text('هذه الصفحة بكلمة سر'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(InstallStatsScreen.secretPrefsKey), isNull);
  });

  testWidgets('خانة فارغة: لا يُسأل الخادم', (tester) async {
    await open(tester);
    await tester.enterText(field, '  - ');
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    expect(find.text('اكتب كلمة السر'), findsOneWidget);
    expect(tried, isEmpty);
  });

  testWidgets('كلمة السر الصحيحة بأي كتابة: الأرقام فوراً، وتُحفظ على الجهاز', (tester) async {
    await open(tester);
    await tester.enterText(field, ' TEST only NOT real ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('57'), findsOneWidget);
    expect(find.text('الأجهزة التي عليها التطبيق'), findsOneWidget);
    expect(tried, hasLength(1), reason: 'الأرقام التي فتحت القفل تُعرض، بلا طلب ثانٍ');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(InstallStatsScreen.secretPrefsKey), isNotNull);
  });

  testWidgets('كلمة سر محفوظة: تُفتح مباشرة، وزر القفل ينساها', (tester) async {
    SharedPreferences.setMockInitialValues({InstallStatsScreen.secretPrefsKey: secret});
    await open(tester);
    expect(find.text('57'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('installStatsLock')));
    await tester.pumpAndSettle();
    expect(find.text('هذه الصفحة بكلمة سر'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(InstallStatsScreen.secretPrefsKey), isNull);
  });

  testWidgets('كلمة السر غُيّرت على الخادم: المحفوظة تُرفض ويعود إلى خانتها', (tester) async {
    SharedPreferences.setMockInitialValues({InstallStatsScreen.secretPrefsKey: 'old-secret'});
    await open(tester);
    expect(find.text('كلمة السر المحفوظة على هذا الجهاز لم تعد صالحة.'), findsOneWidget);

    await tester.tap(find.text('إدخال كلمة السر'));
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(InstallStatsScreen.secretPrefsKey), isNull);
  });

  testWidgets('محاولات كثيرة ولا إنترنت: لكلٍّ رسالته', (tester) async {
    var reason = InstallStatsError.tooManyAttempts;
    await open(tester, load: (_) async => throw InstallStatsException(reason));

    await tester.enterText(field, secret);
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(find.text('محاولات خاطئة كثيرة. أعد المحاولة بعد دقائق.'), findsOneWidget);

    reason = InstallStatsError.unavailable;
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الوصول إلى الخادم. تحقق من الإنترنت.'), findsOneWidget);
  });

  group('المدخل المخفي', () {
    late DateTime now;
    late int opened;

    Future<void> pumpTarget(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SecretTapTarget(
                clock: () => now,
                onTriggered: () => opened++,
                child: const Text('v1.0.15'),
              ),
            ),
          ),
        ),
      );
    }

    setUp(() {
      now = DateTime(2026, 10, 8, 20);
      opened = 0;
    });

    Future<void> taps(WidgetTester tester, int n, {Duration every = const Duration(milliseconds: 300)}) async {
      for (var i = 0; i < n; i++) {
        await tester.tap(find.text('v1.0.15'));
        now = now.add(every);
      }
    }

    testWidgets('سبع نقرات متتالية تفتح، وست لا', (tester) async {
      await pumpTarget(tester);
      await taps(tester, 6);
      expect(opened, 0);
      await taps(tester, 1);
      expect(opened, 1);
    });

    testWidgets('نقرات متباعدة لا تُحسب: النقرة العادية لا تفتح شيئاً مهما تكررت', (tester) async {
      await pumpTarget(tester);
      await taps(tester, 20, every: const Duration(seconds: 2));
      expect(opened, 0);
    });

    testWidgets('توقف في المنتصف يبدأ العدّ من جديد', (tester) async {
      await pumpTarget(tester);
      await taps(tester, 5);
      now = now.add(const Duration(seconds: 3));
      await taps(tester, 5);
      expect(opened, 0);
      await taps(tester, 2);
      expect(opened, 1);
    });
  });
}
