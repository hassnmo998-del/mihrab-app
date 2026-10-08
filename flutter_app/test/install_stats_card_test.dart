import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/install_stats.dart';
import 'package:flutter_app/screens/install_stats/install_stats_card.dart';

/// بطاقة «الأجهزة التي عليها التطبيق»: الأرقام كما وصلت، لا شيء يفيض على عرض الهاتف،
/// ولكل خطأ رسالته وطريقه.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 10, 8);

  InstallStats sample({int days = 30}) => InstallStats(
        today: today,
        countingSince: today.subtract(Duration(days: days - 1)),
        installed: 1284,
        total: 1350,
        openedToday: 312,
        opened7d: 870,
        new7d: 45,
        byPlatform: const [
          InstallCount('android', 980),
          InstallCount('windows', 210),
          InstallCount('ios', 94),
        ],
        byVersion: const [
          InstallCount('1.0.14', 800),
          InstallCount('1.0.13', 300),
          InstallCount('1.0.12', 100),
          InstallCount('1.0.11', 50),
          InstallCount('1.0.10', 20),
          InstallCount('', 14),
        ],
        daily: [
          for (var i = 29; i >= 0; i--)
            InstallDay(today.subtract(Duration(days: i)), 900 + i, i == 3 ? 401 : 200 + (i * 7) % 90),
        ],
      );

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required Future<InstallStats> Function() load,
    VoidCallback? onEnterSecret,
    InstallStats? initial,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: InstallStatsCard(
                load: load,
                initial: initial,
                onEnterSecret: onEnterSecret,
                clock: () => DateTime(2026, 10, 8, 17, 52),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(320, 1800), Size(390, 1800), Size(1280, 1400)]) {
    for (final brightness in Brightness.values) {
      testWidgets('على ${size.width.toInt()} (${brightness.name}): الأرقام ظاهرة ولا شيء يفيض', (tester) async {
        await pump(tester, size: size, brightness: brightness, load: () async => sample());

        expect(tester.takeException(), isNull);
        expect(find.text('الأجهزة التي عليها التطبيق'), findsOneWidget);
        expect(find.text('1,284'), findsOneWidget);
        expect(find.text('ظهر عليها التطبيق خلال آخر 30 يوماً'), findsOneWidget);
        expect(find.text('312'), findsOneWidget);
        expect(find.text('870'), findsOneWidget);
        expect(find.text('45'), findsOneWidget);
        expect(find.text('حُدّث 5:52 م'), findsOneWidget);

        // المنصات بأسمائها ونسبها
        expect(find.text('أندرويد'), findsOneWidget);
        expect(find.text('ويندوز'), findsOneWidget);
        expect(find.text('آيفون'), findsOneWidget);
        expect(find.text('980  ·  76%'), findsOneWidget);

        // الإصدارات: أكثر أربعة ثم «أخرى»
        expect(find.text('v1.0.14'), findsOneWidget);
        expect(find.text('v1.0.11'), findsOneWidget);
        expect(find.text('أخرى'), findsOneWidget);
        expect(find.text('v1.0.10'), findsNothing);

        // قيمة الذروة وحدها فوق عمودها
        expect(find.byKey(const ValueKey('installStatsPeak')), findsOneWidget);
        expect(find.text('401'), findsOneWidget);

        // كل شيء داخل الشاشة
        final card = tester.getRect(find.byKey(const ValueKey('installStatsCard')));
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        for (final text in ['1,284', 'جديدة هذا الأسبوع', 'اليوم', 'أخرى']) {
          final r = tester.getRect(find.text(text).first);
          expect(r.left, greaterThanOrEqualTo(card.left), reason: text);
          expect(r.right, lessThanOrEqualTo(card.right), reason: text);
        }
      });
    }
  }

  testWidgets('المنحنى يبدأ من يوم بدء العدّ لا من أصفار قبله', (tester) async {
    final s = sample(days: 5);
    await pump(tester, size: const Size(390, 1600), load: () async => s);
    final first = s.countingSince!;
    final label = '${first.year}/${first.month.toString().padLeft(2, '0')}/${first.day.toString().padLeft(2, '0')}';
    expect(find.text(label), findsOneWidget);
    expect(find.byType(Tooltip), findsNWidgets(5 + 1)); // خمسة أعمدة + زر التحديث
  });

  testWidgets('يوم واحد فقط من العدّ: لا منحنى بعد', (tester) async {
    await pump(tester, size: const Size(390, 1600), load: () async => sample(days: 1));
    expect(find.text('أجهزة فُتح عليها التطبيق، يوماً بيوم'), findsNothing);
    expect(find.text('1,284'), findsOneWidget);
  });

  testWidgets('لم يُعدّ أي جهاز بعد: رسالة لا أصفار', (tester) async {
    await pump(
      tester,
      size: const Size(390, 900),
      load: () async => InstallStats(
        today: today,
        countingSince: null,
        installed: 0,
        total: 0,
        openedToday: 0,
        opened7d: 0,
        new7d: 0,
        byPlatform: const [],
        byVersion: const [],
        daily: const [],
      ),
    );
    expect(find.textContaining('لم يُعدّ أي جهاز بعد'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('كلمة السر المحفوظة لم تعد صالحة: زر يعيد إلى خانتها', (tester) async {
    var asked = 0;
    await pump(
      tester,
      size: const Size(390, 900),
      load: () async => throw const InstallStatsException(InstallStatsError.wrongSecret),
      onEnterSecret: () => asked++,
    );
    expect(find.text('كلمة السر المحفوظة على هذا الجهاز لم تعد صالحة.'), findsOneWidget);
    await tester.tap(find.text('إدخال كلمة السر'));
    expect(asked, 1);
  });

  testWidgets('محاولات خاطئة كثيرة: رسالتها وإعادة المحاولة', (tester) async {
    var locked = true;
    await pump(
      tester,
      size: const Size(390, 1600),
      load: () async {
        if (locked) throw const InstallStatsException(InstallStatsError.tooManyAttempts);
        return sample();
      },
    );
    expect(find.text('محاولات خاطئة كثيرة. أعد المحاولة بعد دقائق.'), findsOneWidget);
    locked = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('1,284'), findsOneWidget);
  });

  testWidgets('أرقام وصلت عند فتح القفل تُعرض فوراً بلا طلب ثانٍ', (tester) async {
    var calls = 0;
    await pump(
      tester,
      size: const Size(390, 1600),
      initial: sample(),
      load: () async {
        calls++;
        return sample();
      },
    );
    expect(calls, 0);
    expect(find.text('1,284'), findsOneWidget);
  });

  testWidgets('لا إنترنت: إعادة المحاولة تجلب الأرقام', (tester) async {
    var online = false;
    await pump(
      tester,
      size: const Size(390, 1600),
      load: () async {
        if (!online) throw const InstallStatsException(InstallStatsError.unavailable);
        return sample();
      },
    );
    expect(find.textContaining('تعذّر الوصول إلى الخادم'), findsOneWidget);
    online = true;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('1,284'), findsOneWidget);
  });

  testWidgets('فشل التحديث بعد أرقام سابقة: تبقى الأرقام مع تنبيه', (tester) async {
    var fail = false;
    await pump(
      tester,
      size: const Size(390, 1600),
      load: () async {
        if (fail) throw const InstallStatsException(InstallStatsError.unavailable);
        return sample();
      },
    );
    fail = true;
    await tester.tap(find.byKey(const ValueKey('installStatsRefresh')));
    await tester.pumpAndSettle();
    expect(find.text('1,284'), findsOneWidget);
    expect(find.text('تعذّر التحديث الآن، هذه آخر أرقام وصلت.'), findsOneWidget);
  });

  testWidgets('خطأ غير متوقع من المصدر يُعرض كتعذّر وصول لا انهيار', (tester) async {
    await pump(tester, size: const Size(390, 900), load: () async => throw StateError('boom'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('تعذّر الوصول إلى الخادم'), findsOneWidget);
  });
}
