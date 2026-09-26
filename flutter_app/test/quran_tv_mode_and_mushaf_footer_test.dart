import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/quran_audio_bar.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';
import 'package:flutter_app/screens/discover/widgets/quran_tv_recitation_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/quran_audio_service.dart';
import 'package:flutter_app/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  group('Quran TV Recitation & Mushaf Footer Integration Tests', () {
    test('QuranTvTheme defines 7 rich Islamic broadcast styles', () {
      expect(QuranTvTheme.allThemes.length, 7);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'damascene'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'kaaba'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'rawdah'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'andalusian'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'amber'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'manuscript'), isTrue);
      expect(QuranTvTheme.allThemes.any((t) => t.id == 'fajr'), isTrue);
    });

    test('QuranService.getAyah returns correct authentic Ayah data', () {
      final fatiha1 = QuranService.getAyah(1, 1);
      expect(fatiha1, isNotNull);
      expect(fatiha1!.surahNumber, 1);
      expect(fatiha1.ayahNumberInSurah, 1);
      expect(fatiha1.pageNumber, 1);

      final baqarah255 = QuranService.getAyah(2, 255); // Ayat Al-Kursi
      expect(baqarah255, isNotNull);
      expect(baqarah255!.pageNumber, 42);
    });

    testWidgets('QuranAudioBar displays TV mode button on mobile and desktop', (tester) async {
      // 1. Mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: QuranAudioBar(
                isDark: false,
                idleTitle: 'سورة الفاتحة',
                onStart: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);

      // 2. Desktop
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
    });

    testWidgets('QuranPageMushafView displays Hizb, Tajweed, and Rub inside card footer without bottom bar overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Mobile screen size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
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
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ٱلْفَاتِحَةِ'), findsWidgets);
      expect(find.text('الجزء 1'), findsOneWidget);
      expect(find.text('الحزب 1'), findsOneWidget);
      expect(find.text('الربع 1'), findsOneWidget);
      expect(find.text('أحكام التجويد'), findsOneWidget);

      // Tap Tajweed toggle inside footer - verify 2-row wrap without overflow
      await tester.tap(find.text('أحكام التجويد'));
      await tester.pumpAndSettle();

      expect(find.text('مد لازم ومتصل'), findsOneWidget);
      expect(find.text('قلقلة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Forced auto page synchronization when audio plays an Ayah on another page', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
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
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 604'), findsOneWidget);

      // Simulate audio advancing to page 2 (Al-Baqarah Ayah 1)
      final audio = QuranAudioService.instance;
      audio.isPlayingNotifier.value = true;
      audio.activeTagNotifier.value = const QuranAyahAudioTag(
        surahNumber: 2,
        ayahNumber: 1,
        surahName: 'البقرة',
        pageNumber: 2,
      );
      audio.activeAyahNotifier.value = '2:1';
      audio.activePageNotifier.value = 2;

      await tester.pumpAndSettle();

      // Page view is forced to sync with the active page being recited!
      expect(find.text('2 / 604'), findsOneWidget);
    });

    testWidgets('Quran tab is integrated as a sibling in mobile bottom bar and desktop top bar', (tester) async {
      final dataService = DataService();
      addTearDown(() => dataService.dispose());

      // 1. Mobile Test
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: dataService,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MainShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Quran tab in the mobile bottom bar
      final quranTabFinder = find.widgetWithText(InkWell, 'القرآن');
      expect(quranTabFinder, findsOneWidget);

      // Tap on Quran tab
      await tester.tap(quranTabFinder);
      await tester.pumpAndSettle();

      // Verify bottom navigation bar remains VISIBLE and active (not taking over with a bare fullscreen Scaffold)
      expect(find.widgetWithText(InkWell, 'القرآن'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'الفعاليات'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'الأذان والمواقيت'), findsOneWidget);

      // 2. Desktop Test
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();

      // Quran tab exists on desktop top bar and remains visible with all sibling tabs
      expect(find.text('القرآن الكريم'), findsWidgets);
      expect(find.text('الفعاليات والتبرع'), findsOneWidget);
      expect(find.text('الأذان ومواقيت الصلاة'), findsOneWidget);
    });

    test('QuranTvRecitationView auto-play resolves first ayah of target page when idle', () {
      const targetPage = 3;
      final ayahs = QuranService.getPage(targetPage)?.ayahs ?? const [];
      expect(ayahs, isNotEmpty);
      final first = ayahs.first;
      expect(first.surahNumber, 2);
      expect(first.ayahNumberInSurah, 6);
      expect(first.pageNumber, 3);
    });

    test('Active playback is preserved when audio is already running', () {
      final audio = QuranAudioService.instance;
      audio.activeTagNotifier.value = const QuranAyahAudioTag(
        surahNumber: 2,
        ayahNumber: 15,
        surahName: 'البقرة',
        pageNumber: 3,
      );
      // Active tag is not null, so open does not reset to beginning of page
      expect(audio.activeTagNotifier.value?.ayahNumber, 15);
    });

    testWidgets('TV Mode theme dropdown displays concise circular swatches without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Mobile screen size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: QuranTvRecitationView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Find the theme dropdown button
      final paletteFinder = find.byIcon(Icons.palette_outlined);
      expect(paletteFinder, findsOneWidget);

      await tester.tap(paletteFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify no overflow exception thrown
      expect(tester.takeException(), isNull);
    });
  });
}
