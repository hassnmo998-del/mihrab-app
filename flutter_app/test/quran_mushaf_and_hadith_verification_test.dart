import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/hadith_service.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quran Mushaf Page Flipping & Hadiths Verification', () {
    test('HadithService loads expanded Riyad Hadiths collection (60 hadiths across 12 chapters)', () {
      final hadiths = HadithService.getRiyadHadiths();
      expect(hadiths.length, equals(60));

      final chapters = HadithService.getRiyadChapters();
      expect(chapters.length, equals(12));

      // Verify specific essential chapters
      expect(chapters, contains('باب فضل القرآن الكريم وحملته وأهل الله'));
      expect(chapters, contains('باب عمارة المساجد وفضل الخطى إليها'));
      expect(chapters, contains('باب فضل العلم والعلماء ومجالس التدارس'));
      expect(chapters, contains('باب الإخلاص والنية واستحضار مراقبة الله'));
      expect(chapters, contains('باب مكارم الأخلاق والرفق والمعاملة الحسنة'));
      expect(chapters, contains('باب الأمانة والصدق وإتقان العمل والمسؤولية'));
      expect(chapters, contains('باب بر الوالدين وحقوق الأرحام والجيران'));
      expect(chapters, contains('باب حفظ اللسان والتحذير من آفات الكلام'));
      expect(chapters, contains('باب التعاون والتكافل والرحمة بالمسلمين'));
      expect(chapters, contains('باب الصبر واليقين والتوكل على الله'));
      expect(chapters, contains('باب فضل الصدقة والإنفاق وسخاء النفس'));
      expect(chapters, contains('باب الدعاء والاستغفار وذكر الله العظيم'));

      // Verify all hadiths have complete attributes
      for (final h in hadiths) {
        expect(h.number, isPositive);
        expect(h.title.isNotEmpty, isTrue);
        expect(h.narrator.isNotEmpty, isTrue);
        expect(h.matn.isNotEmpty, isTrue);
        expect(h.source.isNotEmpty, isTrue);
        expect(h.fawaid.isNotEmpty, isTrue);
        expect(h.book, equals('riyad'));
      }
    });

    testWidgets('QuranPageMushafView renders with reverse: false for natural page turns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranPageMushafView(
                  initialPage: 1,
                  isDark: false,
                  onClose: () {},
                  onSaveBookmark: (_, __, ___, ____) {},
                ),
              ),
            ),
          ),
        ),
      );

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      final pageViewWidget = tester.widget<PageView>(pageViewFinder);
      expect(pageViewWidget.reverse, isFalse, reason: 'PageView reverse should be false to match natural page flipping');
    });
  });
}
