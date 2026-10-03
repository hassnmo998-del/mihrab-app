import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/screens/discover/widgets/islamic_zad_hub_view.dart';
import 'package:flutter_app/screens/discover/widgets/daily_athkar_view.dart';
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

    testWidgets('IslamicZadHubView renders with its 3 tabs', (tester) async {
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
      expect(find.textContaining('زاد المسلم والأذكار والرقية'), findsOneWidget);

      // Tab 0: Daily Athkar
      expect(find.byType(DailyAthkarView), findsOneWidget);
      expect(find.textContaining('أذكار الصباح'), findsWidgets);

      // Tab 1: Allah Names
      await tester.tap(find.text('أسماء الله الحسنى ✨ (99)'));
      await tester.pump();
      expect(find.byType(AllahNamesView), findsOneWidget);

      // Tab 2: Spiritual Gems
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
              child: IslamicZadHubView(isDark: true, initialTab: 1),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AllahNamesView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('كرت «زاد المسلم» يتبع ثيم التطبيق المختار، لا أخضر ثابتاً', (tester) async {
      Future<Gradient?> bannerGradient(String paletteId) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(isDark: false, paletteId: paletteId),
            home: Scaffold(
              // مفتاح لكل ثيم: يُبنى الكرت من جديد كما يحدث عند تغيير الثيم من الإعدادات
              body: SingleChildScrollView(
                child: IslamicZadHubView(key: ValueKey(paletteId), isDark: false),
              ),
            ),
          ),
        );
        await tester.pump();
        final banner = tester.widget<Container>(
          find.ancestor(of: find.textContaining('زاد المسلم والأذكار والرقية'), matching: find.byType(Container)).first,
        );
        return (banner.decoration as BoxDecoration).gradient;
      }

      for (final palette in AppColors.palettes) {
        expect(await bannerGradient(palette.id), palette.gradient, reason: palette.id);
      }
      AppTheme.buildTheme(isDark: false); // يعيد الثيم الافتراضي لبقية الاختبارات
    });

    test('ثيم كسوة الكعبة (أسود وذهبي) بين ثيمات التطبيق', () {
      final kaaba = AppColors.getPaletteById('kaaba');

      expect(kaaba.id, 'kaaba');
      expect(AppColors.palettes.map((p) => p.id).toSet().length, AppColors.palettes.length);
      // أسود في الوضع الفاتح، وذهبي على الأسود في الداكن
      expect(kaaba.primary.computeLuminance(), lessThan(0.02));
      expect(kaaba.darkBg.computeLuminance(), lessThan(0.01));
      expect(kaaba.darkPrimary.computeLuminance(), greaterThan(0.25));
      // النص الأبيض مقروء فوق أزرار الثيم في الوضعين
      double onWhite(Color c) => 1.05 / (c.computeLuminance() + 0.05);
      expect(onWhite(kaaba.primary), greaterThan(7));
      expect(onWhite(kaaba.darkPrimary), greaterThan(2.8));
    });
  });
}
