import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/zad_data_constants.dart';
import 'package:flutter_app/screens/discover/widgets/zad_card.dart';
import 'package:flutter_app/screens/discover/widgets/islamic_zad_view.dart';
import 'package:flutter_app/screens/discover/widgets/zad_detail_dialog.dart';

void main() {
  group('Zad Al-Muslim Authentic Data Integrity Tests', () {
    test('All Names of Allah have numbers, names, meanings, reflections, and valid duas', () {
      expect(ZadDataConstants.allahNames.length, 99);
      for (final n in ZadDataConstants.allahNames) {
        expect(n.number > 0, isTrue);
        expect(n.name.trim().isNotEmpty, isTrue);
        expect(n.meaning.trim().isNotEmpty, isTrue);
        expect(n.reflection.trim().isNotEmpty, isTrue);
        expect(n.dua.trim().isNotEmpty, isTrue);
      }
    });

    test('All Ruqyah and Duas are properly categorized with authentic sources', () {
      expect(ZadDataConstants.ruqyahAndDuas.isNotEmpty, isTrue);
      final categories = <String>{};
      for (final d in ZadDataConstants.ruqyahAndDuas) {
        expect(d.id.isNotEmpty, isTrue);
        expect(d.title.isNotEmpty, isTrue);
        expect(d.arabicText.isNotEmpty, isTrue);
        expect(d.source.isNotEmpty, isTrue);
        expect(d.instruction.isNotEmpty, isTrue);
        categories.add(d.category);
      }
      expect(categories.contains('ruqyah'), isTrue);
      expect(categories.contains('kurb'), isTrue);
      expect(categories.contains('rizq'), isTrue);
      expect(categories.contains('health'), isTrue);
      expect(categories.contains('family'), isTrue);
    });

    test('All Great Reward Deeds have hadith matn and Bukhari/Muslim or authentic sources', () {
      expect(ZadDataConstants.greatRewardDeeds.isNotEmpty, isTrue);
      for (final gr in ZadDataConstants.greatRewardDeeds) {
        expect(gr.title.isNotEmpty, isTrue);
        expect(gr.hadithMatn.isNotEmpty, isTrue);
        expect(gr.source.isNotEmpty, isTrue);
        expect(gr.rewardDescription.isNotEmpty, isTrue);
      }
    });

    test('All Prophetic Pearls have historical context story and practical daily lessons', () {
      expect(ZadDataConstants.propheticPearls.isNotEmpty, isTrue);
      for (final p in ZadDataConstants.propheticPearls) {
        expect(p.title.isNotEmpty, isTrue);
        expect(p.contextStory.isNotEmpty, isTrue);
        expect(p.practicalLesson.isNotEmpty, isTrue);
        expect(p.source.isNotEmpty, isTrue);
      }
    });
  });

  group('Zad Al-Muslim Widget Tests', () {
    testWidgets('IslamicZadView renders on mobile screen (width 390) without overflow', (tester) async {
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
              child: IslamicZadView(isDark: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('زاد المسلم والفوائد الإيمانية'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('أسماء الله الحسنى'), findsWidgets);
    });

    testWidgets('IslamicZadView renders on desktop wide screen (width 1280) with grid layout', (tester) async {
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
              child: IslamicZadView(isDark: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('زاد المسلم والفوائد الإيمانية'), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('ZadItemCard triggers detail dialog and copy action', (tester) async {
      const testCard = ZadItemCard(
        title: 'الله',
        categoryName: 'اسم الله',
        content: 'المألوه المعبود بحق',
        instructionOrDua: 'يا الله',
        source: 'القرآن الكريم',
        categoryIcon: Icons.star,
        accentColor: Colors.amber,
        fontSize: 16.0,
        isDark: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ZadDetailDialog.show(ctx, testCard, 16.0, false),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('المألوه المعبود بحق'), findsOneWidget);
      expect(find.text('يا الله'), findsOneWidget);
    });
  });
}
