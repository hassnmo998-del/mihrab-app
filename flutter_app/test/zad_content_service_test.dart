import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/zad_seed.dart';
import 'package:flutter_app/models/zad_content.dart';
import 'package:flutter_app/screens/discover/widgets/daily_athkar_view.dart';
import 'package:flutter_app/screens/discover/widgets/spiritual_gems_view.dart';
import 'package:flutter_app/services/zad_content_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// محتوى «الأذكار والرقية» يتحدّث بلا إصدار: يُنزَّل مرة، يُحفظ، ويبقى بلا إنترنت.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = ZadContentService.instance;
  late Directory dir;
  late List<int> askedWith;

  Map<String, dynamic> seedJson() => jsonDecode(kZadSeedJson) as Map<String, dynamic>;

  /// حزمة أحدث من المضمَّنة: نوع أذكار جديد، ذكر صباح مُعدَّل، وتصنيف أدعية جديد.
  Map<String, dynamic> newerPack({int? rev}) {
    final pack = seedJson();
    pack['rev'] = rev ?? kZadSeedRev + 1;
    (pack['athkar'] as List).add({
      'id': 'travel',
      'title': 'أذكار السفر ✈️',
      'items': [
        {'text': 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا', 'virtue': 'دعاء الركوب', 'count': 1},
      ],
    });
    ((pack['athkar'] as List).first['items'] as List).first['text'] = 'نص ذكر الصباح بعد التعديل';
    (pack['duaCategories'] as List).add({'id': 'istikhara', 'title': 'الاستخارة 🧭'});
    (pack['duas'] as List).add({
      'id': 'dua_istikhara',
      'category': 'istikhara',
      'title': 'دعاء الاستخارة',
      'text': 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ',
      'source': 'صحيح البخاري',
    });
    return pack;
  }

  /// كما يفعل Supabase: يعيد الصف فقط إن كانت مراجعته أحدث مما عند السائل.
  ZadPackFetcher serving(Map<String, dynamic>? pack) => (currentRev) async {
        askedWith.add(currentRev);
        if (pack == null || (pack['rev'] as int) <= currentRev) return null;
        return {'rev': pack['rev'], 'payload': pack};
      };

  File storedFile() => File('${dir.path}${Platform.pathSeparator}content${Platform.pathSeparator}zad.json');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('mihrab_zad_test');
    askedWith = [];
    service.debugReset(fetcher: serving(null), dir: dir.path);
  });

  tearDown(() {
    service.debugReset();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('النسخة المضمَّنة (ما يولّده tool/zad/publish.mjs) يقبلها التطبيق وتعمل بلا شبكة', () {
    final content = service.content;

    expect(content.rev, kZadSeedRev);
    expect(content.athkar.map((c) => c.id), containsAll(['morning', 'evening', 'prayer', 'sleep']));
    expect(content.athkar.every((c) => c.items.isNotEmpty), isTrue);
    expect(content.duas, isNotEmpty);
    expect(content.duaCategories.map((c) => c.id).toSet(), content.duas.map((d) => d.category).toSet());
    expect(content.rewards, isNotEmpty);
    expect(content.pearls, isNotEmpty);
    expect(askedWith, isEmpty);
  });

  test('محتوى أحدث: يُنزَّل مرة، يُحفظ على الجهاز، ويُعرض', () async {
    service.debugReset(fetcher: serving(newerPack()), dir: dir.path);
    var notified = 0;
    service.addListener(() => notified++);

    expect(await service.sync(), isTrue);

    expect(askedWith, [kZadSeedRev]);
    expect(service.content.rev, kZadSeedRev + 1);
    expect(service.content.athkar.map((c) => c.id), contains('travel'));
    expect(service.content.athkar.first.items.first.text, 'نص ذكر الصباح بعد التعديل');
    expect(service.content.duas.last.categoryName, 'الاستخارة 🧭');
    expect(notified, 1);
    expect(storedFile().existsSync(), isTrue);

    // سؤال ثانٍ والخادم بلا جديد: لا تنزيل ولا تغيير
    expect(await service.sync(), isFalse);
    expect(askedWith, [kZadSeedRev, kZadSeedRev + 1]);
    expect(notified, 1);
  });

  test('بعد إعادة فتح التطبيق بلا إنترنت: ما نزل يبقى', () async {
    service.debugReset(fetcher: serving(newerPack()), dir: dir.path);
    await service.sync();

    // «إعادة فتح» والشبكة مقطوعة
    service.debugReset(fetcher: (_) async => throw const SocketException('offline'), dir: dir.path);
    expect(service.content.rev, kZadSeedRev); // قبل قراءة القرص: المضمَّن
    await service.init();

    expect(service.content.rev, kZadSeedRev + 1);
    expect(service.content.athkar.map((c) => c.id), contains('travel'));
    expect(await service.sync(), isFalse);
    expect(service.content.athkar.map((c) => c.id), contains('travel'));
  });

  test('إصدار جديد يحمل محتوى أحدث مما حُفظ قديماً: المضمَّن يغلب', () async {
    final old = seedJson()..['rev'] = kZadSeedRev - 1;
    (old['athkar'] as List).removeLast();
    storedFile()
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(old));
    if (kZadSeedRev - 1 < 1) return; // لا مراجعة أقدم من الأولى

    await service.init();

    expect(service.content.rev, kZadSeedRev);
  });

  test('بلا إنترنت: يبقى المحتوى ولا يُرمى خطأ', () async {
    service.debugReset(fetcher: (_) async => throw const SocketException('offline'), dir: dir.path);

    expect(await service.sync(), isFalse);

    expect(service.content.rev, kZadSeedRev);
    expect(storedFile().existsSync(), isFalse);
  });

  for (final (name, breakIt) in <(String, void Function(Map<String, dynamic>))>[
    ('نوع أذكار بلا أذكار', (p) => (p['athkar'] as List).first['items'] = <dynamic>[]),
    ('ذكر بلا نص', (p) => ((p['athkar'] as List).first['items'] as List).first['text'] = '  '),
    ('عدد تكرار صفر', (p) => ((p['athkar'] as List).first['items'] as List).first['count'] = 0),
    ('دعاء بتصنيف غير معرَّف', (p) => (p['duas'] as List).first['category'] = 'nowhere'),
    ('معرّف دعاء مكرر', (p) => (p['duas'] as List).add((p['duas'] as List).first)),
    ('قائمة الأذكار مفقودة', (p) => p.remove('athkar')),
    ('مخطط أحدث مما يفهمه هذا الإصدار', (p) => p['schema'] = ZadContent.supportedSchema + 1),
  ]) {
    test('حزمة معطوبة ($name): لا تُعرض ولا تُحفظ، ويبقى ما كان', () async {
      final broken = newerPack();
      breakIt(broken);
      service.debugReset(fetcher: serving(broken), dir: dir.path);

      expect(await service.sync(), isFalse);

      expect(service.content.rev, kZadSeedRev);
      expect(storedFile().existsSync(), isFalse);
    });
  }

  test('فتح التبويب مراراً يسأل الخادم مرة واحدة كل بضع ساعات', () async {
    service.refreshIfStale();
    await service.sync(); // ينتظر السؤال الجاري نفسه
    expect(askedWith.length, 1);

    service.refreshIfStale();
    service.refreshIfStale();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(askedWith.length, 1);
  });

  group('الواجهة تتبع المحتوى', () {
    // الأزرار في شريط يُمرَّر أفقياً: يُجلب الزر إلى الشاشة ثم يُضغط
    Future<void> tapChip(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
    }

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
      await tester.pump();
    }

    testWidgets('نوع ذكر جديد يظهر زره وأذكاره دون تعديل في التطبيق', (tester) async {
      service.debugReset(fetcher: serving(newerPack()), dir: dir.path);
      await pump(tester, const DailyAthkarView(isDark: false));
      expect(find.text('أذكار السفر ✈️'), findsNothing);
      expect(find.textContaining('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsOneWidget);

      await tester.runAsync(service.sync);
      await tester.pump();

      // الذكر المُعدَّل حلّ محلّ القديم، والنوع الجديد ظهر
      expect(find.text('نص ذكر الصباح بعد التعديل'), findsOneWidget);
      expect(find.textContaining('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsNothing);
      await tapChip(tester, 'أذكار السفر ✈️');
      expect(find.textContaining('سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تصنيف أدعية جديد يظهر زره ويصفّي أدعيته', (tester) async {
      service.debugReset(fetcher: serving(newerPack()), dir: dir.path);
      await tester.runAsync(service.sync);
      await pump(tester, const SpiritualGemsView(isDark: false));

      await tapChip(tester, 'الاستخارة 🧭');

      expect(find.text('دعاء الاستخارة'), findsOneWidget);
      expect(find.textContaining('الفاتحة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('النوع المختار حُذف من المحتوى: يُعرض الأول بلا انهيار', (tester) async {
      final withTravel = newerPack();
      service.debugReset(fetcher: serving(withTravel), dir: dir.path);
      await tester.runAsync(service.sync);
      await pump(tester, const DailyAthkarView(isDark: false));
      await tapChip(tester, 'أذكار السفر ✈️');

      final withoutTravel = newerPack(rev: kZadSeedRev + 2)
        ..['athkar'] = ((seedJson()['athkar'] as List)..removeLast());
      service.debugReset(fetcher: serving(withoutTravel), dir: dir.path);
      await tester.runAsync(service.sync);
      await tester.pump();

      expect(find.text('أذكار السفر ✈️'), findsNothing);
      expect(find.textContaining('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
