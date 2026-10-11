import 'sky_ephemeris.dart';

/// عيّنات السماء لشريط المواقيت في الإشعارات.
///
/// الشريط يرسمه أندرويد وحده والتطبيق مغلق (`PrayerNotificationManager.kt`)، ولا فلك
/// هناك: هنا تُحسب السماء كل [stepMinutes] دقيقة بالخوارزميات نفسها التي ترسم كرت
/// «الصلاة القادمة» ([SkyEphemeris])، وهناك يُستوفى بين العيّنتين خطياً. الاستيفاء لا
/// يبتعد عن الحساب المباشر أكثر من عُشرَي درجة للشمس ونصف درجة للقمر (حين يمرّ قرب سمت
/// الرأس)، وكلاهما دون البكسل في لوحة بهذا الحجم.
///
/// الأعداد صحيحة كي تبقى الحزمة صغيرة (نحو 25 ك.ب لخمسة عشر يوماً):
///  - `sun` و`moon`: الارتفاع بأعشار الدرجة (القمر كما يُرى من سطح الأرض).
///  - `lit`: نسبة إضاءة القمر بالألف.
///  - `limb`: زاوية الطرف المضيء من سمت الرأس بالدرجات (0..359).
///  - `par`: الزاوية البارالاكتية بالدرجات (ميلان بقع القمر).
class SkyTrack {
  SkyTrack._();

  static const int defaultStepMinutes = 20;

  /// من [from] إلى [to] (شاملتين). [from] يسبق اليوم بيوم كي يُعرف طلوع قمرٍ هو فوق
  /// الأفق عند أول الجدول.
  static Map<String, dynamic> build({
    required DateTime from,
    required DateTime to,
    required double latitude,
    required double longitude,
    int stepMinutes = defaultStepMinutes,
  }) {
    final step = Duration(minutes: stepMinutes);
    final start = from.toUtc();
    final count = to.toUtc().difference(start).inMinutes ~/ stepMinutes + 1;

    final sun = List<int>.filled(count, 0);
    final moon = List<int>.filled(count, 0);
    final lit = List<int>.filled(count, 0);
    final limb = List<int>.filled(count, 0);
    final par = List<int>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final t = start.add(step * i);
      final m = SkyEphemeris.moon(t, latitude, longitude);
      sun[i] = (SkyEphemeris.sun(t, latitude, longitude).altitude * 10).round();
      moon[i] = (m.altitude * 10).round();
      lit[i] = (m.illumination * 1000).round();
      limb[i] = m.brightLimbZenithAngle.round() % 360;
      par[i] = m.parallacticAngle.round();
    }

    return {
      'start': start.millisecondsSinceEpoch,
      'step': step.inMilliseconds,
      // السماء كما يراها الراصد: الشرق عن يمينه في نصف الكرة الجنوبي (انظر SkySnapshot)
      'east_right': latitude < 0,
      'sun': sun,
      'moon': moon,
      'lit': lit,
      'limb': limb,
      'par': par,
    };
  }
}
