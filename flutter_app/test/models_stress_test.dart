import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  group('Milestone 1 Barrel & Models De-monolithing Stress Test', () {
    test('Verify barrel export resolves all 17 domain entity types', () {
      final mosque = Mosque(
        id: 'm1',
        name: 'جامع الهدى',
        city: 'دمشق',
        gender: 'male',
        accessCode: 'MSQ-HDY01',
      );
      final sheikh = Sheikh(
        id: 'sh1',
        mosqueId: mosque.id,
        fullName: 'الشيخ أحمد',
        code: 'SHK-001',
      );
      final halaqa = Halaqa(
        id: 'h1',
        mosqueId: mosque.id,
        sheikhId: sheikh.id,
        coSheikhIds: ['sh2'],
        name: 'حلقة البخاري',
        daysOfWeek: [6, 1, 3],
      );
      final student = Student(
        id: 'st1',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        sheikhId: sheikh.id,
        fullName: 'عمر خالد',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-101',
      );
      final memRecord = MemorizationRecord(
        id: 'mr1',
        studentId: student.id,
        halaqaId: halaqa.id,
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'new_memorization',
        qualityRating: 'excellent',
        pointsEarned: 10,
        recordedAt: DateTime.now(),
      );
      final attRecord = AttendanceRecord(
        id: 'ar1',
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionDate: '2026-09-12',
        status: 'present',
        pointsEarned: 5,
      );
      final appMsg = AppMessage(
        id: 'msg1',
        studentId: student.id,
        halaqaId: halaqa.id,
        senderType: 'sheikh',
        senderName: sheikh.fullName,
        content: 'أحسنت التلاوة اليوم',
        createdAt: DateTime.now(),
      );
      final event = CommunityEvent(
        id: 'ev1',
        mosqueId: mosque.id,
        title: 'درس في التفسير',
        description: 'تفسير سورة الكهف',
        eventType: 'lesson',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(const Duration(days: 1)),
        organizerType: 'sheikh',
        organizerName: sheikh.fullName,
      );
      final pointsLog = PointsLog(
        id: 'pl1',
        studentId: student.id,
        points: 15,
        reason: 'حفظ متقن',
        category: 'memorization',
        createdAt: DateTime.now(),
      );
      final comp = Competition(
        id: 'comp1',
        mosqueId: mosque.id,
        title: 'مسابقة حفظ جزء عم',
        description: 'لطلاب الحلقات',
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        genderBranch: 'male',
      );
      final session = ActiveSession(
        role: 'student',
        code: student.code,
        studentId: student.id,
        mosqueId: mosque.id,
      );
      final reward = Reward(
        id: 'rw1',
        mosqueId: mosque.id,
        title: 'مصحف مذهب',
        pointsCost: 150,
        createdAt: DateTime.now(),
      );
      final redemption = RewardRedemption(
        id: 'red1',
        studentId: student.id,
        studentName: student.fullName,
        mosqueId: mosque.id,
        mosqueName: mosque.name,
        rewardId: reward.id,
        rewardTitle: reward.title,
        pointsSpent: reward.pointsCost,
        redemptionCode: 'VCH-7788',
        redeemedAt: DateTime.now(),
      );
      final course = IntensiveCourse(
        id: 'crs1',
        mosqueId: mosque.id,
        name: 'دورة الأترجة الصيفية',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 14)),
        createdAt: DateTime.now(),
      );
      final trip = Trip(
        id: 'trp1',
        mosqueId: mosque.id,
        title: 'رحلة الربيع',
        destination: 'حديقة تشرين',
        tripDate: DateTime.now().add(const Duration(days: 5)),
        meetingTime: '08:00 صباحاً',
        createdAt: DateTime.now(),
      );
      final track = RecitationTrack(
        id: 'trk1',
        mosqueId: mosque.id,
        name: 'الأربعون النووية',
        category: 'hadith',
        unitLabel: 'حديث',
        totalUnits: 42,
        createdAt: DateTime.now(),
      );
      final subjRecord = SubjectRecitationRecord(
        id: 'srr1',
        studentId: student.id,
        trackId: track.id,
        trackName: track.name,
        fromUnit: 1,
        toUnit: 5,
        unitsCount: 5,
        pointsEarned: 10,
        recordedAt: DateTime.now(),
      );

      // Verify all 17 instances are non-null and correctly typed
      expect(mosque, isA<Mosque>());
      expect(sheikh, isA<Sheikh>());
      expect(halaqa, isA<Halaqa>());
      expect(student, isA<Student>());
      expect(memRecord, isA<MemorizationRecord>());
      expect(attRecord, isA<AttendanceRecord>());
      expect(appMsg, isA<AppMessage>());
      expect(event, isA<CommunityEvent>());
      expect(pointsLog, isA<PointsLog>());
      expect(comp, isA<Competition>());
      expect(session, isA<ActiveSession>());
      expect(reward, isA<Reward>());
      expect(redemption, isA<RewardRedemption>());
      expect(course, isA<IntensiveCourse>());
      expect(trip, isA<Trip>());
      expect(track, isA<RecitationTrack>());
      expect(subjRecord, isA<SubjectRecitationRecord>());
    });

    test('Trip inter-model dependency with Student: isStudentTargeted', () {
      final s1 = Student(
        id: 's1',
        mosqueId: 'm1',
        halaqaId: 'h1',
        fullName: 'طالب 1',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-1',
      );
      final s2 = Student(
        id: 's2',
        mosqueId: 'm1',
        halaqaId: 'h2',
        fullName: 'طالب 2',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-2',
      );

      // Empty target lists -> targeted for all students
      final openTrip = Trip(
        id: 't_open',
        mosqueId: 'm1',
        title: 'رحلة عامة',
        destination: 'المتحف',
        tripDate: DateTime.now().add(const Duration(days: 3)),
        meetingTime: '08:00',
        createdAt: DateTime.now(),
      );
      expect(openTrip.isStudentTargeted(s1), isTrue);
      expect(openTrip.isStudentTargeted(s2), isTrue);

      // Targeting specific student ID
      final targetedStudentTrip = openTrip.copyWith(
        targetStudentIds: ['s1'],
        targetHalaqaIds: [],
      );
      expect(targetedStudentTrip.isStudentTargeted(s1), isTrue);
      expect(targetedStudentTrip.isStudentTargeted(s2), isFalse);

      // Targeting specific halaqa ID
      final targetedHalaqaTrip = openTrip.copyWith(
        targetStudentIds: [],
        targetHalaqaIds: ['h2'],
      );
      expect(targetedHalaqaTrip.isStudentTargeted(s1), isFalse);
      expect(targetedHalaqaTrip.isStudentTargeted(s2), isTrue);
    });

    test('Mosque access code logic and branch code generation', () {
      final m1 = Mosque(
        id: 'mosque_123',
        name: 'جامع النور',
        city: 'دمشق',
        gender: 'male',
        accessCode: 'MSQ-NOOR99',
      );
      expect(m1.womenProvisionToken, isNull);
      expect(m1.effectiveCashierCode, equals('CSH-NOOR99'));

      final mWithExplicitWomen = Mosque(
        id: 'mosque_456',
        name: 'جامع الفتح',
        city: 'ريف دمشق',
        gender: 'female',
        accessCode: 'MSQ-FATH01',
        womenAccessCode: 'WMV-CUSTOM12',
      );
      expect(mWithExplicitWomen.womenProvisionToken, equals('WMV-CUSTOM12'));
      expect(mWithExplicitWomen.effectiveCashierCode, equals('CSH-FATH01'));

      // From JSON with auto code generation
      final mFromJson = Mosque.fromJson({
        'id': 'abc-xyz',
        'name': 'جامع الإيمان',
      });
      expect(mFromJson.accessCode, isEmpty);
      expect(mFromJson.womenProvisionToken, isNull);
    });

    test('ActiveSession role labels and fallback names', () {
      final admin = ActiveSession(role: 'mosque_admin', code: 'MSQ-01');
      expect(admin.roleLabel, equals('مدير المسجد'));
      expect(admin.name, equals('مدير المسجد'));

      final sheikh = ActiveSession(role: 'sheikh', code: 'SHK-01', name: 'الشيخ سعيد');
      expect(sheikh.roleLabel, equals('الشيخ المحفظ'));
      expect(sheikh.name, equals('الشيخ سعيد'));

      final student = ActiveSession(role: 'student', code: 'STD-01');
      expect(student.roleLabel, equals('طالب / ولي أمر'));
      expect(student.name, equals('مستخدم المنظومة'));

      final cashier = ActiveSession(role: 'cashier', code: 'CSH-01');
      expect(cashier.roleLabel, equals('صراف الجوائز المعتمد'));

      final visitor = ActiveSession(role: 'visitor', code: 'VISITOR');
      expect(visitor.roleLabel, equals('زائر عام'));
    });

    test('CommunityEvent category and timing formatting', () {
      final lesson = CommunityEvent(
        id: 'ev_l',
        mosqueId: 'm1',
        title: 'درس الفقه',
        description: 'شرح عمدة الفقه',
        eventType: 'lesson',
        targetAudience: 'general',
        eventDateTime: DateTime(2026, 10, 1, 17, 30),
        organizerType: 'sheikh',
        organizerName: 'الشيخ محمد',
        timingType: 'prayer_linked',
        prayerName: 'maghrib',
        prayerRelation: 'after',
        isRecurring: false,
      );
      expect(lesson.displayCategory, equals('دروس فقه وعلم 📖'));
      expect(lesson.timingDescription, equals('مباشرة بعد صلاة المغرب'));

      final custom = CommunityEvent(
        id: 'ev_c',
        mosqueId: 'm1',
        title: 'جلسة حوارية',
        description: 'نقاش شبابي',
        eventType: 'custom',
        customTypeName: 'ندوة فكرية 💡',
        targetAudience: 'general',
        eventDateTime: DateTime(2026, 10, 1, 19, 0),
        organizerType: 'mosque_admin',
        organizerName: 'الإدارة',
        timingType: 'custom_time',
      );
      expect(custom.displayCategory, equals('ندوة فكرية 💡'));
      expect(custom.timingDescription.contains('2026/10/01 الساعة 19:00'), isTrue);
    });

    test('Halaqa schedule and sheikh assignment checks', () {
      final halaqa = Halaqa(
        id: 'h1',
        mosqueId: 'm1',
        sheikhId: 'sh1',
        coSheikhIds: ['sh2', 'sh3'],
        name: 'حلقة الإتقان',
        daysOfWeek: [1, 3, 5],
        customTime: '17:00',
      );

      expect(halaqa.isSheikhAssigned('sh1'), isTrue);
      expect(halaqa.isSheikhAssigned('sh2'), isTrue);
      expect(halaqa.isSheikhAssigned('sh3'), isTrue);
      expect(halaqa.isSheikhAssigned('sh4'), isFalse);

      final dtOnSchedule = DateTime(2026, 9, 14, 17, 10); // 2026-09-14 is Monday (weekday=1)
      expect(halaqa.isScheduledAt(dtOnSchedule, bufferMinutes: 30), isTrue);

      final dtWrongDay = DateTime(2026, 9, 15, 17, 10); // Tuesday (weekday=2)
      expect(halaqa.isScheduledAt(dtWrongDay, bufferMinutes: 30), isFalse);

      final dtWrongTime = DateTime(2026, 9, 14, 21, 0); // Monday, but 21:00
      expect(halaqa.isScheduledAt(dtWrongTime, bufferMinutes: 30), isFalse);
    });

    test('IntensiveCourse schedule, enrollment, and copyWith', () {
      final course = IntensiveCourse(
        id: 'crs1',
        mosqueId: 'm1',
        name: 'مخيم الحفظ المكثف',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 30),
        studentIds: ['st1', 'st2'],
        daysOfWeek: [6, 7, 1], // Sat, Sun, Mon
        startTime: '08:00',
        endTime: '12:00',
        createdAt: DateTime(2026, 6, 1),
      );

      expect(course.isStudentEnrolled('st1'), isTrue);
      expect(course.isStudentEnrolled('st2'), isTrue);
      expect(course.isStudentEnrolled('st3'), isFalse);

      final copied = course.copyWith(name: 'اسم جديد للدورة');
      expect(copied.name, equals('اسم جديد للدورة'));
      expect(copied.id, equals(course.id));
      expect(copied.startDate, equals(course.startDate));
      expect(copied.studentIds, equals(course.studentIds));

      final activeDt = DateTime(2026, 7, 5, 9, 30); // Sunday (weekday=7), in range, 09:30
      expect(course.isScheduledAt(activeDt), isTrue);

      final outOfRangeDt = DateTime(2026, 8, 10, 9, 30);
      expect(course.isScheduledAt(outOfRangeDt), isFalse);
    });

    test('Serialization round-trip resilience across all 17 models', () {
      // 1. Mosque
      final m = Mosque(id: 'm', name: 'N', city: 'C', gender: 'male', accessCode: 'MSQ-X');
      expect(Mosque.fromJson(m.toJson()).id, equals(m.id));

      // 2. Sheikh
      final s = Sheikh(id: 's', mosqueId: 'm', fullName: 'F', code: 'SHK-1');
      expect(Sheikh.fromJson(s.toJson()).fullName, equals(s.fullName));

      // 3. Halaqa
      final h = Halaqa(id: 'h', mosqueId: 'm', name: 'HN', coSheikhIds: ['s1', 's2']);
      final hRound = Halaqa.fromJson(h.toJson());
      expect(hRound.coSheikhIds, equals(['s1', 's2']));

      // 4. Student
      final st = Student(id: 'st', mosqueId: 'm', halaqaId: 'h', fullName: 'S', gender: 'male', phone: '0500000000', code: 'STD-1');
      expect(Student.fromJson(st.toJson()).code, equals(st.code));

      // 5. MemorizationRecord
      final mr = MemorizationRecord(
        id: 'mr',
        studentId: 'st',
        surahName: 'البقرة',
        fromAyah: 1,
        toAyah: 5,
        juzNumber: 1,
        sessionType: 'new_memorization',
        qualityRating: 'good',
        pointsEarned: 10,
        recordedAt: DateTime.now(),
      );
      expect(MemorizationRecord.fromJson(mr.toJson()).surahName, equals('البقرة'));

      // 6. AttendanceRecord
      final ar = AttendanceRecord(id: 'ar', studentId: 'st', halaqaId: 'h', sessionDate: '2026-09-12', status: 'late', pointsEarned: 2);
      expect(AttendanceRecord.fromJson(ar.toJson()).status, equals('late'));

      // 7. AppMessage
      final am = AppMessage(id: 'am', studentId: 'st', halaqaId: 'h', senderType: 'sheikh', senderName: 'S', content: 'رسالة', createdAt: DateTime.now());
      expect(AppMessage.fromJson(am.toJson()).content, equals('رسالة'));

      // 8. CommunityEvent
      final ce = CommunityEvent(id: 'ce', mosqueId: 'm', title: 'T', description: 'D', eventType: 'general', targetAudience: 'all', eventDateTime: DateTime.now(), organizerType: 'admin', organizerName: 'Adm');
      expect(CommunityEvent.fromJson(ce.toJson()).title, equals('T'));

      // 9. PointsLog
      final pl = PointsLog(id: 'pl', studentId: 'st', points: 20, reason: 'R', category: 'dhikr', createdAt: DateTime.now());
      expect(PointsLog.fromJson(pl.toJson()).points, equals(20));

      // 10. Competition
      final cp = Competition(id: 'cp', title: 'C', description: 'CD', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 5)), genderBranch: 'male');
      expect(Competition.fromJson(cp.toJson()).title, equals('C'));

      // 11. ActiveSession
      final as_ = ActiveSession(role: 'visitor', code: 'VISITOR');
      expect(ActiveSession.fromJson(as_.toJson()).role, equals('visitor'));

      // 12. Reward
      final rw = Reward(id: 'rw', mosqueId: 'm', title: 'RT', pointsCost: 100, createdAt: DateTime.now());
      expect(Reward.fromJson(rw.toJson()).pointsCost, equals(100));

      // 13. RewardRedemption
      final rr = RewardRedemption(id: 'rr', studentId: 'st', studentName: 'SN', mosqueId: 'm', mosqueName: 'MN', rewardId: 'rw', rewardTitle: 'RT', pointsSpent: 100, redemptionCode: 'VCH-01', redeemedAt: DateTime.now());
      expect(RewardRedemption.fromJson(rr.toJson()).redemptionCode, equals('VCH-01'));

      // 14. IntensiveCourse
      final ic = IntensiveCourse(id: 'ic', mosqueId: 'm', name: 'IC', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10)), createdAt: DateTime.now());
      expect(IntensiveCourse.fromJson(ic.toJson()).name, equals('IC'));

      // 15. Trip
      final tr = Trip(id: 'tr', mosqueId: 'm', title: 'TT', destination: 'TD', tripDate: DateTime.now(), meetingTime: '08:00', createdAt: DateTime.now());
      expect(Trip.fromJson(tr.toJson()).destination, equals('TD'));

      // 16. RecitationTrack
      final rt = RecitationTrack(id: 'rt', mosqueId: 'm', name: 'RT', createdAt: DateTime.now());
      expect(RecitationTrack.fromJson(rt.toJson()).name, equals('RT'));

      // 17. SubjectRecitationRecord
      final srr = SubjectRecitationRecord(id: 'srr', studentId: 'st', trackId: 'rt', trackName: 'RT', fromUnit: 1, toUnit: 10, unitsCount: 10, pointsEarned: 20, recordedAt: DateTime.now());
      expect(SubjectRecitationRecord.fromJson(srr.toJson()).trackName, equals('RT'));
    });
  });
}
