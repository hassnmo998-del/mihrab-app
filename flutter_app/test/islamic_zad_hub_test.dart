import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/islamic_zad_hub_view.dart';
import 'package:flutter_app/screens/discover/widgets/daily_athkar_view.dart';
import 'package:flutter_app/screens/discover/widgets/hadith_encyclopedia_view.dart';
import 'package:flutter_app/screens/discover/widgets/allah_names_view.dart';
import 'package:flutter_app/screens/discover/widgets/spiritual_gems_view.dart';
import 'package:flutter_app/services/allah_names_full_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified Islamic Zad Hub Tests', () {
    test('All 99 Names of Allah are present and complete', () {
      expect(AllahNamesFullData.names.length, 99);
      for (int i = 0; i < 99; i++) {
        final item = AllahNamesFullData.names[i];
        expect(item.number, i + 1);
        expect(item.name.isNotEmpty, isTrue);
        expect(item.meaning.isNotEmpty, isTrue);
        expect(item.reflection.isNotEmpty, isTrue);
        expect(item.dua.isNotEmpty, isTrue);
      }
    });

    testWidgets('IslamicZadHubView renders with all 4 tabs', (tester) async {
      tester.view.physicalSize = const Size(1280 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IslamicZadHubView(isDark: false),
            ),
          ),
        ),
      );
      await tester.pump();

      // Header Banner
      expect(find.textContaining('زاد المسلم والسنة النبوية المشرفة'), findsOneWidget);

      // Tab 0: Daily Athkar
      expect(find.byType(DailyAthkarView), findsOneWidget);
      expect(find.textContaining('أذكار الصباح'), findsWidgets);

      // Tab 1: Hadith Encyclopedia visible after tap
      await tester.tap(find.text('موسوعة الحديث 📜'));
      await tester.pump();
      expect(find.byType(HadithEncyclopediaView), findsOneWidget);
      expect(find.textContaining('روائع الصحيحين'), findsNothing);

      // Tab 2: Allah Names
      await tester.tap(find.text('أسماء الله الحسنى ✨ (99)'));
      await tester.pump();
      expect(find.byType(AllahNamesView), findsOneWidget);

      // Tab 3: Spiritual Gems
      await tester.tap(find.text('الرقية والكنوز والدرر 🛡️'));
      await tester.pump();
      expect(find.byType(SpiritualGemsView), findsOneWidget);
    });

    testWidgets('IslamicZadHubView renders adaptively on mobile', (tester) async {
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
              child: IslamicZadHubView(isDark: true, initialTab: 2),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AllahNamesView), findsOneWidget);
    });
  });
}
