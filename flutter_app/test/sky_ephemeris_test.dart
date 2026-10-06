import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/astro/sky_ephemeris.dart';

/// الحساب الفلكي مقابل قيم مرجعية منشورة: أمثلة كتاب Meeus المحلولة، لحظات أطوار
/// قمرية وكسوف معروفة، ومواقيت حزمة `adhan` التي تُعرض في شبكة المواقيت.
void main() {
  const damascusLat = 33.5138, damascusLng = 36.2765;

  // القرن اليولياني (توقيت أرضي) لتاريخ يولياني معطى
  double centuries(double jde) => (jde - 2451545.0) / 36525.0;

  // لحظة UTC يقابلها التوقيت الأرضي المعطى، بفرق ΔT الذي يستعمله الحساب نفسه
  DateTime utcForTT(DateTime tt) =>
      tt.subtract(Duration(milliseconds: (SkyEphemeris.deltaTSeconds * 1000).round()));

  group('أمثلة Meeus المحلولة', () {
    test('القمر (مثال 47.a): 12 نيسان 1992، سلسلة الطول والعرض والبعد كاملة', () {
      final s = SkyEphemeris.moonSeries(centuries(2448724.5));
      expect(s.longitude, closeTo(133.162655, 0.00003));
      expect(s.latitude, closeTo(-3.229126, 0.00003));
      expect(s.distanceKm, closeTo(368409.7, 0.5));

      final g = SkyEphemeris.moonGeocentric(centuries(2448724.5));
      expect(g.longitude, closeTo(133.167265, 0.0005));
      expect(g.rightAscension, closeTo(134.688470, 0.0006));
      expect(g.declination, closeTo(13.768368, 0.0006));
    });

    test('الشمس (مثال 25.a): 13 تشرين الأول 1992', () {
      final g = SkyEphemeris.sunGeocentric(centuries(2448908.5));
      expect(g.longitude, closeTo(199.90895, 0.0002));
      expect(g.rightAscension, closeTo(198.38083, 0.0003));
      expect(g.declination, closeTo(-7.78507, 0.0003));
      expect(g.distanceKm / 149597870.7, closeTo(0.99766, 0.00001));
    });

    test('إضاءة القمر وزاوية طرفه المضيء (مثال 48.a)', () {
      final m = SkyEphemeris.moon(utcForTT(DateTime.utc(1992, 4, 12)), damascusLat, damascusLng);
      expect(m.illumination, closeTo(0.6786, 0.0005));
      expect(m.brightLimbPositionAngle, closeTo(285.0, 0.1));
      expect(m.waxing, isTrue);
    });
  });

  group('أطوار القمر في لحظاتها المعروفة', () {
    test('بدر 17 تشرين الأول 2024 الساعة 11:26 UTC', () {
      final m = SkyEphemeris.moon(DateTime.utc(2024, 10, 17, 11, 26), damascusLat, damascusLng);
      expect(m.illumination, greaterThan(0.995));
      expect(m.elongation, closeTo(180, 0.1));
      expect(SkyEphemeris.phaseNameAr(m.illumination, m.waxing), 'بدر');
    });

    test('محاق 2 تشرين الأول 2024 الساعة 18:49 UTC (كسوف حلقي)', () {
      final m = SkyEphemeris.moon(DateTime.utc(2024, 10, 2, 18, 49), damascusLat, damascusLng);
      expect(m.illumination, lessThan(0.002));
      expect(SkyEphemeris.phaseNameAr(m.illumination, m.waxing), 'محاق');
    });

    test('تربيع أول 10 تشرين الأول 2024 الساعة 18:55 UTC', () {
      final m = SkyEphemeris.moon(DateTime.utc(2024, 10, 10, 18, 55), damascusLat, damascusLng);
      expect(m.elongation, closeTo(90, 0.1));
      expect(m.illumination, closeTo(0.5, 0.01));
      expect(m.waxing, isTrue);
      expect(SkyEphemeris.phaseNameAr(m.illumination, m.waxing), 'تربيع أول');
    });

    test('تربيع أخير 24 تشرين الأول 2024 الساعة 08:03 UTC', () {
      final m = SkyEphemeris.moon(DateTime.utc(2024, 10, 24, 8, 3), damascusLat, damascusLng);
      expect(m.elongation, closeTo(270, 0.1));
      expect(m.waxing, isFalse);
      expect(SkyEphemeris.phaseNameAr(m.illumination, m.waxing), 'تربيع أخير');
    });

    test('عمر القمر يُحسب من لحظة المحاق الفعلية', () {
      final newMoon = SkyEphemeris.previousNewMoon(DateTime.utc(2024, 10, 17, 11, 26));
      expect(newMoon.difference(DateTime.utc(2024, 10, 2, 18, 49)).inMinutes.abs(), lessThan(3));
      expect(SkyEphemeris.moonAgeDays(DateTime.utc(2024, 10, 17, 11, 26)), closeTo(14.69, 0.01));
    });

    test('أسماء الأطوار الثمانية', () {
      expect(SkyEphemeris.phaseNameAr(0.0, true), 'محاق');
      expect(SkyEphemeris.phaseNameAr(0.2, true), 'هلال متزايد');
      expect(SkyEphemeris.phaseNameAr(0.5, true), 'تربيع أول');
      expect(SkyEphemeris.phaseNameAr(0.8, true), 'أحدب متزايد');
      expect(SkyEphemeris.phaseNameAr(1.0, true), 'بدر');
      expect(SkyEphemeris.phaseNameAr(0.8, false), 'أحدب متناقص');
      expect(SkyEphemeris.phaseNameAr(0.5, false), 'تربيع أخير');
      expect(SkyEphemeris.phaseNameAr(0.2, false), 'هلال متناقص');
    });
  });

  group('موضع الشمس والقمر في سماء الراصد', () {
    test('كسوف 8 نيسان 2024 الكلي: القمر فوق الشمس تماماً عند نقطة الذروة', () {
      // أعظم الكسوف: 18:17:20 UTC عند 25°17.4′ شمالاً، 104°08.3′ غرباً، وارتفاع الشمس 69.8°
      final t = DateTime.utc(2024, 4, 8, 18, 17, 20);
      const lat = 25.29, lng = -104.138;
      final s = SkyEphemeris.sun(t, lat, lng);
      final m = SkyEphemeris.moon(t, lat, lng);

      expect(s.altitude, closeTo(69.8, 0.15));
      expect(m.altitude, closeTo(s.altitude, 0.05));
      final azGap = (m.azimuth - s.azimuth) * math.cos(s.altitude * math.pi / 180);
      expect(azGap.abs(), lessThan(0.05));
      expect(m.illumination, lessThan(0.0005));
    });

    test('ظهر الانقلاب الصيفي في دمشق: الشمس على ارتفاع 79.9° جنوباً', () {
      var best = -90.0;
      var bestAz = 0.0;
      for (var minute = 0; minute < 180; minute++) {
        final s = SkyEphemeris.sun(
            DateTime.utc(2024, 6, 20, 8, 0).add(Duration(minutes: minute)), damascusLat, damascusLng);
        if (s.altitude > best) {
          best = s.altitude;
          bestAz = s.azimuth;
        }
      }
      expect(best, closeTo(79.92, 0.03));
      expect(bestAz, closeTo(180, 2));
    });

    test('قوس الشتاء أوطأ من قوس الصيف', () {
      final winterNoon = SkyEphemeris.sun(DateTime.utc(2024, 12, 21, 9, 35), damascusLat, damascusLng);
      final summerNoon = SkyEphemeris.sun(DateTime.utc(2024, 6, 20, 9, 35), damascusLat, damascusLng);
      expect(winterNoon.altitude, closeTo(33.05, 0.2));
      expect(summerNoon.altitude - winterNoon.altitude, greaterThan(46));
    });

    test('الشروق والغروب يطابقان مواقيت حزمة adhan المعروضة في الشبكة (ضمن دقيقتين)', () {
      final params = CalculationMethod.muslim_world_league.getParameters();
      for (final place in const [
        (33.5138, 36.2765), // دمشق
        (21.4225, 39.8262), // مكة
        (51.5074, -0.1278), // لندن
        (-6.2088, 106.8456), // جاكرتا
      ]) {
        for (final date in [DateTime(2024, 3, 20), DateTime(2024, 6, 21), DateTime(2026, 10, 6), DateTime(2026, 12, 22)]) {
          final pt = PrayerTimes(Coordinates(place.$1, place.$2), DateComponents.from(date), params);
          final mine = SkyEphemeris.sunRiseSet(date, place.$1, place.$2);
          expect(mine.rise!.difference(pt.sunrise.toUtc()).inSeconds.abs(), lessThan(120),
              reason: 'sunrise $place $date');
          expect(mine.set!.difference(pt.maghrib.toUtc()).inSeconds.abs(), lessThan(120),
              reason: 'sunset $place $date');
        }
      }
    });

    test('عند لحظتي الشروق والغروب المحسوبتين مركز الشمس تحت الأفق بـ0.83°', () {
      final times = SkyEphemeris.sunRiseSet(DateTime(2026, 10, 6), damascusLat, damascusLng);
      expect(SkyEphemeris.sun(times.rise!, damascusLat, damascusLng).altitude, closeTo(-0.8333, 0.002));
      expect(SkyEphemeris.sun(times.set!, damascusLat, damascusLng).altitude, closeTo(-0.8333, 0.002));
      expect(SkyEphemeris.sun(times.rise!, damascusLat, damascusLng).hourAngle, lessThan(0));
      expect(SkyEphemeris.sun(times.set!, damascusLat, damascusLng).hourAngle, greaterThan(0));
    });
  });

  group('طلوع القمر وغروبه', () {
    test('البدر يطلع قرب غروب الشمس ويغرب قرب شروقها', () {
      // بدر 17 تشرين الأول 2024؛ غروب الشمس في دمشق ذلك اليوم نحو 14:55 UTC
      final sunset = SkyEphemeris.sunRiseSet(DateTime(2024, 10, 17), damascusLat, damascusLng).set!;
      final times = SkyEphemeris.moonTimes(sunset.subtract(const Duration(hours: 3)), damascusLat, damascusLng);
      expect(times.isUp, isFalse);
      expect(times.nextRise!.difference(sunset).inMinutes.abs(), lessThan(45));

      final sunrise = SkyEphemeris.sunRiseSet(DateTime(2024, 10, 18), damascusLat, damascusLng).rise!;
      expect(times.nextSet!.difference(sunrise).inMinutes.abs(), lessThan(75));
    });

    test('المحاق يطلع ويغرب مع الشمس', () {
      final day = SkyEphemeris.sunRiseSet(DateTime(2024, 10, 2), damascusLat, damascusLng);
      final times = SkyEphemeris.moonTimes(day.rise!.subtract(const Duration(hours: 2)), damascusLat, damascusLng);
      expect(times.nextRise!.difference(day.rise!).inMinutes.abs(), lessThan(40));
      expect(times.nextSet!.difference(day.set!).inMinutes.abs(), lessThan(40));
    });

    test('عند لحظة الطلوع والغروب المحسوبتين طرف القمر العلوي عند الأفق', () {
      final now = DateTime.utc(2026, 10, 6, 12);
      final times = SkyEphemeris.moonTimes(now, damascusLat, damascusLng);
      for (final t in [times.nextRise!, times.nextSet!]) {
        final m = SkyEphemeris.moon(t, damascusLat, damascusLng);
        expect(m.altitude + 0.5667 + m.semiDiameter, closeTo(0, 0.003));
      }
    });

    test('القمر فوق الأفق: الطلوع السابق قبل الآن والغروب القادم بعده، وبينهما يبقى مرتفعاً', () {
      // نبحث عن لحظة يكون القمر فيها مرتفعاً
      var now = DateTime.utc(2026, 10, 6);
      while (!SkyEphemeris.moonTimes(now, damascusLat, damascusLng).isUp) {
        now = now.add(const Duration(hours: 1));
      }
      now = now.add(const Duration(hours: 2));
      final times = SkyEphemeris.moonTimes(now, damascusLat, damascusLng);

      expect(times.isUp, isTrue);
      expect(times.previousRise!.isBefore(now), isTrue);
      expect(times.nextSet!.isAfter(now), isTrue);
      final span = times.nextSet!.difference(times.previousRise!);
      expect(span.inHours, inInclusiveRange(8, 16));
      for (var i = 1; i < 10; i++) {
        final t = times.previousRise!.add(span * (i / 10));
        expect(SkyEphemeris.moon(t, damascusLat, damascusLng).altitude, greaterThan(0));
      }
    });
  });

  group('ميلان الهلال كما يُرى من المكان', () {
    test('هلال أول الشهر مساءً في دمشق: الطرف المضيء إلى الأسفل واليمين، جهة الشمس الغاربة', () {
      // 5 تشرين الأول 2024 بعد الغروب (15:30 UTC): هلال عمره ثلاثة أيام فوق الأفق الغربي
      final t = DateTime.utc(2024, 10, 5, 15, 30);
      final m = SkyEphemeris.moon(t, damascusLat, damascusLng);
      expect(m.altitude, greaterThan(0));
      expect(m.azimuth, inInclusiveRange(200, 260));
      expect(m.waxing, isTrue);
      expect(m.illumination, inInclusiveRange(0.03, 0.12));
      // 180 أسفل، 270 يمين
      expect(m.brightLimbZenithAngle, inInclusiveRange(185, 265));
    });

    test('هلال آخر الشهر فجراً في دمشق: الطرف المضيء إلى الأسفل واليسار، جهة الشمس الطالعة', () {
      // 29 أيلول 2024 قبل الشروق (02:30 UTC): هلال متناقص فوق الأفق الشرقي
      final t = DateTime.utc(2024, 9, 29, 2, 30);
      final m = SkyEphemeris.moon(t, damascusLat, damascusLng);
      expect(m.altitude, greaterThan(0));
      expect(m.azimuth, inInclusiveRange(60, 120));
      expect(m.waxing, isFalse);
      // 90 يسار، 180 أسفل
      expect(m.brightLimbZenithAngle, inInclusiveRange(95, 175));
    });

    test('في نصف الكرة الجنوبي ينقلب الهلال: المساء نفسه في كيب تاون والطرف المضيء إلى اليسار', () {
      final t = DateTime.utc(2024, 10, 5, 17, 30);
      final m = SkyEphemeris.moon(t, -33.9249, 18.4241);
      expect(m.altitude, greaterThan(0));
      expect(m.brightLimbZenithAngle, inInclusiveRange(95, 175));
    });

    test('الطرف المضيء يتجه دوماً نحو الشمس في السماء', () {
      // اتجاه الشمس من القمر على القبة: يُحسب من الارتفاع والسمت مباشرة ويُقارن بالزاوية
      for (final t in [
        DateTime.utc(2024, 10, 5, 15, 30),
        DateTime.utc(2024, 10, 12, 16, 0),
        DateTime.utc(2024, 10, 22, 22, 0),
        DateTime.utc(2026, 10, 6, 3, 0),
      ]) {
        final m = SkyEphemeris.moon(t, damascusLat, damascusLng);
        final s = SkyEphemeris.sun(t, damascusLat, damascusLng);
        const d = math.pi / 180;
        // زاوية الاتجاه نحو الشمس عند القمر، من سمت الرأس عكس عقارب الساعة كما يُرى
        final dAz = (s.azimuth - m.azimuth) * d;
        final toSun = math.atan2(
              math.sin(dAz) * math.cos(s.altitude * d),
              math.cos(m.altitude * d) * math.sin(s.altitude * d) -
                  math.sin(m.altitude * d) * math.cos(s.altitude * d) * math.cos(dAz),
            ) /
            d;
        // السمت يزيد باتجاه اليمين للناظر، فالزاوية عكس عقارب الساعة هي سالب المحسوبة
        final expected = (-toSun) % 360.0;
        final diff = ((m.brightLimbZenithAngle - expected + 540) % 360) - 180;
        expect(diff.abs(), lessThan(2.0), reason: '$t');
      }
    });
  });
}
