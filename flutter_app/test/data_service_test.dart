import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DataService Multi-role and Local-first Tests', () {
    test('Multi-role persistent sessions support', () async {
      final service = DataService();
      await service.init();

      // Register Mosque Admin session
      final adminSession = ActiveSession(
        role: 'mosque_admin',
        name: 'جامع الهدى',
        code: 'MOSQUE123',
        mosqueId: 'm-1',
        mosqueName: 'جامع الهدى',
      );
      service.setRoleSession(adminSession);

      // Register Sheikh session
      final sheikhSession = ActiveSession(
        role: 'sheikh',
        name: 'الشيخ عمر',
        code: 'SHK123',
        mosqueId: 'm-1',
        sheikhId: 's-1',
        mosqueName: 'جامع الهدى',
      );
      service.setRoleSession(sheikhSession);

      // Verify both sessions coexist
      expect(service.hasRole('mosque_admin'), isTrue);
      expect(service.hasRole('sheikh'), isTrue);
      expect(service.getSessionForRole('mosque_admin')?.code, equals('MOSQUE123'));
      expect(service.getSessionForRole('sheikh')?.code, equals('SHK123'));

      // Disconnecting one does not disconnect the other
      service.disconnectRole('sheikh');
      expect(service.hasRole('sheikh'), isFalse);
      expect(service.hasRole('mosque_admin'), isTrue);
    });

    test('Sheikh creation has no points and Student receives points', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد النور', address: 'وسط البلد', city: 'دمشق', gender: 'male');
      final sheikh = service.addSheikh(mosque.id, 'الشيخ أحمد', null);

      // Add a halaqa
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة البخاري', sheikhId: sheikh.id);

      // Add student with customizable welcome points
      final student = service.addStudent(
        fullName: 'خالد المنصور',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0500000000',
        welcomePoints: 50,
      );

      expect(student.totalPoints, equals(50));

      // Record attendance without points (default)
      service.recordAttendance(
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionDate: '2026-09-12',
        status: 'present',
        pointsEarned: 0,
      );

      final updatedSt1 = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updatedSt1.totalPoints, equals(50));

      // Record memorization with points
      service.recordMemorization(
        studentId: student.id,
        halaqaId: halaqa.id,
        sheikhId: sheikh.id,
        surahName: 'النبأ',
        fromAyah: 1,
        toAyah: 20,
        juzNumber: 30,
        sessionType: 'new_memorization',
        qualityRating: 'excellent',
        points: 15,
      );

      final updatedSt2 = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updatedSt2.totalPoints, equals(65));
    });

    test('Halaqa multi-sheikh co-supervision support', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد التقوى', address: 'الميدان', city: 'دمشق', gender: 'male');
      final sheikh1 = service.addSheikh(mosque.id, 'الشيخ الأول', null);
      final sheikh2 = service.addSheikh(mosque.id, 'الشيخ المساعد', null);

      final halaqa = service.addHalaqa(
        mosqueId: mosque.id,
        name: 'حلقة الفجر',
        sheikhId: sheikh1.id,
        coSheikhIds: [sheikh2.id],
      );

      expect(halaqa.isSheikhAssigned(sheikh1.id), isTrue);
      expect(halaqa.isSheikhAssigned(sheikh2.id), isTrue);
      expect(halaqa.isSheikhAssigned('other-id'), isFalse);
    });

    test('Community events support custom category type', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد الفرقان', address: 'حي الجامعة', city: 'حلب', gender: 'male');

      final event = service.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'شرح الشمائل المحمدية',
        description: 'درس في شمائل المصطفى ﷺ',
        eventType: 'custom',
        customTypeName: 'السيرة النبوية',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(const Duration(days: 1)),
        organizerType: 'sheikh',
        organizerName: 'الشيخ بلال',
      );

      expect(event.displayCategory, equals('السيرة النبوية'));
      expect(event.eventType, equals('custom'));
    });

    test('Executive overview returns comprehensive student matrix', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد الأنصار', address: 'الوعر', city: 'حمص', gender: 'male');
      final sheikh = service.addSheikh(mosque.id, 'الشيخ حمزة', null);
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة النور', sheikhId: sheikh.id);

      final student = service.addStudent(
        fullName: 'طارق زياد',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0500000000',
        welcomePoints: 50,
      );

      final overview = service.getExecutiveOverview(mosqueId: mosque.id);
      expect(overview.length, equals(1));
      expect((overview.first['student'] as Student).id, equals(student.id));
      expect((overview.first['student'] as Student).fullName, equals('طارق زياد'));
      expect((overview.first['sheikh'] as Sheikh).fullName, equals('الشيخ حمزة'));
      expect(overview.first['completedAjza'], equals(0));
      expect(overview.first['totalPoints'], equals(50));
    });

    test('Women branch exists only through a token issued by a men admin',
        () async {
      final service = DataService();
      await service.init();

      final mensMosque = service.addMosque(
          name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');

      // لا يوجد قسم نسائي ولا رمز قبل أن يصدره المدير
      expect(mensMosque.hasWomenBranch, isFalse);
      expect(mensMosque.womenProvisionToken, isNull);

      // الكود القديم المشتق (WM-) لا يُقبل لا للدخول ولا كرمز تسليم
      final derived =
          'WM-${mensMosque.accessCode.replaceAll('MSQ-', '')}';
      expect(await service.verifyCode(derived), isNull);
      expect(await service.inspectWomenProvisionToken(derived), isNull);

      // إصدار رمز التسليم من إدارة الرجال
      final token = service.issueWomenProvisionToken(mensMosque.id);
      expect(token, isNotNull);
      expect(token!.startsWith('WMV-'), isTrue);
      // الرمز غير مشتق من كود المسجد
      expect(token.contains(mensMosque.accessCode.replaceAll('MSQ-', '')),
          isFalse);

      // الرمز لا يمنح أي جلسة على مسجد الرجال
      expect(await service.verifyCode(token), isNull);

      final offer = await service.inspectWomenProvisionToken(token);
      expect(offer, isNotNull);
      expect(offer!.isHandover, isFalse);
      expect(offer.parentMosque.id, equals(mensMosque.id));

      final branch = await service.redeemWomenProvisionToken(
        offer: offer,
        name: 'القسم النسائي - جامع النور',
        city: 'دمشق',
        address: 'الميدان',
      );

      expect(branch, isNotNull);
      expect(branch!.gender, equals('female'));
      expect(branch.parentMosqueId, equals(mensMosque.id));
      // كود مستقل تماماً ولا يمكن استنتاجه من كود الرجال
      expect(branch.accessCode, isNot(equals(mensMosque.accessCode)));
      expect(branch.id, isNot(equals(mensMosque.id)));

      // الجلسة الناتجة على الفرع النسائي نفسه، لا على مسجد الرجال
      final session = service.getSessionForRole('mosque_admin');
      expect(session?.mosqueId, equals(branch.id));
      expect(service.branchOfSession(session), equals('female'));

      // الرمز يُستهلك: لا يمكن إنشاء فرع ثانٍ بنفس الرمز
      expect(await service.inspectWomenProvisionToken(token), isNull);
      expect(service.getMosqueById(mensMosque.id)!.womenProvisionToken, isNull);
      expect(service.getMosqueById(mensMosque.id)!.hasWomenBranch, isTrue);
    });

    test('Branch records are mutually invisible across the two administrations',
        () async {
      final service = DataService();
      await service.init();

      final mens = service.addMosque(
          name: 'جامع الهدى', address: 'القابون', city: 'دمشق', gender: 'male');
      final token = service.issueWomenProvisionToken(mens.id)!;
      final offer = (await service.inspectWomenProvisionToken(token))!;
      final branch = (await service.redeemWomenProvisionToken(
        offer: offer,
        name: 'القسم النسائي - جامع الهدى',
        city: 'دمشق',
        address: 'القابون',
      ))!;

      // سجلات فرع الرجال
      final sheikh = service.addSheikh(mens.id, 'الشيخ حسن', '0911111111');
      final halaqa = service.addHalaqa(
          mosqueId: mens.id, name: 'حلقة الفرقان', sheikhId: sheikh.id);
      service.addStudent(
        mosqueId: mens.id,
        halaqaId: halaqa.id,
        fullName: 'بلال',
        gender: 'male',
        phone: '0500000000',
      );

      // سجلات الفرع النسائي
      final teacher = service.addSheikh(branch.id, 'المعلمة سلمى', '0922222222');
      final halaqaF = service.addHalaqa(
          mosqueId: branch.id, name: 'حلقة خديجة', sheikhId: teacher.id);
      final girl = service.addStudent(
        mosqueId: branch.id,
        halaqaId: halaqaF.id,
        fullName: 'مريم',
        gender: 'female',
        phone: '0511111111',
      );

      // ما تراه إدارة الرجال (نطاق mosqueId الخاص بها)
      expect(service.getSheikhs(mosqueId: mens.id).map((s) => s.fullName),
          equals(['الشيخ حسن']));
      expect(service.getStudents(mosqueId: mens.id).map((s) => s.fullName),
          equals(['بلال']));
      expect(service.getHalaqat(mosqueId: mens.id).map((h) => h.name),
          equals(['حلقة الفرقان']));

      // وما تراه الإدارة النسائية
      expect(service.getSheikhs(mosqueId: branch.id).map((s) => s.fullName),
          equals(['المعلمة سلمى']));
      expect(service.getStudents(mosqueId: branch.id).map((s) => s.fullName),
          equals(['مريم']));
      expect(service.getHalaqat(mosqueId: branch.id).map((h) => h.name),
          equals(['حلقة خديجة']));

      // الطالبة تُسجَّل على فرعها، وترتيب الرجال لا يحتوي اسمها
      expect(service.branchOfMosque(girl.mosqueId), equals('female'));
      final maleRankings = service.getRankings(gender: 'male');
      expect(
        maleRankings.map((r) => (r['student'] as Student).fullName),
        isNot(contains('مريم')),
      );
      final femaleRankings = service.getRankings(gender: 'female');
      expect(
        femaleRankings.map((r) => (r['student'] as Student).fullName),
        isNot(contains('بلال')),
      );
    });

    test('Archive is asymmetric: women cannot record, men cannot get women media',
        () async {
      final service = DataService();
      await service.init();

      final mens = service.addMosque(
          name: 'جامع الرحمة', address: 'برزة', city: 'دمشق', gender: 'male');
      final token = service.issueWomenProvisionToken(mens.id)!;
      final offer = (await service.inspectWomenProvisionToken(token))!;
      final branch = (await service.redeemWomenProvisionToken(
        offer: offer,
        name: 'القسم النسائي - جامع الرحمة',
        city: 'دمشق',
        address: 'برزة',
      ))!;

      final mensEvent = service.addCommunityEvent(
        mosqueId: mens.id,
        title: 'درس الفقه',
        description: 'باب الطهارة',
        eventType: 'lesson',
        targetAudience: 'male',
        eventDateTime: DateTime.now(),
        organizerType: 'sheikh',
        organizerName: 'الشيخ حسن',
        isRecurring: false,
      );
      final womenEvent = service.addCommunityEvent(
        mosqueId: branch.id,
        title: 'درس التجويد',
        description: 'أحكام النون',
        eventType: 'tajweed',
        targetAudience: 'female',
        eventDateTime: DateTime.now(),
        organizerType: 'sheikh',
        organizerName: 'المعلمة سلمى',
        isRecurring: false,
      );

      // الجلسة الحالية نسائية (نتيجة الاستلام): كل مسارات الأرشفة مقفلة
      expect(service.viewerBranch, equals('female'));
      service.setEventAudioUrl(womenEvent.id, '/tmp/women.m4a');
      service.setEventVideoUrl(womenEvent.id, '/tmp/women.mp4');
      service.finalizeLiveSession(womenEvent.id);
      var stored = service
          .getCommunityEvents()
          .firstWhere((e) => e.id == womenEvent.id);
      expect(stored.audioRecordUrl, isNull);
      expect(stored.videoRecordUrl, isNull);
      expect(stored.eventStatus, isNot('archived'));

      // ولا تستطيع أرشفة درس الرجال أيضاً
      service.setEventAudioUrl(mensEvent.id, '/tmp/hijack.m4a');
      expect(
        service
            .getCommunityEvents()
            .firstWhere((e) => e.id == mensEvent.id)
            .audioRecordUrl,
        isNull,
      );

      // جلسة الرجال: الأرشفة تعمل على دروس فرعها
      await service.verifyCode(mens.accessCode);
      expect(service.canRecordArchive, isTrue);
      service.setEventAudioUrl(mensEvent.id, '/tmp/lesson.m4a');
      expect(
        service
            .getCommunityEvents()
            .firstWhere((e) => e.id == mensEvent.id)
            .audioRecordUrl,
        equals('/tmp/lesson.m4a'),
      );

      // لكنها لا تستطيع أرشفة أي درس تابع للقسم النسائي
      service.setEventAudioUrl(womenEvent.id, '/tmp/leak.m4a');
      stored = service
          .getCommunityEvents()
          .firstWhere((e) => e.id == womenEvent.id);
      expect(stored.audioRecordUrl, isNull);
    });

    test('Men and visitors never see the women branch; women never record',
        () async {
      final service = DataService();
      await service.init();

      final mens = service.addMosque(
          name: 'جامع الفتح', address: 'المزة', city: 'دمشق', gender: 'male');
      final token = service.issueWomenProvisionToken(mens.id)!;
      final offer = (await service.inspectWomenProvisionToken(token))!;
      final branch = (await service.redeemWomenProvisionToken(
        offer: offer,
        name: 'القسم النسائي - جامع الفتح',
        city: 'دمشق',
        address: 'المزة',
      ))!;

      // الجلسة الحالية نسائية: ترى الفرعين (فرعها والمسجد العام)
      expect(service.viewerBranch, equals('female'));
      expect(service.getVisibleMosques().map((m) => m.id), contains(branch.id));
      // ولا تسجّل أرشيفاً أبداً
      expect(service.canRecordArchive, isFalse);

      // جلسة الرجال: الفرع النسائي محجوب كلياً
      final adminSession = await service.verifyCode(mens.accessCode);
      expect(adminSession, isNotNull);
      expect(adminSession!.mosqueId, equals(mens.id));
      expect(service.viewerBranch, equals('male'));
      expect(service.canRecordArchive, isTrue);
      expect(
        service.getVisibleMosques().map((m) => m.id),
        isNot(contains(branch.id)),
      );

      // الزائر بلا جلسة يُعامل كفرع الرجال
      service.clearSession();
      expect(service.viewerBranch, equals('male'));
      expect(
        service.getVisibleMosques().map((m) => m.id),
        isNot(contains(branch.id)),
      );
    });

    test('Authentic Quran Progress calculation and deduplication', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد التوبة', address: 'المهاجرين', city: 'دمشق', gender: 'male');
      final sheikh = service.addSheikh(mosque.id, 'الشيخ سعيد', null);
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة الإتقان', sheikhId: sheikh.id);
      final student = service.addStudent(mosqueId: mosque.id, halaqaId: halaqa.id, fullName: 'عمر الفاروق', gender: 'male', phone: '0500000000', welcomePoints: 0);

      // Recite Al-Fatiha (Ayahs 1-7)
      service.recordRecitationBatch(
        studentId: student.id,
        halaqaId: halaqa.id,
        sheikhId: sheikh.id,
        sessionType: 'new_memorization',
        points: 10,
        items: [
          {
            'surahName': 'الفاتحة',
            'surahNumber': 1,
            'fromAyah': 1,
            'toAyah': 7,
            'juzNumber': 1,
          }
        ],
      );

      final keys = service.getStudentMemorizedAyahKeys(student.id);
      expect(keys.length, equals(7)); // 7 ayahs in Al-Fatiha

      // Reciting again awards points but does not duplicate unique ayahs
      service.recordRecitationBatch(
        studentId: student.id,
        halaqaId: halaqa.id,
        sheikhId: sheikh.id,
        sessionType: 'new_memorization',
        points: 10,
        items: [
          {
            'surahName': 'الفاتحة',
            'surahNumber': 1,
            'fromAyah': 1,
            'toAyah': 7,
            'juzNumber': 1,
          }
        ],
      );

      final keysAfterRepeat = service.getStudentMemorizedAyahKeys(student.id);
      expect(keysAfterRepeat.length, equals(7));

      // Overall progress
      final overall = service.getStudentOverallQuranProgress(student.id);
      expect(overall['totalAyahs'], equals(6236));
      expect(overall['memorizedAyahs'], equals(7));
    });

    test('Rewards claiming and cashier dispensation flow', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'جامع الهدى', address: 'الشعلان', city: 'دمشق', gender: 'male');
      final sheikh = service.addSheikh(mosque.id, 'الشيخ عاصم', null);
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة عاصم', sheikhId: sheikh.id);
      final student = service.addStudent(mosqueId: mosque.id, halaqaId: halaqa.id, fullName: 'ياسين أحمد', gender: 'male', phone: '0500000000', welcomePoints: 200);

      // Add reward
      final reward = service.addReward(mosqueId: mosque.id, title: 'مصحف مذهب', pointsCost: 150);

      // Claim reward
      final redemption = service.claimReward(studentId: student.id, rewardId: reward.id);
      expect(redemption, isNotNull);
      expect(redemption!.redemptionCode.startsWith('VCH-'), isTrue);
      expect(redemption.status, equals('pending'));

      // Cashier dispensation
      final result = service.dispenseReward(voucherCode: redemption.redemptionCode, cashierName: 'أمين المستودع');
      expect(result['success'], isTrue);
      expect(result['pointsDeducted'], equals(150));
      expect(result['remainingPoints'], equals(50));

      final updatedStudent = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updatedStudent.totalPoints, equals(50));
    });

    test('countsTowardsStatistics toggle controls statistical inclusion and points', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد النور', address: 'وسط البلد', city: 'عمان', gender: 'male');
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة بلال');
      final student = service.addStudent(mosqueId: mosque.id, halaqaId: halaqa.id, fullName: 'عمر الفاروق', gender: 'male', phone: '0500000000', welcomePoints: 100);

      // Record non-statistical Quran recitation
      service.recordRecitationBatch(
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionType: 'new_memorization',
        items: [
          {'surahName': 'الإخلاص', 'surahNumber': 112, 'fromAyah': 1, 'toAyah': 4, 'juzNumber': 30}
        ],
        points: 25,
        countsTowardsStatistics: false,
      );

      // Verify points were NOT added and memorized ayahs NOT counted towards progress
      var updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, equals(100)); // still 100
      var keys = service.getStudentMemorizedAyahKeys(student.id);
      expect(keys.length, equals(0)); // not in statistical keys

      // But record IS in the student history log
      final history = service.getStudentMemorizations(student.id);
      expect(history.length, equals(1));
      expect(history.first.countsTowardsStatistics, isFalse);

      // Now record statistical recitation
      service.recordRecitationBatch(
        studentId: student.id,
        halaqaId: halaqa.id,
        sessionType: 'new_memorization',
        items: [
          {'surahName': 'الفلق', 'surahNumber': 113, 'fromAyah': 1, 'toAyah': 5, 'juzNumber': 30}
        ],
        points: 30,
        countsTowardsStatistics: true,
      );

      updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, equals(130)); // 100 + 30
      keys = service.getStudentMemorizedAyahKeys(student.id);
      expect(keys.length, equals(5));
    });

    test('Course-specific rankings and track halaqa delegation filtering', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'جامع الإيمان', address: 'الميدان', city: 'دمشق', gender: 'male');
      final halaqa1 = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة 1');
      final halaqa2 = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة 2');

      final st1 = service.addStudent(mosqueId: mosque.id, halaqaId: halaqa1.id, fullName: 'طالب 1', gender: 'male', phone: '0500000000', welcomePoints: 50);
      final st2 = service.addStudent(mosqueId: mosque.id, halaqaId: halaqa2.id, fullName: 'طالب 2', gender: 'male', phone: '0500000000', welcomePoints: 200);

      // Intensive course
      final course = service.addIntensiveCourse(
        mosqueId: mosque.id,
        name: 'دورة صيفية مكثفة',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        studentIds: [st1.id, st2.id],
      );

      // Record course recitations: st1 earns 80 pts in course, st2 earns 20 pts in course
      service.recordRecitationBatch(
        studentId: st1.id,
        halaqaId: halaqa1.id,
        sessionType: 'new_memorization',
        items: [{'surahName': 'الناس', 'surahNumber': 114, 'fromAyah': 1, 'toAyah': 6, 'juzNumber': 30}],
        points: 80,
        courseId: course.id,
      );
      service.recordRecitationBatch(
        studentId: st2.id,
        halaqaId: halaqa2.id,
        sessionType: 'new_memorization',
        items: [{'surahName': 'الفلق', 'surahNumber': 113, 'fromAyah': 1, 'toAyah': 5, 'juzNumber': 30}],
        points: 20,
        courseId: course.id,
      );

      // General rankings: st2 has 220 (200 + 20), st1 has 130 (50 + 80) -> st2 is rank 1
      final generalRankings = service.getRankings(gender: 'male');
      expect(generalRankings.first['student'].id, equals(st2.id));

      // Course rankings: st1 has 80 pts in course, st2 has 20 pts in course -> st1 is rank 1!
      final courseRankings = service.getRankings(gender: 'male', courseId: course.id);
      expect(courseRankings.first['student'].id, equals(st1.id));
      expect(courseRankings.first['score'], equals(80));
      expect(courseRankings[1]['student'].id, equals(st2.id));
      expect(courseRankings[1]['score'], equals(20));

      // Tracks filtering by targetHalaqaIds
      final generalTrack = service.addRecitationTrack(
        mosqueId: mosque.id,
        name: 'متن عام لكل الحلقات',
        unitLabel: 'صفحة',
        totalUnits: 50,
        targetHalaqaIds: [], // general
      );
      final assignedTrack = service.addRecitationTrack(
        mosqueId: mosque.id,
        name: 'متن مخصص لحلقة 1',
        unitLabel: 'حديث',
        totalUnits: 40,
        targetHalaqaIds: [halaqa1.id], // assigned only to halaqa1
      );

      // For halaqa1: both tracks visible
      final tracksH1 = service.getRecitationTracks(halaqaId: halaqa1.id);
      expect(tracksH1.any((t) => t.id == generalTrack.id), isTrue);
      expect(tracksH1.any((t) => t.id == assignedTrack.id), isTrue);

      // For halaqa2: only generalTrack visible
      final tracksH2 = service.getRecitationTracks(halaqaId: halaqa2.id);
      expect(tracksH2.any((t) => t.id == generalTrack.id), isTrue);
      expect(tracksH2.any((t) => t.id == assignedTrack.id), isFalse);
    });

    test('Sheikh deletion immediately revokes active session and blocks event creation', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'مسجد عمر', address: 'وسط المدينة', city: 'دمشق', gender: 'male');
      final sheikh = service.addSheikh(mosque.id, 'الشيخ خالد', null);

      final sheikhSession = ActiveSession(
        role: 'sheikh',
        name: sheikh.fullName,
        code: sheikh.code,
        mosqueId: mosque.id,
        sheikhId: sheikh.id,
        mosqueName: mosque.name,
      );
      service.setRoleSession(sheikhSession);
      expect(service.hasRole('sheikh'), isTrue);

      // Sheikh can add event while active
      final ev = service.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'درس الفقه',
        description: 'شرح كتاب الطهارة',
        eventType: 'lesson',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(const Duration(days: 1)),
        organizerType: 'sheikh',
        organizerName: sheikh.fullName,
        sheikhId: sheikh.id,
      );
      expect(service.getCommunityEvents().any((e) => e.id == ev.id), isTrue);

      // Admin deletes the Sheikh
      service.deleteSheikh(sheikh.id);

      // Session MUST be revoked immediately
      expect(service.hasRole('sheikh'), isFalse);
      expect(service.getSessionForRole('sheikh'), isNull);
      expect(service.getSheikhs().any((s) => s.id == sheikh.id), isFalse);

      // Attempting to add event with deleted sheikh must throw StateError
      expect(
        () => service.addCommunityEvent(
          mosqueId: mosque.id,
          title: 'درس جديد بعد الحذف',
          description: 'محاولة اختراق',
          eventType: 'lesson',
          targetAudience: 'general',
          eventDateTime: DateTime.now().add(const Duration(days: 1)),
          organizerType: 'sheikh',
          organizerName: sheikh.fullName,
          sheikhId: sheikh.id,
        ),
        throwsA(isA<StateError>()),
      );

      // Deleting event removes it cleanly
      service.deleteCommunityEvent(ev.id);
      expect(service.getCommunityEvents().any((e) => e.id == ev.id), isFalse);
    });
  });
}
