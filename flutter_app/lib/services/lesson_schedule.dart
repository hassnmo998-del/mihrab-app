import 'package:adhan/adhan.dart';

import '../models/community_event.dart';

/// متى ينعقد الدرس فعلاً، محسوباً من إعداداته (وقت محدد أو صلاة، أيام التكرار)
/// لا من حقل `eventDateTime` وحده.
///
/// ذلك الحقل لا يكفي: الدرس المربوط بصلاة يُحفظ فيه «وقت الإعلان + ساعتان»،
/// والدرس المتكرر لا يتقدّم تاريخه إلا إذا سُجّل وأُرشف. فكان باب الأسئلة يُغلق
/// نهائياً بعد أول موعد، ودرس المرة الواحدة يبقى في القائمة بعد انقضائه.
class LessonSchedule {
  LessonSchedule._();

  /// الدروس تتأخر وتطول: لا يُعدّ الدرس منتهياً إلا بعد هذه المهلة من نهايته.
  static const Duration endGrace = Duration(minutes: 30);

  /// يُغلق استقبال الأسئلة قبل بداية الدرس بهذه المدة ليتسنى للشيخ قراءتها.
  static const Duration questionsCloseBefore = Duration(minutes: 30);

  /// درس «بعد الصلاة» يبدأ بعد الأذان بهذه المدة (الإقامة ثم الصلاة).
  static const Duration afterPrayerDelay = Duration(minutes: 20);

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

  /// درس لمرة واحدة انقضى موعده: يختفي من قائمة الدروس القادمة.
  static bool hasEnded(CommunityEvent e, DateTime now) =>
      !e.isRecurring && currentOrNextStart(e, now) == null;

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
