import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/quran_audio_bar.dart';
import 'package:flutter_app/services/quran_audio_service.dart';
import 'package:flutter_app/services/quran_service.dart';

QuranAyahAudioTag tagOf(int surah, int ayah) => QuranAyahAudioTag(
      surahNumber: surah,
      ayahNumber: ayah,
      surahName: QuranService.getSurahName(surah),
      pageNumber: QuranService.getPageForAyah(surah, ayah) ?? 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  tearDown(() {
    QuranAudioService.instance.setStopAfter(QuranStopAfter.never);
    QuranAudioService.instance.setRepeatCount(1);
  });

  group('"يتوقف بعد" boundaries', () {
    bool crosses(QuranStopAfter mode, (int, int) from, (int, int) to) =>
        QuranAudioService.crossesStopBoundary(mode, tagOf(from.$1, from.$2), tagOf(to.$1, to.$2));

    test('لا تتوقف never stops', () {
      expect(crosses(QuranStopAfter.never, (1, 7), (2, 1)), isFalse);
    });

    test('هذه الآية: moving to another ayah stops; repeating the same one does not', () {
      expect(crosses(QuranStopAfter.ayah, (2, 5), (2, 6)), isTrue);
      expect(crosses(QuranStopAfter.ayah, (2, 5), (2, 5)), isFalse);
    });

    test('هذه السورة: stops only when the next ayah is in another surah', () {
      expect(crosses(QuranStopAfter.surah, (2, 1), (2, 2)), isFalse);
      expect(crosses(QuranStopAfter.surah, (1, 7), (2, 1)), isTrue);
    });

    test('هذا الجزء: stops at the juz boundary (juz 2 starts at Al-Baqarah 142)', () {
      expect(crosses(QuranStopAfter.juz, (2, 140), (2, 141)), isFalse);
      expect(crosses(QuranStopAfter.juz, (2, 141), (2, 142)), isTrue);
    });
  });

  group('Audio bar never overflows', () {
    Future<void> pumpBar(WidgetTester tester, double width, double textScale) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 700), textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: QuranAudioBar(
                    isDark: false,
                    idleTitle: 'سورة الشعراء',
                    onStart: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // On mobile, unfold settings to check pill visibility
      final toggle = find.byIcon(Icons.settings_rounded);
      if (toggle.evaluate().isNotEmpty) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
    }

    for (final width in <double>[300, 320, 360, 414, 600, 800, 899, 900, 1000, 1400]) {
      for (final scale in [1.0, 1.4]) {
        testWidgets('width $width, text ×$scale', (tester) async {
          QuranAudioService.instance.setRepeatCount(-1);
          QuranAudioService.instance.setStopAfter(QuranStopAfter.surah);
          await pumpBar(tester, width, scale);
          expect(tester.takeException(), isNull);
          expect(find.text('بلا توقف'), findsOneWidget);
          expect(find.text('بعد السورة'), findsOneWidget);
        });
      }
    }
  });

  testWidgets('"يتوقف بعد" menu lists its heading and four options, and selecting one applies it', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: QuranAudioBar(isDark: false, idleTitle: 'سورة الفاتحة', onStart: () {}),
        ),
      ),
    ));

    // On desktop, the bar is unfolded by default without toggle button
    expect(find.byIcon(Icons.settings_rounded), findsNothing);

    await tester.tap(find.text('لا يتوقف'));
    await tester.pumpAndSettle();
    expect(find.text('إيقاف التلاوة تلقائياً'), findsWidgets);
    for (final label in ['هذه الآية', 'هذه السورة', 'هذا الجزء', 'لا تتوقف']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('هذا الجزء').last);
    await tester.pumpAndSettle();
    expect(QuranAudioService.instance.stopAfterNotifier.value, QuranStopAfter.juz);
    expect(find.text('بعد الجزء'), findsOneWidget);
  });
}
