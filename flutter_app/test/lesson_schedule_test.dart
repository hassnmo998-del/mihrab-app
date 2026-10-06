import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/community_event.dart';
import 'package:flutter_app/services/lesson_schedule.dart';

/// متى ينعقد الدرس، ومتى يختفي درس المرة الواحدة، ومتى يُفتح باب الأسئلة.
void main() {
  CommunityEvent lesson({
    required DateTime at,
    bool recurring = false,
    String? days,
    String timing = 'custom_time',
    String? prayer,
    String relation = 'after',
    int minutes = 60,
  }) =>
      CommunityEvent(
        id: 'e1',
        mosqueId: 'm1',
        title: 'درس',
        description: '',
        eventType: 'lesson',
        targetAudience: 'general',
        organizerType: 'sheikh',
        organizerName: 'الشيخ',
        eventDateTime: at,
        timingType: timing,
        prayerName: prayer,
        prayerRelation: relation,
        durationMinutes: minutes,
        isRecurring: recurring,
        recurringDays: days,
      );

  /// أذان الصلاة عند المسجد في ذلك اليوم، كما يحسبه التطبيق.
  DateTime adhan(String prayer, DateTime day) {
    final times = PrayerTimes(
      Coordinates(33.5138, 36.2765),
      DateComponents(day.year, day.month, day.day),
      CalculationMethod.muslim_world_league.getParameters()..madhab = Madhab.shafi,
    );
    return switch (prayer) {
      'fajr' => times.fajr,
      'asr' => times.asr,
      'maghrib' => times.maghrib,
      'isha' => times.isha,
      _ => times.dhuhr,
    }
        .toLocal();
  }

  // الثلاثاء 6 أكتوبر 2026
  final tuesday = DateTime(2026, 10, 6);
  DateTime at(int hour, [int minute = 0, int dayOffset = 0]) =>
      DateTime(tuesday.year, tuesday.month, tuesday.day + dayOffset, hour, minute);

  group('درس لمرة واحدة بوقت محدد', () {
    final e = lesson(at: at(18));

    test('يظهر قبل موعده وأثناءه وفي مهلة ما بعد نهايته', () {
      expect(LessonSchedule.hasEnded(e, at(9)), isFalse);
      expect(LessonSchedule.hasEnded(e, at(18, 30)), isFalse);
      // انتهى 19:00، والمهلة نصف ساعة
      expect(LessonSchedule.hasEnded(e, at(19, 29)), isFalse);
      expect(LessonSchedule.currentOrNextStart(e, at(19, 29)), at(18));
    });

    test('يختفي بعد نهايته والمهلة، ولا يعود في الأيام التالية', () {
      expect(LessonSchedule.hasEnded(e, at(19, 31)), isTrue);
      expect(LessonSchedule.hasEnded(e, at(10, 0, 1)), isTrue);
      expect(LessonSchedule.hasEnded(e, at(18, 0, 7)), isTrue);
      expect(LessonSchedule.currentOrNextStart(e, at(19, 31)), isNull);
    });

    test('الأسئلة تُغلق قبل الدرس بنصف ساعة ولا تُفتح بعده', () {
      expect(LessonSchedule.questionsOpen(e, at(17, 29)), isTrue);
      expect(LessonSchedule.questionsOpen(e, at(17, 31)), isFalse);
      expect(LessonSchedule.questionsOpen(e, at(18, 30)), isFalse);
      expect(LessonSchedule.questionsOpen(e, at(9, 0, 1)), isFalse);
    });

    test('كل أسئلته تخصه: لا جلسة سابقة تُستثنى أسئلتها', () {
      expect(LessonSchedule.questionsSince(e, at(17)).year, 2000);
    });
  });

  group('درس متكرر بوقت محدد', () {
    // كل ثلاثاء وخميس الساعة 18:00، أُعلن قبل أسبوعين
    final e = lesson(at: at(18, 0, -14), recurring: true, days: 'الثلاثاء, الخميس');

    test('لا ينتهي أبداً: بعد كل جلسة تأتي التي بعدها', () {
      for (var day = 0; day < 30; day++) {
        expect(LessonSchedule.hasEnded(e, at(23, 0, day)), isFalse);
      }
    });

    test('الجلسة الجارية تبقى هي المعنيّة حتى نهايتها والمهلة، ثم التالية', () {
      expect(LessonSchedule.currentOrNextStart(e, at(9)), at(18));
      expect(LessonSchedule.currentOrNextStart(e, at(19, 20)), at(18));
      // بعد 19:30 يوم الثلاثاء: جلسة الخميس
      expect(LessonSchedule.currentOrNextStart(e, at(19, 40)), at(18, 0, 2));
      // الأربعاء ليس من أيامه
      expect(LessonSchedule.currentOrNextStart(e, at(12, 0, 1)), at(18, 0, 2));
      // بعد جلسة الخميس: الثلاثاء القادم
      expect(LessonSchedule.currentOrNextStart(e, at(20, 0, 2)), at(18, 0, 7));
    });

    test('باب الأسئلة يُغلق قبل الجلسة ويُفتح من جديد للجلسة التالية', () {
      expect(LessonSchedule.questionsOpen(e, at(17)), isTrue);
      expect(LessonSchedule.questionsOpen(e, at(17, 45)), isFalse);
      expect(LessonSchedule.questionsOpen(e, at(18, 30)), isFalse);
      // انتهت جلسة الثلاثاء: الباب مفتوح لجلسة الخميس
      expect(LessonSchedule.questionsOpen(e, at(19, 40)), isTrue);
      expect(LessonSchedule.questionsOpen(e, at(17, 45, 2)), isFalse);
    });

    test('أسئلة الجلسة القادمة هي ما طُرح بعد نهاية السابقة', () {
      // قبل جلسة الثلاثاء: السابقة كانت الخميس الماضي، انتهت 19:00 + المهلة
      expect(LessonSchedule.questionsSince(e, at(12)), at(19, 30, -5));
      // بعد جلسة الثلاثاء: أسئلتها صارت قديمة
      expect(LessonSchedule.questionsSince(e, at(19, 40)), at(19, 30));
    });

    test('الشيخ يفتح شاشة الدرس متأخراً: أسئلة جلسته التي انتهت للتو تبقى له', () {
      // 19:40: الجلسة انتهت قبل عشر دقائق والتالية بعد يومين
      expect(LessonSchedule.questionsSince(e, at(19, 40), forSpeaker: true), at(19, 30, -5));
      // قبيل جلسة الخميس بساعة: أسئلة جلسة الخميس
      expect(LessonSchedule.questionsSince(e, at(17, 0, 2), forSpeaker: true), at(19, 30));
      // اليوم التالي ظهراً، بعد أكثر من 12 ساعة: الجلسة القادمة
      expect(LessonSchedule.questionsSince(e, at(12, 0, 1), forSpeaker: true), at(19, 30));
    });
  });

  test('درس متكرر بلا أيام محددة ينعقد كل يوم', () {
    final e = lesson(at: at(20, 0, -3), recurring: true);
    expect(LessonSchedule.currentOrNextStart(e, at(9)), at(20));
    expect(LessonSchedule.currentOrNextStart(e, at(22)), at(20, 0, 1));
  });

  test('درس متكرر يبدأ من تاريخه الأول لا قبله', () {
    // كل ثلاثاء، وأول جلسة بعد ثلاثة أسابيع
    final e = lesson(at: at(18, 0, 21), recurring: true, days: 'الثلاثاء');
    expect(LessonSchedule.currentOrNextStart(e, at(9)), at(18, 0, 21));
    expect(LessonSchedule.questionsOpen(e, at(9)), isTrue);
  });

  group('درس مربوط بصلاة', () {
    test('لمرة واحدة: موعده أول صلاة بعد إعلانه، ثم يختفي', () {
      // أُعلن الثلاثاء 10:00 «بعد المغرب» (الحقل يحفظ وقت الإعلان + ساعتين)
      final e = lesson(at: at(12), timing: 'prayer_linked', prayer: 'maghrib');
      final start = adhan('maghrib', tuesday).add(LessonSchedule.afterPrayerDelay);

      expect(LessonSchedule.singleStart(e), start);
      expect(LessonSchedule.hasEnded(e, at(12)), isFalse);
      expect(LessonSchedule.hasEnded(e, start.add(const Duration(minutes: 80))), isFalse);
      expect(LessonSchedule.hasEnded(e, start.add(const Duration(minutes: 95))), isTrue);
      expect(LessonSchedule.hasEnded(e, at(12, 0, 1)), isTrue);
    });

    test('أُعلن بعد انقضاء صلاة اليوم: موعده صلاة الغد', () {
      // أُعلن 23:00 «بعد العشاء»
      final e = lesson(at: at(1, 0, 1), timing: 'prayer_linked', prayer: 'isha');
      final tomorrow = DateTime(tuesday.year, tuesday.month, tuesday.day + 1);

      expect(LessonSchedule.singleStart(e), adhan('isha', tomorrow).add(LessonSchedule.afterPrayerDelay));
      expect(LessonSchedule.hasEnded(e, at(23, 30)), isFalse);
      expect(LessonSchedule.hasEnded(e, at(12, 0, 1)), isFalse);
      expect(LessonSchedule.hasEnded(e, at(2, 0, 2)), isTrue);
    });

    test('«قبل الأذان» ينتهي عند الأذان، و«بين الأذان والإقامة» يبدأ معه', () {
      final before = lesson(at: at(12), timing: 'prayer_linked', prayer: 'asr', relation: 'before', minutes: 30);
      final between = lesson(at: at(12), timing: 'prayer_linked', prayer: 'asr', relation: 'between_adhan_iqama');
      final asr = adhan('asr', tuesday);

      expect(LessonSchedule.endOf(before, LessonSchedule.singleStart(before)), asr);
      expect(LessonSchedule.singleStart(between), asr);
    });

    test('درس الجمعة ينعقد يوم الجمعة وحده', () {
      // أُعلن الثلاثاء: أول جمعة بعد ثلاثة أيام
      final once = lesson(at: at(12), timing: 'prayer_linked', prayer: 'jumua');
      final friday = DateTime(tuesday.year, tuesday.month, tuesday.day + 3);
      expect(friday.weekday, DateTime.friday);
      expect(LessonSchedule.singleStart(once), adhan('dhuhr', friday).add(LessonSchedule.afterPrayerDelay));
      expect(LessonSchedule.hasEnded(once, at(12, 0, 2)), isFalse);
      expect(LessonSchedule.hasEnded(once, at(20, 0, 3)), isTrue);

      final weekly = lesson(at: at(12), recurring: true, timing: 'prayer_linked', prayer: 'jumua');
      expect(LessonSchedule.currentOrNextStart(weekly, at(9))!.weekday, DateTime.friday);
      expect(LessonSchedule.currentOrNextStart(weekly, at(20, 0, 3))!.weekday, DateTime.friday);
    });

    test('متكرر بأيام: يتبع صلاة كل يوم من أيامه، وبابه يُفتح بعد كل جلسة', () {
      final e = lesson(
        at: at(12, 0, -30),
        recurring: true,
        days: 'الثلاثاء, الخميس',
        timing: 'prayer_linked',
        prayer: 'fajr',
      );
      final thursday = DateTime(tuesday.year, tuesday.month, tuesday.day + 2);

      // ظهر الثلاثاء: فجر اليوم انقضى، القادم فجر الخميس
      expect(LessonSchedule.currentOrNextStart(e, at(12)),
          adhan('fajr', thursday).add(LessonSchedule.afterPrayerDelay));
      // الحقل المحفوظ قديم بشهر، ومع ذلك الباب مفتوح للجلسة القادمة
      expect(LessonSchedule.questionsOpen(e, at(12)), isTrue);
      expect(LessonSchedule.hasEnded(e, at(12)), isFalse);
    });
  });
}
