import 'dart:io';
import 'dart:ui' as ui;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/astro/sky_ephemeris.dart';
import 'package:flutter_app/screens/discover/widgets/sky_day_strip.dart';

/// لوحة السماء في كرت العدّ: مواضع الشمس والقمر من الحساب، والرسم سليم على الهاتف
/// وسطح المكتب وبالاتجاهين.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lat = 33.5138, lng = 36.2765; // دمشق

  ({DateTime sunrise, DateTime sunset}) sunTimes(DateTime day) {
    final pt = PrayerTimes(
      Coordinates(lat, lng),
      DateComponents.from(day),
      CalculationMethod.muslim_world_league.getParameters(),
    );
    return (sunrise: pt.sunrise, sunset: pt.maghrib);
  }

  SkySnapshot snapshotAt(DateTime now) {
    final t = sunTimes(now);
    return SkySnapshot.compute(now: now, latitude: lat, longitude: lng, sunrise: t.sunrise, sunset: t.sunset);
  }

  group('لقطة السماء', () {
    test('عند الزوال: الشمس في منتصف الكرت وفي أعلى قوسها', () {
      final t = sunTimes(DateTime.utc(2026, 10, 6));
      final noon = t.sunrise.add(t.sunset.difference(t.sunrise) ~/ 2);
      final s = snapshotAt(noon);

      expect(s.sunUp, isTrue);
      expect(s.sunFraction, closeTo(0.5, 0.01));
      final peak = s.sunPath.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      expect(s.sunAltitude, closeTo(peak, 0.2));
      // 6 تشرين الأول في دمشق: ارتفاع الظهر نحو 51 درجة
      expect(s.sunAltitude, closeTo(51.2, 0.6));
    });

    test('قوس الشمس يبدأ عند الأفق وينتهي عنده، ويعلو بينهما', () {
      final s = snapshotAt(DateTime.utc(2026, 10, 6, 9));
      expect(s.sunPath.first.dy, closeTo(-0.83, 0.4));
      expect(s.sunPath.last.dy, closeTo(-0.83, 0.4));
      expect(s.sunPath[s.sunPath.length ~/ 2].dy, greaterThan(45));
    });

    test('الشمس تتقدم من بداية الكرت إلى آخره مع ساعات النهار', () {
      final t = sunTimes(DateTime.utc(2026, 10, 6));
      final span = t.sunset.difference(t.sunrise);
      double at(double f) => snapshotAt(t.sunrise.add(span * f)).sunFraction;
      expect(at(0), closeTo(0, 0.001));
      expect(at(0.25), closeTo(0.25, 0.001));
      expect(at(0.75), closeTo(0.75, 0.001));
      expect(at(1), closeTo(1, 0.001));
    });

    test('ليلاً: لا شمس، والشفق جهة الغروب قبل منتصف الليل وجهة الشروق بعده', () {
      final evening = snapshotAt(DateTime.utc(2026, 10, 6, 17)); // 20:00 بتوقيت دمشق
      expect(evening.sunUp, isFalse);
      expect(evening.sunPastNoon, isTrue);

      final dawn = snapshotAt(DateTime.utc(2026, 10, 6, 2)); // 05:00 بتوقيت دمشق
      expect(dawn.sunUp, isFalse);
      expect(dawn.sunPastNoon, isFalse);
    });

    test('القمر يُرسم فقط وهو فوق الأفق فعلاً، وموضعه بين طلوعه وغروبه', () {
      var up = 0, down = 0;
      for (var hour = 0; hour < 48; hour += 2) {
        final now = DateTime.utc(2026, 10, 6).add(Duration(hours: hour));
        final s = snapshotAt(now);
        final altitude = SkyEphemeris.moon(now, lat, lng).altitude;
        if (s.moonUp) {
          up++;
          expect(altitude, greaterThan(-1.0));
          expect(s.moonFraction, inInclusiveRange(0.0, 1.0));
          expect(s.moonPath, isNotEmpty);
          expect(s.moonNextSet, isNotNull);
        } else {
          down++;
          expect(altitude, lessThan(0.0));
          expect(s.moonNextRise, isNotNull);
        }
      }
      expect(up, greaterThan(5));
      expect(down, greaterThan(5));
    });

    test('بدر 17 تشرين الأول 2024 عند منتصف الليل: قمر كامل قرب منتصف مساره', () {
      final s = snapshotAt(DateTime.utc(2024, 10, 17, 21, 30));
      expect(s.moonUp, isTrue);
      expect(s.phaseName, 'بدر');
      expect(s.illuminationPercent, greaterThanOrEqualTo(99));
      expect(s.moonFraction, closeTo(0.5, 0.08));
    });
  });

  group('مواضع الرسم', () {
    const size = Size(360, 104);

    test('نصف الكرة الشمالي: الشرق يسار من يتجه جنوباً، فالشروق يسار اللوحة والغروب يمينها', () {
      expect(snapshotAt(DateTime.utc(2026, 10, 6, 9)).eastOnRight, isFalse);
      final rise = SkyPainter.bodyOffset(size, 0, 0, eastOnRight: false);
      final set = SkyPainter.bodyOffset(size, 1, 0, eastOnRight: false);
      expect(rise.dx, lessThan(size.width * 0.15));
      expect(set.dx, greaterThan(size.width * 0.85));
    });

    test('نصف الكرة الجنوبي: الراصد يتجه شمالاً، فالشروق يمين اللوحة', () {
      final now = DateTime.utc(2026, 10, 6, 9);
      final times = SkyEphemeris.sunRiseSet(now, -33.9249, 18.4241);
      final cape = SkySnapshot.compute(
        now: now,
        latitude: -33.9249,
        longitude: 18.4241,
        sunrise: times.rise!,
        sunset: times.set!,
      );
      expect(cape.eastOnRight, isTrue);
      final rise = SkyPainter.bodyOffset(size, 0, 0, eastOnRight: true);
      expect(rise.dx, greaterThan(size.width * 0.85));
    });

    test('الطرف المضيء من القمر يواجه الشمس على اللوحة كما في السماء', () {
      // تربيع أول عصراً في دمشق: الشمس غرباً (يمين اللوحة) والقمر شرقها، ونصفه المضيء يمينه
      final s = snapshotAt(DateTime.utc(2024, 10, 11, 13));
      expect(s.sunUp && s.moonUp, isTrue);
      final sun = SkyPainter.bodyOffset(size, s.sunFraction, s.sunAltitude, eastOnRight: s.eastOnRight);
      final moon = SkyPainter.bodyOffset(size, s.moonFraction, s.moon.altitude, eastOnRight: s.eastOnRight);
      expect(sun.dx, greaterThan(moon.dx));
      // 270 = الطرف المضيء إلى يمين القرص
      expect(s.moon.brightLimbZenithAngle, inInclusiveRange(225, 315));
    });

    test('الأعلى ارتفاعاً أعلى على اللوحة، ولا يخرج القرص من أعلاها', () {
      final horizon = SkyPainter.bodyOffset(size, 0.5, 0, eastOnRight: false);
      final winter = SkyPainter.bodyOffset(size, 0.5, 33, eastOnRight: false);
      final summer = SkyPainter.bodyOffset(size, 0.5, 80, eastOnRight: false);
      final zenith = SkyPainter.bodyOffset(size, 0.5, 90, eastOnRight: false);

      expect(horizon.dy, closeTo(size.height - SkyPainter.groundHeight, 0.001));
      expect(winter.dy, lessThan(horizon.dy));
      expect(summer.dy, lessThan(winter.dy));
      expect(zenith.dy - SkyPainter.discRadius(size), greaterThanOrEqualTo(0));
    });

    test('ألوان السماء: زرقاء نهاراً، دافئة الأفق عند الغروب، داكنة ليلاً', () {
      final day = SkyPainter.skyColors(50);
      final sunsetColors = SkyPainter.skyColors(0);
      final night = SkyPainter.skyColors(-30);

      expect(day.$1.b, greaterThan(day.$1.r));
      expect(sunsetColors.$2.r, greaterThan(sunsetColors.$2.b));
      expect(night.$1.computeLuminance(), lessThan(0.01));
      expect(day.$1.computeLuminance(), greaterThan(night.$1.computeLuminance() * 10));
    });
  });

  group('الودجة', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      required TextDirection direction,
      required DateTime now,
    }) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final t = sunTimes(now);
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4532A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkyDayStrip(
                        latitude: lat,
                        longitude: lng,
                        sunrise: t.sunrise,
                        sunset: t.sunset,
                        now: now,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    final moments = <String, DateTime>{
      'ظهراً': DateTime.utc(2026, 10, 6, 9, 30),
      'عند الغروب': DateTime.utc(2026, 10, 6, 15, 10),
      'ليلاً': DateTime.utc(2026, 10, 6, 21),
      'بدراً': DateTime.utc(2024, 10, 17, 21, 30),
    };

    for (final width in const [320.0, 1366.0]) {
      for (final direction in TextDirection.values) {
        for (final moment in moments.entries) {
          testWidgets('تُرسم بلا أخطاء: عرض ${width.toInt()}، ${direction.name}، ${moment.key}', (tester) async {
            await pump(tester, width: width, direction: direction, now: moment.value);

            expect(tester.takeException(), isNull);
            expect(find.byType(SkyDayStrip), findsOneWidget);
            expect(find.textContaining('الشروق'), findsOneWidget);
            expect(find.textContaining('الغروب'), findsOneWidget);
            expect(find.textContaining('القمر:'), findsOneWidget);
            // اللوحة أعلى على العريض منها على الهاتف
            final strip = tester.getSize(
                find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SkyPainter));
            expect(strip.height, width < 520 ? 104 : 132);
          });
        }
      }
    }

    testWidgets('سطر القمر: اسم الطور ونسبته وموعد طلوعه أو غروبه', (tester) async {
      await pump(tester, width: 390, direction: TextDirection.rtl, now: DateTime.utc(2024, 10, 17, 21, 30));

      expect(find.text('القمر: بدر · 100%'), findsOneWidget);
      expect(find.textContaining('يغرب'), findsOneWidget);
      expect(find.textContaining('يطلع'), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('وقت الشروق تحت طرف القوس الشرقي ولو تغيّر اتجاه النص (${direction.name})', (tester) async {
        await pump(tester, width: 390, direction: direction, now: DateTime.utc(2026, 10, 6, 9, 30));

        final rise = tester.getCenter(find.textContaining('الشروق'));
        final set = tester.getCenter(find.textContaining('الغروب'));
        expect(rise.dx, lessThan(set.dx));
      });
    }

    // صور للمعاينة بالعين: SKY_PNG_DIR=<مجلد> flutter test test/sky_day_strip_test.dart
    final pngDir = Platform.environment['SKY_PNG_DIR'];
    if (pngDir != null && pngDir.isNotEmpty) {
      testWidgets('صور المعاينة', (tester) async {
        await tester.runAsync(() async {
          for (final font in const {
            'Tajawal': ['assets/fonts/Tajawal-Regular.ttf', 'assets/fonts/Tajawal-Bold.ttf'],
          }.entries) {
            final loader = FontLoader(font.key);
            for (final path in font.value) {
              loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
            }
            await loader.load();
          }
        });

        final shots = <String, DateTime>{
          '01_sunrise': DateTime.utc(2026, 10, 6, 3, 40),
          '02_morning': DateTime.utc(2026, 10, 6, 6, 0),
          '03_noon': DateTime.utc(2026, 10, 6, 9, 30),
          '04_afternoon': DateTime.utc(2026, 10, 6, 13, 0),
          '05_sunset': DateTime.utc(2026, 10, 6, 15, 10),
          '06_dusk': DateTime.utc(2026, 10, 6, 15, 40),
          '07_night': DateTime.utc(2026, 10, 6, 21, 0),
          '08_full_moon': DateTime.utc(2024, 10, 17, 21, 30),
          '09_evening_crescent': DateTime.utc(2024, 10, 5, 15, 25),
          '10_dawn_crescent': DateTime.utc(2024, 9, 29, 2, 40),
          '11_day_moon': DateTime.utc(2024, 10, 11, 13, 0),
          '12_gibbous_night': DateTime.utc(2024, 10, 13, 19, 0),
        };
        for (final width in const [360.0, 900.0]) {
          for (final shot in shots.entries) {
            final key = GlobalKey();
            tester.view.physicalSize = Size(width * 2, 640);
            tester.view.devicePixelRatio = 2.0;
            final t = sunTimes(shot.value);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'Tajawal'),
                home: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: RepaintBoundary(
                      key: key,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB4532A), Color(0xCCB4532A)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SkyDayStrip(
                                key: ValueKey('${shot.key}-$width'),
                                latitude: lat,
                                longitude: lng,
                                sunrise: t.sunrise,
                                sunset: t.sunset,
                                now: shot.value,
                              ),
                              const SizedBox(height: 14),
                              const Text('02:14:36',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2.0);
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              File('$pngDir/sky_${width.toInt()}_${shot.key}.png')
                ..createSync(recursive: true)
                ..writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          }
        }
        tester.view.reset();
      });
    }
  });
}
