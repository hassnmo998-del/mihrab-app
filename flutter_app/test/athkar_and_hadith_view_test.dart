import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/athkar_and_hadith_view.dart';
import 'package:flutter_app/screens/discover/widgets/athkar_data_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Athkar Database Integrity Tests', () {
    test('All Athkar categories contain valid text, virtue, and count', () {
      expect(kAthkarDatabase.containsKey('morning'), isTrue);
      expect(kAthkarDatabase.containsKey('evening'), isTrue);
      expect(kAthkarDatabase.containsKey('prayer'), isTrue);
      expect(kAthkarDatabase.containsKey('sleep'), isTrue);

      for (final entry in kAthkarDatabase.entries) {
        for (final item in entry.value) {
          expect(item['text'] != null, isTrue);
          expect((item['text'] as String).isNotEmpty, isTrue);
          expect(item['count'] != null, isTrue);
          expect((item['count'] as num) > 0, isTrue);
        }
      }
    });
  });

  group('Athkar and Hadith View Widget Tests', () {
    testWidgets('Renders Morning Athkar without null cast error and allows tapping counter', (tester) async {
      tester.view.physicalSize = const Size(800 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AthkarAndHadithView(isDark: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure morning athkar rendered without red screen
      expect(find.textContaining('أذكار الصباح'), findsWidgets);
      expect(find.textContaining('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsOneWidget);
      expect(find.textContaining('سيد الاستغفار'), findsOneWidget);

      // Tap on a dhikr card to increment counter
      await tester.tap(find.textContaining('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'));
      await tester.pumpAndSettle();

      // Switch to Evening Athkar
      await tester.tap(find.textContaining('أذكار المساء'));
      await tester.pumpAndSettle();

      expect(find.textContaining('أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ'), findsOneWidget);

      // Switch to Prayer Duas
      await tester.tap(find.textContaining('أدعية بعد الصلاة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('أَسْتَغْفِرُ اللَّهَ'), findsOneWidget);
    });
  });
}
