import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';
import 'package:flutter_app/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  Future<List<int>> pumpMushaf(WidgetTester tester, {int initialPage = 1}) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bookmarks = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: QuranPageMushafView(
              initialPage: initialPage,
              isDark: false,
              onClose: () {},
              onSaveBookmark: (page, _, __, ___) => bookmarks.add(page),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return bookmarks;
  }

  testWidgets('Old toolbar is gone; zoom and bookmark live as icon chips on the page', (tester) async {
    final bookmarks = await pumpMushaf(tester);

    expect(find.textContaining('المصحف الشريف'), findsNothing);
    expect(find.byIcon(Icons.find_in_page_outlined), findsNothing);
    expect(find.byTooltip('تصغير الخط'), findsWidgets);
    expect(find.byTooltip('تكبير الخط'), findsWidgets);

    await tester.tap(find.byTooltip('حفظ علامة القراءة').first);
    await tester.pump();
    expect(bookmarks, [1]);
  });

  testWidgets('Word search opens the right page', (tester) async {
    await pumpMushaf(tester);

    await tester.tap(find.byTooltip('بحث'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'قل هو الله أحد');
    await tester.pump();

    final hit = find.textContaining('سورة ${QuranService.getSurahName(112)} · 1');
    expect(hit, findsOneWidget);
    await tester.tap(hit);
    await tester.pumpAndSettle();

    expect(find.text('604 / 604'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'search closes after picking a result');
  });

  testWidgets('Typing a page number offers a jump to that page', (tester) async {
    await pumpMushaf(tester);

    await tester.tap(find.byTooltip('بحث'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '٤٢');
    await tester.pump();

    await tester.tap(find.text('الصفحة 42'));
    await tester.pumpAndSettle();
    expect(find.text('42 / 604'), findsOneWidget);
  });

  testWidgets('Header chips fit a 360px phone even with two surah names on the page', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: QuranPageMushafView(
              initialPage: 359, // Al-Furqan ends, Ash-Shu'ara begins
              isDark: false,
              onClose: () {},
              onSaveBookmark: (_, __, ___, ____) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('تكبير الخط'), findsWidgets);
  });
}
