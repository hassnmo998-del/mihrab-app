import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/quran_audio_bar.dart';
import 'package:flutter_app/screens/discover/widgets/quran_page_mushaf_view.dart';
import 'package:flutter_app/services/quran_audio_service.dart';
import 'package:flutter_app/services/quran_service.dart';

/// قراءة المصحف بملء الشاشة: زر بجوار «الفهرس» يعرض صفحة المصحف وحدها تملأ الشاشة،
/// بأزرارها هي (تكبير، علامة، تجويد)، وتتبع التلاوة كما في الشاشة العادية، وما يتغيّر
/// فيها يبقى عند العودة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audio = QuranAudioService.instance;
  final played = <String>[];

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  setUp(() async {
    played.clear();
    audio.debugPlay = (tag) async => played.add(tag.key);
    await audio.stop();
    await audio.setScope(QuranRepeatScope.quran);
    audio.setRepeatCount(1);
    audio.setStopAfter(QuranStopAfter.never);
  });

  tearDown(() async {
    await audio.stop();
    audio.debugPlay = null;
  });

  final fullscreenButton = find.byKey(const ValueKey('mushafFullscreenButton'));
  final exitChip = find.byTooltip('الخروج من ملء الشاشة');
  Finder card(int page) => find.byKey(ValueKey('mushaf_page_$page'));

  /// الشاشة العادية كما يستضيفها تبويب القرآن: الأب يحفظ العلامة ويعيد بناءها.
  Future<List<int>> pumpMushaf(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    int initialPage = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bookmarks = <int>[];
    int? bookmarked;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: QuranPageMushafView(
                initialPage: initialPage,
                isDark: false,
                onClose: () {},
                bookmarkedPage: bookmarked,
                onSaveBookmark: (page, _, __, ___) {
                  bookmarks.add(page);
                  setState(() => bookmarked = page);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return bookmarks;
  }

  Future<void> enterFullscreen(WidgetTester tester) async {
    await tester.tap(fullscreenButton);
    await tester.pumpAndSettle();
  }

  /// أكبر حجم خط في نص آيات الصفحة المعروضة.
  double ayahFontSize(WidgetTester tester, int page) {
    var size = 0.0;
    for (final rich in tester.widgetList<RichText>(find.descendant(of: card(page), matching: find.byType(RichText)))) {
      rich.text.visitChildren((span) {
        final s = span.style?.fontSize;
        if (span is TextSpan && span.recognizer != null && s != null && s > size) size = s;
        return true;
      });
    }
    return size;
  }

  testWidgets('زر بجوار «الفهرس» يعرض الصفحة وحدها تملأ الشاشة، بأزرارها هي', (tester) async {
    const size = Size(390, 844);
    await pumpMushaf(tester, size: size);
    expect(find.byTooltip('قراءة بملء الشاشة'), findsOneWidget);
    // الزر بين «الفهرس» والبحث، في السطر نفسه
    final indexRect = tester.getRect(find.text('الفهرس'));
    final buttonRect = tester.getRect(fullscreenButton);
    expect((buttonRect.center.dy - indexRect.center.dy).abs(), lessThan(6));
    expect(buttonRect.right, lessThan(indexRect.left), reason: 'يسار «الفهرس» في واجهة عربية');
    final before = tester.getRect(card(1));

    await enterFullscreen(tester);

    // لا شيء غير الصفحة: لا فهرس ولا بحث ولا شريط سماع ولا شريط صفحات
    expect(find.text('الفهرس'), findsNothing);
    expect(find.byTooltip('بحث'), findsNothing);
    expect(find.byType(QuranAudioBar), findsNothing);
    expect(find.text('1 / 604'), findsNothing);

    // وما في الصفحة باقٍ كما هو
    expect(find.byTooltip('تصغير الخط'), findsOneWidget);
    expect(find.byTooltip('تكبير الخط'), findsOneWidget);
    expect(find.byTooltip('حفظ علامة القراءة'), findsOneWidget);
    expect(find.byTooltip('قصة السورة ومقاصدها'), findsOneWidget);
    expect(find.text('أحكام التجويد'), findsOneWidget);
    expect(find.text('الجزء 1'), findsOneWidget);
    expect(exitChip, findsOneWidget);

    // تملأ الشاشة
    final full = tester.getRect(card(1));
    expect(full.width, greaterThanOrEqualTo(size.width - 12));
    expect(full.height, greaterThanOrEqualTo(size.height - 12));
    expect(full.height, greaterThan(before.height + 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('الخروج بزر الصفحة أو بزر الرجوع يعيد الشاشة العادية', (tester) async {
    await pumpMushaf(tester);

    await enterFullscreen(tester);
    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(find.text('الفهرس'), findsOneWidget);
    expect(find.byType(QuranAudioBar), findsOneWidget);
    expect(exitChip, findsNothing);

    await enterFullscreen(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('الفهرس'), findsOneWidget);

    await enterFullscreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('الفهرس'), findsOneWidget);
  });

  testWidgets('الصفحة وحجم الخط وألوان التجويد تدخل معه وتعود معه', (tester) async {
    await pumpMushaf(tester);
    final base = ayahFontSize(tester, 1);
    await tester.tap(find.byTooltip('تكبير الخط'));
    await tester.tap(find.text('أحكام التجويد'));
    await tester.pump();

    await enterFullscreen(tester);
    expect(ayahFontSize(tester, 1), base + 2, reason: 'حجم الخط كما كان خارجها');
    expect(find.text('قلقلة'), findsOneWidget, reason: 'دليل ألوان التجويد مفعّل كما كان');

    // يكبّر مرة أخرى، يطفئ التجويد، ويقلب إلى الصفحة التالية
    await tester.tap(find.byTooltip('تكبير الخط'));
    await tester.tap(find.text('أحكام التجويد'));
    await tester.pump();
    await tester.fling(card(1), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(card(2), findsOneWidget);

    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(find.text('2 / 604'), findsOneWidget, reason: 'الشاشة العادية تقف حيث انتهت القراءة');
    expect(card(2), findsOneWidget);
    expect(ayahFontSize(tester, 2), base + 4);
    expect(find.text('قلقلة'), findsNothing);
  });

  testWidgets('حفظ العلامة من ملء الشاشة يصل الأب ويظهر فوراً، هنا وبعد العودة', (tester) async {
    final bookmarks = await pumpMushaf(tester, initialPage: 3);
    await enterFullscreen(tester);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

    await tester.tap(find.byTooltip('حفظ علامة القراءة'));
    await tester.pump();
    expect(bookmarks, [3]);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });

  testWidgets('النقر على آية يتلوها، والتظليل وقلب الصفحة يتبعان التلاوة داخل ملء الشاشة', (tester) async {
    await pumpMushaf(tester);
    await enterFullscreen(tester);

    // نقرة على نص الفاتحة: تبدأ التلاوة من الآية المنقورة
    final text = find.descendant(
      of: card(1),
      matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('ٱلْعَٰلَمِينَ')),
    );
    await tester.tapAt(tester.getRect(text).topRight + const Offset(-40, 22));
    await tester.pump();
    expect(played, isNotEmpty);
    expect(played.first, startsWith('1:'));
    expect(audio.isPlayingNotifier.value, isTrue);

    // التلاوة تنتقل إلى صفحة أخرى: الصفحة تُقلب وحدها
    await audio.playAyah(2, 6, pageNumber: 3);
    await tester.pumpAndSettle();
    expect(card(3), findsOneWidget);
    expect(audio.activeAyahNotifier.value, '2:6');

    // وعند العودة تقف الشاشة العادية على الصفحة نفسها
    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(find.text('3 / 604'), findsOneWidget);
    expect(card(3), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('هاتف ضيق وصفحة بثلاث سور: رأس الصفحة مع زر الخروج لا يفيض', (tester) async {
    await pumpMushaf(tester, size: const Size(320, 640), initialPage: 604);
    await enterFullscreen(tester);
    expect(tester.takeException(), isNull);
    expect(exitChip, findsOneWidget);
    final chip = tester.getRect(exitChip);
    final page = tester.getRect(card(604));
    expect(chip.left, greaterThanOrEqualTo(page.left));
    expect(chip.right, lessThanOrEqualTo(page.right));
  });

  group('شريطا النظام', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) calls.add(call);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('أندرويد: يختفيان عند الدخول ويعودان كما كانا عند الخروج', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pumpMushaf(tester);
      expect(calls, isEmpty, reason: 'الشاشة العادية لا تمسّهما');

      await enterFullscreen(tester);
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');

      await tester.tap(exitChip);
      await tester.pumpAndSettle();
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.last.arguments, ['SystemUiOverlay.top', 'SystemUiOverlay.bottom']);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('ويندوز: لا شيء يُطلب من النظام', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpMushaf(tester, size: const Size(1280, 800));
      await enterFullscreen(tester);
      await tester.tap(exitChip);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
