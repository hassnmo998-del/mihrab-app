import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/discover/widgets/mosque_donations_view.dart';
import 'package:flutter_app/screens/discover_screen.dart';
import 'package:flutter_app/services/data_service.dart';

/// بحث «اكتشف» والتبرع من الواجهة: الفلترة فورية على ما في الجهاز، متسامحة مع الحروف
/// المتشابهة، ولها حالات فارغة واضحة. (طلب الخادم نفسه يُجرَّب على السيرفر الحقيقي
/// في `discover_search_test.dart` وفي فحوص التسليم.)
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

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: home))),
      ),
    );
    await tester.pump();
  }

  Mosque newMosque(String name, String city, {bool donation = false}) {
    final m = data.addMosque(name: name, address: '', city: city, gender: 'male');
    if (donation) {
      data.updateMosqueDonationSettings(
        mosqueId: m.id,
        isEnabled: true,
        accountName: name,
        accountNumber: '123456',
      );
    }
    return m;
  }

  void lessonAt(Mosque mosque, String title) => data.addCommunityEvent(
        mosqueId: mosque.id,
        title: title,
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(const Duration(hours: 3)),
        organizerType: 'mosque',
        organizerName: 'إدارة المسجد',
        isRecurring: false,
      );

  final field = find.byKey(const ValueKey('discoverSearchField'));

  group('اكتشف', () {
    late Mosque aleppo;
    late Mosque homs;

    setUpAll(() {
      aleppo = newMosque('جامع الروضة', 'حلب');
      homs = newMosque('جامع النور', 'حمص');
      lessonAt(aleppo, 'درس بحلب أول');
      lessonAt(homs, 'درس بحمص ثاني');
    });

    testWidgets('البحث بمسجد أو مدينة يُبقي المطابق فقط، ويتسامح مع ة/ه وأ/ا', (tester) async {
      await pump(tester, DiscoverScreen(onOpenScanner: () {}));

      expect(find.text('درس بحلب أول'), findsOneWidget);
      expect(find.text('درس بحمص ثاني'), findsOneWidget);

      // اسم المسجد بهاء بدل التاء المربوطة
      await tester.enterText(field, 'الروضه');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('درس بحلب أول'), findsOneWidget);
      expect(find.text('درس بحمص ثاني'), findsNothing);
      expect(find.text('نتائج البحث عن «الروضه»'), findsOneWidget);

      // مدينة المسجد
      await tester.enterText(field, 'حمص');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('درس بحلب أول'), findsNothing);
      expect(find.text('درس بحمص ثاني'), findsOneWidget);

      // عنوان الدرس نفسه
      await tester.enterText(field, 'أول');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('درس بحلب أول'), findsOneWidget);
      expect(find.text('درس بحمص ثاني'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('لا نتيجة: رسالة واضحة، والمسح يعيد كل شيء', (tester) async {
      await pump(tester, DiscoverScreen(onOpenScanner: () {}));

      await tester.enterText(field, 'تمبكتو');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('لا توجد مجالس تطابق «تمبكتو»'), findsOneWidget);
      expect(find.text('درس بحلب أول'), findsNothing);

      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('درس بحلب أول'), findsOneWidget);
      expect(find.text('درس بحمص ثاني'), findsOneWidget);
      expect(find.textContaining('لا توجد مجالس تطابق'), findsNothing);
    });

    testWidgets('حرف واحد لا يبحث (لا يُفرغ القائمة)', (tester) async {
      await pump(tester, DiscoverScreen(onOpenScanner: () {}));
      await tester.enterText(field, 'ح');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('درس بحلب أول'), findsOneWidget);
      expect(find.text('درس بحمص ثاني'), findsOneWidget);
    });

    testWidgets('خانة بحث المجالس تختفي في تبويب التبرع (له خانته)', (tester) async {
      await pump(tester, DiscoverScreen(onOpenScanner: () {}));
      expect(field, findsOneWidget);

      final tab = find.textContaining('التبرع للمساجد');
      await tester.ensureVisible(tab); // التبويبات شريط أفقي قابل للتمرير
      await tester.pump();
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 300));
      expect(field, findsNothing);
      expect(find.text('ابحث باسم المسجد أو المدينة للتبرع...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('التبرع للمساجد', () {
    setUpAll(() {
      newMosque('جامع التقوى', 'اللاذقية', donation: true);
      newMosque('جامع الفرقان', 'درعا', donation: true);
    });

    testWidgets('بحث بحروف مختلفة يجد المسجد، ولا يُظهر غيره', (tester) async {
      await pump(tester, const MosqueDonationsView());
      expect(find.text('جامع التقوى'), findsWidgets);
      expect(find.text('جامع الفرقان'), findsWidgets);

      final box = find.byType(TextField);
      await tester.enterText(box, 'التقوي'); // ياء بدل الألف المقصورة لا فرق، وهنا ياء أصلية
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('جامع التقوى'), findsWidgets);
      expect(find.text('جامع الفرقان'), findsNothing);

      await tester.enterText(box, 'درعا');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('جامع الفرقان'), findsWidgets);
      expect(find.text('جامع التقوى'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('لا تطابق: رسالة «لا توجد مساجد تطابق»', (tester) async {
      await pump(tester, const MosqueDonationsView());
      await tester.enterText(find.byType(TextField), 'تمبكتو');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('لا توجد مساجد تطابق «تمبكتو»'), findsOneWidget);
    });
  });
}
