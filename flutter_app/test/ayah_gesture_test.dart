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
}
