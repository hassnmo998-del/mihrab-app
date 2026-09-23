import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/quran_service.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quran Mushaf Multi-Surah & Basmalah Fix Verification', () {
    setUpAll(() async {
      await QuranService.ensureLoaded();
    });

    test('toArabicDigits formats numbers into authentic Eastern Arabic numerals', () {
      expect(QuranService.toArabicDigits(1), equals('١'));
      expect(QuranService.toArabicDigits(9), equals('٩'));
      expect(QuranService.toArabicDigits(10), equals('١٠'));
      expect(QuranService.toArabicDigits(64), equals('٦٤'));
      expect(QuranService.toArabicDigits(604), equals('٦٠٤'));
    });

    test('formatAyahBracket wraps ayah number in authentic inward-curving ornate brackets', () {
      expect(QuranService.formatAyahBracket(1), equals('\uFD3F١\uFD3E'));
      expect(QuranService.formatAyahBracket(35), equals('\uFD3F٣٥\uFD3E'));
      expect(QuranService.formatAyahBracket(64), equals('\uFD3F٦٤\uFD3E'));
    });

    test('Basmalah is completely stripped from Ayah 1 of Surah 25 (Al-Furqan)', () {
      final page359 = QuranService.getPage(359);
      expect(page359, isNotNull);
      expect(page359!.surahNumbers, equals([24, 25]));

      final furqanAyah1 = page359.ayahs.firstWhere(
        (a) => a.surahNumber == 25 && a.ayahNumberInSurah == 1,
      );
      expect(furqanAyah1.uthmaniText.startsWith('تَبَارَكَ ٱلَّذِى نَزَّلَ'), isTrue);
      expect(furqanAyah1.uthmaniText.contains('بِسْمِ'), isFalse);
    });

    test('Basmalah is stripped from Surah 95 (At-Tin) and Surah 97 (Al-Qadr) despite shaddah', () {
      final page597 = QuranService.getPage(597);
      expect(page597, isNotNull);
      final tinAyah1 = page597!.ayahs.firstWhere(
        (a) => a.surahNumber == 95 && a.ayahNumberInSurah == 1,
      );
      expect(tinAyah1.uthmaniText.startsWith('وَٱلتِّينِ وَٱلزَّيْتُونِ'), isTrue);
      expect(tinAyah1.uthmaniText.contains('بِسْمِ'), isFalse);

      final page598 = QuranService.getPage(598);
      expect(page598, isNotNull);
      final qadrAyah1 = page598!.ayahs.firstWhere(
        (a) => a.surahNumber == 97 && a.ayahNumberInSurah == 1,
      );
      expect(qadrAyah1.uthmaniText.startsWith('إِنَّآ أَنزَلْنَٰهُ فِى لَيْلَةِ ٱلْقَدْرِ'), isTrue);
      expect(qadrAyah1.uthmaniText.contains('بِسْمِ'), isFalse);
    });

    test('All 113 Surahs (except At-Tawbah 9) do NOT contain Basmalah in Ayah 1 uthmaniText', () {
      for (int s = 2; s <= 114; s++) {
        if (s == 9) continue;
        final startPageNum = QuranService.getSurahStartPage(s);
        final page = QuranService.getPage(startPageNum);
        expect(page, isNotNull);

        final ayah1 = page!.ayahs.firstWhere((a) => a.surahNumber == s && a.ayahNumberInSurah == 1);
        expect(
          ayah1.uthmaniText.startsWith('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'),
          isFalse,
          reason: 'Surah $s Ayah 1 should not have leading Basmalah in uthmaniText',
        );
      }
    });

    test('Surah Al-Fatiha (1) keeps its Ayah 1 Basmalah as authentic first verse', () {
      final page1 = QuranService.getPage(1);
      expect(page1, isNotNull);
      final ayah1 = page1!.ayahs.firstWhere((a) => a.surahNumber == 1 && a.ayahNumberInSurah == 1);
      expect(ayah1.uthmaniText, contains('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'));
    });

    test('Surah At-Tawbah (9) on Page 187 has no Basmalah', () {
      final page187 = QuranService.getPage(187);
      expect(page187, isNotNull);
      final ayah1 = page187!.ayahs.firstWhere((a) => a.surahNumber == 9 && a.ayahNumberInSurah == 1);
      expect(ayah1.uthmaniText.startsWith('بَرَآءَةٌۭ مِّنَ ٱللَّهِ وَرَسُولِهِۦٓ'), isTrue);
      expect(ayah1.uthmaniText.contains('بِسْمِ'), isFalse);
    });

    test('Multi-surah page 359 has exact Surah transition from 24 (62-64) to 25 (1-2)', () {
      final page359 = QuranService.getPage(359)!;
      final ayahs = page359.ayahs;
      expect(ayahs.length, equals(5));

      // Surah 24 ending verses
      expect(ayahs[0].surahNumber, equals(24));
      expect(ayahs[0].ayahNumberInSurah, equals(62));
      expect(ayahs[1].surahNumber, equals(24));
      expect(ayahs[1].ayahNumberInSurah, equals(63));
      expect(ayahs[2].surahNumber, equals(24));
      expect(ayahs[2].ayahNumberInSurah, equals(64));

      // Surah 25 beginning verses
      expect(ayahs[3].surahNumber, equals(25));
      expect(ayahs[3].ayahNumberInSurah, equals(1));
      expect(ayahs[4].surahNumber, equals(25));
      expect(ayahs[4].ayahNumberInSurah, equals(2));
    });

    test('Multi-surah page 604 contains 3 surahs in sequential order: 112, 113, 114', () {
      final page604 = QuranService.getPage(604)!;
      expect(page604.surahNumbers, equals([112, 113, 114]));

      final s112Ayah1 = page604.ayahs.firstWhere((a) => a.surahNumber == 112 && a.ayahNumberInSurah == 1);
      final s113Ayah1 = page604.ayahs.firstWhere((a) => a.surahNumber == 113 && a.ayahNumberInSurah == 1);
      final s114Ayah1 = page604.ayahs.firstWhere((a) => a.surahNumber == 114 && a.ayahNumberInSurah == 1);

      expect(s112Ayah1.uthmaniText.startsWith('قُلْ هُوَ ٱللَّهُ أَحَدٌ'), isTrue);
      expect(s113Ayah1.uthmaniText.startsWith('قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ'), isTrue);
      expect(s114Ayah1.uthmaniText.startsWith('قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ'), isTrue);
    });

    testWidgets('QuranPageMushafView renders page 359 with both Surah titles and banners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranPageMushafView(
                  initialPage: 359,
                  isDark: false,
                  onClose: () {},
                  onSaveBookmark: (_, __, ___, ____) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Page top header should mention both Surah names
      expect(find.textContaining('النُّورِ'), findsWidgets);
      expect(find.textContaining('الفُرۡقَانِ'), findsWidgets);
      // Surah Al-Furqan banner should be present for Ayah 1 start
      expect(find.text('سُورَةُ الفُرۡقَانِ'), findsOneWidget);
      // Basmalah for Surah Al-Furqan
      expect(find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), findsOneWidget);
    });
  });
}
