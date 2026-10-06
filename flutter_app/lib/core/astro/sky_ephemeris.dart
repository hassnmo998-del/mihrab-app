import 'dart:math' as math;

/// حساب فلكي صافٍ (بلا اعتماديات) لموضع الشمس والقمر في سماء الراصد وطور القمر.
///
/// الخوارزميات من كتاب Jean Meeus «Astronomical Algorithms» (الطبعة الثانية):
/// الشمس من الفصل 25، القمر بسلسلته الكاملة من الفصل 47 (دقة نحو 10 ثوانٍ قوسية)،
/// الإضاءة وزاوية الطرف المضيء من الفصل 48، والزاوية البارالاكتية من الفصل 14.
/// كل الزوايا بالدرجات، وكل الأوقات UTC.
class SkyEphemeris {
  SkyEphemeris._();

  static const double _deg = math.pi / 180.0;
  static const double _auKm = 149597870.7;
  static const double _earthRadiusKm = 6378.14;

  /// الفرق بين التوقيت الأرضي TT والتوقيت العالمي UT بالثواني (نحو 69 ثانية في
  /// عشرينيات هذا القرن). أثره على موضع القمر أقل من دقيقة قوسية.
  static const double deltaTSeconds = 70.0;

  /// انكسار الأفق القياسي (34 دقيقة قوسية).
  static const double _horizonRefraction = 0.5667;

  // ===========================================================
  // الزمن
  // ===========================================================
  static double julianDay(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static DateTime _fromJulianDay(double jd) =>
      DateTime.fromMillisecondsSinceEpoch(((jd - 2440587.5) * 86400000.0).round(), isUtc: true);

  static double _centuriesTT(double jdUt) => (jdUt + deltaTSeconds / 86400.0 - 2451545.0) / 36525.0;

  static double _norm360(double x) => x % 360.0;

  static double _norm180(double x) {
    final n = x % 360.0;
    return n > 180.0 ? n - 360.0 : n;
  }

  static double _meanObliquity(double t) =>
      23.0 + 26.0 / 60.0 + 21.448 / 3600.0 - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600.0;

  /// التمايل في الطول والميل (درجات)، الحدود الأربعة الكبرى.
  static ({double dPsi, double dEps}) _nutation(double t) {
    final omega = (125.04452 - 1934.136261 * t) * _deg;
    final ls = (280.4665 + 36000.7698 * t) * _deg;
    final lm = (218.3165 + 481267.8813 * t) * _deg;
    final dPsi = (-17.20 * math.sin(omega) -
            1.32 * math.sin(2 * ls) -
            0.23 * math.sin(2 * lm) +
            0.21 * math.sin(2 * omega)) /
        3600.0;
    final dEps = (9.20 * math.cos(omega) +
            0.57 * math.cos(2 * ls) +
            0.10 * math.cos(2 * lm) -
            0.09 * math.cos(2 * omega)) /
        3600.0;
    return (dPsi: dPsi, dEps: dEps);
  }

  /// الزمن النجمي الظاهري في غرينتش (درجات).
  static double _greenwichSiderealTime(double jdUt) {
    final t = (jdUt - 2451545.0) / 36525.0;
    final mean = 280.46061837 +
        360.98564736629 * (jdUt - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;
    final tt = _centuriesTT(jdUt);
    final nut = _nutation(tt);
    final eps = (_meanObliquity(tt) + nut.dEps) * _deg;
    return _norm360(mean + nut.dPsi * math.cos(eps));
  }

  // ===========================================================
  // الشمس (مركز الأرض)
  // ===========================================================
  /// إحداثيات الشمس الظاهرية عند القرن اليولياني [t] (توقيت أرضي).
  static GeocentricBody sunGeocentric(double t) {
    final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * _deg;
    final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) +
        (0.019993 - 0.000101 * t) * math.sin(2 * m) +
        0.000289 * math.sin(3 * m);
    final trueLongitude = l0 + c;
    final nu = m + c * _deg;
    final r = 1.000001018 * (1 - e * e) / (1 + e * math.cos(nu));
    final omega = (125.04 - 1934.136 * t) * _deg;
    final lambda = trueLongitude - 0.00569 - 0.00478 * math.sin(omega);
    final eps = (_meanObliquity(t) + 0.00256 * math.cos(omega)) * _deg;
    final lam = lambda * _deg;
    final ra = math.atan2(math.cos(eps) * math.sin(lam), math.cos(lam)) / _deg;
    final dec = math.asin(math.sin(eps) * math.sin(lam)) / _deg;
    return GeocentricBody(
      longitude: _norm360(lambda),
      latitude: 0,
      rightAscension: _norm360(ra),
      declination: dec,
      distanceKm: r * _auKm,
    );
  }

  // ===========================================================
  // القمر (مركز الأرض) — سلسلة Meeus الكاملة
  // ===========================================================
  /// الطول والعرض الهندسيان للقمر وبعده، قبل التمايل (للتحقق من السلسلة).
  static ({double longitude, double latitude, double distanceKm}) moonSeries(double t) {
    final lp = 218.3164477 +
        481267.88123421 * t -
        0.0015786 * t * t +
        t * t * t / 538841.0 -
        t * t * t * t / 65194000.0;
    final d = 297.8501921 +
        445267.1114034 * t -
        0.0018819 * t * t +
        t * t * t / 545868.0 -
        t * t * t * t / 113065000.0;
    final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t + t * t * t / 24490000.0;
    final mp = 134.9633964 +
        477198.8675055 * t +
        0.0087414 * t * t +
        t * t * t / 69699.0 -
        t * t * t * t / 14712000.0;
    final f = 93.2720950 +
        483202.0175233 * t -
        0.0036539 * t * t -
        t * t * t / 3526000.0 +
        t * t * t * t / 863310000.0;
    final a1 = (119.75 + 131.849 * t) * _deg;
    final a2 = (53.09 + 479264.290 * t) * _deg;
    final a3 = (313.45 + 481266.484 * t) * _deg;
    final e = 1 - 0.002516 * t - 0.0000074 * t * t;

    final dr = d * _deg, mr = m * _deg, mpr = mp * _deg, fr = f * _deg, lpr = lp * _deg;

    double sumL = 0, sumR = 0, sumB = 0;
    for (final row in _moonLongitudeDistance) {
      final arg = row[0] * dr + row[1] * mr + row[2] * mpr + row[3] * fr;
      final ecc = row[1] == 0 ? 1.0 : (row[1].abs() == 1 ? e : e * e);
      sumL += row[4] * ecc * math.sin(arg);
      sumR += row[5] * ecc * math.cos(arg);
    }
    for (final row in _moonLatitude) {
      final arg = row[0] * dr + row[1] * mr + row[2] * mpr + row[3] * fr;
      final ecc = row[1] == 0 ? 1.0 : (row[1].abs() == 1 ? e : e * e);
      sumB += row[4] * ecc * math.sin(arg);
    }
    sumL += 3958 * math.sin(a1) + 1962 * math.sin(lpr - fr) + 318 * math.sin(a2);
    sumB += -2235 * math.sin(lpr) +
        382 * math.sin(a3) +
        175 * math.sin(a1 - fr) +
        175 * math.sin(a1 + fr) +
        127 * math.sin(lpr - mpr) -
        115 * math.sin(lpr + mpr);

    return (
      longitude: _norm360(lp + sumL / 1000000.0),
      latitude: sumB / 1000000.0,
      distanceKm: 385000.56 + sumR / 1000.0,
    );
  }

  /// إحداثيات القمر الظاهرية عند القرن اليولياني [t] (توقيت أرضي).
  static GeocentricBody moonGeocentric(double t) {
    final s = moonSeries(t);
    final nut = _nutation(t);
    final lambda = (s.longitude + nut.dPsi) * _deg;
    final beta = s.latitude * _deg;
    final eps = (_meanObliquity(t) + nut.dEps) * _deg;
    final ra = math.atan2(
          math.sin(lambda) * math.cos(eps) - math.tan(beta) * math.sin(eps),
          math.cos(lambda),
        ) /
        _deg;
    final dec = math.asin(
          math.sin(beta) * math.cos(eps) + math.cos(beta) * math.sin(eps) * math.sin(lambda),
        ) /
        _deg;
    return GeocentricBody(
      longitude: _norm360(s.longitude + nut.dPsi),
      latitude: s.latitude,
      rightAscension: _norm360(ra),
      declination: dec,
      distanceKm: s.distanceKm,
    );
  }

  // ===========================================================
  // سماء الراصد
  // ===========================================================
  static ({double altitude, double azimuth, double hourAngle}) _horizontal(
    double jdUt,
    double latitude,
    double longitude,
    double rightAscension,
    double declination,
  ) {
    final h = _norm180(_greenwichSiderealTime(jdUt) + longitude - rightAscension);
    final hr = h * _deg;
    final phi = latitude.clamp(-89.99, 89.99) * _deg;
    final dec = declination * _deg;
    final sinAlt = math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(hr);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0)) / _deg;
    final az = math.atan2(
          math.sin(hr),
          math.cos(hr) * math.sin(phi) - math.tan(dec) * math.cos(phi),
        ) /
        _deg;
    return (altitude: alt, azimuth: _norm360(az + 180.0), hourAngle: h);
  }

  /// موضع الشمس في سماء الراصد (ارتفاع هندسي لمركز القرص بلا انكسار).
  static SunState sun(DateTime time, double latitude, double longitude) {
    final jd = julianDay(time);
    final g = sunGeocentric(_centuriesTT(jd));
    final h = _horizontal(jd, latitude, longitude, g.rightAscension, g.declination);
    return SunState(
      altitude: h.altitude,
      azimuth: h.azimuth,
      hourAngle: h.hourAngle,
      geocentric: g,
    );
  }

  /// موضع القمر في سماء الراصد وطوره كما يُرى من مكانه.
  static MoonState moon(DateTime time, double latitude, double longitude) {
    final jd = julianDay(time);
    final t = _centuriesTT(jd);
    final g = moonGeocentric(t);
    final s = sunGeocentric(t);
    final h = _horizontal(jd, latitude, longitude, g.rightAscension, g.declination);

    // اختلاف المنظر: القمر قريب، فارتفاعه من سطح الأرض أوطأ منه من مركزها بنحو درجة
    final sinPi = _earthRadiusKm / g.distanceKm;
    final altR = h.altitude * _deg;
    final topoAlt = math.atan2(math.sin(altR) - sinPi, math.cos(altR)) / _deg;

    // نسبة الإضاءة وزاوية الطرف المضيء
    final ra0 = s.rightAscension * _deg, dec0 = s.declination * _deg;
    final ra = g.rightAscension * _deg, dec = g.declination * _deg;
    final cosPsi = math.sin(dec0) * math.sin(dec) + math.cos(dec0) * math.cos(dec) * math.cos(ra0 - ra);
    final psi = math.acos(cosPsi.clamp(-1.0, 1.0));
    final i = math.atan2(s.distanceKm * math.sin(psi), g.distanceKm - s.distanceKm * math.cos(psi));
    final k = (1 + math.cos(i)) / 2;
    final chi = math.atan2(
          math.cos(dec0) * math.sin(ra0 - ra),
          math.sin(dec0) * math.cos(dec) - math.cos(dec0) * math.sin(dec) * math.cos(ra0 - ra),
        ) /
        _deg;

    // الزاوية البارالاكتية: بين اتجاه القطب الشمالي واتجاه سمت الرأس عند القمر
    final hr = h.hourAngle * _deg;
    final phi = latitude.clamp(-89.99, 89.99) * _deg;
    final q = math.atan2(
          math.sin(hr),
          math.tan(phi) * math.cos(dec) - math.sin(dec) * math.cos(hr),
        ) /
        _deg;

    final elongation = _norm360(g.longitude - s.longitude);
    return MoonState(
      altitude: topoAlt,
      azimuth: h.azimuth,
      hourAngle: h.hourAngle,
      illumination: k.clamp(0.0, 1.0),
      waxing: elongation < 180.0,
      elongation: elongation,
      brightLimbPositionAngle: _norm360(chi),
      parallacticAngle: q,
      brightLimbZenithAngle: _norm360(chi - q),
      semiDiameter: math.asin(0.2725 * sinPi) / _deg,
      geocentric: g,
    );
  }

  // ===========================================================
  // الطلوع والغروب
  // ===========================================================
  /// ارتفاع مركز الشمس فوق عتبة الشروق/الغروب (الطرف العلوي عند الأفق مع الانكسار).
  static double _sunAboveHorizon(DateTime t, double lat, double lng) =>
      sun(t, lat, lng).altitude + 0.8333;

  /// ارتفاع مركز القمر فوق عتبة طلوعه/غروبه (الطرف العلوي عند الأفق مع الانكسار).
  static double _moonAboveHorizon(DateTime t, double lat, double lng) {
    final m = moon(t, lat, lng);
    return m.altitude + _horizonRefraction + m.semiDiameter;
  }

  /// أول عبور للأفق بين [from] و[to] بالاتجاه المطلوب، بدقة ثانية؛ أو null.
  static DateTime? _crossing(
    double Function(DateTime) above,
    DateTime from,
    DateTime to, {
    required bool rising,
    Duration step = const Duration(minutes: 10),
  }) {
    final forward = !to.isBefore(from);
    var a = from;
    var fa = above(a);
    while (forward ? a.isBefore(to) : a.isAfter(to)) {
      var b = forward ? a.add(step) : a.subtract(step);
      if (forward ? b.isAfter(to) : b.isBefore(to)) b = to;
      final fb = above(b);
      // بترتيب الزمن: الأقدم ثم الأحدث
      final early = forward ? a : b, late = forward ? b : a;
      final fEarly = forward ? fa : fb, fLate = forward ? fb : fa;
      final hit = rising ? (fEarly < 0 && fLate >= 0) : (fEarly >= 0 && fLate < 0);
      if (hit) {
        var lo = early, hi = late;
        for (var i = 0; i < 12; i++) {
          final mid = lo.add(Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2));
          final fm = above(mid);
          if ((fm >= 0) == rising) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        return hi;
      }
      a = b;
      fa = fb;
    }
    return null;
  }

  /// شروق الشمس وغروبها لليوم المدني [day] عند الراصد (null في نهار أو ليل قطبي).
  static ({DateTime? rise, DateTime? set}) sunRiseSet(DateTime day, double latitude, double longitude) {
    final noon = DateTime.utc(day.year, day.month, day.day, 12)
        .subtract(Duration(seconds: (longitude / 15.0 * 3600).round()));
    double above(DateTime t) => _sunAboveHorizon(t, latitude, longitude);
    return (
      rise: _crossing(above, noon.subtract(const Duration(hours: 12)), noon, rising: true),
      set: _crossing(above, noon, noon.add(const Duration(hours: 12)), rising: false),
    );
  }

  /// طلوع القمر وغروبه حول اللحظة [time]: الطلوع السابق (إن كان فوق الأفق الآن)،
  /// والطلوع والغروب القادمان.
  static MoonTimes moonTimes(DateTime time, double latitude, double longitude) {
    final now = time.toUtc();
    double above(DateTime t) => _moonAboveHorizon(t, latitude, longitude);
    final isUp = above(now) >= 0;
    final horizon = now.add(const Duration(hours: 26));
    return MoonTimes(
      isUp: isUp,
      previousRise:
          isUp ? _crossing(above, now, now.subtract(const Duration(hours: 26)), rising: true) : null,
      nextRise: _crossing(above, now, horizon, rising: true),
      nextSet: _crossing(above, now, horizon, rising: false),
    );
  }

  // ===========================================================
  // عمر القمر واسم طوره
  // ===========================================================
  /// لحظة آخر اقتران (محاق) قبل [time].
  static DateTime previousNewMoon(DateTime time) {
    double signedElongation(double jd) {
      final t = _centuriesTT(jd);
      return _norm180(moonGeocentric(t).longitude - sunGeocentric(t).longitude);
    }

    final jd0 = julianDay(time);
    final t0 = _centuriesTT(jd0);
    final elongation = _norm360(moonGeocentric(t0).longitude - sunGeocentric(t0).longitude);
    var jd = jd0 - elongation / 12.1907;
    for (var i = 0; i < 6; i++) {
      jd -= signedElongation(jd) / 12.1907;
    }
    return _fromJulianDay(jd);
  }

  /// عمر القمر بالأيام منذ آخر محاق.
  static double moonAgeDays(DateTime time) =>
      time.toUtc().difference(previousNewMoon(time)).inSeconds / 86400.0;

  /// اسم الطور بالعربية من نسبة الإضاءة واتجاهها.
  static String phaseNameAr(double illumination, bool waxing) {
    if (illumination < 0.01) return 'محاق';
    if (illumination > 0.985) return 'بدر';
    if ((illumination - 0.5).abs() < 0.06) return waxing ? 'تربيع أول' : 'تربيع أخير';
    if (illumination < 0.5) return waxing ? 'هلال متزايد' : 'هلال متناقص';
    return waxing ? 'أحدب متزايد' : 'أحدب متناقص';
  }

  // ===========================================================
  // جداول Meeus 47.A و47.B
  // ===========================================================
  /// D, M, M', F, معامل الطول (1e-6 درجة)، معامل البعد (1e-3 كم).
  static const List<List<int>> _moonLongitudeDistance = [
    [0, 0, 1, 0, 6288774, -20905355],
    [2, 0, -1, 0, 1274027, -3699111],
    [2, 0, 0, 0, 658314, -2955968],
    [0, 0, 2, 0, 213618, -569925],
    [0, 1, 0, 0, -185116, 48888],
    [0, 0, 0, 2, -114332, -3149],
    [2, 0, -2, 0, 58793, 246158],
    [2, -1, -1, 0, 57066, -152138],
    [2, 0, 1, 0, 53322, -170733],
    [2, -1, 0, 0, 45758, -204586],
    [0, 1, -1, 0, -40923, -129620],
    [1, 0, 0, 0, -34720, 108743],
    [0, 1, 1, 0, -30383, 104755],
    [2, 0, 0, -2, 15327, 10321],
    [0, 0, 1, 2, -12528, 0],
    [0, 0, 1, -2, 10980, 79661],
    [4, 0, -1, 0, 10675, -34782],
    [0, 0, 3, 0, 10034, -23210],
    [4, 0, -2, 0, 8548, -21636],
    [2, 1, -1, 0, -7888, 24208],
    [2, 1, 0, 0, -6766, 30824],
    [1, 0, -1, 0, -5163, -8379],
    [1, 1, 0, 0, 4987, -16675],
    [2, -1, 1, 0, 4036, -12831],
    [2, 0, 2, 0, 3994, -10445],
    [4, 0, 0, 0, 3861, -11650],
    [2, 0, -3, 0, 3665, 14403],
    [0, 1, -2, 0, -2689, -7003],
    [2, 0, -1, 2, -2602, 0],
    [2, -1, -2, 0, 2390, 10056],
    [1, 0, 1, 0, -2348, 6322],
    [2, -2, 0, 0, 2236, -9884],
    [0, 1, 2, 0, -2120, 5751],
    [0, 2, 0, 0, -2069, 0],
    [2, -2, -1, 0, 2048, -4950],
    [2, 0, 1, -2, -1773, 4130],
    [2, 0, 0, 2, -1595, 0],
    [4, -1, -1, 0, 1215, -3958],
    [0, 0, 2, 2, -1110, 0],
    [3, 0, -1, 0, -892, 3258],
    [2, 1, 1, 0, -810, 2616],
    [4, -1, -2, 0, 759, -1897],
    [0, 2, -1, 0, -713, -2117],
    [2, 2, -1, 0, -700, 2354],
    [2, 1, -2, 0, 691, 0],
    [2, -1, 0, -2, 596, 0],
    [4, 0, 1, 0, 549, -1423],
    [0, 0, 4, 0, 537, -1117],
    [4, -1, 0, 0, 520, -1571],
    [1, 0, -2, 0, -487, -1739],
    [2, 1, 0, -2, -399, 0],
    [0, 0, 2, -2, -381, -4421],
    [1, 1, 1, 0, 351, 0],
    [3, 0, -2, 0, -340, 0],
    [4, 0, -3, 0, 330, 0],
    [2, -1, 2, 0, 327, 0],
    [0, 2, 1, 0, -323, 1165],
    [1, 1, -1, 0, 299, 0],
    [2, 0, 3, 0, 294, 0],
    [2, 0, -1, -2, 0, 8752],
  ];

  /// D, M, M', F, معامل العرض (1e-6 درجة).
  static const List<List<int>> _moonLatitude = [
    [0, 0, 0, 1, 5128122],
    [0, 0, 1, 1, 280602],
    [0, 0, 1, -1, 277693],
    [2, 0, 0, -1, 173237],
    [2, 0, -1, 1, 55413],
    [2, 0, -1, -1, 46271],
    [2, 0, 0, 1, 32573],
    [0, 0, 2, 1, 17198],
    [2, 0, 1, -1, 9266],
    [0, 0, 2, -1, 8822],
    [2, -1, 0, -1, 8216],
    [2, 0, -2, -1, 4324],
    [2, 0, 1, 1, 4200],
    [2, 1, 0, -1, -3359],
    [2, -1, -1, 1, 2463],
    [2, -1, 0, 1, 2211],
    [2, -1, -1, -1, 2065],
    [0, 1, -1, -1, -1870],
    [4, 0, -1, -1, 1828],
    [0, 1, 0, 1, -1794],
    [0, 0, 0, 3, -1749],
    [0, 1, -1, 1, -1565],
    [1, 0, 0, 1, -1491],
    [0, 1, 1, 1, -1475],
    [0, 1, 1, -1, -1410],
    [0, 1, 0, -1, -1344],
    [1, 0, 0, -1, -1335],
    [0, 0, 3, 1, 1107],
    [4, 0, 0, -1, 1021],
    [4, 0, -1, 1, 833],
    [0, 0, 1, -3, 777],
    [4, 0, -2, 1, 671],
    [2, 0, 0, -3, 607],
    [2, 0, 2, -1, 596],
    [2, -1, 1, -1, 491],
    [2, 0, -2, 1, -451],
    [0, 0, 3, -1, 439],
    [2, 0, 2, 1, 422],
    [2, 0, -3, -1, 421],
    [2, 1, -1, 1, -366],
    [2, 1, 0, 1, -351],
    [4, 0, 0, 1, 331],
    [2, -1, 1, 1, 315],
    [2, -2, 0, -1, 302],
    [0, 0, 1, 3, -283],
    [2, 1, 1, -1, -229],
    [1, 1, 0, -1, 223],
    [1, 1, 0, 1, 223],
    [0, 1, -2, -1, -220],
    [2, 1, -1, -1, -220],
    [1, 0, 1, 1, -185],
    [2, -1, -2, -1, 181],
    [0, 1, 2, 1, -177],
    [4, 0, -2, -1, 176],
    [4, -1, -1, -1, 166],
    [1, 0, 1, -1, -164],
    [4, 0, 1, -1, 132],
    [1, 0, -1, -1, -119],
    [4, -1, 0, -1, 115],
    [2, -2, 0, 1, 107],
  ];
}

/// إحداثيات جرم من مركز الأرض (درجات وكيلومترات).
class GeocentricBody {
  final double longitude;
  final double latitude;
  final double rightAscension;
  final double declination;
  final double distanceKm;

  const GeocentricBody({
    required this.longitude,
    required this.latitude,
    required this.rightAscension,
    required this.declination,
    required this.distanceKm,
  });
}

class SunState {
  /// الارتفاع فوق الأفق بالدرجات (سالب تحته).
  final double altitude;

  /// السمت من الشمال باتجاه الشرق.
  final double azimuth;

  /// الزاوية الساعية (سالبة قبل الزوال، موجبة بعده).
  final double hourAngle;
  final GeocentricBody geocentric;

  const SunState({
    required this.altitude,
    required this.azimuth,
    required this.hourAngle,
    required this.geocentric,
  });
}

class MoonState {
  /// ارتفاع مركز القمر من مكان الراصد (بعد تصحيح اختلاف المنظر).
  final double altitude;
  final double azimuth;
  final double hourAngle;

  /// نسبة المضيء من القرص: 0 محاق، 1 بدر.
  final double illumination;

  /// متزايد (بين المحاق والبدر) أم متناقص.
  final bool waxing;

  /// فرق الطول بين القمر والشمس (0 محاق، 180 بدر).
  final double elongation;

  /// زاوية منتصف الطرف المضيء من شمال القرص باتجاه الشرق.
  final double brightLimbPositionAngle;
  final double parallacticAngle;

  /// زاوية منتصف الطرف المضيء من أعلى القرص (جهة سمت الرأس) عكس عقارب الساعة كما
  /// يراه الراصد: 90 الطرف المضيء يساراً، 180 أسفل، 270 يميناً.
  final double brightLimbZenithAngle;

  /// نصف القطر الظاهري للقرص بالدرجات.
  final double semiDiameter;
  final GeocentricBody geocentric;

  const MoonState({
    required this.altitude,
    required this.azimuth,
    required this.hourAngle,
    required this.illumination,
    required this.waxing,
    required this.elongation,
    required this.brightLimbPositionAngle,
    required this.parallacticAngle,
    required this.brightLimbZenithAngle,
    required this.semiDiameter,
    required this.geocentric,
  });
}

class MoonTimes {
  final bool isUp;
  final DateTime? previousRise;
  final DateTime? nextRise;
  final DateTime? nextSet;

  const MoonTimes({
    required this.isUp,
    required this.previousRise,
    required this.nextRise,
    required this.nextSet,
  });
}
