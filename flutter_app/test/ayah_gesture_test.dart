import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/widgets/ayah_gesture_recognizer.dart';

void main() {
  testWidgets('AyahTapAndLongPressGestureRecognizer disambiguates tap and long press', (tester) async {
    bool tapped = false;
    bool longPressed = false;

    final recognizer = AyahTapAndLongPressGestureRecognizer();
    recognizer.onTap = () => tapped = true;
    recognizer.onLongPress = () => longPressed = true;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RichText(
            text: TextSpan(
              text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              recognizer: recognizer,
            ),
          ),
        ),
      ),
    );

    // 1. Simulate short tap
    await tester.tap(find.byType(RichText));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(longPressed, isFalse);

    // 2. Reset flags and simulate long press
    tapped = false;
    longPressed = false;

    await tester.longPress(find.byType(RichText));
    await tester.pumpAndSettle();

    expect(longPressed, isTrue);
    expect(tapped, isFalse);

    recognizer.dispose();
  });

  // Reported by a user: scrolling the Quran page opened the Tafsir by itself.
  // A quick scroll lets the page's drag win the arena before the tap recognizer
  // has announced a tap-down, so the long-press timer was never told to stop.
  group('scrolling over an ayah never opens the Tafsir', () {
    late bool longPressed;
    late AyahTapAndLongPressGestureRecognizer recognizer;

    Future<void> pumpScrollableAyah(WidgetTester tester) async {
      longPressed = false;
      recognizer = AyahTapAndLongPressGestureRecognizer()
        ..onTap = () {}
        ..onLongPress = () => longPressed = true;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            children: [
              // Center sizes the paragraph to its text, so touching its centre touches the ayah
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    recognizer: recognizer,
                  ),
                ),
              ),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      );
    }

    testWidgets('a quick fling', (tester) async {
      await pumpScrollableAyah(tester);
      await tester.fling(find.byType(RichText), const Offset(0, -300), 2000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(longPressed, isFalse);
      recognizer.dispose();
    });

    testWidgets('a drag that keeps the finger down afterwards', (tester) async {
      await pumpScrollableAyah(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byType(RichText)));
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(seconds: 1)); // finger still resting on the page
      expect(longPressed, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      recognizer.dispose();
    });

    testWidgets('a real long press on the same page still opens it', (tester) async {
      await pumpScrollableAyah(tester);
      await tester.longPress(find.byType(RichText));
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);
      recognizer.dispose();
    });
  });
}
