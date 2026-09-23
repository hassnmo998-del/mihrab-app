import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/hadith_service.dart';
import 'package:flutter_app/services/bukhari_sections.dart';
import 'package:flutter_app/services/muslim_sections.dart';
import 'package:flutter_app/screens/discover/widgets/hadith_encyclopedia_view.dart';
import 'package:flutter_app/screens/discover/widgets/hadith_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hadith Encyclopedia Full Datasets Tests (15,200+ Hadiths)', () {
    test('Bukhari Arabic sections mapping contains 98 books', () {
      final chapters = HadithService.getChaptersByBook('bukhari');
      expect(chapters.length, 98);
      expect(chapters.contains('كتاب بدء الوحي'), isTrue);
      expect(chapters.contains('كتاب الإيمان'), isTrue);
      expect(chapters.contains('كتاب التوحيد والرد على الجهمية'), isTrue);

      final ch1 = BukhariSections.getChapterName(1, 1);
      expect(ch1, 'كتاب بدء الوحي');
    });

    test('Muslim Arabic sections mapping contains 57 books', () {
      final chapters = HadithService.getChaptersByBook('muslim');
      expect(chapters.length, 57);
      expect(chapters.contains('مقدمة صحيح مسلم'), isTrue);
      expect(chapters.contains('كتاب الإيمان'), isTrue);
      expect(chapters.contains('كتاب الجنة وصفة نعيمها وأهلها'), isTrue);

      final ch1 = MuslimSections.getChapterName(1, 100);
      expect(ch1, 'كتاب الإيمان');
    });

    test('Loads Sahih al-Bukhari full dataset (7,589 hadiths)', () async {
      await HadithService.ensureBukhariLoaded();
      final bukhari = HadithService.getBukhariHadiths();
      expect(bukhari.length, greaterThan(7550));

      final first = bukhari.first;
      expect(first.number, 1);
      expect(first.book, 'bukhari');
      expect(first.chapter, 'كتاب بدء الوحي');
      expect(first.matn.contains('الاعمال بالنيات'), isTrue);
    });

    test('Loads Sahih Muslim full dataset (7,360 non-empty hadiths)', () async {
      await HadithService.ensureMuslimLoaded();
      final muslim = HadithService.getMuslimHadiths();
      expect(muslim.length, greaterThan(7300));

      final sample = muslim.first;
      expect(sample.book, 'muslim');
      expect(sample.matn.isNotEmpty, isTrue);
    });

    test('Loads Forty Hadith Qudsi complete collection (40 hadiths)', () async {
      await HadithService.ensureQudsiLoaded();
      final qudsi = HadithService.getQudsiHadiths();
      expect(qudsi.length, 40);
      for (final h in qudsi) {
        expect(h.number, greaterThan(0));
        expect(h.matn.isNotEmpty, isTrue);
        expect(h.book, 'qudsi');
      }
    });

    test('Muttafaq Alayh collection has verified data', () {
      final muttafaq = HadithService.getMuttafaqHadiths();
      expect(muttafaq.isNotEmpty, isTrue);
      for (final h in muttafaq) {
        expect(h.number > 0, isTrue);
        expect(h.title.isNotEmpty, isTrue);
        expect(h.matn.isNotEmpty, isTrue);
        expect(h.source.contains('البخاري') || h.source.contains('مسلم'), isTrue);
        expect(h.chapter.isNotEmpty, isTrue);
        expect(h.book, 'muttafaq');
      }
    });
  });

  group('Hadith Encyclopedia Widget Responsive Tests', () {
    testWidgets('HadithEncyclopediaView renders on mobile screen (width 390) with pagination', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HadithEncyclopediaView(isDark: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('صحيح البخاري'), findsWidgets);
      expect(find.textContaining('صحيح مسلم'), findsOneWidget);
      expect(find.textContaining('الأحاديث القدسية'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(HadithCard), findsWidgets);
      expect(find.textContaining('عرض'), findsWidgets);
    });

    testWidgets('HadithEncyclopediaView switches books and renders on desktop wide screen (width 1280)', (tester) async {
      tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HadithEncyclopediaView(isDark: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Sahih Muslim
      await tester.tap(find.textContaining('صحيح مسلم'));
      await tester.pumpAndSettle();

      expect(find.byType(HadithCard), findsWidgets);
      expect(find.byType(Row), findsWidgets);
    });
  });
}
