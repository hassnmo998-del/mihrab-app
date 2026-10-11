import 'dart:convert';

import 'package:flutter_app/core/astro/sky_ephemeris.dart';
import 'package:flutter_app/core/astro/sky_track.dart';
import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// سماء شريط الإشعار: أندرويد يستوفي خطياً بين هذه العيّنات ولا يحسب فلكاً، فيجب أن
/// تطابق العيّنات الحساب نفسه الذي يرسم كرت التطبيق، وأن يبقى الاستيفاء بينها قريباً منه.
void main() {
  const lat = 33.5138, lng = 36.2765; // دمشق
  final from = DateTime(2026, 10, 9);
  final to = DateTime(2026, 10, 24);
  late Map<String, dynamic> track;
  late List<int> sun, moon, lit, limb, par;
  late DateTime start;
  late Duration step;

  DateTime at(int i) => start.add(step * i);
  double lerp(List<int> a, double x) {
    final i = x.floor();
    return a[i] + (a[i + 1] - a[i]) * (x - i);
  }

  setUpAll(() {
    track = SkyTrack.build(from: from, to: to, latitude: lat, longitude: lng);
    sun = (track['sun'] as List).cast<int>();
    moon = (track['moon'] as List).cast<int>();
    lit = (track['lit'] as List).cast<int>();
    limb = (track['limb'] as List).cast<int>();
    par = (track['par'] as List).cast<int>();
    start = DateTime.fromMillisecondsSinceEpoch(track['start'] as int, isUtc: true);
    step = Duration(milliseconds: track['step'] as int);
  });

  test('عيّنة كل 20 دقيقة من أول المدة إلى آخرها، وكل الأعمدة بالطول نفسه', () {
    expect(start, from.toUtc());
    expect(step, const Duration(minutes: 20));
    expect(sun.length, 15 * 72 + 1);
    for (final column in [moon, lit, limb, par]) {
      expect(column.length, sun.length);
    }
    expect(at(sun.length - 1), to.toUtc());
    expect(track['east_right'], isFalse);
  });

  test('كل عيّنة هي الحساب نفسه الذي يرسم كرت التطبيق', () {
    for (var i = 0; i < sun.length; i += 37) {
      final s = SkyEphemeris.sun(at(i), lat, lng);
      final m = SkyEphemeris.moon(at(i), lat, lng);
      expect(sun[i], (s.altitude * 10).round());
      expect(moon[i], (m.altitude * 10).round());
      expect(lit[i], (m.illumination * 1000).round());
      expect(limb[i], m.brightLimbZenithAngle.round() % 360);
      expect(par[i], m.parallacticAngle.round());
      expect(lit[i], inInclusiveRange(0, 1000));
      expect(limb[i], inInclusiveRange(0, 359));
    }
  });

  test('الاستيفاء الخطي بين عيّنتين قريب من الحساب المباشر: دون البكسل على لوحة الإشعار', () {
    var worstSun = 0.0, worstMoon = 0.0, worstLit = 0.0;
    for (var i = 0; i < sun.length - 1; i++) {
      for (final f in const [0.25, 0.5, 0.75]) {
        final t = start.add(Duration(seconds: (step.inSeconds * (i + f)).round()));
        final m = SkyEphemeris.moon(t, lat, lng);
        final sunError = (lerp(sun, i + f) / 10 - SkyEphemeris.sun(t, lat, lng).altitude).abs();
        final moonError = (lerp(moon, i + f) / 10 - m.altitude).abs();
        final litError = (lerp(lit, i + f) / 1000 - m.illumination).abs();
        if (sunError > worstSun) worstSun = sunError;
        if (moonError > worstMoon) worstMoon = moonError;
        if (litError > worstLit) worstLit = litError;
      }
    }
    expect(worstSun, lessThan(0.2));
    // القمر قرب سمت الرأس يتغيّر ارتفاعه أسرع، وهناك جيب الارتفاع شبه ثابت فلا يتحرك القرص
    expect(worstMoon, lessThan(0.5));
    expect(worstLit, lessThan(0.002));
  });

  test('الحزمة صغيرة: تُرسل مع جدول المواقيت وتُحفظ في أندرويد', () {
    expect(jsonEncode(track).length, lessThan(40 * 1024));
  });

  test('نصف الكرة الجنوبي: الشرق عن يمين الراصد', () {
    final south = SkyTrack.build(
      from: from,
      to: from.add(const Duration(hours: 1)),
      latitude: -33.9,
      longitude: 18.4,
    );
    expect(south['east_right'], isTrue);
    expect((south['sun'] as List).length, 4);
  });

  test('ما يُرسل للشريط يغطي من أمس إلى آخر جدول المواقيت', () {
    final sky = AdhanService.instance.buildNotificationSky();
    final timeline = AdhanService.instance.buildNotificationTimeline();
    final first = sky['start'] as int;
    final last = first + (sky['step'] as int) * ((sky['sun'] as List).length - 1);
    final now = DateTime.now();

    expect(first, DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch);
    expect(last, greaterThanOrEqualTo(timeline.last['adhan'] as int));
  });
}
