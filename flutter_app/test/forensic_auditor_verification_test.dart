import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/data/repositories/repositories.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageDataSource localDataSource;
  late OfflineSyncQueueManager syncQueueManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localDataSource = LocalStorageDataSource();
    syncQueueManager = OfflineSyncQueueManager();
    await localDataSource.loadAllFromStorage();
    await syncQueueManager.loadQueue();
  });

  group('Forensic Audit 1: Smart Timing Detection (±30m Window)', () {
    test('Authentic timing window calculation for intensive course vs normal halaqa vs custom', () {
      final coursesRepo = CoursesRepositoryImpl(localDataSource, syncQueueManager);

      // Create a test Halaqa on Saturday (weekday 6) at Asr (16:00)
      final halaqa = Halaqa(
        id: 'hal-test-1',
        mosqueId: 'msq-1',
        name: 'حلقة النور',
        daysOfWeek: [6], // Saturday
        timingType: 'prayer_linked',
        prayerName: 'asr', // 16:00
      );
      localDataSource.halaqat.add(halaqa);

      // Create an intensive course on Saturday 10:00 to 12:00
      final course = IntensiveCourse(
        id: 'crs-test-1',
        mosqueId: 'msq-1',
        name: 'دورة الصيف المكثفة',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        halaqaIds: ['hal-test-1'],
        studentIds: ['std-1'],
        daysOfWeek: [6],
        startTime: '10:00',
        endTime: '12:00',
        countsTowardsQuranProgress: true,
        createdAt: DateTime.now(),
      );
      localDataSource.intensiveCourses.add(course);

      // 1. Saturday 2026-09-12 at 09:29 -> Outside buffer of course (10:00 - 30m = 09:30)
      final res1 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 9, 29),
      );
      expect(res1['mode'], 'custom');

      // 2. Saturday 2026-09-12 at 09:30 -> Inside buffer of course (10:00 - 30m)
      final res2 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 9, 30),
      );
      expect(res2['mode'], 'course');
      expect(res2['courseId'], 'crs-test-1');

      // 3. Saturday 2026-09-12 at 12:30 -> Inside buffer of course (12:00 + 30m)
      final res3 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 12, 30),
      );
      expect(res3['mode'], 'course');

      // 4. Saturday 2026-09-12 at 12:31 -> Outside buffer of course
      final res4 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 12, 31),
      );
      expect(res4['mode'], 'custom');

      // 5. Saturday 2026-09-12 at 15:30 -> Inside buffer of normal halaqa (16:00 - 30m)
      final res5 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 15, 30),
      );
      expect(res5['mode'], 'normal');

      // 6. Saturday 2026-09-12 at 18:30 -> Inside buffer of normal halaqa (16:00 + 2h + 30m = 18:30)
      final res6 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 18, 30),
      );
      expect(res6['mode'], 'normal');

      // 7. Saturday 2026-09-12 at 18:31 -> Outside buffer of normal halaqa
      final res7 = coursesRepo.detectSessionTimingMode(
        halaqaId: 'hal-test-1',
        studentId: 'std-1',
        currentTime: DateTime(2026, 9, 12, 18, 31),
      );
      expect(res7['mode'], 'custom');
    });
  });

  group('Forensic Audit 2: Authentic Quran 6,236 Ayahs & 30 Ajza Deduplication', () {
    test('Deduplicates repeated recitations and respects non-counting courses', () {
      final recitationRepo = RecitationRepositoryImpl(localDataSource, syncQueueManager);

      final student = Student(
        id: 'std-quran-1',
        mosqueId: 'msq-1',
        halaqaId: 'hal-1',
        fullName: 'عمر الفاروق',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-1001',
      );
      localDataSource.students.add(student);

      // Recite Al-Fatiha (1:1 to 1:7) three separate times
      recitationRepo.recordMemorization(
        studentId: 'std-quran-1',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'new_memorization',
        points: 10,
      );
      recitationRepo.recordMemorization(
        studentId: 'std-quran-1',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'review',
        points: 5,
      );
      recitationRepo.recordMemorization(
        studentId: 'std-quran-1',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'test',
        points: 15,
      );

      // Verify deduplication: exactly 7 unique keys
      final keys = recitationRepo.getStudentMemorizedAyahKeys('std-quran-1');
      expect(keys.length, 7);
      expect(keys, {'1:1', '1:2', '1:3', '1:4', '1:5', '1:6', '1:7'});

      // Now recite the rest of Juz 1 (Al-Baqarah 1 to 141)
      recitationRepo.recordMemorization(
        studentId: 'std-quran-1',
        surahName: 'البقرة',
        fromAyah: 1,
        toAyah: 141,
        juzNumber: 1,
        sessionType: 'new_memorization',
        points: 50,
      );

      final juz1Prog = recitationRepo.getStudentJuzProgress('std-quran-1', 1);
      expect(juz1Prog['memorizedAyahs'], 148);
      expect(juz1Prog['totalAyahs'], 148);
      expect(juz1Prog['progress'], 1.0);
      expect(juz1Prog['isCompleted'], true);

      final overall = recitationRepo.getStudentOverallQuranProgress('std-quran-1');
      expect(overall['memorizedAyahs'], 148);
      expect(overall['totalAyahs'], 6236);
      expect(overall['completedAjza'], 1);
      expect(overall['totalAjza'], 30);

      // Now add a course that does NOT count towards Quran progress
      final courseNoQuran = IntensiveCourse(
        id: 'crs-no-quran',
        mosqueId: 'msq-1',
        name: 'دورة خاصة غير محسوبة',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 5)),
        countsTowardsQuranProgress: false,
        createdAt: DateTime.now(),
      );
      localDataSource.intensiveCourses.add(courseNoQuran);

      recitationRepo.recordMemorization(
        studentId: 'std-quran-1',
        courseId: 'crs-no-quran',
        surahName: 'البقرة',
        fromAyah: 142,
        toAyah: 200,
        juzNumber: 2,
        sessionType: 'new_memorization',
        points: 20,
      );

      // Verify that ayahs 142-200 are NOT added to authentic memorized keys
      final keysAfterCourse = recitationRepo.getStudentMemorizedAyahKeys('std-quran-1');
      expect(keysAfterCourse.length, 148);
      expect(keysAfterCourse.contains('2:142'), false);
    });
  });

  group('Forensic Audit 3: Student Attendance Commitment Formula', () {
    test('Computes (present + late*0.5) / total * 100 exactly', () {
      final attendanceRepo = AttendanceRepositoryImpl(localDataSource, syncQueueManager);

      final student = Student(
        id: 'std-att-1',
        mosqueId: 'msq-1',
        halaqaId: 'hal-1',
        fullName: 'خالد بن الوليد',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-1002',
      );
      localDataSource.students.add(student);

      // 4 sessions: 2 present, 1 late, 1 absent
      attendanceRepo.recordAttendance(
        studentId: 'std-att-1',
        halaqaId: 'hal-1',
        sessionDate: '2026-09-01',
        status: 'present',
      );
      attendanceRepo.recordAttendance(
        studentId: 'std-att-1',
        halaqaId: 'hal-1',
        sessionDate: '2026-09-02',
        status: 'present',
      );
      attendanceRepo.recordAttendance(
        studentId: 'std-att-1',
        halaqaId: 'hal-1',
        sessionDate: '2026-09-03',
        status: 'late',
      );
      attendanceRepo.recordAttendance(
        studentId: 'std-att-1',
        halaqaId: 'hal-1',
        sessionDate: '2026-09-04',
        status: 'absent',
      );

      final summary = attendanceRepo.getStudentAttendanceSummary('std-att-1');
      expect(summary['total'], 4);
      expect(summary['present'], 2);
      expect(summary['late'], 1);
      expect(summary['absent'], 1);
      // (2 + 1*0.5)/4 * 100 = 2.5/4 * 100 = 62.5%
      expect(summary['attendanceRate'], '62.5');
    });
  });

  group('Forensic Audit 4: Rewards Bank Voucher VCH-XXXX & Cashier Dispensation', () {
    test('Generates VCH-XXXX, validates points, dispenses, and prevents duplicate dispensation', () {
      final rewardsRepo = RewardsRepositoryImpl(localDataSource, syncQueueManager);

      final student = Student(
        id: 'std-rew-1',
        mosqueId: 'msq-1',
        halaqaId: 'hal-1',
        fullName: 'سعد بن أبي وقاص',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-1003',
        totalPoints: 300,
      );
      localDataSource.students.add(student);

      final reward = rewardsRepo.addReward(
        mosqueId: 'msq-1',
        title: 'كتاب رياض الصالحين',
        pointsCost: 150,
      );

      // 1. Claim reward with sufficient points
      final redemption = rewardsRepo.claimReward(
        studentId: 'std-rew-1',
        rewardId: reward.id,
      );
      expect(redemption, isNotNull);
      expect(RegExp(r'^VCH-\d{4}$').hasMatch(redemption!.redemptionCode), true);
      expect(redemption.status, 'pending');
      expect(student.totalPoints, 300); // points deducted on dispensation

      // 2. Dispense voucher by cashier
      final dispResult = rewardsRepo.dispenseReward(
        voucherCode: redemption.redemptionCode,
        cashierName: 'أبو أحمد',
      );
      expect(dispResult['success'], true);
      expect(dispResult['remainingPoints'], 150);
      expect(student.totalPoints, 150);
      expect(redemption.status, 'dispensed');
      expect(redemption.cashierName, 'أبو أحمد');

      // Check points log has negative deduction
      final deductionLog = localDataSource.pointsLogs.firstWhere(
        (p) => p.studentId == 'std-rew-1' && p.category == 'reward',
      );
      expect(deductionLog.points, -150);

      // 3. Attempt to dispense again -> must fail
      final reDispResult = rewardsRepo.dispenseReward(
        voucherCode: redemption.redemptionCode,
        cashierName: 'أبو أحمد',
      );
      expect(reDispResult['success'], false);
      expect(reDispResult['message'], contains('مسبقاً'));

      // 4. Student with insufficient points cannot claim
      student.totalPoints = 50;
      final failedClaim = rewardsRepo.claimReward(
        studentId: 'std-rew-1',
        rewardId: reward.id,
      );
      expect(failedClaim, isNull);
    });
  });

  group('Forensic Audit 5: Custom Recitation Tracks & Unit Deduplication', () {
    test('Deduplicates units in custom curricula (e.g. Hadith/Mutun)', () {
      final tracksRepo = RecitationTracksRepositoryImpl(localDataSource, syncQueueManager);

      final student = Student(
        id: 'std-trk-1',
        mosqueId: 'msq-1',
        halaqaId: 'hal-1',
        fullName: 'معاذ بن جبل',
        gender: 'male',
        phone: '0500000000',
        code: 'STD-1004',
      );
      localDataSource.students.add(student);

      final track = tracksRepo.addRecitationTrack(
        mosqueId: 'msq-1',
        name: 'الأربعون النووية',
        category: 'hadith',
        unitLabel: 'حديث',
        totalUnits: 42,
        pointsPerUnit: 5,
      );

      // Recite Hadith 1 to 10
      tracksRepo.recordSubjectRecitation(
        studentId: 'std-trk-1',
        trackId: track.id,
        trackName: track.name,
        fromUnit: 1,
        toUnit: 10,
        pointsEarned: 50,
      );

      // Recite Hadith 5 to 15 (overlapping 5..10)
      tracksRepo.recordSubjectRecitation(
        studentId: 'std-trk-1',
        trackId: track.id,
        trackName: track.name,
        fromUnit: 5,
        toUnit: 15,
        pointsEarned: 25,
      );

      final prog = tracksRepo.getStudentSubjectProgress('std-trk-1', track.id);
      // Unique units 1..15 = 15 units
      expect(prog['uniqueUnitsCount'], 15);
      expect(prog['totalUnits'], 42);
      expect(prog['progress'], closeTo(15 / 42, 0.001));
      expect(prog['isCompleted'], false);
    });
  });

  group('Forensic Audit 6: Persistence & FIFO Sync Queue Integrity', () {
    test('Serializes collections and maintains FIFO queue in SharedPreferences', () async {
      localDataSource.mosques.add(Mosque(
        id: 'msq-persist',
        name: 'مسجد الفاروق',
        city: 'حلب',
        gender: 'male',
        accessCode: 'MSQ-9999',
      ));

      syncQueueManager.queueSync(
        table: 'mosques',
        action: 'upsert',
        data: {'id': 'msq-persist', 'name': 'مسجد الفاروق'},
      );

      expect(syncQueueManager.pendingQueue.length, 1);
      expect(syncQueueManager.pendingQueue.first['table'], 'mosques');
      expect(syncQueueManager.pendingQueue.first['action'], 'upsert');

      await localDataSource.saveToStorage();

      // Cold start reload simulation
      final newLocal = LocalStorageDataSource();
      final newQueue = OfflineSyncQueueManager();
      await newLocal.loadAllFromStorage();
      await newQueue.loadQueue();

      expect(newLocal.mosques.any((m) => m.id == 'msq-persist'), true);
      expect(newQueue.pendingQueue.length, 1);
      expect(newQueue.pendingQueue.first['table'], 'mosques');
    });
  });
}
