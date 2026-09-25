import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/quran_audio_bar.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';
import 'package:flutter_app/services/quran_audio_service.dart';
import 'package:flutter_app/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  group('Quran Defaults & Mobile Experience Tests', () {
    test('Default audio settings match user preference', () {
      final audio = QuranAudioService.instance;
      expect(audio.reciterNotifier.value.id, 'abdul_basit_murattal_192kbps');
      expect(audio.reciterNotifier.value.nameArabic, 'عبد الباسط عبد الصمد');
      expect(audio.scopeNotifier.value, QuranRepeatScope.quran);
      expect(audio.repeatCountNotifier.value, -1);
      expect(audio.stopAfterNotifier.value, QuranStopAfter.never);
      expect(audio.speedNotifier.value, 1.0);
    });

    testWidgets('QuranAudioBar is collapsed by default and expands on toggle with soft labels', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Standard mobile phone size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: QuranAudioBar(
                isDark: false,
                idleTitle: 'سورة البقرة',
                onStart: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar elements exist
      expect(find.text('سورة البقرة'), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // Expand toggle button with settings gear icon exists on mobile
      final toggleFinder = find.byIcon(Icons.settings_rounded);
      expect(toggleFinder, findsOneWidget);

      // Soft titles are not visible while collapsed
      expect(find.text('نطاق التلاوة'), findsNothing);
      expect(find.text('تكرار الآية'), findsNothing);
      expect(find.text('التوقف التلقائي'), findsNothing);
      expect(find.text('القارئ الشيخ'), findsNothing);
      expect(find.text('السرعة'), findsNothing);

      // Tap toggle to expand options
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Soft titles are now visible!
      expect(find.text('نطاق التلاوة'), findsOneWidget);
      expect(find.text('تكرار الآية'), findsOneWidget);
      expect(find.text('التوقف التلقائي'), findsOneWidget);
      expect(find.text('القارئ الشيخ'), findsOneWidget);
      expect(find.text('السرعة'), findsOneWidget);

      // Default values are shown on the pills
      expect(find.text('القرآن كاملاً'), findsOneWidget);
      expect(find.text('بلا توقف'), findsOneWidget);
      expect(find.text('لا يتوقف'), findsOneWidget);
      expect(find.text('عبد الباسط عبد الصمد'), findsOneWidget);
      expect(find.text('1×'), findsOneWidget);
    });

    testWidgets('QuranAudioBar on desktop is unfolded by default without toggle button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800); // Standard desktop size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: QuranAudioBar(
                isDark: false,
                idleTitle: 'سورة البقرة',
                onStart: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No gear toggle button on desktop
      expect(find.byIcon(Icons.settings_rounded), findsNothing);

      // Speed pill is in the transport row on desktop
      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
      expect(find.text('1×'), findsOneWidget);

      // All options are unfolded and visible immediately
      expect(find.text('القرآن كاملاً'), findsOneWidget);
      expect(find.text('بلا توقف'), findsOneWidget);
      expect(find.text('لا يتوقف'), findsOneWidget);
      expect(find.text('عبد الباسط عبد الصمد'), findsOneWidget);
    });

    testWidgets('QuranPageMushafView renders on mobile without overflow and includes bottom slider in scroll', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: QuranPageMushafView(
                initialPage: 2,
                isDark: false,
                onClose: () {},
                onSaveBookmark: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The bottom slider controls are present
      expect(find.text('2 / 604'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    });
  });
}
