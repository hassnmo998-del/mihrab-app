import 'package:adhan/adhan.dart';

import '../core/utils/arabic_time.dart';
import '../models/community_event.dart';

/// متى ينعقد الدرس فعلاً، محسوباً من إعداداته (وقت محدد أو صلاة، أيام التكرار)
/// لا من حقل `eventDateTime` وحده.
///
/// ذلك الحقل لا يكفي: الدرس المربوط بصلاة يُحفظ فيه «وقت الإعلان + ساعتان»،
/// والدرس المتكرر لا يتقدّم تاريخه إلا إذا سُجّل وأُرشف. فكان باب الأسئلة يُغلق
/// نهائياً بعد أول موعد، ودرس المرة الواحدة يبقى في القائمة بعد انقضائه.
class LessonSchedule {
  LessonSchedule._();

  /// الساعة التي تقرأ بها شاشات الدروس «الآن». الاختبار يثبّتها على لحظة بعينها.
  static DateTime Function() clock = DateTime.now;

  /// الدروس تتأخر وتطول: لا يُعدّ الدرس منتهياً إلا بعد هذه المهلة من نهايته.
  static const Duration endGrace = Duration(minutes: 30);

  /// يُغلق استقبال الأسئلة قبل بداية الدرس بهذه المدة ليتسنى للشيخ قراءتها.
  static const Duration questionsCloseBefore = Duration(minutes: 30);

  /// درس «بعد الصلاة» يبدأ بعد الأذان بهذه المدة (الإقامة ثم الصلاة).
  static const Duration afterPrayerDelay = Duration(minutes: 20);

  /// علامة «مباشر» تُصدَّق من قبل موعد الجلسة بهذه المدة...
  static const Duration liveEarly = Duration(hours: 3);

  /// ...وحتى هذه المدة بعد نهايتها ومهلتها. خارج ذلك هي علامة عالقة: هاتف أُطفئ أثناء
  /// التسجيل فلم يُرجعها، فكان درس المرة الواحدة لا يختفي أبداً و«مباشر الآن» ظاهرة دائماً.
  static const Duration liveLate = Duration(hours: 4);

  static const Map<String, int> _weekdays = {
    'الاثنين': DateTime.monday,
    'الثلاثاء': DateTime.tuesday,
    'الأربعاء': DateTime.wednesday,
    'الخميس': DateTime.thursday,
    'الجمعة': DateTime.friday,
    'السبت': DateTime.saturday,
    'الأحد': DateTime.sunday,
  };

  static bool _isPrayerLinked(CommunityEvent e) =>
      e.timingType == 'prayer_linked' && (e.prayerName?.isNotEmpty ?? false);

  /// أيام الأسبوع التي ينعقد فيها الدرس؛ فارغة تعني كل يوم.
  static Set<int> weekdaysOf(CommunityEvent e) {
    if (_isPrayerLinked(e) && e.prayerName == 'jumua') return {DateTime.friday};
    if (!e.isRecurring) return const {};
    final raw = e.recurringDays ?? '';
    return {
      for (final entry in _weekdays.entries)
        if (raw.contains(entry.key)) entry.value,
    };
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime endOf(CommunityEvent e, DateTime start) =>
      start.add(Duration(minutes: e.durationMinutes));

  /// بداية جلسة الدرس لو انعقد في يوم [day].
  static DateTime startOn(CommunityEvent e, DateTime day) {
    if (!_isPrayerLinked(e)) {
      return DateTime(day.year, day.month, day.day, e.eventDateTime.hour, e.eventDateTime.minute);
    }
    final adhan = _prayerTime(e, day);
    switch (e.prayerRelation) {
      case 'before':
        return adhan.subtract(Duration(minutes: e.durationMinutes));
      case 'between_adhan_iqama':
        return adhan;
      default:
        return adhan.add(afterPrayerDelay);
    }
  }

  /// موعد الجلسة الوحيدة لدرس غير متكرر.
  static DateTime singleStart(CommunityEvent e) {
    if (!_isPrayerLinked(e)) return e.eventDateTime;
    // الدرس المربوط بصلاة لا تاريخ له: هو أول موعد لتلك الصلاة بعد إعلانه
    final announced = e.eventDateTime.subtract(const Duration(hours: 2));
    final first = _dayOf(announced);
    final days = weekdaysOf(e);
    for (var i = 0; i < 9; i++) {
      final day = DateTime(first.year, first.month, first.day + i);
      if (days.isNotEmpty && !days.contains(day.weekday)) continue;
      final start = startOn(e, day);
      if (endOf(e, start).isAfter(announced)) return start;
    }
    return e.eventDateTime;
  }

  /// جلسات الدرس المتكرر التي تبدأ بين اليومين، من الأقدم إلى الأحدث.
  static List<DateTime> _recurringStarts(CommunityEvent e, DateTime fromDay, DateTime toDay) {
    final days = weekdaysOf(e);
    // درس متكرر بوقت محدد يبدأ من تاريخه الأول، لا قبله
    final firstDay = _isPrayerLinked(e) ? null : _dayOf(e.eventDateTime);
    final starts = <DateTime>[];
    for (var day = _dayOf(fromDay); !day.isAfter(toDay); day = DateTime(day.year, day.month, day.day + 1)) {
      if (days.isNotEmpty && !days.contains(day.weekday)) continue;
      if (firstDay != null && day.isBefore(firstDay)) continue;
      starts.add(startOn(e, day));
    }
    return starts;
  }

  /// الجلسة الجارية الآن (حتى نهايتها والمهلة) وإلا القادمة.
  /// null لدرس المرة الواحدة الذي انقضى موعده.
  static DateTime? currentOrNextStart(CommunityEvent e, DateTime now) {
    bool stillOn(DateTime start) => endOf(e, start).add(endGrace).isAfter(now);

    if (!e.isRecurring) {
      final start = singleStart(e);
      return stillOn(start) ? start : null;
    }
    final today = _dayOf(now);
    final from = DateTime(today.year, today.month, today.day - 1);
    // حتى تاريخ الدرس الأول إن كان بعيداً، وإلا أسبوع يكفي ليمرّ كل يوم مرة
    final horizon = DateTime(today.year, today.month, today.day + 8);
    final firstDay = _dayOf(e.eventDateTime);
    final to = !_isPrayerLinked(e) && firstDay.isAfter(today)
        ? DateTime(firstDay.year, firstDay.month, firstDay.day + 8)
        : horizon;
    for (final start in _recurringStarts(e, from, to)) {
      if (stillOn(start)) return start;
    }
    return null;
  }

  /// درس لمرة واحدة انقضى موعده (بعد نهايته و[endGrace]).
  static bool hasEnded(CommunityEvent e, DateTime now) =>
      !e.isRecurring && currentOrNextStart(e, now) == null;

  /// درس المرة الواحدة يبقى في القائمة بعد انتهائه حتى آخر يومه، معلَّماً «مضى موعده»:
  /// قد يُضاف درس بلا تسجيل، فيعرف من فاته أنه كان. وإن امتدّ بعد منتصف الليل يبقى حتى
  /// نهايته ومهلتها.
  static DateTime listedUntil(CommunityEvent e) {
    final start = singleStart(e);
    final midnight = DateTime(start.year, start.month, start.day + 1);
    final over = endOf(e, start).add(endGrace);
    return over.isAfter(midnight) ? over : midnight;
  }

  /// انتهى موعده لكنه ما زال ظاهراً لبقية يومه.
  static bool isPastToday(CommunityEvent e, DateTime now) =>
      hasEnded(e, now) && now.isBefore(listedUntil(e));

  /// يُبث الآن فعلاً: علامة «مباشر» ضمن نافذة جلسة من جلساته (انظر [liveEarly] و[liveLate]).
  static bool isLive(CommunityEvent e, DateTime now) {
    if (e.eventStatus != 'live') return false;
    final today = _dayOf(now);
    final starts = e.isRecurring
        ? _recurringStarts(
            e,
            DateTime(today.year, today.month, today.day - 2),
            DateTime(today.year, today.month, today.day + 1),
          )
        : [singleStart(e)];
    return starts.any((start) =>
        !now.isBefore(start.subtract(liveEarly)) &&
        now.isBefore(endOf(e, start).add(endGrace).add(liveLate)));
  }

  /// يظهر في قائمة الدروس: يُبث الآن، أو له جلسة لم تنتهِ، أو انتهى اليوم ([isPastToday]).
  static bool isListed(CommunityEvent e, DateTime now) =>
      isLive(e, now) || !hasEnded(e, now) || now.isBefore(listedUntil(e));

  /// ترتيب القائمة: المباشر، ثم القادم الأقرب فالأبعد، ثم ما مضى موعده.
  static int compareBySchedule(CommunityEvent a, CommunityEvent b, DateTime now) {
    int group(CommunityEvent e) => isLive(e, now) ? 0 : (hasEnded(e, now) ? 2 : 1);
    DateTime? when(CommunityEvent e) => currentOrNextStart(e, now) ?? (e.isRecurring ? null : singleStart(e));

    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final startA = when(a), startB = when(b);
    if (startA == null || startB == null) {
      if (startA == null && startB == null) return a.title.compareTo(b.title);
      return startA == null ? 1 : -1;
    }
    final byStart = startA.compareTo(startB);
    return byStart != 0 ? byStart : a.title.compareTo(b.title);
  }

  /// موعد بدايته تقريبي: «بعد الصلاة» يتبع إقامة المسجد، والحساب يفترض [afterPrayerDelay].
  static bool _startIsApproximate(CommunityEvent e) =>
      _isPrayerLinked(e) && e.prayerRelation != 'before' && e.prayerRelation != 'between_adhan_iqama';

  /// الجلسة الجارية أو القادمة بكلام الناس: «جارٍ الآن • بدأ 6:00 م»، «اليوم • 6:00 م»،
  /// «غداً • نحو 4:05 م»، «السبت 17/10 • 6:00 م». ودرس المرة الواحدة المنتهي:
  /// «مضى موعده • اليوم 6:00 م».
  static String? sessionLabel(CommunityEvent e, DateTime now) {
    final start = currentOrNextStart(e, now);
    if (start == null) {
      if (e.isRecurring) return null;
      final past = singleStart(e);
      return 'مضى موعده • ${ArabicTime.relativeDay(past, now)} ${ArabicTime.clock(past)}';
    }
    if (!now.isBefore(start)) return 'جارٍ الآن • بدأ ${ArabicTime.clock(start)}';
    final time = _startIsApproximate(e) ? 'نحو ${ArabicTime.clock(start)}' : ArabicTime.clock(start);
    return '${ArabicTime.relativeDay(start, now)} • $time';
  }

  /// هل باب الأسئلة مفتوح الآن للجلسة القادمة؟
  static bool questionsOpen(CommunityEvent e, DateTime now) {
    final start = currentOrNextStart(e, now);
    return start != null && now.isBefore(start.subtract(questionsCloseBefore));
  }

  /// أسئلة الجلسة المعنيّة هي ما طُرح بعد هذه اللحظة؛ ما قبلها يخص جلسة سابقة
  /// من الدرس المتكرر فلا يُعدّ ولا يُعرض.
  ///
  /// [forSpeaker]: الشيخ قد يفتح شاشة الدرس متأخراً بعد موعده، فتبقى له أسئلة
  /// الجلسة التي انتهت للتوّ ما لم تقترب الجلسة التالية.
  static DateTime questionsSince(CommunityEvent e, DateTime now, {bool forSpeaker = false}) {
    final beginning = DateTime(2000);
    if (!e.isRecurring) return beginning;

    final today = _dayOf(now);
    final starts = _recurringStarts(
      e,
      DateTime(today.year, today.month, today.day - 9),
      DateTime(today.year, today.month, today.day + 8),
    );
    if (starts.isEmpty) return beginning;

    DateTime ended(DateTime start) => endOf(e, start).add(endGrace);
    var index = starts.indexWhere((s) => ended(s).isAfter(now));
    if (index < 0) index = starts.length - 1;

    if (forSpeaker && index > 0) {
      final next = starts[index];
      final previous = starts[index - 1];
      final nextIsSoon = next.difference(now) <= const Duration(hours: 3);
      final previousJustEnded = now.difference(ended(previous)) < const Duration(hours: 12);
      if (!nextIsSoon && previousJustEnded) index -= 1;
    }
    return index == 0 ? beginning : ended(starts[index - 1]);
  }

  // ── مواقيت الصلاة عند المسجد ──

  static final Map<String, PrayerTimes> _prayerCache = {};

  static DateTime _prayerTime(CommunityEvent e, DateTime day) {
    DateTime fallback(int hour, int minute) => DateTime(day.year, day.month, day.day, hour, minute);
    try {
      final key = '${e.latitude.toStringAsFixed(3)},${e.longitude.toStringAsFixed(3)}'
          ',${day.year}-${day.month}-${day.day}';
      if (_prayerCache.length > 500) _prayerCache.clear();
      final times = _prayerCache[key] ??= PrayerTimes(
        Coordinates(e.latitude, e.longitude),
        DateComponents(day.year, day.month, day.day),
        CalculationMethod.muslim_world_league.getParameters()..madhab = Madhab.shafi,
      );
      switch (e.prayerName) {
        case 'fajr':
          return times.fajr.toLocal();
        case 'asr':
          return times.asr.toLocal();
        case 'maghrib':
          return times.maghrib.toLocal();
        case 'isha':
          return times.isha.toLocal();
        default: // dhuhr, jumua
          return times.dhuhr.toLocal();
      }
    } catch (_) {
      switch (e.prayerName) {
        case 'fajr':
          return fallback(5, 0);
        case 'asr':
          return fallback(15, 45);
        case 'maghrib':
          return fallback(18, 30);
        case 'isha':
          return fallback(20, 0);
        default:
          return fallback(12, 30);
      }
    }
  }
}
