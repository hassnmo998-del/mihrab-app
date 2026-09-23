import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  group('Milestone 1: Domain Models Adversarial Stress Suite', () {
    // -----------------------------------------------------------------------
    // 1. Mosque Model Stress Testing
    // -----------------------------------------------------------------------
    group('1. Mosque Model Stress Tests', () {
      test('Standard Instantiation and Default Fields', () {
        final mosque = Mosque(
          id: 'mosque-uuid-1',
          name: 'جامع بني أمية الكبير',
          city: 'دمشق',
          gender: 'male',
          accessCode: 'MSQ-UMAYYAD',
        );

        expect(mosque.id, 'mosque-uuid-1');
        expect(mosque.name, 'جامع بني أمية الكبير');
        expect(mosque.city, 'دمشق');
        expect(mosque.neighborhood, 'دمشق');
        expect(mosque.gender, 'male');
        expect(mosque.genderBranch, 'male');
        expect(mosque.accessCode, 'MSQ-UMAYYAD');
        // لا يوجد رمز نسائي مشتق من كود المسجد بعد العزل
        expect(mosque.womenProvisionToken, isNull);
        expect(mosque.hasWomenBranch, isFalse);
        expect(mosque.effectiveCashierCode, 'CSH-UMAYYAD');
        expect(mosque.latitude, 33.5138);
        expect(mosque.longitude, 36.2765);
      });

      test('Provision token is honoured only in the hardened WMV- form', () {
        final mosque = Mosque(
          id: 'mosque-uuid-2',
          name: 'جامع الهدى',
          city: 'حلب',
          gender: 'female',
          accessCode: 'MSQ-ALHUDA',
          womenAccessCode: 'WMV-CUSTOM12',
          latitude: 36.2021,
          longitude: 37.1343,
        );

        expect(mosque.womenProvisionToken, 'WMV-CUSTOM12');
        expect(mosque.isAwaitingWomenBranch, isTrue);
        expect(mosque.effectiveCashierCode, 'CSH-ALHUDA');
        expect(mosque.genderBranch, 'female');
        expect(mosque.isWomenSection, isTrue);
      });

      test('fromJson never synthesises a guessable code from the mosque id', () {
        final json = {
          'id': 'abc-123-xyz',
          'name': 'مسجد التقوى',
          'city': 'حمص',
          'gender': 'male',
        };
        final mosque = Mosque.fromJson(json);

        expect(mosque.id, 'abc-123-xyz');
        // كود مشتق من الـ id كان قابلاً للتخمين لأن الـ id يظهر في كل السجلات
        expect(mosque.accessCode, isEmpty);
        expect(mosque.womenProvisionToken, isNull);
      });

      test('fromJson Deserialization Supports snake_case and camelCase Alternates', () {
        final snakeJson = {
          'id': 'm1',
          'name': 'مسجد 1',
          'city': 'اللاذقية',
          'gender_branch': 'female',
          'access_code': 'MSQ-SNAKE',
          'women_access_code': 'WM-SNAKE',
          'latitude': 35.5,
          'longitude': 35.8,
        };
        final m1 = Mosque.fromJson(snakeJson);
        expect(m1.gender, 'female');
        expect(m1.accessCode, 'MSQ-SNAKE');
        // الرمز القديم المشتق (WM-) يُسقَط عند القراءة فلا يُقبل مرة أخرى
        expect(m1.womenAccessCode, isNull);
        expect(m1.womenProvisionToken, isNull);

        final camelJson = {
          'id': 'm2',
          'name': 'مسجد 2',
          'neighborhood': 'طرطوس',
          'gender': 'male',
          'accessCode': 'MSQ-CAMEL',
          'womenAccessCode': 'WMV-CAMEL12',
        };
        final m2 = Mosque.fromJson(camelJson);
        expect(m2.city, 'طرطوس');
        expect(m2.accessCode, 'MSQ-CAMEL');
        expect(m2.womenAccessCode, 'WMV-CAMEL12');
      });

      test('toJson and fromJson Roundtrip Consistency', () {
        final original = Mosque(
          id: 'mosque-99',
          name: 'مسجد الصحابة',
          city: 'حماة',
          address: 'شارع المرابط',
          phone: '0331234567',
          gender: 'male',
          accessCode: 'MSQ-HAMAH',
          womenAccessCode: 'WMV-HAMAH12',
          womenBranchId: 'mosque-branch-99',
          cashierAccessCode: 'CSH-HAMAH12',
          latitude: 35.1318,
          longitude: 36.7578,
        );

        final map = original.toJson();
        final restored = Mosque.fromJson(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.city, original.city);
        expect(restored.address, original.address);
        expect(restored.phone, original.phone);
        expect(restored.gender, original.gender);
        expect(restored.accessCode, original.accessCode);
        expect(restored.womenAccessCode, original.womenAccessCode);
        expect(restored.womenBranchId, original.womenBranchId);
        expect(restored.parentMosqueId, original.parentMosqueId);
        expect(restored.cashierAccessCode, original.cashierAccessCode);
        expect(restored.latitude, original.latitude);
        expect(restored.longitude, original.longitude);
      });
    });

    // -----------------------------------------------------------------------
    // 2. Sheikh Model Stress Testing
    // -----------------------------------------------------------------------
    group('2. Sheikh Model Stress Tests', () {
      test('Standard Instantiation & Serialization Roundtrip', () {
        final sheikh = Sheikh(
          id: 'shk-1',
          mosqueId: 'msq-1',
          fullName: 'الشيخ محمد راتب النابلسي',
          phone: '0944112233',
          code: 'SHK-1001',
        );

        expect(sheikh.id, 'shk-1');
        expect(sheikh.mosqueId, 'msq-1');
        expect(sheikh.fullName, 'الشيخ محمد راتب النابلسي');
        expect(sheikh.phone, '0944112233');
        expect(sheikh.code, 'SHK-1001');

        final json = sheikh.toJson();
        final fromJsonSheikh = Sheikh.fromJson(json);

        expect(fromJsonSheikh.id, sheikh.id);
        expect(fromJsonSheikh.mosqueId, sheikh.mosqueId);
        expect(fromJsonSheikh.fullName, sheikh.fullName);
        expect(fromJsonSheikh.phone, sheikh.phone);
        expect(fromJsonSheikh.code, sheikh.code);
      });

      test('fromJson Auto-generates Code When Code is Omitted', () {
        final json = {
          'id': 'shk-2',
          'mosque_id': 'msq-2',
          'full_name': 'الشيخ سعيد البوطي',
        };
        final sheikh = Sheikh.fromJson(json);
        expect(sheikh.code.startsWith('SHK-'), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 3. Halaqa Model Stress Testing
    // -----------------------------------------------------------------------
    group('3. Halaqa Model Stress Tests', () {
      test('Default Values and Sheikh Assignment Check', () {
        final halaqa = Halaqa(
          id: 'h-1',
          mosqueId: 'm-1',
          name: 'حلقة الإمام الشاطبي',
          sheikhId: 'shk-10',
          coSheikhIds: ['shk-11', 'shk-12'],
        );

        expect(halaqa.ageGroupMin, 6);
        expect(halaqa.ageGroupMax, 18);
        expect(halaqa.daysOfWeek, [6, 1, 3]);
        expect(halaqa.timingType, 'prayer_linked');
        expect(halaqa.prayerName, 'asr');
        expect(halaqa.prayerRelation, 'after');

        expect(halaqa.isSheikhAssigned('shk-10'), isTrue);
        expect(halaqa.isSheikhAssigned('shk-11'), isTrue);
        expect(halaqa.isSheikhAssigned('shk-12'), isTrue);
        expect(halaqa.isSheikhAssigned('shk-99'), isFalse);
      });

      test('dayName and formattedDays Generation', () {
        expect(Halaqa.dayName(1), 'الإثنين');
        expect(Halaqa.dayName(2), 'الثلاثاء');
        expect(Halaqa.dayName(3), 'الأربعاء');
        expect(Halaqa.dayName(4), 'الخميس');
        expect(Halaqa.dayName(5), 'الجمعة');
        expect(Halaqa.dayName(6), 'السبت');
        expect(Halaqa.dayName(7), 'الأحد');
        expect(Halaqa.dayName(0), '');
        expect(Halaqa.dayName(8), '');

        final halaqa = Halaqa(
          id: 'h-2',
          mosqueId: 'm-1',
          name: 'حلقة',
          daysOfWeek: [6, 1, 3],
        );
        expect(halaqa.formattedDays, 'السبت - الإثنين - الأربعاء');
      });

      test('isScheduledToday matches DateTime.now().weekday', () {
        final today = DateTime.now().weekday;
        final halaqaToday = Halaqa(
          id: 'h-today',
          mosqueId: 'm-1',
          name: 'حلقة اليوم',
          daysOfWeek: [today],
        );
        expect(halaqaToday.isScheduledToday(), isTrue);

        final otherWeekday = today == 7 ? 1 : today + 1;
        final halaqaNotToday = Halaqa(
          id: 'h-not-today',
          mosqueId: 'm-1',
          name: 'حلقة غير اليوم',
          daysOfWeek: [otherWeekday],
        );
        expect(halaqaNotToday.isScheduledToday(), isFalse);
      });

      test('isScheduledAt Smart Window Detection for All Prayer Times', () {
        // Find a Monday date (weekday = 1)
        DateTime testMonday = DateTime.now();
        while (testMonday.weekday != 1) {
          testMonday = testMonday.add(const Duration(days: 1));
        }

        final prayers = {
          'fajr': {'hour': 5, 'min': 0},
          'dhuhr': {'hour': 12, 'min': 30},
          'asr': {'hour': 16, 'min': 0},
          'maghrib': {'hour': 18, 'min': 45},
          'isha': {'hour': 20, 'min': 0},
        };

        for (final entry in prayers.entries) {
          final pName = entry.key;
          final pHour = entry.value['hour']!;
          final pMin = entry.value['min']!;

          final halaqa = Halaqa(
            id: 'h-$pName',
            mosqueId: 'm-1',
            name: 'حلقة $pName',
            daysOfWeek: [1], // Monday
            timingType: 'prayer_linked',
            prayerName: pName,
          );

          // Test exact start
          final exactStart = DateTime(testMonday.year, testMonday.month, testMonday.day, pHour, pMin);
          expect(halaqa.isScheduledAt(exactStart), isTrue, reason: 'Failed for $pName exact start');

          // Test 30 min buffer before
          final thirtyMinBefore = exactStart.subtract(const Duration(minutes: 30));
          expect(halaqa.isScheduledAt(thirtyMinBefore), isTrue, reason: 'Failed for $pName -30m buffer');

          // Test 31 min before (should be false)
          final thirtyOneMinBefore = exactStart.subtract(const Duration(minutes: 31));
          expect(halaqa.isScheduledAt(thirtyOneMinBefore), isFalse, reason: 'Failed for $pName -31m out of buffer');

          // Test 2 hours + 30 mins after start (endDt = startDt + 2 hours + 30 min buffer)
          final endBuffer = exactStart.add(const Duration(hours: 2, minutes: 30));
          expect(halaqa.isScheduledAt(endBuffer), isTrue, reason: 'Failed for $pName +2h30m end buffer');

          // Test 2 hours + 31 mins after start (should be false)
          final pastEndBuffer = exactStart.add(const Duration(hours: 2, minutes: 31));
          expect(halaqa.isScheduledAt(pastEndBuffer), isFalse, reason: 'Failed for $pName +2h31m past buffer');
        }
      });

      test('isScheduledAt with customTime', () {
        DateTime testWed = DateTime.now();
        while (testWed.weekday != 3) {
          testWed = testWed.add(const Duration(days: 1));
        }

        final halaqa = Halaqa(
          id: 'h-custom',
          mosqueId: 'm-1',
          name: 'حلقة مسائية',
          daysOfWeek: [3], // Wed
          timingType: 'custom',
          customTime: '19:15',
        );

        // At 19:15 on Wednesday
        final exact = DateTime(testWed.year, testWed.month, testWed.day, 19, 15);
        expect(halaqa.isScheduledAt(exact), isTrue);

        // Buffer: 18:45 (-30m) -> true
        expect(halaqa.isScheduledAt(exact.subtract(const Duration(minutes: 30))), isTrue);

        // Buffer: 18:44 (-31m) -> false
        expect(halaqa.isScheduledAt(exact.subtract(const Duration(minutes: 31))), isFalse);

        // Different weekday (Thursday = 4)
        final thursday = testWed.add(const Duration(days: 1));
        final thursdayTime = DateTime(thursday.year, thursday.month, thursday.day, 19, 15);
        expect(halaqa.isScheduledAt(thursdayTime), isFalse);
      });

      test('fromJson and toJson Roundtrip with stringified and list formats', () {
        final json = {
          'id': 'h-json',
          'mosque_id': 'm-json',
          'sheikh_id': 'shk-json',
          'co_sheikh_ids': ['shk-co-1', 'shk-co-2'],
          'name': 'حلقة التيسير',
          'description': 'شرح التيسير',
          'age_group_min': 10,
          'age_group_max': 25,
          'schedule': 'يومي بعد الفجر',
          'days_of_week': ['6', '7', '1', '2', '3', '4', '5'],
          'timing_type': 'custom',
          'prayer_name': 'fajr',
          'prayer_relation': 'after',
          'custom_time': '05:30',
        };

        final halaqa = Halaqa.fromJson(json);
        expect(halaqa.coSheikhIds.length, 2);
        expect(halaqa.daysOfWeek.length, 7);
        expect(halaqa.ageGroupMin, 10);
        expect(halaqa.customTime, '05:30');

        final serialized = halaqa.toJson();
        expect(serialized['id'], 'h-json');
        expect(serialized['sheikh_id'], 'shk-json');
        expect(serialized['co_sheikh_ids'], ['shk-co-1', 'shk-co-2']);
        expect(serialized['days_of_week'], [6, 7, 1, 2, 3, 4, 5]);

        final restored = Halaqa.fromJson(serialized);
        expect(restored.name, halaqa.name);
        expect(restored.daysOfWeek, halaqa.daysOfWeek);
      });
    });

    // -----------------------------------------------------------------------
    // 4. Student Model Stress Testing
    // -----------------------------------------------------------------------
    group('4. Student Model Stress Tests', () {
      test('Default Points and Field Assignments', () {
        final student = Student(
          id: 'std-1',
          mosqueId: 'm-1',
          halaqaId: 'h-1',
          sheikhId: 'shk-1',
          fullName: 'طارق بن زياد',
          gender: 'male',
          phone: '0500000000',
          code: 'STD-1001',
        );

        expect(student.totalPoints, 50); // Default welcome points
        expect(student.birthDate, isNull);
        expect(student.notes, isNull);
      });

      test('fromJson and toJson Roundtrip with snake_case and camelCase', () {
        final json = {
          'id': 'std-2',
          'mosque_id': 'm-2',
          'halaqa_id': 'h-2',
          'sheikh_id': 'shk-2',
          'full_name': 'عبد الله بن عمر',
          'birth_date': '2012-05-15',
          'gender': 'male',
          'notes': 'طالب متميز وسريع الحفظ',
          'total_points': 120,
          'code': 'STD-7788',
        };

        final student = Student.fromJson(json);
        expect(student.fullName, 'عبد الله بن عمر');
        expect(student.birthDate, '2012-05-15');
        expect(student.totalPoints, 120);

        final exported = student.toJson();
        expect(exported['full_name'], 'عبد الله بن عمر');
        expect(exported['total_points'], 120);

        final restored = Student.fromJson(exported);
        expect(restored.id, student.id);
        expect(restored.code, student.code);
      });
    });

    // -----------------------------------------------------------------------
    // 5. MemorizationRecord Model Stress Testing
    // -----------------------------------------------------------------------
    group('5. MemorizationRecord Model Stress Tests', () {
      test('Default countsTowardsStatistics and Serialization Roundtrip', () {
        final rec = MemorizationRecord(
          id: 'mem-1',
          studentId: 'std-1',
          halaqaId: 'h-1',
          sheikhId: 'shk-1',
          courseId: 'course-1',
          surahName: 'البقرة',
          fromAyah: 1,
          toAyah: 25,
          juzNumber: 1,
          sessionType: 'new_memorization',
          qualityRating: 'excellent',
          pointsEarned: 50,
          notes: 'إتقان تام مع أحكام النون الساكنة',
          recordedAt: DateTime(2026, 9, 12, 10, 30),
        );

        expect(rec.countsTowardsStatistics, isTrue);

        final json = rec.toJson();
        expect(json['surah_name'], 'البقرة');
        expect(json['from_ayah'], 1);
        expect(json['to_ayah'], 25);

        final restored = MemorizationRecord.fromJson(json);
        expect(restored.id, rec.id);
        expect(restored.surahName, rec.surahName);
        expect(restored.pointsEarned, rec.pointsEarned);
        expect(restored.recordedAt, rec.recordedAt);
      });

      test('fromJson Fallbacks for Nullable/Omitted Fields', () {
        final minimalJson = {
          'id': 'mem-2',
          'student_id': 'std-2',
        };

        final rec = MemorizationRecord.fromJson(minimalJson);
        expect(rec.fromAyah, 1);
        expect(rec.toAyah, 1);
        expect(rec.juzNumber, 1);
        expect(rec.sessionType, 'new_memorization');
        expect(rec.qualityRating, 'excellent');
        expect(rec.pointsEarned, 0);
        expect(rec.countsTowardsStatistics, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 6. AttendanceRecord Model Stress Testing
    // -----------------------------------------------------------------------
    group('6. AttendanceRecord Model Stress Tests', () {
      test('Roundtrip Serialization and Status Defaults', () {
        final record = AttendanceRecord(
          id: 'att-1',
          studentId: 'std-10',
          halaqaId: 'h-10',
          sessionDate: '2026-09-12',
          status: 'present',
          pointsEarned: 10,
          notes: 'حضور مبكر',
        );

        final json = record.toJson();
        expect(json['status'], 'present');
        expect(json['points_earned'], 10);

        final fromJsonRec = AttendanceRecord.fromJson(json);
        expect(fromJsonRec.id, record.id);
        expect(fromJsonRec.status, 'present');
        expect(fromJsonRec.pointsEarned, 10);
      });

      test('fromJson Default Status and Points', () {
        final json = {
          'id': 'att-2',
          'studentId': 'std-2',
          'halaqaId': 'h-2',
          'sessionDate': '2026-09-12',
        };

        final rec = AttendanceRecord.fromJson(json);
        expect(rec.status, 'present');
        expect(rec.pointsEarned, 0);
        expect(rec.notes, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // 7. AppMessage Model Stress Testing
    // -----------------------------------------------------------------------
    group('7. AppMessage Model Stress Tests', () {
      test('Instantiation Defaults and ISO8601 Date Roundtrip', () {
        final created = DateTime(2026, 9, 12, 14, 0, 0);
        final msg = AppMessage(
          id: 'msg-1',
          studentId: 'std-1',
          halaqaId: 'h-1',
          senderType: 'sheikh',
          senderName: 'الشيخ عاصم',
          content: 'السلام عليكم، يرجى مراجعة الربع الأول من سورة آل عمران',
          createdAt: created,
        );

        expect(msg.messageType, 'general');
        expect(msg.isRead, isFalse);

        final json = msg.toJson();
        expect(json['created_at'], created.toIso8601String());

        final fromJsonMsg = AppMessage.fromJson(json);
        expect(fromJsonMsg.id, msg.id);
        expect(fromJsonMsg.content, msg.content);
        expect(fromJsonMsg.messageType, 'general');
        expect(fromJsonMsg.isRead, isFalse);
        expect(fromJsonMsg.createdAt, created);
      });
    });

    // -----------------------------------------------------------------------
    // 8. CommunityEvent Model Stress Testing
    // -----------------------------------------------------------------------
    group('8. CommunityEvent Model Stress Tests', () {
      test('displayCategory for All Standard and Custom Event Types', () {
        final base = CommunityEvent(
          id: 'ev-1',
          mosqueId: 'm-1',
          title: 'فعالية',
          description: 'وصف',
          eventType: 'lesson',
          targetAudience: 'general',
          eventDateTime: DateTime(2026, 9, 15, 18, 0),
          organizerType: 'sheikh',
          organizerName: 'الشيخ',
        );

        expect(base.displayCategory, 'دروس فقه وعلم 📖');

        base.eventType = 'mawlid';
        expect(base.displayCategory, 'مجالس صلاة على النبي ﷺ 💚');

        base.eventType = 'tajweed';
        expect(base.displayCategory, 'دورات تجويد 🎙️');

        base.eventType = 'dhikr_circle';
        expect(base.displayCategory, 'مجالس ذكر وتلاوة 📿');

        base.eventType = 'custom';
        base.customTypeName = 'نشاط شبابي كشفي';
        expect(base.displayCategory, 'نشاط شبابي كشفي');

        base.eventType = 'unknown';
        base.customTypeName = null;
        expect(base.displayCategory, 'نشاط مجتمعي');
      });

      test('timingDescription for Prayer Linked and Custom Times', () {
        final ev = CommunityEvent(
          id: 'ev-2',
          mosqueId: 'm-1',
          title: 'درس العصر',
          description: 'شرح رياض الصالحين',
          eventType: 'lesson',
          timingType: 'prayer_linked',
          prayerName: 'asr',
          prayerRelation: 'after',
          targetAudience: 'general',
          eventDateTime: DateTime(2026, 9, 15, 16, 30),
          organizerType: 'sheikh',
          organizerName: 'الشيخ',
          isRecurring: false,
        );

        expect(ev.timingDescription, 'مباشرة بعد صلاة العصر');

        ev.prayerRelation = 'between_adhan_iqama';
        expect(ev.timingDescription, 'بين أذان وإقامة صلاة العصر');

        ev.prayerRelation = 'before';
        expect(ev.timingDescription, 'قبل أذان صلاة العصر');

        ev.timingType = 'custom_time';
        expect(ev.timingDescription, '2026/09/15 الساعة 16:30');
      });

      test('fromJson and toJson Roundtrip with Lat/Lng Precision', () {
        final ev = CommunityEvent(
          id: 'ev-3',
          mosqueId: 'm-1',
          title: 'دورة الصيف',
          description: 'تفاصيل',
          eventType: 'tajweed',
          targetAudience: 'male',
          latitude: 33.513824,
          longitude: 36.276518,
          eventDateTime: DateTime(2026, 9, 20, 10, 0),
          organizerType: 'mosque_admin',
          organizerName: 'أبو أحمد',
        );

        final json = ev.toJson();
        final restored = CommunityEvent.fromJson(json);

        expect(restored.id, ev.id);
        expect(restored.latitude, closeTo(33.513824, 0.000001));
        expect(restored.longitude, closeTo(36.276518, 0.000001));
        expect(restored.durationMinutes, 60);
      });
    });

    // -----------------------------------------------------------------------
    // 9. Competition Model Stress Testing
    // -----------------------------------------------------------------------
    group('9. Competition Model Stress Tests', () {
      test('isActive Date Window Checking', () {
        final now = DateTime.now();

        final activeComp = Competition(
          id: 'comp-1',
          title: 'مسابقة الحفظ الصيفي',
          description: 'حفظ جزء عم',
          startDate: now.subtract(const Duration(days: 5)),
          endDate: now.add(const Duration(days: 5)),
          genderBranch: 'male',
        );
        expect(activeComp.isActive, isTrue);

        final expiredComp = Competition(
          id: 'comp-2',
          title: 'مسابقة ماضية',
          description: '',
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now.subtract(const Duration(days: 2)), // 2 days ago -> outside +1 day buffer
          genderBranch: 'male',
        );
        expect(expiredComp.isActive, isFalse);

        final futureComp = Competition(
          id: 'comp-3',
          title: 'مسابقة قادمة',
          description: '',
          startDate: now.add(const Duration(days: 5)), // 5 days in future -> outside -1 day buffer
          endDate: now.add(const Duration(days: 20)),
          genderBranch: 'male',
        );
        expect(futureComp.isActive, isFalse);
      });

      test('Serialization Roundtrip and Default Boolean Flags', () {
        final now = DateTime(2026, 9, 1, 0, 0, 0);
        final comp = Competition(
          id: 'c-1',
          mosqueId: 'm-1',
          title: 'مسابقة الحديث',
          description: 'الأربعين النووية',
          startDate: now,
          endDate: now.add(const Duration(days: 15)),
          countQuran: false,
          countHadith: true,
          countAttendance: true,
          bonusPoints: 100,
          genderBranch: 'female',
        );

        final json = comp.toJson();
        expect(json['count_quran'], isFalse);
        expect(json['bonus_points'], 100);

        final fromJsonComp = Competition.fromJson(json);
        expect(fromJsonComp.countQuran, isFalse);
        expect(fromJsonComp.countHadith, isTrue);
        expect(fromJsonComp.bonusPoints, 100);
        expect(fromJsonComp.genderBranch, 'female');
      });
    });

    // -----------------------------------------------------------------------
    // 10. ActiveSession Model Stress Testing
    // -----------------------------------------------------------------------
    group('10. ActiveSession Model Stress Tests', () {
      test('Role Labels and Fallback Names for All Distinct Roles', () {
        final visitor = ActiveSession(role: 'visitor', code: 'V-01');
        expect(visitor.roleLabel, 'زائر عام');
        expect(visitor.name, 'مستخدم المنظومة');
        expect(visitor.genderBranch, 'male');

        final admin = ActiveSession(role: 'mosque_admin', code: 'MSQ-01');
        expect(admin.roleLabel, 'مدير المسجد');
        expect(admin.name, 'مدير المسجد');

        final sheikh = ActiveSession(role: 'sheikh', code: 'SHK-01', name: 'الشيخ تميم');
        expect(sheikh.roleLabel, 'الشيخ المحفظ');
        expect(sheikh.name, 'الشيخ تميم');

        final student = ActiveSession(role: 'student', code: 'STD-01', name: 'عمر');
        expect(student.roleLabel, 'طالب / ولي أمر');
        expect(student.name, 'عمر');

        final cashier = ActiveSession(role: 'cashier', code: 'CSH-01');
        expect(cashier.roleLabel, 'صراف الجوائز المعتمد');
        expect(cashier.name, 'مستخدم المنظومة');
      });

      test('toJson and fromJson Roundtrip across all optional attributes', () {
        final session = ActiveSession(
          role: 'sheikh',
          code: 'SHK-999',
          name: 'الشيخ يحيى',
          mosqueId: 'm-88',
          mosqueName: 'جامع خالد بن الوليد',
          gender: 'male',
          sheikhId: 'shk-88',
          studentId: null,
          halaqaId: 'h-88',
        );

        final json = session.toJson();
        final restored = ActiveSession.fromJson(json);

        expect(restored.role, session.role);
        expect(restored.code, session.code);
        expect(restored.name, session.name);
        expect(restored.mosqueId, session.mosqueId);
        expect(restored.mosqueName, session.mosqueName);
        expect(restored.gender, session.gender);
        expect(restored.sheikhId, session.sheikhId);
        expect(restored.halaqaId, session.halaqaId);
      });
    });

    // -----------------------------------------------------------------------
    // 11. PointsLog Model Stress Testing
    // -----------------------------------------------------------------------
    group('11. PointsLog Model Stress Tests', () {
      test('PointsLog Instantiation and Roundtrip', () {
        final dt = DateTime(2026, 9, 12, 11, 0);
        final log = PointsLog(
          id: 'log-1',
          studentId: 'std-1',
          points: 25,
          reason: 'حفظ سورة الأعلى بتفوق',
          category: 'memorization',
          createdAt: dt,
          competitionId: 'comp-10',
        );

        expect(log.points, 25);
        expect(log.competitionId, 'comp-10');

        final json = log.toJson();
        final restored = PointsLog.fromJson(json);

        expect(restored.id, log.id);
        expect(restored.points, 25);
        expect(restored.reason, log.reason);
        expect(restored.category, 'memorization');
        expect(restored.competitionId, 'comp-10');
        expect(restored.createdAt, dt);
      });
    });

    // -----------------------------------------------------------------------
    // 12. RecitationTrack Model Stress Testing
    // -----------------------------------------------------------------------
    group('12. RecitationTrack Model Stress Tests', () {
      test('Default Values and Category Configurations', () {
        final track = RecitationTrack(
          id: 'trk-1',
          mosqueId: 'm-1',
          name: 'متن تحفة الأطفال',
          createdAt: DateTime(2026, 9, 1),
        );

        expect(track.title, 'متن تحفة الأطفال');
        expect(track.category, 'custom');
        expect(track.unitLabel, 'حديث');
        expect(track.totalUnits, 40);
        expect(track.pointsPerUnit, 2);
        expect(track.isActive, isTrue);
        expect(track.isDefaultQuran, isFalse);
        expect(track.targetHalaqaIds, isEmpty);
      });

      test('Serialization Roundtrip with Target Halaqas', () {
        final track = RecitationTrack(
          id: 'trk-2',
          mosqueId: 'm-2',
          name: 'صحيح الأذكار',
          category: 'hadith',
          unitLabel: 'ذكر',
          totalUnits: 50,
          pointsPerUnit: 3,
          isActive: true,
          isDefaultQuran: false,
          targetHalaqaIds: ['h-1', 'h-2'],
          sheikhId: 'shk-1',
          createdAt: DateTime(2026, 9, 12),
        );

        final json = track.toJson();
        expect(json['total_units'], 50);
        expect(json['target_halaqa_ids'], ['h-1', 'h-2']);

        final restored = RecitationTrack.fromJson(json);
        expect(restored.id, track.id);
        expect(restored.name, track.name);
        expect(restored.targetHalaqaIds, ['h-1', 'h-2']);
        expect(restored.sheikhId, 'shk-1');
      });
    });

    // -----------------------------------------------------------------------
    // 13. Reward Model Stress Testing
    // -----------------------------------------------------------------------
    group('13. Reward Model Stress Tests', () {
      test('Default isActive and Serialization', () {
        final reward = Reward(
          id: 'rew-1',
          mosqueId: 'm-1',
          title: 'ساعة يد رقمية',
          description: 'مع منبه لأوقات الصلاة',
          pointsCost: 250,
          createdAt: DateTime(2026, 9, 10),
        );

        expect(reward.isActive, isTrue);

        final json = reward.toJson();
        expect(json['points_cost'], 250);

        final restored = Reward.fromJson(json);
        expect(restored.title, reward.title);
        expect(restored.pointsCost, 250);
        expect(restored.isActive, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 14. RewardRedemption Model Stress Testing
    // -----------------------------------------------------------------------
    group('14. RewardRedemption Model Stress Tests', () {
      test('Status Checkers (isDispensed / isPending) and Dispensation Tracking', () {
        final red = RewardRedemption(
          id: 'red-1',
          studentId: 'std-1',
          studentName: 'عمار بن ياسر',
          mosqueId: 'm-1',
          mosqueName: 'جامع الإيمان',
          rewardId: 'rew-1',
          rewardTitle: 'مصحف مذهب',
          pointsSpent: 150,
          redemptionCode: 'VCH-1234',
          redeemedAt: DateTime(2026, 9, 12, 12, 0),
        );

        expect(red.isPending, isTrue);
        expect(red.isDispensed, isFalse);

        red.status = 'dispensed';
        red.dispensedAt = DateTime(2026, 9, 12, 13, 0);
        red.cashierName = 'أبو بكر الصراف';

        expect(red.isPending, isFalse);
        expect(red.isDispensed, isTrue);

        final json = red.toJson();
        expect(json['status'], 'dispensed');
        expect(json['cashier_name'], 'أبو بكر الصراف');

        final restored = RewardRedemption.fromJson(json);
        expect(restored.status, 'dispensed');
        expect(restored.cashierName, 'أبو بكر الصراف');
        expect(restored.dispensedAt, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // 15. IntensiveCourse Model Stress Testing
    // -----------------------------------------------------------------------
    group('15. IntensiveCourse Model Stress Tests', () {
      test('copyWith Immutability and Targeted Field Updates', () {
        final original = IntensiveCourse(
          id: 'c-1',
          mosqueId: 'm-1',
          name: 'دورة حفظ النور',
          description: 'وصف قديم',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          sheikhIds: ['shk-1'],
          halaqaIds: ['h-1'],
          studentIds: ['std-1'],
          daysOfWeek: [6, 1, 3],
          startTime: '16:00',
          endTime: '18:00',
          countsTowardsQuranProgress: true,
          createdAt: DateTime(2026, 8, 25),
        );

        // Update single field
        final updatedName = original.copyWith(name: 'دورة حفظ القرآن المكثفة');
        expect(updatedName.name, 'دورة حفظ القرآن المكثفة');
        expect(original.name, 'دورة حفظ النور'); // Immutability check
        expect(updatedName.id, original.id);
        expect(updatedName.sheikhIds, original.sheikhIds);

        // Update multiple fields
        final updatedMulti = original.copyWith(
          description: 'وصف جديد',
          startTime: '17:00',
          countsTowardsQuranProgress: false,
        );
        expect(updatedMulti.description, 'وصف جديد');
        expect(updatedMulti.startTime, '17:00');
        expect(updatedMulti.countsTowardsQuranProgress, isFalse);
        expect(updatedMulti.name, original.name);
      });

      test('isStudentEnrolled Logic (Empty vs Specific Target List)', () {
        final openCourse = IntensiveCourse(
          id: 'c-open',
          mosqueId: 'm-1',
          name: 'دورة عامة مفتوحة للجميع',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 10)),
          studentIds: [], // Empty list means enrolled for all students
          createdAt: DateTime.now(),
        );

        expect(openCourse.isStudentEnrolled('any-student-id'), isTrue);
        expect(openCourse.isStudentEnrolled('another-student-id'), isTrue);

        final restrictedCourse = IntensiveCourse(
          id: 'c-restricted',
          mosqueId: 'm-1',
          name: 'دورة النخبة',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 10)),
          studentIds: ['std-vip-1', 'std-vip-2'],
          createdAt: DateTime.now(),
        );

        expect(restrictedCourse.isStudentEnrolled('std-vip-1'), isTrue);
        expect(restrictedCourse.isStudentEnrolled('std-vip-2'), isTrue);
        expect(restrictedCourse.isStudentEnrolled('std-regular'), isFalse);
      });

      test('isScheduledAt Boundary Conditions (Dates, Weekdays, ±30m Buffer)', () {
        final now = DateTime.now();
        // Find next Saturday (weekday = 6)
        DateTime sat = now;
        while (sat.weekday != 6) {
          sat = sat.add(const Duration(days: 1));
        }

        final course = IntensiveCourse(
          id: 'c-timing',
          mosqueId: 'm-1',
          name: 'دورة السبت المكثفة',
          startDate: sat.subtract(const Duration(days: 1)),
          endDate: sat.add(const Duration(days: 1)),
          daysOfWeek: [6], // Saturday only
          startTime: '16:00',
          endTime: '18:00',
          createdAt: now,
        );

        // 1. Exact start at 16:00 -> true
        final exactStart = DateTime(sat.year, sat.month, sat.day, 16, 0);
        expect(course.isScheduledAt(exactStart), isTrue);

        // 2. 25 minutes before (15:35) -> true (within 30m buffer)
        expect(course.isScheduledAt(exactStart.subtract(const Duration(minutes: 25))), isTrue);

        // 3. 35 minutes before (15:25) -> false (outside 30m buffer)
        expect(course.isScheduledAt(exactStart.subtract(const Duration(minutes: 35))), isFalse);

        // 4. Exact end at 18:00 -> true
        final exactEnd = DateTime(sat.year, sat.month, sat.day, 18, 0);
        expect(course.isScheduledAt(exactEnd), isTrue);

        // 5. 25 minutes after end (18:25) -> true (within 30m buffer)
        expect(course.isScheduledAt(exactEnd.add(const Duration(minutes: 25))), isTrue);

        // 6. 35 minutes after end (18:35) -> false (outside 30m buffer)
        expect(course.isScheduledAt(exactEnd.add(const Duration(minutes: 35))), isFalse);

        // 7. Wrong weekday (Sunday = 7) even at 16:00 -> false
        final sundayTime = DateTime(sat.year, sat.month, sat.day + 1, 16, 0);
        expect(course.isScheduledAt(sundayTime), isFalse);

        // 8. Outside course date range -> false
        final futureSat = sat.add(const Duration(days: 14));
        final futureTime = DateTime(futureSat.year, futureSat.month, futureSat.day, 16, 0);
        expect(course.isScheduledAt(futureTime), isFalse);
      });

      test('fromJson and toJson Roundtrip', () {
        final course = IntensiveCourse(
          id: 'ic-json',
          mosqueId: 'm-json',
          name: 'دورة صيفية',
          description: 'تفاصيل كاملة',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 20),
          sheikhIds: ['shk-1', 'shk-2'],
          halaqaIds: ['h-1', 'h-2'],
          studentIds: ['s-1', 's-2'],
          daysOfWeek: [1, 3, 5],
          startTime: '10:00',
          endTime: '12:00',
          countsTowardsQuranProgress: false,
          createdAt: DateTime(2026, 8, 30),
        );

        final map = course.toJson();
        expect(map['sheikh_ids'], ['shk-1', 'shk-2']);
        expect(map['counts_towards_quran_progress'], isFalse);

        final restored = IntensiveCourse.fromJson(map);
        expect(restored.id, course.id);
        expect(restored.name, course.name);
        expect(restored.daysOfWeek, [1, 3, 5]);
        expect(restored.countsTowardsQuranProgress, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // 16. Trip Model Stress Testing
    // -----------------------------------------------------------------------
    group('16. Trip Model Stress Tests', () {
      test('copyWith Immutability and Partial Mutation', () {
        final original = Trip(
          id: 'trip-1',
          mosqueId: 'm-1',
          title: 'رحلة حديقة تشرين',
          destination: 'حديقة تشرين',
          tripDate: DateTime(2026, 9, 25),
          meetingTime: '08:00 صباحاً',
          requiredItems: 'حقيبة ظهر، مياه، مصحف',
          createdAt: DateTime(2026, 9, 12),
        );

        final updated = original.copyWith(
          title: 'رحلة حديقة تشرين الكبرى',
          costPoints: 50,
          status: 'completed',
        );

        expect(original.title, 'رحلة حديقة تشرين');
        expect(original.costPoints, 0);
        expect(updated.title, 'رحلة حديقة تشرين الكبرى');
        expect(updated.costPoints, 50);
        expect(updated.status, 'completed');
        expect(updated.destination, original.destination);
      });

      test('Leader Name and Phone Extraction from Description', () {
        final tripWithInfo = Trip(
          id: 't-1',
          mosqueId: 'm-1',
          title: 'رحلة استكشافية',
          destination: 'معلولا',
          tripDate: DateTime.now().add(const Duration(days: 7)),
          meetingTime: '07:30 صباحاً',
          description: 'رحلة ثقافية وترفيهية - المشرف: الشيخ عمر الخطاب - هاتف: 0933112233',
          createdAt: DateTime.now(),
        );

        expect(tripWithInfo.leaderName, 'الشيخ عمر الخطاب');
        expect(tripWithInfo.leaderPhone, '0933112233');

        final tripWithoutInfo = Trip(
          id: 't-2',
          mosqueId: 'm-1',
          title: 'رحلة عامة',
          destination: 'صيدنايا',
          tripDate: DateTime.now().add(const Duration(days: 7)),
          meetingTime: '08:00 صباحاً',
          description: 'لا توجد بيانات مشرف',
          createdAt: DateTime.now(),
        );

        expect(tripWithoutInfo.leaderName, isNull);
        expect(tripWithoutInfo.leaderPhone, isNull);
      });

      test('isStudentTargeted Scenarios (Target Student, Target Halaqa, Open All)', () {
        final studentH1S1 = Student(
          id: 's-1',
          mosqueId: 'm-1',
          halaqaId: 'h-1',
          fullName: 'طالب 1 حلقة 1',
          gender: 'male',
          phone: '0500000000',
          code: 'STD-1',
        );
        final studentH2S2 = Student(
          id: 's-2',
          mosqueId: 'm-1',
          halaqaId: 'h-2',
          fullName: 'طالب 2 حلقة 2',
          gender: 'male',
          phone: '0500000000',
          code: 'STD-2',
        );
        final studentH3S3 = Student(
          id: 's-3',
          mosqueId: 'm-1',
          halaqaId: 'h-3',
          fullName: 'طالب 3 حلقة 3',
          gender: 'male',
          phone: '0500000000',
          code: 'STD-3',
        );

        // Case 1: Open to all (both targetStudentIds and targetHalaqaIds empty)
        final openTrip = Trip(
          id: 't-open',
          mosqueId: 'm-1',
          title: 'رحلة عامة لكل المسجد',
          destination: 'الغوطة',
          tripDate: DateTime.now().add(const Duration(days: 10)),
          meetingTime: '08:00 صباحاً',
          createdAt: DateTime.now(),
        );
        expect(openTrip.isStudentTargeted(studentH1S1), isTrue);
        expect(openTrip.isStudentTargeted(studentH2S2), isTrue);
        expect(openTrip.isStudentTargeted(studentH3S3), isTrue);

        // Case 2: Targeted by Halaqa (only h-1)
        final halaqaTrip = Trip(
          id: 't-halaqa',
          mosqueId: 'm-1',
          title: 'رحلة حلقة 1',
          destination: 'الربوة',
          tripDate: DateTime.now().add(const Duration(days: 5)),
          meetingTime: '09:00 صباحاً',
          targetHalaqaIds: ['h-1'],
          createdAt: DateTime.now(),
        );
        expect(halaqaTrip.isStudentTargeted(studentH1S1), isTrue);
        expect(halaqaTrip.isStudentTargeted(studentH2S2), isFalse);
        expect(halaqaTrip.isStudentTargeted(studentH3S3), isFalse);

        // Case 3: Targeted by specific Student ID (only s-3)
        final studentTrip = Trip(
          id: 't-student',
          mosqueId: 'm-1',
          title: 'رحلة المتفوقين',
          destination: 'قاسيون',
          tripDate: DateTime.now().add(const Duration(days: 3)),
          meetingTime: '10:00 صباحاً',
          targetStudentIds: ['s-3'],
          createdAt: DateTime.now(),
        );
        expect(studentTrip.isStudentTargeted(studentH1S1), isFalse);
        expect(studentTrip.isStudentTargeted(studentH2S2), isFalse);
        expect(studentTrip.isStudentTargeted(studentH3S3), isTrue);
      });

      test('isUpcoming Getter Edge Cases', () {
        final now = DateTime.now();

        final futureTrip = Trip(
          id: 't-f',
          mosqueId: 'm-1',
          title: 'رحلة قادمة',
          destination: 'دمشق',
          tripDate: now.add(const Duration(days: 3)),
          meetingTime: '08:00',
          status: 'upcoming',
          createdAt: now,
        );
        expect(futureTrip.isUpcoming, isTrue);

        final cancelledTrip = Trip(
          id: 't-c',
          mosqueId: 'm-1',
          title: 'رحلة ملغاة',
          destination: 'دمشق',
          tripDate: now.add(const Duration(days: 3)),
          meetingTime: '08:00',
          status: 'cancelled',
          createdAt: now,
        );
        expect(cancelledTrip.isUpcoming, isFalse);

        final pastTrip = Trip(
          id: 't-p',
          mosqueId: 'm-1',
          title: 'رحلة ماضية',
          destination: 'دمشق',
          tripDate: now.subtract(const Duration(days: 3)),
          meetingTime: '08:00',
          status: 'upcoming',
          createdAt: now,
        );
        expect(pastTrip.isUpcoming, isFalse);
      });

      test('fromJson and toJson Roundtrip', () {
        final trip = Trip(
          id: 'tr-json',
          mosqueId: 'm-json',
          title: 'رحلة الربوة',
          destination: 'الربوة',
          tripDate: DateTime(2026, 9, 30),
          meetingTime: '08:30 صباحاً',
          deadlineDate: DateTime(2026, 9, 28),
          description: 'المشرف: الشيخ تميم - هاتف: 0911223344',
          requiredItems: 'دفتر وقلم ومصحف',
          targetHalaqaIds: ['h-1'],
          targetStudentIds: ['s-1'],
          costPoints: 20,
          status: 'upcoming',
          createdAt: DateTime(2026, 9, 12),
        );

        final json = trip.toJson();
        final restored = Trip.fromJson(json);

        expect(restored.id, trip.id);
        expect(restored.title, trip.title);
        expect(restored.destination, trip.destination);
        expect(restored.costPoints, 20);
        expect(restored.requiredItems, 'دفتر وقلم ومصحف');
        expect(restored.requirements, 'دفتر وقلم ومصحف');
        expect(restored.registrationDeadline, DateTime(2026, 9, 28));
        expect(restored.leaderName, 'الشيخ تميم');
        expect(restored.leaderPhone, '0911223344');
      });
    });

    // -----------------------------------------------------------------------
    // 17. SubjectRecitationRecord Model Stress Testing
    // -----------------------------------------------------------------------
    group('17. SubjectRecitationRecord Model Stress Tests', () {
      test('Default countsTowardsStatistics and Serialization Roundtrip', () {
        final rec = SubjectRecitationRecord(
          id: 'srec-1',
          studentId: 'std-1',
          halaqaId: 'h-1',
          sheikhId: 'shk-1',
          trackId: 'trk-1',
          trackName: 'الأربعون النووية',
          fromUnit: 1,
          toUnit: 10,
          unitsCount: 10,
          pointsEarned: 50,
          courseId: 'c-1',
          notes: 'حفظ متقن للأحاديث',
          recordedAt: DateTime(2026, 9, 12, 16, 0),
        );

        expect(rec.countsTowardsStatistics, isTrue);

        final json = rec.toJson();
        expect(json['track_name'], 'الأربعون النووية');
        expect(json['units_count'], 10);
        expect(json['points_earned'], 50);

        final restored = SubjectRecitationRecord.fromJson(json);
        expect(restored.id, rec.id);
        expect(restored.trackId, rec.trackId);
        expect(restored.fromUnit, 1);
        expect(restored.toUnit, 10);
        expect(restored.unitsCount, 10);
        expect(restored.pointsEarned, 50);
        expect(restored.notes, rec.notes);
      });
    });

    // -----------------------------------------------------------------------
    // 18. Barrel Export Verification
    // -----------------------------------------------------------------------
    group('18. Barrel Export Compatibility', () {
      test('All 17 models are directly constructible via barrel import', () {
        // This test compiling without specific file imports is itself a compile-time assertion
        expect(Mosque, isNotNull);
        expect(Sheikh, isNotNull);
        expect(Halaqa, isNotNull);
        expect(Student, isNotNull);
        expect(MemorizationRecord, isNotNull);
        expect(AttendanceRecord, isNotNull);
        expect(AppMessage, isNotNull);
        expect(CommunityEvent, isNotNull);
        expect(PointsLog, isNotNull);
        expect(Competition, isNotNull);
        expect(ActiveSession, isNotNull);
        expect(Reward, isNotNull);
        expect(RewardRedemption, isNotNull);
        expect(IntensiveCourse, isNotNull);
        expect(Trip, isNotNull);
        expect(RecitationTrack, isNotNull);
        expect(SubjectRecitationRecord, isNotNull);
      });
    });
  });
}
