import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/arabic_time.dart';
import 'package:flutter_app/core/utils/wall_clock.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/lesson_schedule.dart';

/// مواعيد الفعاليات بعد المزامنة، اختفاء درس المرة الواحدة، علامة «مباشر» العالقة،
/// ترتيب القائمة، ونصوص المواعيد المعروضة.
void main() {
  CommunityEvent lesson({
    String id = 'e1',
    String title = 'درس',
    required DateTime at,
    bool recurring = false,
    String? days,
    String timing = 'custom_time',
    String? prayer,
    String relation = 'after',
    String status = 'upcoming',
  }) =>
      CommunityEvent(
        id: id,
        mosqueId: 'm1',
        title: title,
        description: '',
        eventType: 'lesson',
        targetAudience: 'general',
        organizerType: 'sheikh',
        organizerName: 'الشيخ',
        eventDateTime: at,
        timingType: timing,
        prayerName: prayer,
        prayerRelation: relation,
        isRecurring: recurring,
        recurringDays: days,
        eventStatus: status,
      );

  /// ما يحدث للسجل في السحابة: يُرسل الوقت المحلي بلا منطقة، يحفظه الخادم (على UTC)
  /// كما كُتب، ويعيده بلاحقة `+00:00` (كما يعيدها PostgREST والبث اللحظي).
  CommunityEvent viaCloud(CommunityEvent e) {
    final json = e.toJson();
    final sent = json['event_datetime'] as String;
    expect(sent.endsWith('Z') || sent.contains('+'), isFalse, reason: 'يُرسل بلا منطقة زمنية');
    final stored = DateTime.parse('${sent.split('.').first}+00:00');
    json['event_datetime'] = stored.toIso8601String().replaceFirst('Z', '+00:00');
    return CommunityEvent.fromJson(json);
  }

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

  // الأربعاء 7 تشرين الأول 2026
  DateTime at(int hour, [int minute = 0, int dayOffset = 0]) => DateTime(2026, 10, 7 + dayOffset, hour, minute);

  group('الموعد بعد المزامنة مع السحابة', () {
    test('القراءة: الساعة المكتوبة نفسها بالتوقيت المحلي، بأي صيغة وصلت', () {
      for (final raw in [
        '2026-10-07T18:00:00+00:00', // من الخادم
        '2026-10-07T18:00:00.000Z', // نسخة محفوظة على الجهاز بعد مزامنة سابقة
        '2026-10-07T18:00:00.000', // كما كتبها التطبيق
        '2026-10-07 18:00:00+00', // صيغة Postgres الخام
      ]) {
        final t = parseWallClock(raw);
        expect(t.isUtc, isFalse, reason: raw);
        expect(t, DateTime(2026, 10, 7, 18), reason: raw);
      }
      expect(tryParseWallClock(null), isNull);
      expect(tryParseWallClock(''), isNull);
      expect(tryParseWallClock('ليس تاريخاً'), isNull);
      expect(parseWallClock(null, fallback: DateTime(2020)), DateTime(2020));
    });

    test('الكتابة: الساعة المحلية بلا منطقة، كما كتبتها كل نسخ التطبيق', () {
      expect(wallClockJson(DateTime(2026, 10, 7, 18)), '2026-10-07T18:00:00.000');
      expect(wallClockJson(DateTime.utc(2026, 10, 7, 18)), '2026-10-07T18:00:00.000');
    });

    test('درس المرة الواحدة بوقت محدد: يختفي في اللحظة نفسها على الجهاز الذي أعلنه وعلى كل جهاز وصله من السحابة', () {
      final local = lesson(at: at(18));
      final synced = viaCloud(local);

      expect(synced.eventDateTime, local.eventDateTime);
      expect(synced.timingDescription, local.timingDescription);
      // كل خمس دقائق من الظهر حتى منتصف الليل
      for (var t = at(12); t.isBefore(at(0, 0, 1)); t = t.add(const Duration(minutes: 5))) {
        expect(LessonSchedule.hasEnded(synced, t), LessonSchedule.hasEnded(local, t), reason: '$t');
        expect(LessonSchedule.questionsOpen(synced, t), LessonSchedule.questionsOpen(local, t), reason: '$t');
        expect(LessonSchedule.sessionLabel(synced, t), LessonSchedule.sessionLabel(local, t), reason: '$t');
      }
      // ساعة الدرس ونصف الساعة مهلة: ينتهي في 7:30 م لا في 10:30 م
      expect(LessonSchedule.hasEnded(synced, at(19, 29)), isFalse);
      expect(LessonSchedule.hasEnded(synced, at(19, 31)), isTrue);
      expect(LessonSchedule.listedUntil(synced), LessonSchedule.listedUntil(local));
    });

    test('درس مربوط بصلاة لمرة واحدة: موعده بعد المزامنة هو نفسه (لا ينتقل إلى الغد)', () {
      // أُعلن الساعة 2:30 م لدرس بعد العصر: موعد الإعلان المحفوظ = 4:30 م
      final local = lesson(at: at(16, 30), timing: 'prayer_linked', prayer: 'asr');
      final synced = viaCloud(local);

      expect(LessonSchedule.singleStart(synced), LessonSchedule.singleStart(local));
      final start = LessonSchedule.singleStart(local);
      expect(start.day, 7);
      expect(start, adhan('asr', at(0)).add(LessonSchedule.afterPrayerDelay));
    });

    test('درس متكرر بوقت محدد: جلساته هي نفسها بعد المزامنة', () {
      final local = lesson(at: at(18, 0, -14), recurring: true, days: 'السبت, الاثنين, الأربعاء');
      final synced = viaCloud(local);
      for (var t = at(0); t.isBefore(at(0, 0, 8)); t = t.add(const Duration(hours: 3))) {
        expect(LessonSchedule.currentOrNextStart(synced, t), LessonSchedule.currentOrNextStart(local, t), reason: '$t');
      }
    });

    test('سؤال وحركة نقاط وتاريخ رحلة من السحابة: الساعة المكتوبة نفسها', () {
      final q = EventQuestion.fromJson({
        'id': 'q1',
        'event_id': 'e1',
        'content': 'سؤال',
        'created_at': '2026-10-07T17:10:00+00:00',
      });
      expect(q.createdAt, DateTime(2026, 10, 7, 17, 10));

      final log = PointsLog.fromJson({
        'id': 'p1',
        'student_id': 's1',
        'points': 5,
        'reason': 'حضور',
        'category': 'attendance',
        'created_at': '2026-09-30T23:30:00+00:00',
      });
      // حركة 11:30 م آخر أيلول تبقى في أيلول (كانت تُحسب في تشرين الأول)
      expect(log.createdAt, DateTime(2026, 9, 30, 23, 30));
      expect(log.createdAt.month, 9);

      final redemption = RewardRedemption.fromJson({
        'id': 'r1',
        'student_id': 's1',
        'mosque_id': 'm1',
        'reward_id': 'w1',
        'redeemed_at': '2026-10-07T09:00:00+00:00',
        'dispensed_at': null,
      });
      expect(redemption.redeemedAt, DateTime(2026, 10, 7, 9));
      expect(redemption.dispensedAt, isNull);
    });
  });

  group('درس المرة الواحدة يبقى حتى نهاية يومه معلَّماً «مضى موعده»، والمتكرر لا يختفي', () {
    test('بوقت محدد: قادم، ثم جارٍ، ثم «مضى موعده» بقية اليوم، ثم يختفي منتصف الليل', () {
      final e = lesson(at: at(18));
      expect(LessonSchedule.isListed(e, at(9)), isTrue);
      expect(LessonSchedule.isPastToday(e, at(9)), isFalse);
      expect(LessonSchedule.isListed(e, at(18, 30)), isTrue);
      expect(LessonSchedule.sessionLabel(e, at(18, 30)), 'جارٍ الآن • بدأ 6:00 م');
      expect(LessonSchedule.isListed(e, at(19, 25)), isTrue);
      expect(LessonSchedule.isPastToday(e, at(19, 25)), isFalse);

      // انتهى ونصف ساعة: ظاهر بقية اليوم ومعلَّم
      for (final t in [at(19, 35), at(21), at(23, 59)]) {
        expect(LessonSchedule.isListed(e, t), isTrue, reason: '$t');
        expect(LessonSchedule.isPastToday(e, t), isTrue, reason: '$t');
        expect(LessonSchedule.sessionLabel(e, t), 'مضى موعده • اليوم 6:00 م', reason: '$t');
      }
      expect(LessonSchedule.questionsOpen(e, at(21)), isFalse);

      expect(LessonSchedule.listedUntil(e), at(0, 0, 1));
      expect(LessonSchedule.isListed(e, at(0, 0, 1)), isFalse);
      expect(LessonSchedule.isListed(e, at(9, 0, 1)), isFalse);
    });

    test('درس يمتد بعد منتصف الليل: يبقى حتى نهايته ومهلتها', () {
      final late = lesson(at: at(23, 30));
      expect(LessonSchedule.listedUntil(late), at(1, 0, 1));
      expect(LessonSchedule.isListed(late, at(0, 45, 1)), isTrue);
      expect(LessonSchedule.isListed(late, at(1, 1, 1)), isFalse);
    });

    test('مربوط بصلاة: يبقى بقية يومه بعد درسه، والمتكرر ينتقل لجلسته التالية', () {
      final once = lesson(at: at(10), timing: 'prayer_linked', prayer: 'maghrib');
      final weekly = lesson(at: at(10), timing: 'prayer_linked', prayer: 'maghrib', recurring: true, days: 'الأربعاء');
      final end = adhan('maghrib', at(0)).add(LessonSchedule.afterPrayerDelay).add(const Duration(minutes: 60));

      expect(LessonSchedule.isPastToday(once, end.add(const Duration(minutes: 29))), isFalse);
      expect(LessonSchedule.isPastToday(once, end.add(const Duration(minutes: 31))), isTrue);
      expect(LessonSchedule.isListed(once, end.add(const Duration(minutes: 31))), isTrue);
      expect(LessonSchedule.isListed(once, at(0, 1, 1)), isFalse);
      expect(LessonSchedule.isListed(weekly, end.add(const Duration(minutes: 31))), isTrue);
      expect(LessonSchedule.isPastToday(weekly, end.add(const Duration(minutes: 31))), isFalse);
      // التالي بعد أسبوع
      expect(LessonSchedule.currentOrNextStart(weekly, end.add(const Duration(minutes: 31)))!.day, 14);
    });
  });

  group('علامة «مباشر»', () {
    test('تُصدَّق أثناء الجلسة وقبلها بقليل وبعدها بساعات قليلة', () {
      final e = lesson(at: at(18), status: 'live');
      expect(LessonSchedule.isLive(e, at(16)), isTrue);
      expect(LessonSchedule.isLive(e, at(18, 30)), isTrue);
      expect(LessonSchedule.isLive(e, at(23)), isTrue);
      // تسجيل امتدّ بعد نهاية الدرس: يبقى ظاهراً ولو انتهى موعده
      expect(LessonSchedule.isListed(e, at(21)), isTrue);
    });

    test('علامة عالقة من هاتف أُطفئ أثناء التسجيل: لا «مباشر الآن»، ودرس المرة الواحدة يختفي', () {
      final once = lesson(at: at(18, 0, -1), status: 'live');
      expect(LessonSchedule.isLive(once, at(12)), isFalse);
      expect(LessonSchedule.isListed(once, at(12)), isFalse);

      final weekly = lesson(at: at(18, 0, -7), recurring: true, days: 'الأربعاء', status: 'live');
      expect(LessonSchedule.isLive(weekly, at(11, 0, -1)), isFalse);
      // المتكرر يبقى ظاهراً لجلسته القادمة
      expect(LessonSchedule.isListed(weekly, at(11, 0, -1)), isTrue);
      // ومباشر فعلاً إن بدأ تسجيله في يومه
      expect(LessonSchedule.isLive(weekly, at(18, 10)), isTrue);
    });

    test('غير «مباشر» أبداً بلا العلامة', () {
      expect(LessonSchedule.isLive(lesson(at: at(18)), at(18, 10)), isFalse);
    });
  });

  group('ترتيب القائمة', () {
    test('المباشر أولاً، ثم الأقرب موعداً، والمتكرر بجلسته القادمة لا بتاريخ إعلانه', () {
      final now = at(12);
      final events = [
        lesson(id: 'next-week', title: 'بعد أسبوع', at: at(18, 0, 6)),
        lesson(id: 'weekly', title: 'أسبوعي', at: at(17, 0, -30), recurring: true, days: 'الخميس'),
        lesson(id: 'tonight', title: 'الليلة', at: at(20)),
        lesson(id: 'live', title: 'مباشر', at: at(11, 30), status: 'live'),
        lesson(id: 'after-asr', title: 'بعد العصر', at: at(14), timing: 'prayer_linked', prayer: 'asr'),
      ]..sort((a, b) => LessonSchedule.compareBySchedule(a, b, now));

      expect(events.map((e) => e.id), ['live', 'after-asr', 'tonight', 'weekly', 'next-week']);
    });

    test('ما مضى موعده اليوم في آخر القائمة، الأقدم فالأحدث', () {
      final now = at(15);
      final events = [
        lesson(id: 'past-noon', title: 'أ', at: at(12)),
        lesson(id: 'tonight', title: 'ب', at: at(20)),
        lesson(id: 'past-morning', title: 'ج', at: at(8)),
        lesson(id: 'tomorrow', title: 'د', at: at(9, 0, 1)),
      ]..sort((a, b) => LessonSchedule.compareBySchedule(a, b, now));

      expect(events.map((e) => e.id), ['tonight', 'tomorrow', 'past-morning', 'past-noon']);
    });
  });

  group('نص الموعد المعروض', () {
    test('القاعدة: الأيام بترتيب الأسبوع، الساعة بنظام 12، ولا تاريخ قديم للمتكرر', () {
      expect(lesson(at: at(18, 0, -40), recurring: true, days: 'الخميس, السبت, الاثنين').timingDescription,
          'كل السبت، الاثنين، الخميس • 6:00 م');
      expect(lesson(at: at(6, 5), recurring: true).timingDescription, 'يومياً • 6:05 ص');
      expect(lesson(at: at(6, 5), recurring: true, days: ArabicTime.weekOrder.join(', ')).timingDescription,
          'يومياً • 6:05 ص');
      expect(lesson(at: at(18)).timingDescription, 'الأربعاء 2026/10/07 • 6:00 م');
      expect(lesson(at: at(0, 15)).timingDescription, 'الأربعاء 2026/10/07 • 12:15 ص');
      expect(lesson(at: at(12)).timingDescription, 'الأربعاء 2026/10/07 • 12:00 م');
      expect(lesson(at: at(9), timing: 'prayer_linked', prayer: 'asr', recurring: true, days: 'السبت').timingDescription,
          'كل السبت • مباشرة بعد صلاة العصر');
      expect(lesson(at: at(9), timing: 'prayer_linked', prayer: 'jumua', recurring: true, days: 'السبت').timingDescription,
          'كل جمعة • مباشرة بعد صلاة الجمعة');
    });

    test('الجلسة القادمة: اليوم، غداً، اسم اليوم، ثم التاريخ؛ و«جارٍ الآن» أثناءها', () {
      final now = at(12);
      expect(LessonSchedule.sessionLabel(lesson(at: at(18)), now), 'اليوم • 6:00 م');
      expect(LessonSchedule.sessionLabel(lesson(at: at(18, 0, 1)), now), 'غداً • 6:00 م');
      expect(LessonSchedule.sessionLabel(lesson(at: at(18, 0, 3)), now), 'السبت • 6:00 م');
      expect(LessonSchedule.sessionLabel(lesson(at: at(18, 0, 10)), now), 'السبت 17/10 • 6:00 م');
      expect(LessonSchedule.sessionLabel(lesson(at: at(11, 30)), now), 'جارٍ الآن • بدأ 11:30 ص');
      expect(LessonSchedule.sessionLabel(lesson(at: at(9)), now), 'مضى موعده • اليوم 9:00 ص');

      final weekly = lesson(at: at(18, 0, -30), recurring: true, days: 'الأحد, الخميس');
      expect(LessonSchedule.sessionLabel(weekly, now), 'غداً • 6:00 م');
    });

    test('مربوط بصلاة: الوقت محسوب من أذان المسجد، و«بعد الصلاة» تقريبي فيُقال «نحو»', () {
      final now = at(9);
      final asr = adhan('asr', at(0));
      String clock(DateTime t) => ArabicTime.clock(t);

      expect(LessonSchedule.sessionLabel(lesson(at: at(10), timing: 'prayer_linked', prayer: 'asr'), now),
          'اليوم • نحو ${clock(asr.add(LessonSchedule.afterPrayerDelay))}');
      expect(
          LessonSchedule.sessionLabel(
              lesson(at: at(10), timing: 'prayer_linked', prayer: 'asr', relation: 'between_adhan_iqama'), now),
          'اليوم • ${clock(asr)}');
      expect(
          LessonSchedule.sessionLabel(lesson(at: at(10), timing: 'prayer_linked', prayer: 'asr', relation: 'before'), now),
          'اليوم • ${clock(asr.subtract(const Duration(minutes: 60)))}');
    });

    test('أسماء الأيام والأيام النسبية', () {
      final now = at(12);
      expect(ArabicTime.relativeDay(at(1), now), 'اليوم');
      expect(ArabicTime.relativeDay(at(23, 59, 1), now), 'غداً');
      expect(ArabicTime.relativeDay(at(9, 0, -1), now), 'أمس');
      expect(ArabicTime.relativeDay(at(9, 0, 6), now), 'الثلاثاء');
      expect(ArabicTime.relativeDay(DateTime(2027, 1, 5), now), 'الثلاثاء 5/1/2027');
      expect([for (var d = 0; d < 7; d++) ArabicTime.weekday(at(9, 0, d))],
          ['الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد', 'الاثنين', 'الثلاثاء']);
    });
  });
}
