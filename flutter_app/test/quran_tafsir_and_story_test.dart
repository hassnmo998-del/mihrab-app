import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/screens/discover/widgets/quran_ayah_tafsir_sheet.dart';
import 'package:flutter_app/screens/discover/widgets/quran_surah_story_view.dart';
import 'package:flutter_app/services/surah_story_service.dart';
import 'package:flutter_app/services/tafsir_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('TafsirService & SurahStoryService Offline Data Tests', () {
    test('TafsirService loads and provides Tafsir Al-Muyassar', () async {
      await TafsirService.ensureLoaded();
      expect(TafsirService.isLoaded, isTrue);

      // Test Al-Fatiha Ayah 1
      final fatiha1 = TafsirService.getAyahTafsir(1, 1);
      expect(fatiha1, isNotEmpty);
      expect(fatiha1, contains('الله'));

      // Test Al-Baqarah Ayah 255 (Ayat Al-Kursi)
      final kursi = TafsirService.getAyahTafsir(2, 255);
      expect(kursi, isNotEmpty);
      expect(kursi, contains('الحي'));

      // Test An-Nas Ayah 6
      final nas6 = TafsirService.getAyahTafsir(114, 6);
      expect(nas6, isNotEmpty);
    });

    test('SurahStoryService loads and provides rich stories for all 114 Surahs', () async {
      await SurahStoryService.ensureLoaded();
      expect(SurahStoryService.isLoaded, isTrue);

      // Verify Surah 1 (Al-Fatiha)
      final story1 = SurahStoryService.getStory(1);
      expect(story1, isNotNull);
      expect(story1!.name, contains('فَاتِحَة'));
      expect(story1.story, isNotEmpty);

      // Verify Surah 18 (Al-Kahf)
      final story18 = SurahStoryService.getStory(18);
      expect(story18, isNotNull);
      expect(story18!.number, 18);
      expect(story18.story, contains('أصحاب الكهف'));

      // Verify Surah 114 (An-Nas)
      final story114 = SurahStoryService.getStory(114);
      expect(story114, isNotNull);
      expect(story114!.number, 114);
      expect(story114.story, isNotEmpty);
    });
  });

  group('QuranSurahStoryView Widget Tests', () {
    testWidgets('Renders top bar with ONLY Surah name and scrolls content', (tester) async {
      await SurahStoryService.ensureLoaded();

      await tester.pumpWidget(
        const MaterialApp(
          home: QuranSurahStoryView(
            initialSurahNumber: 1,
            isDark: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title must display Surah name
      expect(find.textContaining('الفاتحة'), findsWidgets);
      // Revelation tag
      expect(find.textContaining('مكية'), findsWidgets);

      // Back button pops
      await tester.tap(find.byTooltip('رجوع للمصحف'));
      await tester.pumpAndSettle();
    });
  });

  group('QuranAyahTafsirSheet Widget Tests', () {
    testWidgets('Displays Ayah at top and Tafsir below, bounded within Surah', (tester) async {
      await TafsirService.ensureLoaded();

      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuranAyahTafsirSheet(
              surahNumber: 1,
              surahName: 'الفاتحة',
              initialAyahNumber: 1,
              totalAyahs: 7,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header details
      expect(find.text('سورة الفاتحة'), findsOneWidget);
      expect(find.text('الآية 1 من 7'), findsOneWidget);
      expect(find.text('التفسير وبيان المعنى'), findsOneWidget);

      // Copy button exists
      expect(find.text('نسخ'), findsOneWidget);

      // Audio button is removed as requested
      expect(find.byTooltip('سماع الآية'), findsNothing);
    });
  });
}
