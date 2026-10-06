import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/astro/sky_ephemeris.dart';

/// حالة السماء عند لحظة ومكان: كل ما ترسمه [SkyDayStrip]، محسوباً لا مرسوماً بالتقدير.
class SkySnapshot {
  final DateTime time;
  final DateTime sunrise;
  final DateTime sunset;

  /// ارتفاع الشمس بالدرجات (سالب تحت الأفق).
  final double sunAltitude;

  /// الشمس تجاوزت الزوال (فشفقها جهة الغروب) أم لم تبلغه (جهة الشروق).
  final bool sunPastNoon;

  /// موضع الشمس بين الشروق (0) والغروب (1).
  final double sunFraction;

  /// قوس الشمس اليوم: (الموضع بين الشروق والغروب، الارتفاع بالدرجات).
  final List<Offset> sunPath;

  final MoonState moon;
  final bool moonUp;

  /// موضع القمر بين طلوعه (0) وغروبه (1)، حين يكون فوق الأفق.
  final double moonFraction;

  /// قوس القمر بين طلوعه وغروبه: (الموضع، الارتفاع بالدرجات).
  final List<Offset> moonPath;
  final DateTime? moonNextRise;
  final DateTime? moonNextSet;

  /// اللوحة هي السماء كما يراها الراصد وهو متجه إلى حيث تعبر الشمس والقمر: في نصف
  /// الكرة الشمالي يتجه جنوباً فالشرق عن يساره، وفي الجنوبي يتجه شمالاً فالشرق عن يمينه.
  /// لا تتبع اتجاه النص: لو عُكست لانعكس الهلال عن شكله في السماء.
  final bool eastOnRight;

  const SkySnapshot({
    required this.time,
    required this.sunrise,
    required this.sunset,
    required this.sunAltitude,
    required this.sunPastNoon,
    required this.sunFraction,
    required this.sunPath,
    required this.moon,
    required this.moonUp,
    required this.moonFraction,
    required this.moonPath,
    required this.moonNextRise,
    required this.moonNextSet,
    required this.eastOnRight,
  });

  bool get sunUp => sunAltitude > -0.8333;

  String get phaseName => SkyEphemeris.phaseNameAr(moon.illumination, moon.waxing);

  int get illuminationPercent => (moon.illumination * 100).round();

  static const int _samples = 32;

  /// [sunrise] و[sunset] من جدول المواقيت نفسه المعروض تحت الكرت، فلا يختلف الرسم عنه.
  static SkySnapshot compute({
    required DateTime now,
    required double latitude,
    required double longitude,
    required DateTime sunrise,
    required DateTime sunset,
  }) {
    final sun = SkyEphemeris.sun(now, latitude, longitude);
    final dayLength = sunset.difference(sunrise).inSeconds;
    final sunFraction =
        dayLength > 0 ? (now.difference(sunrise).inSeconds / dayLength).clamp(0.0, 1.0) : 0.5;

    final sunPath = <Offset>[
      if (dayLength > 0)
        for (var i = 0; i <= _samples; i++)
          Offset(
            i / _samples,
            SkyEphemeris.sun(
              sunrise.add(Duration(seconds: (dayLength * i / _samples).round())),
              latitude,
              longitude,
            ).altitude,
          ),
    ];

    final moon = SkyEphemeris.moon(now, latitude, longitude);
    final times = SkyEphemeris.moonTimes(now, latitude, longitude);
    var moonFraction = 0.5;
    var moonPath = const <Offset>[];
    if (times.isUp) {
      final rise = times.previousRise, set = times.nextSet;
      if (rise != null && set != null && set.isAfter(rise)) {
        final span = set.difference(rise).inSeconds;
        moonFraction = (now.toUtc().difference(rise).inSeconds / span).clamp(0.0, 1.0);
        moonPath = [
          for (var i = 0; i <= _samples; i++)
            Offset(
              i / _samples,
              SkyEphemeris.moon(
                rise.add(Duration(seconds: (span * i / _samples).round())),
                latitude,
                longitude,
              ).altitude,
            ),
        ];
      } else {
        // عروض قطبية لا يغرب فيها القمر: موضعه من سمته، من الشرق إلى الغرب
        final fromEast = latitude >= 0 ? moon.azimuth - 90.0 : 90.0 - moon.azimuth;
        moonFraction = ((fromEast % 360.0) / 180.0).clamp(0.0, 1.0);
      }
    }

    return SkySnapshot(
      time: now,
      sunrise: sunrise,
      sunset: sunset,
      sunAltitude: sun.altitude,
      sunPastNoon: sun.hourAngle > 0,
      sunFraction: sunFraction,
      sunPath: sunPath,
      moon: moon,
      moonUp: times.isUp,
      moonFraction: moonFraction,
      moonPath: moonPath,
      moonNextRise: times.nextRise,
      moonNextSet: times.nextSet,
      eastOnRight: latitude < 0,
    );
  }
}

/// سماء اليوم الحقيقية أعلى كرت العدّ: الشمس من الشروق (طرف الكرت) إلى الغروب (طرفه
/// الآخر) بارتفاعها الفعلي، والقمر بين طلوعه وغروبه بطوره وميلان هلاله كما يُرى من المكان.
///
/// اللوحة منظر حقيقي لا مخطط زمني: الشرق في الجهة التي يراه فيها الراصد
/// ([SkySnapshot.eastOnRight])، فلا تنقلب مع اتجاه النص. الألوان من ارتفاع الشمس لا من
/// ثيم التطبيق. تُعاد الحسبة كل دقيقة.
class SkyDayStrip extends StatefulWidget {
  final double latitude;
  final double longitude;
  final DateTime sunrise;
  final DateTime sunset;

  /// لحظة ثابتة بدل الساعة (للاختبار والمعاينة).
  final DateTime? now;

  const SkyDayStrip({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.sunrise,
    required this.sunset,
    this.now,
  });

  @override
  State<SkyDayStrip> createState() => _SkyDayStripState();
}

class _SkyDayStripState extends State<SkyDayStrip> {
  static final DateFormat _timeFmt = DateFormat('hh:mm a');

  late SkySnapshot _snapshot;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _snapshot = _compute();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _snapshot = _compute());
      });
    }
  }

  @override
  void didUpdateWidget(covariant SkyDayStrip old) {
    super.didUpdateWidget(old);
    if (old.latitude != widget.latitude ||
        old.longitude != widget.longitude ||
        old.sunrise != widget.sunrise ||
        old.sunset != widget.sunset ||
        old.now != widget.now) {
      _snapshot = _compute();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SkySnapshot _compute() => SkySnapshot.compute(
        now: widget.now ?? DateTime.now(),
        latitude: widget.latitude,
        longitude: widget.longitude,
        sunrise: widget.sunrise,
        sunset: widget.sunset,
      );

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    final moonEvent = s.moonUp ? s.moonNextSet : s.moonNextRise;
    final moonEventLabel = moonEvent == null
        ? ''
        : '${s.moonUp ? 'يغرب' : 'يطلع'} ${_timeFmt.format(moonEvent.toLocal())}';

    const edgeStyle = TextStyle(
      color: Colors.white,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 520 ? 104.0 : 132.0;
        return Semantics(
          label: 'السماء الآن. القمر: ${s.phaseName}، إضاءته ${s.illuminationPercent} بالمئة',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: SkyPainter(s)),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      height: SkyPainter.groundHeight,
                      // كل وقت تحت طرف القوس الذي يخصّه: الشروق جهة الشرق
                      child: Row(
                        textDirection: s.eastOnRight ? TextDirection.rtl : TextDirection.ltr,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الشروق ${_timeFmt.format(s.sunrise)}', maxLines: 1, style: edgeStyle),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'الغروب ${_timeFmt.format(s.sunset)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: edgeStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(painter: MoonGlyphPainter(s.moon)),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'القمر: ${s.phaseName} · ${s.illuminationPercent}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (moonEventLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        moonEventLabel,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// يرسم قرص القمر بطوره وميلانه: المضيء نصف دائرة جهة الشمس وحدّ الإضاءة قطع ناقص
/// عرضه من نسبة الإضاءة، والكل مدوَّر بزاوية الطرف المضيء كما تُرى من مكان الراصد.
void paintMoonDisc(
  Canvas canvas,
  Offset center,
  double radius,
  MoonState moon, {
  required double night,
}) {
  final k = moon.illumination;
  canvas.save();
  canvas.translate(center.dx, center.dy);

  // الجزء المعتم: يُرى ليلاً بنور الأرض، ويذوب في زرقة السماء نهاراً
  canvas.drawCircle(
    Offset.zero,
    radius,
    Paint()..color = const Color(0xFF18203A).withValues(alpha: 0.03 + 0.87 * night),
  );

  // 0 أعلى القرص، وتزيد عكس عقارب الساعة كما يراها الراصد؛ ومحور الشاشة الرأسي إلى الأسفل
  final z = moon.brightLimbZenithAngle * math.pi / 180.0;
  final limbRotation = math.atan2(-math.cos(z), -math.sin(z));

  canvas.save();
  canvas.rotate(limbRotation);
  const steps = 40;
  final lit = Path();
  for (var i = 0; i <= steps; i++) {
    final t = -math.pi / 2 + math.pi * i / steps;
    final p = Offset(radius * math.cos(t), radius * math.sin(t));
    if (i == 0) {
      lit.moveTo(p.dx, p.dy);
    } else {
      lit.lineTo(p.dx, p.dy);
    }
  }
  final terminator = radius * (1 - 2 * k);
  for (var i = 0; i <= steps; i++) {
    final t = math.pi / 2 - math.pi * i / steps;
    lit.lineTo(terminator * math.cos(t), radius * math.sin(t));
  }
  lit.close();

  final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
  canvas.drawPath(
    lit,
    Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(0.35, 0),
        radius: 1.0,
        colors: [
          const Color(0xFFFFFEF6).withValues(alpha: 0.82 + 0.18 * night),
          const Color(0xFFE4DFCB).withValues(alpha: 0.78 + 0.22 * night),
        ],
      ).createShader(bounds),
  );
  canvas.restore();

  // بحار القمر: بقع باهتة تثبت على وجهه، تميل معه بالزاوية البارالاكتية
  canvas.save();
  canvas.rotate(limbRotation);
  canvas.clipPath(lit);
  canvas.rotate(-limbRotation + moon.parallacticAngle * math.pi / 180.0);
  final mare = Paint()
    ..color = const Color(0xFF7F7C6E).withValues(alpha: 0.20 + 0.06 * night)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07);
  for (final m in const [
    (-0.30, -0.42, 0.30),
    (0.22, -0.32, 0.20),
    (0.38, -0.05, 0.22),
    (0.68, -0.22, 0.11),
    (-0.58, -0.05, 0.28),
    (-0.25, 0.42, 0.22),
    (0.52, 0.22, 0.14),
  ]) {
    canvas.drawCircle(Offset(m.$1 * radius, m.$2 * radius), m.$3 * radius, mare);
  }
  canvas.restore();

  canvas.restore();
}

/// قمر صغير بطوره الحالي بجانب اسم الطور.
class MoonGlyphPainter extends CustomPainter {
  final MoonState moon;

  const MoonGlyphPainter(this.moon);

  @override
  void paint(Canvas canvas, Size size) {
    paintMoonDisc(canvas, size.center(Offset.zero), size.shortestSide / 2, moon, night: 1);
  }

  @override
  bool shouldRepaint(covariant MoonGlyphPainter old) => old.moon != moon;
}

class SkyPainter extends CustomPainter {
  final SkySnapshot s;

  const SkyPainter(this.s);

  /// شريط الأرض أسفل اللوحة، وعليه وقتا الشروق والغروب.
  static const double groundHeight = 24;

  /// (ارتفاع الشمس، لون أعلى السماء، لون الأفق)
  static const List<(double, Color, Color)> _skyKeys = [
    (-18, Color(0xFF050A1C), Color(0xFF0D1633)),
    (-12, Color(0xFF0A1230), Color(0xFF1C2A57)),
    (-6, Color(0xFF1A2456), Color(0xFF7C4A76)),
    (-2, Color(0xFF2B3A78), Color(0xFFE38A63)),
    (0, Color(0xFF3C5A9E), Color(0xFFF6AE6A)),
    (6, Color(0xFF3E86D8), Color(0xFFD5E2EC)),
    (15, Color(0xFF2F80E4), Color(0xFFA6D2F7)),
    (90, Color(0xFF1F6FDB), Color(0xFF8FC6F5)),
  ];

  /// لونا السماء (الأعلى ثم الأفق) عند ارتفاع الشمس المعطى.
  static (Color, Color) skyColors(double sunAltitude) {
    if (sunAltitude <= _skyKeys.first.$1) return (_skyKeys.first.$2, _skyKeys.first.$3);
    for (var i = 1; i < _skyKeys.length; i++) {
      final a = _skyKeys[i - 1], b = _skyKeys[i];
      if (sunAltitude <= b.$1) {
        final t = (sunAltitude - a.$1) / (b.$1 - a.$1);
        return (Color.lerp(a.$2, b.$2, t)!, Color.lerp(a.$3, b.$3, t)!);
      }
    }
    return (_skyKeys.last.$2, _skyKeys.last.$3);
  }

  /// نصف قطر القرصين من ارتفاع اللوحة.
  static double discRadius(Size size) => (size.height * 0.115).clamp(9.0, 15.0);

  /// موضع جرم على اللوحة: أفقياً بنسبة ما قطع من مساره، ورأسياً بجيب ارتفاعه
  /// (إسقاط القبة السماوية)، فشمس الشتاء أوطأ من شمس الصيف.
  static Offset bodyOffset(Size size, double fraction, double altitude, {required bool eastOnRight}) {
    final r = discRadius(size);
    final horizonY = size.height - groundHeight;
    final padX = r + 12;
    final x = padX + fraction.clamp(0.0, 1.0) * (size.width - 2 * padX);
    final skyHeight = horizonY - (r + 7);
    final y = horizonY - math.sin(altitude.clamp(-10.0, 90.0) * math.pi / 180.0) * skyHeight;
    return Offset(eastOnRight ? size.width - x : x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizonY = h - groundHeight;
    final r = discRadius(size);
    final full = Offset.zero & size;

    // 1) السماء
    final colors = skyColors(s.sunAltitude);
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.$1, colors.$2],
        ).createShader(Rect.fromLTWH(0, 0, w, horizonY)),
    );

    // من 0 نهاراً إلى 1 ليلاً
    final night = ((-s.sunAltitude - 3) / 9).clamp(0.0, 1.0);

    // 2) النجوم
    if (night > 0) {
      final rnd = math.Random(11);
      final star = Paint();
      for (var i = 0; i < 46; i++) {
        final x = rnd.nextDouble() * w;
        final y = rnd.nextDouble() * (horizonY - 8);
        final size = 0.45 + rnd.nextDouble() * 0.85;
        final fade = 1 - 0.65 * (y / horizonY);
        star.color = Colors.white.withValues(alpha: night * fade * (0.35 + rnd.nextDouble() * 0.65));
        canvas.drawCircle(Offset(x, y), size, star);
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, horizonY));

    // 3) وهج الأفق عند الشروق والغروب، جهة الشمس
    final glow = (1 - (s.sunAltitude + 2).abs() / 12).clamp(0.0, 1.0);
    if (glow > 0) {
      final side = s.sunUp ? s.sunFraction : (s.sunPastNoon ? 1.0 : 0.0);
      final c = Offset(bodyOffset(size, side, 0, eastOnRight: s.eastOnRight).dx, horizonY);
      final radius = w * 0.5;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFC27A).withValues(alpha: 0.80 * glow),
              const Color(0xFFFF8560).withValues(alpha: 0.32 * glow),
              const Color(0x00FF8560),
            ],
            stops: const [0, 0.42, 1],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    // 4) القوسان: مسار الشمس نهاراً ومسار القمر ليلاً
    if (s.sunUp) {
      _dots(canvas, size, s.sunPath, Colors.white.withValues(alpha: 0.42));
    } else if (s.moonUp) {
      _dots(canvas, size, s.moonPath, const Color(0xFFDDE6FF).withValues(alpha: 0.30));
    }

    // 5) القمر ثم الشمس
    if (s.moonUp) {
      final c = bodyOffset(size, s.moonFraction, s.moon.altitude, eastOnRight: s.eastOnRight);
      final moonRadius = r * 0.95;
      if (night > 0.05) {
        final halo = moonRadius * 2.9;
        canvas.drawCircle(
          c,
          halo,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.30 * night * s.moon.illumination),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: halo)),
        );
      }
      paintMoonDisc(canvas, c, moonRadius, s.moon, night: night);
    }
    if (s.sunUp) {
      _paintSun(canvas, bodyOffset(size, s.sunFraction, s.sunAltitude, eastOnRight: s.eastOnRight), r);
    }
    canvas.restore();

    // 6) الأرض: تلال هادئة وشريط داكن
    final ground = Color.fromRGBO(7, 12, 26, 0.34 + 0.46 * night);
    final hills = Path()
      ..moveTo(0, horizonY - 2)
      ..quadraticBezierTo(w * 0.12, horizonY - 6, w * 0.27, horizonY - 2.5)
      ..quadraticBezierTo(w * 0.40, horizonY, w * 0.52, horizonY - 3.5)
      ..quadraticBezierTo(w * 0.66, horizonY - 7, w * 0.80, horizonY - 2.5)
      ..quadraticBezierTo(w * 0.92, horizonY, w, horizonY - 3)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hills, Paint()..color = ground);
    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, groundHeight), Paint()..color = ground);
  }

  /// قوس منقّط بتباعد ثابت مهما كان عرض اللوحة (الارتفاع بين العيّنات بالاستيفاء).
  void _dots(Canvas canvas, Size size, List<Offset> path, Color color) {
    if (path.length < 2) return;
    final paint = Paint()..color = color;
    final count = (size.width / 9).round().clamp(16, 160);
    final last = path.length - 1;
    for (var i = 0; i <= count; i++) {
      final f = i / count;
      final at = f * last;
      final lo = at.floor().clamp(0, last - 1);
      final altitude = path[lo].dy + (path[lo + 1].dy - path[lo].dy) * (at - lo);
      if (altitude < 0) continue;
      canvas.drawCircle(bodyOffset(size, f, altitude, eastOnRight: s.eastOnRight), 1.1, paint);
    }
  }

  void _paintSun(Canvas canvas, Offset c, double r) {
    // قرب الأفق يحمرّ القرص، وفي كبد السماء يبيضّ
    final warm = ((14 - s.sunAltitude) / 14).clamp(0.0, 1.0);
    final core = Color.lerp(const Color(0xFFFFFDF0), const Color(0xFFFFE3A8), warm)!;
    final rim = Color.lerp(const Color(0xFFFFE27A), const Color(0xFFFF8A3D), warm)!;
    final halo = r * 3.6;
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            rim.withValues(alpha: 0.55),
            rim.withValues(alpha: 0.16),
            rim.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: halo)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [core, rim],
          stops: const [0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant SkyPainter old) => old.s != s;
}
